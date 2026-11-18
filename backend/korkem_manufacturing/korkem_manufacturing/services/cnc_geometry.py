"""Facade patterns as tool paths, and tool paths as G-code (owner, 18.11.2026).

Pure geometry — no Frappe, no database — so every rule here is a plain
function a test can call with numbers.

What the shops that do this well have in common, and what is taken from them:

- **A pattern is a template, the size is a parameter.** Vectric's toolpath
  templates and the parametric door libraries (Doors Plus) draw a style once
  and fit it to any door; the shop types only height and width. Here a
  pattern is a list of elements — frame, arch, grooves — each with its tool
  and depth, measured from the facade's edges, so «Классика» fits 718×500
  and 2000×500 alike.
- **A post-processor per machine.** CAM systems write one neutral program and
  translate it for the controller (КОМПАС «Модуль ЧПУ», Vectric's posts). The
  Chinese routers common here (Weihong NcStudio, Richauto DSP, Mach3) read
  plain ISO G-code; what differs is whether they take arcs, comments and line
  numbers and which extension they want. Those four are settings.
- **One file per tool.** These routers change tools by hand, so a pattern
  that needs two cutters is two programs, run one after the other.
- **Check before the machine does.** The size the pattern needs, a fallback
  for small facades, a cut that would leave the board, and the time it takes
  are all said before a file exists.

Coordinates: millimetres; origin at the facade's bottom-left corner, X along
its width, Y along its height (the machine can swap them); Z = 0 is the face,
cuts go below it.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

KINDS = ("frame", "arch", "grooves")
CORNERS = ("square", "round", "cove")
TOOL_KINDS = ("v", "ball", "flat")
DIRECTIONS = ("vertical", "horizontal")

#: How far a through groove starts and ends beyond the board, past the cutter.
THROUGH_CLEAR = 2.0
#: Arcs written as straight lines step at most this many degrees.
ARC_STEP_DEG = 3.0

TOOL_LIMITS = {"diameter": (1, 60), "angle": (10, 170), "feed": (100, 30000), "plunge": (50, 10000),
			   "rpm": (1000, 30000), "pass_depth": (0.2, 20)}
MACHINE_DEFAULT = {"ext": "nc", "comments": True, "arcs": True, "line_numbers": False, "safe_z": 20.0,
				   "clear_z": 3.0, "rapid": 6000.0, "dwell": 0.0, "swap_xy": False}
MACHINE_LIMITS = {"safe_z": (2, 200), "clear_z": (0.5, 50), "rapid": (500, 60000), "dwell": (0, 30)}
EXTENSIONS = ("nc", "tap", "gcode", "txt", "cnc")


class PatternError(ValueError):
	"""The pattern cannot be cut on this facade; the message says why, in Russian."""


# --------------------------------------------------------------------------
# Tools and paths
# --------------------------------------------------------------------------


@dataclass
class Tool:
	name: str
	kind: str = "v"
	diameter: float = 12.0
	angle: float = 90.0
	feed: float = 3000.0
	plunge: float = 1000.0
	rpm: float = 18000.0
	pass_depth: float = 3.0

	@classmethod
	def of(cls, name: str, card: dict) -> Tool:
		return cls(name=name, **{k: card[k] for k in ("kind", "diameter", "angle", "feed", "plunge", "rpm",
													  "pass_depth") if card.get(k) is not None})

	def width_at(self, depth: float) -> float:
		"""How wide the cut is at this depth — what the eye sees on the face."""
		if self.kind == "v":
			return min(2 * depth * math.tan(math.radians(self.angle / 2)), self.diameter)
		if self.kind == "ball":
			r = self.diameter / 2
			return self.diameter if depth >= r else 2 * math.sqrt(r * r - (r - depth) ** 2)
		return self.diameter


@dataclass
class Path:
	"""One cut: from `start` along `moves`, at `depth` below the face.

	A move is ``("L", x, y)`` or ``("A", x, y, cx, cy, cw)`` — an arc about
	(cx, cy) ending at (x, y), clockwise when `cw`.
	"""

	start: tuple[float, float]
	moves: list[tuple] = field(default_factory=list)
	closed: bool = True
	depth: float = 1.0
	tool: str = ""

	def points(self) -> list[tuple[float, float]]:
		"""The path as a polyline, arcs in short chords."""
		out = [self.start]
		x0, y0 = self.start
		for m in self.moves:
			if m[0] == "A":
				out.extend(_arc_points(x0, y0, *m[1:]))
			else:
				out.append((m[1], m[2]))
			x0, y0 = m[1], m[2]
		return out

	def length(self) -> float:
		pts = self.points()
		return sum(math.dist(a, b) for a, b in zip(pts, pts[1:], strict=False))


def _arc_sweep(x0, y0, x1, y1, cx, cy, cw) -> tuple[float, float, float]:
	a0 = math.atan2(y0 - cy, x0 - cx)
	a1 = math.atan2(y1 - cy, x1 - cx)
	sweep = a1 - a0
	if cw and sweep >= 0:
		sweep -= 2 * math.pi
	if not cw and sweep <= 0:
		sweep += 2 * math.pi
	return a0, sweep, math.hypot(x0 - cx, y0 - cy)


def _arc_points(x0, y0, x1, y1, cx, cy, cw) -> list[tuple[float, float]]:
	a0, sweep, r = _arc_sweep(x0, y0, x1, y1, cx, cy, cw)
	steps = max(2, math.ceil(abs(math.degrees(sweep)) / ARC_STEP_DEG))
	pts = [(cx + r * math.cos(a0 + sweep * i / steps), cy + r * math.sin(a0 + sweep * i / steps))
		   for i in range(1, steps)]
	return [*pts, (x1, y1)]


# --------------------------------------------------------------------------
# Elements: frame, arch, grooves
# --------------------------------------------------------------------------


def _num(element: dict, key: str, default: float | None = None) -> float:
	value = element.get(key, default)
	try:
		return float(value)
	except (TypeError, ValueError):
		raise PatternError(f"«{key}» — число в мм.") from None


def frame(w: float, h: float, offset: float, corner: str = "square", radius: float = 0.0) -> Path:
	"""A rectangle `offset` in from every edge; its corners square, rounded or
	cut inward (the classic facade's «вогнутый угол»)."""
	if corner not in CORNERS:
		raise PatternError("Угол рамки — прямой, скруглённый или вогнутый.")
	x0, y0, x1, y1 = offset, offset, w - offset, h - offset
	if offset <= 0 or x1 - x0 < 10 or y1 - y0 < 10:
		raise PatternError(f"Рамка с отступом {offset:g} мм не помещается на {w:g}×{h:g}.")
	r = radius if corner != "square" else 0.0
	if r < 0 or r * 2 >= min(x1 - x0, y1 - y0):
		raise PatternError(f"Радиус угла {r:g} мм больше, чем позволяет рамка {x1 - x0:g}×{y1 - y0:g}.")
	if r == 0:
		return Path(start=(x0, y0), moves=[("L", x1, y0), ("L", x1, y1), ("L", x0, y1), ("L", x0, y0)])
	cove = corner == "cove"

	def turn(x, y, cx, cy, ccx, ccy):
		# A round corner turns about the inner centre, a cove about the corner itself.
		return ("A", x, y, ccx, ccy, True) if cove else ("A", x, y, cx, cy, False)

	return Path(start=(x0 + r, y0), moves=[
		("L", x1 - r, y0), turn(x1, y0 + r, x1 - r, y0 + r, x1, y0),
		("L", x1, y1 - r), turn(x1 - r, y1, x1 - r, y1 - r, x1, y1),
		("L", x0 + r, y1), turn(x0, y1 - r, x0 + r, y1 - r, x0, y1),
		("L", x0, y0 + r), turn(x0 + r, y0, x0 + r, y0 + r, x0, y0),
	])


def arch(w: float, h: float, offset: float, rise: float) -> Path:
	"""A frame whose top is an arc rising `rise` mm in the middle."""
	x0, y0, x1, y1 = offset, offset, w - offset, h - offset
	chord = x1 - x0
	if offset <= 0 or chord < 10 or y1 - y0 < 10:
		raise PatternError(f"Арка с отступом {offset:g} мм не помещается на {w:g}×{h:g}.")
	if rise <= 0 or rise > chord / 2:
		raise PatternError(f"Подъём арки — от 1 до {chord / 2:g} мм (половина ширины рамки).")
	if y1 - rise - y0 < 10:
		raise PatternError(f"Арка с подъёмом {rise:g} мм не помещается по высоте {h:g}.")
	r = (chord * chord / 4 + rise * rise) / (2 * rise)
	cx, cy = w / 2, y1 - r
	return Path(start=(x0, y0), moves=[("L", x1, y0), ("L", x1, y1 - rise), ("A", x0, y1 - rise, cx, cy, False),
									   ("L", x0, y0)])


def grooves(w: float, h: float, direction: str, step: float, side: float, ends: float, tool_d: float) -> list[Path]:
	"""Parallel grooves («рифлёный»), `step` apart, centred across the facade
	within `side` of its edges; along it from edge to edge when `ends` is 0,
	else stopping `ends` short of them."""
	if direction not in DIRECTIONS:
		raise PatternError("Пазы — вертикальные или горизонтальные.")
	across, along = (w, h) if direction == "vertical" else (h, w)
	if step < tool_d or step <= 0:
		raise PatternError(f"Шаг пазов {step:g} мм меньше фрезы {tool_d:g} мм.")
	span = across - 2 * side
	if side < 0 or span < 0:
		raise PatternError(f"Отступ пазов {side:g} мм больше половины фасада.")
	n = int(span // step) + 1
	first = (across - (n - 1) * step) / 2
	if ends == 0:
		a0, a1 = -(tool_d / 2 + THROUGH_CLEAR), along + tool_d / 2 + THROUGH_CLEAR
	else:
		a0, a1 = ends, along - ends
		if ends < 0 or a1 - a0 < 10:
			raise PatternError(f"Пазы с отступом {ends:g} мм от торцов не помещаются.")
	paths = []
	for i in range(n):
		p = first + i * step
		s, e = (a0, a1) if i % 2 == 0 else (a1, a0)
		start, end = ((p, s), (p, e)) if direction == "vertical" else ((s, p), (e, p))
		paths.append(Path(start=start, moves=[("L", *end)], closed=False))
	return paths


def element_paths(element: dict, w: float, h: float, tools: dict[str, Tool]) -> list[Path]:
	kind = element.get("kind")
	tool = tools.get(element.get("tool") or "")
	if tool is None:
		raise PatternError(f"Нет фрезы «{element.get('tool') or ''}» — выберите фрезу для элемента.")
	depth = _num(element, "depth", 1)
	if not 0.1 <= depth <= 30:
		raise PatternError("Глубина — от 0,1 до 30 мм.")
	if kind == "frame":
		paths = [frame(w, h, _num(element, "offset", 50), element.get("corner") or "square",
					   _num(element, "radius", 0))]
	elif kind == "arch":
		paths = [arch(w, h, _num(element, "offset", 50), _num(element, "rise", 60))]
	elif kind == "grooves":
		paths = grooves(w, h, element.get("direction") or "vertical", _num(element, "step", 30),
						_num(element, "side", 0), _num(element, "ends", 0), tool.diameter)
	else:
		raise PatternError("Элемент узора — рамка, арка или пазы.")
	for p in paths:
		p.depth, p.tool = depth, tool.name
	return paths


def build(pattern: dict, w: float, h: float, tools: dict[str, Tool]) -> tuple[list[Path], list[str]]:
	"""Every cut of the pattern on a facade `w`×`h`, and what to look at."""
	if w < 50 or h < 50 or w > 3000 or h > 3000:
		raise PatternError("Фасад — от 50 до 3000 мм по каждой стороне.")
	elements = pattern.get("elements") or []
	if not elements:
		raise PatternError("В узоре нет ни одного элемента.")
	paths: list[Path] = []
	for element in elements:
		paths.extend(element_paths(element, w, h, tools))
	warnings = []
	for p in paths:
		half = tools[p.tool].width_at(p.depth) / 2
		inside = all(-0.01 <= x - half and x + half <= w + 0.01 and -0.01 <= y - half and y + half <= h + 0.01
					 for x, y in p.points())
		if p.closed and not inside:
			raise PatternError("Узор выходит за край фасада — увеличьте отступ.")
	for name in {p.tool for p in paths}:
		tool = tools[name]
		deepest = max(p.depth for p in paths if p.tool == name)
		if tool.kind == "v" and 2 * deepest * math.tan(math.radians(tool.angle / 2)) > tool.diameter + 0.01:
			warnings.append(f"Фреза «{name}» на глубине {deepest:g} мм режет всем диаметром — край будет прямым.")
	return paths, warnings


# --------------------------------------------------------------------------
# G-code
# --------------------------------------------------------------------------

_TRANSLIT = dict(zip("абвгдеёжзийклмнопрстуфхцчшщъыьэюяәғқңөұүһі",
					 ["a", "b", "v", "g", "d", "e", "e", "zh", "z", "i", "y", "k", "l", "m", "n", "o", "p", "r",
					  "s", "t", "u", "f", "h", "ts", "ch", "sh", "sch", "", "y", "", "e", "yu", "ya", "a", "g", "q",
					  "n", "o", "u", "u", "h", "i"], strict=True))


def ascii_comment(text: str) -> str:
	"""Controllers that read only ASCII choke on Cyrillic, so comments are spelt
	in Latin, and without the brackets that would close them early."""
	out = []
	for ch in text:
		low = ch.lower()
		if low in _TRANSLIT:
			t = _TRANSLIT[low]
			out.append(t.capitalize() if ch != low else t)
		elif ch in "()":
			out.append(" ")
		elif ord(ch) < 128:
			out.append(ch)
		elif ch == "×":
			out.append("x")
	return "".join(out).strip()


def _n(v: float) -> str:
	s = f"{v:.3f}".rstrip("0").rstrip(".")
	return "0" if s in ("-0", "") else s


@dataclass
class _Writer:
	machine: dict
	lines: list[str] = field(default_factory=list)
	x: float | None = None
	y: float | None = None
	blocks: int = 0

	def emit(self, block: str) -> None:
		self.blocks += 1
		if self.machine["line_numbers"]:
			block = f"N{self.blocks * 10} {block}"
		self.lines.append(block)

	def note(self, text: str) -> None:
		if self.machine["comments"] and (text := ascii_comment(text)):
			self.lines.append(f"({text})")

	def xy(self, x: float, y: float) -> str:
		if self.machine["swap_xy"]:
			x, y = y, x
		return f"X{_n(x)} Y{_n(y)}"

	def rapid(self, x: float, y: float) -> None:
		self.emit(f"G0 {self.xy(x, y)}")
		self.x, self.y = x, y

	def path(self, path: Path, feed: float) -> None:
		x0, y0 = path.start
		first = True
		for m in path.moves:
			tail = f" F{_n(feed)}" if first else ""
			if m[0] == "A" and self.machine["arcs"]:
				_, x1, y1, cx, cy, cw = m
				i, j = cx - x0, cy - y0
				if self.machine["swap_xy"]:
					i, j, cw = j, i, not cw
				self.emit(f"{'G2' if cw else 'G3'} {self.xy(x1, y1)} I{_n(i)} J{_n(j)}{tail}")
			elif m[0] == "A":
				for k, (px, py) in enumerate(_arc_points(x0, y0, *m[1:])):
					self.emit(f"G1 {self.xy(px, py)}{tail if k == 0 else ''}")
			else:
				self.emit(f"G1 {self.xy(m[1], m[2])}{tail}")
			first = False
			x0, y0 = m[1], m[2]
		self.x, self.y = x0, y0


def passes(depth: float, step: float) -> list[float]:
	n = max(1, math.ceil(depth / step - 1e-9))
	return [round(depth * k / n, 3) for k in range(1, n + 1)]


def gcode(paths: list[Path], tools: dict[str, Tool], machine: dict, title: str) -> list[dict]:
	"""One program per tool, in the order the pattern first uses them.

	Each: ``{"tool", "text", "stats"}``; the stats say the cut length, the
	passes and the minutes — feed for cutting, plunge feed down, the rapid
	speed for the moves in air.
	"""
	machine = {**MACHINE_DEFAULT, **(machine or {})}
	order: list[str] = []
	for p in paths:
		if p.tool not in order:
			order.append(p.tool)
	files = []
	for index, name in enumerate(order, 1):
		tool = tools[name]
		mine = [p for p in paths if p.tool == name]
		w = _Writer(machine)
		safe, clear = machine["safe_z"], machine["clear_z"]
		w.note(title)
		w.note(f"Freza {index}/{len(order)}: {name}, d{_n(tool.diameter)}"
			   + (f" V{_n(tool.angle)}" if tool.kind == "v" else ""))
		w.note("Nol: levyy nizhniy ugol fasada, Z0 - poverhnost" if not machine["swap_xy"]
			   else "Nol: levyy nizhniy ugol fasada, X - po vysote, Z0 - poverhnost")
		w.emit("G21 G90 G17")
		w.emit(f"G0 Z{_n(safe)}")
		w.emit(f"M3 S{int(tool.rpm)}")
		if machine["dwell"]:
			w.emit(f"G4 P{_n(machine['dwell'])}")
		cut = plunge = air = 0.0
		count = 0
		x, y = 0.0, 0.0
		for p in mine:
			depths = passes(p.depth, tool.pass_depth)
			count += len(depths)
			length = p.length()
			air += math.dist((x, y), p.start) + 2 * (safe - clear)
			w.rapid(*p.start)
			w.emit(f"G0 Z{_n(clear)}")
			for k, d in enumerate(depths):
				if not p.closed and k:
					w.emit(f"G0 Z{_n(clear)}")
					w.rapid(*p.start)
					air += length
				w.emit(f"G1 Z{_n(-d)} F{_n(tool.plunge)}")
				plunge += d + clear if (p.closed and k == 0) or not p.closed else d - depths[k - 1]
				w.path(p, tool.feed)
				cut += length
			w.emit(f"G0 Z{_n(safe)}")
			x, y = w.x or 0.0, w.y or 0.0
		w.emit("M5")
		w.emit(f"G0 {w.xy(0, 0)}")
		w.emit("M30")
		air += math.dist((x, y), (0, 0))
		minutes = cut / tool.feed + plunge / tool.plunge + air / machine["rapid"]
		files.append({"tool": name, "text": "\n".join(w.lines) + "\n",
					  "stats": {"cut_m": round(cut / 1000, 2), "passes": count, "minutes": round(minutes, 1)}})
	return files


def preview(paths: list[Path], tools: dict[str, Tool]) -> list[dict]:
	"""Each cut as points with the width it leaves — for the screen to draw."""
	return [{"tool": p.tool, "depth": p.depth, "width": round(tools[p.tool].width_at(p.depth), 2),
			 "closed": p.closed, "points": [[round(x, 2), round(y, 2)] for x, y in p.points()]} for p in paths]
