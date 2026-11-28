# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Sheet cutting on a panel saw with a manual fence — pure, no database.

Owner, 28.11.2026: the shop's форматно-раскроечный станок, the fence moved by
hand, the cut map on paper for now. What a panel saw can do decides the shape
of the layout, and it is not a CNC's:

**Guillotine, in strips.** A saw cut runs from edge to edge. The sheet is
drawn as it is set in the settings — its height going away from the sawyer —
and the first cuts run **along the height**, parting it into strips; each
strip is crosscut into segments; a segment holding two parts side by side is
parted again, and a part shorter than its segment is trimmed. Three stages
and a trim: what a manual saw does without turning a piece twice.

**The fence costs, not only the board.** On a manual saw a strip of a new
width is a fence moved and measured; one of the same width is a cut. So the
strips of one width are cut one after another, the segments of one height
likewise, and «упор ставят N раз» is counted and compared.

**The order of what matters** (owner, 28.11.2026): fewer sheets, then fewer
fence settings, then the larger offcut. Several layouts are made by different
rules and ranked by exactly that; the three best distinct ones are offered,
the first recommended.

**Sizes.** Every edge of the sheet is trimmed by `trim_mm` — a factory edge is
not straight, and nothing is measured from it. Between parts goes the saw's
`kerf_mm`. With `edge_deduct`, a banded side is cut short by its band's
thickness, so the part comes to its size with the band on.

What is left is an **offcut** when it is at least `min_offcut` either way
round — it goes to the shelf with a QR — and waste otherwise.
"""

from __future__ import annotations

from dataclasses import dataclass, field

#: How a layout is made — each a rule for which side of a part goes across,
#: and in what order parts are taken.
ORIENTATIONS = ("narrow", "wide", "as_is")
ORDERS = ("width", "height", "area", "same")


@dataclass(frozen=True)
class Piece:
	"""One part to cut — one of `qty` copies of an input row."""

	n: int  # the row's number, as the person entered it
	k: int  # which copy of it, from 1
	height: float  # cut size, along the sheet's height when not turned
	width: float
	rotate: bool
	edges: tuple[float, float, float, float] = (0, 0, 0, 0)  # top, bottom, left, right — as entered


@dataclass
class Placed:
	n: int
	k: int
	x: float
	y: float
	width: float  # as it lies: across the sheet
	height: float  # along the sheet's height
	rotated: bool
	edges: tuple[float, float, float, float]  # top, bottom, left, right — as it lies


@dataclass
class Segment:
	y: float
	height: float
	parts: list[Placed] = field(default_factory=list)


@dataclass
class Strip:
	x: float
	width: float
	segments: list[Segment] = field(default_factory=list)


@dataclass
class Sheet:
	strips: list[Strip] = field(default_factory=list)


def pieces(rows: list[dict], *, edge_deduct: bool = True) -> list[Piece]:
	"""An entered list — height, width, qty, rotate, edges — as pieces to cut."""
	out: list[Piece] = []
	for row in rows:
		edges = tuple(float(e or 0) for e in (list(row.get("edges") or []) + [0, 0, 0, 0])[:4])
		height, width = float(row["height"]), float(row["width"])
		if edge_deduct:
			height -= edges[0] + edges[1]
			width -= edges[2] + edges[3]
		for k in range(1, int(row.get("qty") or 1) + 1):
			out.append(Piece(int(row["n"]), k, height, width, bool(row.get("rotate", True)), edges))
	return out


def _ways(p: Piece, orientation: str) -> list[tuple[float, float, bool]]:
	"""A piece's (across, along, turned), the rule's preferred first."""
	ways = [(p.width, p.height, False)]
	if p.rotate and p.width != p.height:
		turned = (p.height, p.width, True)
		if orientation == "narrow":
			ways = sorted([ways[0], turned], key=lambda w: w[0])
		elif orientation == "wide":
			ways = sorted([ways[0], turned], key=lambda w: -w[0])
		else:
			ways.append(turned)
	return ways


def _key(order: str, orientation: str, counts: dict[float, int]):
	def key(p: Piece):
		across, along, _ = _ways(p, orientation)[0]
		if order == "height":
			return (-along, -across)
		if order == "area":
			return (-(across * along), -across)
		if order == "same":
			# Parts of a width there are many of first: one fence, many cuts.
			return (-counts.get(across, 0), -across, -along)
		return (-across, -along)

	return key


def _placed(p: Piece, x: float, y: float, way: tuple[float, float, bool]) -> Placed:
	across, along, turned = way
	top, bottom, left, right = p.edges
	edges = (left, right, top, bottom) if turned else (top, bottom, left, right)
	return Placed(p.n, p.k, x, y, across, along, turned, edges)


def _fill_sheet(left: list[Piece], used_w: float, used_h: float, kerf: float, orientation: str) -> tuple[Sheet, list[Piece]]:
	"""One sheet's strips, taking from `left` in its order; what did not go on."""
	sheet = Sheet()
	x = 0.0
	left = list(left)
	while left:
		room = used_w - x
		lead = None
		for i, p in enumerate(left):
			for way in _ways(p, orientation):
				if way[0] <= room and way[1] <= used_h:
					lead = (i, way)
					break
			if lead:
				break
		if lead is None:
			break
		strip = Strip(x=x, width=lead[1][0])
		y = 0.0
		while True:
			found = None
			for i, p in enumerate(left):
				fits = [w for w in _ways(p, orientation) if w[0] <= strip.width and w[1] <= used_h - y]
				if fits:
					# The way that fills the strip's width best.
					found = (i, max(fits, key=lambda w: (w[0], -w[1])))
					break
			if found is None:
				break
			i, way = found
			piece = left.pop(i)
			segment = Segment(y=y, height=way[1])
			segment.parts.append(_placed(piece, x, y, way))
			cx = way[0] + kerf
			while True:
				best = None
				for j, p in enumerate(left):
					for w in _ways(p, orientation):
						if w[0] <= strip.width - cx and w[1] <= segment.height:
							score = (w[1], w[0])
							if best is None or score > best[0]:
								best = (score, j, w)
				if best is None:
					break
				_, j, w = best
				segment.parts.append(_placed(left.pop(j), x + cx, y, w))
				cx += w[0] + kerf
			strip.segments.append(segment)
			y += segment.height + kerf
		sheet.strips.append(strip)
		x += strip.width + kerf
	return sheet, left


def _tidy(sheet: Sheet, kerf: float) -> Sheet:
	"""Strips of one width side by side, segments of one height one after
	another — the same layout, cut with fewer fence settings."""
	strips = sorted(sheet.strips, key=lambda s: -s.width)
	x = 0.0
	for strip in strips:
		segments = sorted(strip.segments, key=lambda s: -s.height)
		y = 0.0
		for seg in segments:
			cx = 0.0
			for part in seg.parts:
				part.x, part.y = x + cx, y
				cx += part.width + kerf
			seg.y = y
			y += seg.height + kerf
		strip.segments = segments
		strip.x = x
		x += strip.width + kerf
	sheet.strips = strips
	return sheet


def cuts(sheet: Sheet, sheet_h: float, sheet_w: float, trim: float, kerf: float) -> list[dict]:
	"""The sawyer's sequence: what to cut, against which fence, how long.

	`fence` is the rip fence's setting for a cut along the height, `stop` the
	crosscut stop's for a cut across; each is set once and kept while the next
	cut wants the same."""
	used_h = sheet_h - 2 * trim
	out: list[dict] = []
	if trim > 0:
		out.append({"kind": "trim", "along": True, "set": trim, "length": sheet_h})
		out.append({"kind": "trim", "along": False, "set": trim, "length": sheet_w})
	for strip in sheet.strips:
		out.append({"kind": "strip", "along": True, "set": strip.width, "length": used_h,
					"parts": [[p.n, p.k] for seg in strip.segments for p in seg.parts]})
		for seg in strip.segments:
			out.append({"kind": "cross", "along": False, "set": seg.height, "length": strip.width,
						"parts": [[p.n, p.k] for p in seg.parts]})
			rest = strip.width
			for part in seg.parts:
				if part.width < rest - 0.01:
					out.append({"kind": "split", "along": True, "set": part.width, "length": seg.height,
								"parts": [[part.n, part.k]]})
				rest -= part.width + kerf
				if part.height < seg.height - 0.01:
					out.append({"kind": "trim_part", "along": False, "set": part.height, "length": part.width,
								"parts": [[part.n, part.k]]})
	return out


def fence_settings(sequence: list[dict]) -> int:
	"""How many times a fence or the stop is set: the rip fence and the
	crosscut stop each kept while the next cut wants the same."""
	count, last = 0, {True: None, False: None}
	for cut in sequence:
		if cut["kind"] == "trim":
			continue
		if last[cut["along"]] != cut["set"]:
			count += 1
			last[cut["along"]] = cut["set"]
	return count


def leftovers(sheet: Sheet, used_h: float, used_w: float, kerf: float) -> list[dict]:
	"""What is left of a sheet, as pieces that come off it: beside a part, under
	a part, at a strip's end, and the column after the last strip."""
	out = []
	x_end = 0.0
	for strip in sheet.strips:
		y_end = 0.0
		for seg in strip.segments:
			cx = 0.0
			for part in seg.parts:
				if part.height < seg.height - kerf:
					out.append({"x": part.x, "y": part.y + part.height + kerf, "width": part.width,
								"height": seg.height - part.height - kerf})
				cx += part.width + kerf
			if strip.width - cx > 0:
				out.append({"x": strip.x + cx, "y": seg.y, "width": strip.width - cx, "height": seg.height})
			y_end = seg.y + seg.height + kerf
		if used_h - y_end > 0:
			out.append({"x": strip.x, "y": y_end, "width": strip.width, "height": used_h - y_end})
		x_end = strip.x + strip.width + kerf
	if used_w - x_end > 0:
		out.append({"x": x_end, "y": 0.0, "width": used_w - x_end, "height": used_h})
	return [r for r in out if r["width"] > 0.5 and r["height"] > 0.5]


def _keeps(rect: dict, min_offcut: tuple[float, float]) -> bool:
	a, b = min_offcut
	w, h = rect["width"], rect["height"]
	return (w >= a and h >= b) or (w >= b and h >= a)


@dataclass
class Plan:
	rule: str
	sheets: list[Sheet]
	too_big: list[Piece]
	fences: int
	offcut_area: float  # the largest offcut's, mm²
	waste_pct: float


def plan(rows: list[dict], *, sheet_h: float, sheet_w: float, kerf: float, trim: float,
		 min_offcut: tuple[float, float], edge_deduct: bool = True, rules: list[tuple[str, str]] | None = None,
		 limit_sheets: int = 200) -> list[Plan]:
	"""Every rule's layout of the parts, best first, distinct by result."""
	used_h, used_w = sheet_h - 2 * trim, sheet_w - 2 * trim
	if used_h <= 0 or used_w <= 0:
		raise ValueError("Обрезка края больше листа.")
	all_pieces = pieces(rows, edge_deduct=edge_deduct)
	too_big = [p for p in all_pieces
			   if p.height <= 0 or p.width <= 0
			   or not any(w[0] <= used_w and w[1] <= used_h for w in _ways(p, "as_is"))]
	cuttable = [p for p in all_pieces if p not in too_big]
	counts: dict[float, int] = {}
	for p in cuttable:
		across = _ways(p, "narrow")[0][0]
		counts[across] = counts.get(across, 0) + 1
	results: list[Plan] = []
	for orientation, order in rules or [(o, s) for o in ORIENTATIONS for s in ORDERS]:
		left = sorted(cuttable, key=_key(order, orientation, counts))
		sheets: list[Sheet] = []
		while left and len(sheets) < limit_sheets:
			sheet, rest = _fill_sheet(left, used_w, used_h, kerf, orientation)
			if len(rest) == len(left):
				break
			sheets.append(_tidy(sheet, kerf))
			left = rest
		fences = sum(fence_settings(cuts(s, sheet_h, sheet_w, trim, kerf)) for s in sheets)
		offcuts = [r for s in sheets[-1:] for r in leftovers(s, used_h, used_w, kerf) if _keeps(r, min_offcut)]
		area_parts = sum(p.width * p.height for p in cuttable)
		total = len(sheets) * sheet_h * sheet_w
		kept = sum(r["width"] * r["height"] for s in sheets for r in leftovers(s, used_h, used_w, kerf)
				   if _keeps(r, min_offcut))
		waste = (1 - (area_parts + kept) / total) * 100 if total else 0.0
		results.append(Plan(f"{orientation}/{order}", sheets, too_big, fences,
							max((r["width"] * r["height"] for r in offcuts), default=0.0), round(waste, 1)))
	results.sort(key=lambda p: (len(p.sheets), p.fences, -p.offcut_area, p.waste_pct, p.rule))
	distinct, seen = [], set()
	for p in results:
		sign = (len(p.sheets), p.fences, round(p.offcut_area), p.waste_pct)
		if sign not in seen:
			seen.add(sign)
			distinct.append(p)
	return distinct


def choices(plans: list[Plan]) -> list[tuple[str, Plan]]:
	"""Up to three layouts to choose from: the recommended one, the fewest
	fence settings, the largest offcut — each only when it is another."""
	if not plans:
		return []
	best = plans[0]
	out = [("best", best)]
	fewest = min(plans, key=lambda p: (p.fences, len(p.sheets), -p.offcut_area))
	if fewest is not best:
		out.append(("fences", fewest))
	largest = max(plans, key=lambda p: (p.offcut_area, -len(p.sheets), -p.fences))
	if all(largest is not p for _, p in out):
		out.append(("offcut", largest))
	return out


def as_dict(p: Plan, *, sheet_h: float, sheet_w: float, kerf: float, trim: float,
			min_offcut: tuple[float, float]) -> dict:
	"""A plan as the screen and the print read it."""
	used_h, used_w = sheet_h - 2 * trim, sheet_w - 2 * trim
	sheets = []
	for s in p.sheets:
		rest = leftovers(s, used_h, used_w, kerf)
		sequence = cuts(s, sheet_h, sheet_w, trim, kerf)
		sheets.append({
			"parts": [vars(part) | {"edges": list(part.edges)}
					  for strip in s.strips for seg in strip.segments for part in seg.parts],
			"strips": [{"x": st.x, "width": st.width} for st in s.strips],
			"offcuts": [r for r in rest if _keeps(r, min_offcut)],
			"waste": [r for r in rest if not _keeps(r, min_offcut)],
			"cuts": sequence,
			"fences": fence_settings(sequence),
		})
	return {
		"rule": p.rule,
		"sheets": sheets,
		"fences": p.fences,
		"waste_pct": p.waste_pct,
		"too_big": sorted({piece.n for piece in p.too_big}),
	}
