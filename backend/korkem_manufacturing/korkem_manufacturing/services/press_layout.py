# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Facades laid out on the membrane-vacuum press, and the film that takes.

Film is not used by the square metre. It is used by the **press load**: the
film is ordered as one of the press's sections — 1.1, 2.1 or the whole 3.1 m
on the shop's Yellow 3013 — however full that section turns out to be. So
the film an order needs is the sum of its loads, and its loads come from a
layout of its facades on the press table, as the shop has done by hand in
cutting2 until now.

**The layout.** For each film decor of an order, its facades (both faces of a
double-sided one) are placed on the table's working area — less a margin at
the edge, with a gap between parts, all in the company's settings. A **plain
film** may be turned 90°; a **textured** one may not («Текстурная» on the
film's card): its parts keep the order's orientation — width along the table,
height across — so the texture runs the same way on every facade.

**The section.** Each load takes the shortest section that holds what is left.
What does not fit even the whole table goes on another load. A facade larger
than the table is reported, never squeezed.

The packing is MaxRects with the best-short-side rule — what cutting tools
use — on parts grown by the gap, in a bin grown by the gap. It is good, not
optimal; the press operator sees the map and may lay it better, and the
metres can be corrected by hand with a reason (`set_film_metres`).

Who may change the settings: the people who keep the material norms.
"""

from __future__ import annotations

import hashlib
import json
import random
from dataclasses import dataclass, field

import frappe
from frappe.utils import cint, flt, get_fullname, now_datetime

from korkem_manufacturing.services import audit, facade_prices, material_stock
from korkem_manufacturing.services.scope import current_company, ensure_company

NORMS = "Facade Material Norms"
OVERRIDE = "Facade Film Metres"
#: The shop's Yellow 3013: working area inside, and its sections — film ordered
#: (m) against the working length it gives (mm). Measured on the shop's press
#: by the owner, 30.10.2026 — the area facades can be laid on, per section:
#: 3,1 m → 2 750 × 1 150, 2,1 m → 1 700 × 1 150, 1,1 m → 850 × 1 150 mm.
#: Those are already the usable sizes, so the default margin is 0; the gap
#: between facades stays the shop's 60 mm. All of it is editable in the
#: press settings.
DEFAULT_PRESS = {
	"press_length_mm": 2750,
	"press_width_mm": 1150,
	"press_margin_mm": 0,
	"press_gap_mm": 60,
	"press_sections": [
		{"film_m": 1.1, "length_mm": 850},
		{"film_m": 2.1, "length_mm": 1700},
		{"film_m": 3.1, "length_mm": 2750},
	],
}


# --------------------------------------------------------------------------
# The packing — pure, no database
# --------------------------------------------------------------------------


@dataclass
class Part:
	pos: int
	width: int
	height: int


@dataclass
class Placed:
	pos: int
	x: int
	y: int
	width: int
	height: int
	rotated: bool


@dataclass
class Load:
	film_m: float
	length_mm: int
	placed: list[Placed] = field(default_factory=list)


#: The orders the smart layout tries the parts in first, before shuffles.
_ORDERS = (
	lambda p: (p.width * p.height, max(p.width, p.height)),
	lambda p: max(p.width, p.height),
	lambda p: p.width,
	lambda p: p.height,
	lambda p: p.width + p.height,
)
#: How many orders of the parts the smart layout tries, at most: fewer for a
#: big order, so a card of 200 facades still opens at once.
SEARCH_WORK = 6000
SEARCH_TRIES = 300


def plan(parts: list[Part], press: dict, rotate: bool) -> tuple[list[Load], list[Part]]:
	"""Loads for `parts`, shortest section each time; and the parts no load can take."""
	left = sorted(parts, key=_ORDERS[0], reverse=True)
	return _plan_in_order(left, press, rotate)


def best_plan(parts: list[Part], press: dict, rotate: bool, effort: int = 1) -> tuple[list[Load], list[Part]]:
	"""The plain layout, and then the parts in other orders — by size, by length,
	by width, then shuffled — keeping the layout that takes the least film,
	then the fewest loads (owner, 12.11.2026: «умный перебор»). The same parts
	always give the same layout: the shuffles are seeded by the parts.
	`effort` multiplies the tries — «Максимум» on the press panel."""
	best, too_big = plan(parts, press, rotate)
	fit = [p for p in parts if p not in too_big]
	if len(fit) < 2:
		return best, too_big
	cost = _cost(best)
	tries = max(len(_ORDERS), min(SEARCH_TRIES * effort, SEARCH_WORK * effort // len(fit)))
	shuffle = random.Random(";".join(f"{p.pos}:{p.width}x{p.height}" for p in sorted(fit, key=_key)))
	for t in range(1, tries):
		if t < len(_ORDERS):
			order = sorted(fit, key=_ORDERS[t], reverse=True)
		else:
			order = shuffle.sample(fit, len(fit))
		loads, _ = _plan_in_order(order, press, rotate)
		if _cost(loads) < cost:
			best, cost = loads, _cost(loads)
	# Load by load: of a few orders of what is left, the one that fills the
	# table most — and the last load in the shortest section any order fits.
	loads = _plan_filling(fit, press, rotate, shuffle, max(3, min(30 * effort, SEARCH_WORK * effort // 2 // len(fit))))
	if _cost(loads) < cost:
		best = loads
	return best, too_big


def _plan_filling(fit: list[Part], press: dict, rotate: bool, shuffle: random.Random, k: int) -> list[Load]:
	sections = sorted(press["press_sections"], key=lambda s: flt(s["length_mm"]))
	margin, gap, width = cint(press["press_margin_mm"]), cint(press["press_gap_mm"]), cint(press["press_width_mm"])
	whole = sections[-1]
	left = list(fit)
	loads: list[Load] = []
	while left:
		orders = [sorted(left, key=o, reverse=True) for o in _ORDERS] + [shuffle.sample(left, len(left)) for _ in range(k)]
		chosen = None
		for section in sections:
			for order in orders:
				placed, rest = _pack(order, cint(section["length_mm"]) - 2 * margin, width - 2 * margin, gap, rotate)
				if not rest:
					chosen = (section, placed, rest)
					break
			if chosen:
				break
		if chosen is None:
			most = None
			for order in orders:
				placed, rest = _pack(order, cint(whole["length_mm"]) - 2 * margin, width - 2 * margin, gap, rotate)
				area = sum(p.width * p.height for p in placed)
				if most is None or area > most[0]:
					most = (area, placed, rest)
			chosen = (whole, most[1], most[2])
		section, placed, rest = chosen
		if not placed:
			break
		loads.append(Load(
			film_m=flt(section["film_m"]),
			length_mm=cint(section["length_mm"]),
			placed=[Placed(p.pos, p.x + margin, p.y + margin, p.width, p.height, p.rotated) for p in placed],
		))
		left = rest
	return loads if not left else [Load(film_m=1e9, length_mm=0, placed=[])]


def _key(p: Part) -> tuple:
	return (p.pos, p.width, p.height)


def _cost(loads: list[Load]) -> tuple:
	return (round(sum(load.film_m for load in loads), 2), len(loads))


def _plan_in_order(left: list[Part], press: dict, rotate: bool) -> tuple[list[Load], list[Part]]:
	"""Loads for `left`, packed in the order given."""
	sections = sorted(press["press_sections"], key=lambda s: flt(s["length_mm"]))
	margin, gap, width = cint(press["press_margin_mm"]), cint(press["press_gap_mm"]), cint(press["press_width_mm"])
	whole = sections[-1]
	too_big = [p for p in left if not _fits(p, cint(whole["length_mm"]) - 2 * margin, width - 2 * margin, rotate)]
	left = [p for p in left if p not in too_big]
	loads: list[Load] = []
	while left:
		chosen = None
		for section in sections:
			placed, rest = _pack(left, cint(section["length_mm"]) - 2 * margin, width - 2 * margin, gap, rotate)
			if not rest:
				chosen = (section, placed, rest)
				break
		if chosen is None:
			placed, rest = _pack(left, cint(whole["length_mm"]) - 2 * margin, width - 2 * margin, gap, rotate)
			chosen = (whole, placed, rest)
		section, placed, rest = chosen
		loads.append(
			Load(
				film_m=flt(section["film_m"]),
				length_mm=cint(section["length_mm"]),
				placed=[Placed(p.pos, p.x + margin, p.y + margin, p.width, p.height, p.rotated) for p in placed],
			)
		)
		left = rest
	return loads, too_big


def _fits(part: Part, length: int, width: int, rotate: bool) -> bool:
	return (part.width <= length and part.height <= width) or (rotate and part.height <= length and part.width <= width)


def _pack(parts: list[Part], length: int, width: int, gap: int, rotate: bool) -> tuple[list[Placed], list[Part]]:
	"""MaxRects, best short side fit. Parts and bin grow by the gap, so the gap
	sits between parts and not at the far edges."""
	free = [(0, 0, length + gap, width + gap)]
	placed: list[Placed] = []
	rest: list[Part] = []
	for part in parts:
		best = None
		for fx, fy, fw, fh in free:
			for w, h, turned in ((part.width, part.height, False), (part.height, part.width, True)):
				if turned and (not rotate or part.width == part.height):
					continue
				gw, gh = w + gap, h + gap
				if gw <= fw and gh <= fh:
					score = (min(fw - gw, fh - gh), max(fw - gw, fh - gh), fy, fx)
					if best is None or score < best[0]:
						best = (score, fx, fy, w, h, turned)
		if best is None:
			rest.append(part)
			continue
		_, x, y, w, h, turned = best
		placed.append(Placed(part.pos, x, y, w, h, turned))
		free = _split(free, (x, y, w + gap, h + gap))
	return placed, rest


def _split(free: list[tuple], used: tuple) -> list[tuple]:
	ux, uy, uw, uh = used
	result = []
	for fx, fy, fw, fh in free:
		if ux >= fx + fw or ux + uw <= fx or uy >= fy + fh or uy + uh <= fy:
			result.append((fx, fy, fw, fh))
			continue
		if ux > fx:
			result.append((fx, fy, ux - fx, fh))
		if ux + uw < fx + fw:
			result.append((ux + uw, fy, fx + fw - (ux + uw), fh))
		if uy > fy:
			result.append((fx, fy, fw, uy - fy))
		if uy + uh < fy + fh:
			result.append((fx, uy + uh, fw, fy + fh - (uy + uh)))
	# Drop rectangles contained in another: they add nothing but work.
	return [
		r for i, r in enumerate(result)
		if not any(
			j != i and o[0] <= r[0] and o[1] <= r[1] and o[0] + o[2] >= r[0] + r[2] and o[1] + o[3] >= r[1] + r[3]
			and (o != r or j < i)
			for j, o in enumerate(result)
		)
	]


# --------------------------------------------------------------------------
# Settings
# --------------------------------------------------------------------------


def press_settings(company: str | None = None) -> dict:
	company = company or current_company()
	row = frappe.db.get_value(NORMS, company, list(DEFAULT_PRESS), as_dict=True) if frappe.db.exists(NORMS, company) else None
	# An Int field reads 0 when never set, and a gap or margin of 0 is a real
	# choice: the press is «saved» once its length is, and then read as stored.
	saved = bool(row and cint(row.press_length_mm) > 0)
	result = {}
	for key, default in DEFAULT_PRESS.items():
		value = row.get(key) if saved else None
		if key == "press_sections":
			result[key] = _sections(value) or default
		else:
			result[key] = cint(value) if saved else default
	result["can_edit"] = material_stock.can_edit()
	return result


def save_press_settings(**values) -> dict:
	if not material_stock.can_edit():
		frappe.throw("Настройки пресса меняют администратор и менеджеры.", frappe.PermissionError)
	company = current_company()
	doc = frappe.get_doc(NORMS, company) if frappe.db.exists(NORMS, company) else frappe.new_doc(NORMS)
	doc.company = company
	before = press_settings(company)
	for key in ("press_length_mm", "press_width_mm", "press_margin_mm", "press_gap_mm"):
		doc.set(key, before[key])
		if values.get(key) not in (None, ""):
			number = cint(values[key])
			if number < 0 or (key in ("press_length_mm", "press_width_mm") and number < 100):
				frappe.throw("Размеры пресса — в миллиметрах, больше 100; зазор и отступ — не меньше нуля.")
			doc.set(key, number)
	doc.set("press_sections", json.dumps(before["press_sections"], ensure_ascii=False))
	if values.get("press_sections") not in (None, ""):
		sections = _sections(values["press_sections"])
		if not sections:
			frappe.throw("Секции — список «метров плёнки : рабочая длина, мм», хотя бы одна.")
		longest = cint(values.get("press_length_mm") or before["press_length_mm"])
		if any(s["length_mm"] > longest for s in sections):
			frappe.throw("Рабочая длина секции не может быть больше стола.")
		doc.set("press_sections", json.dumps(sections, ensure_ascii=False))
	doc.save(ignore_permissions=True)
	audit.record_audit(
		action="stock.press_settings_saved", entity_type=NORMS, entity_id=company,
		diff={"before": {k: before[k] for k in DEFAULT_PRESS}, "after": {k: press_settings(company)[k] for k in DEFAULT_PRESS}},
	)
	return press_settings(company)


def _sections(raw) -> list[dict] | None:
	if raw in (None, ""):
		return None
	if isinstance(raw, str):
		try:
			raw = json.loads(raw)
		except ValueError:
			return None
	if not isinstance(raw, list):
		return None
	sections = []
	for item in raw:
		if not isinstance(item, dict):
			return None
		film_m, length = flt(item.get("film_m")), cint(item.get("length_mm"))
		if film_m <= 0 or length <= 0:
			return None
		sections.append({"film_m": round(film_m, 2), "length_mm": length})
	return sorted(sections, key=lambda s: s["length_mm"]) or None


# --------------------------------------------------------------------------
# An order's layouts
# --------------------------------------------------------------------------


def order_layout(sales_order: str) -> dict:
	"""Per film decor: the loads on the press, the metres, and the correction if any."""
	ensure_company("Sales Order", sales_order)
	order = frappe.db.get_value("Sales Order", sales_order, ["company", "customer_name", "customer"], as_dict=True)
	press = press_settings(order.company)
	groups = _parts_by_decor(sales_order)
	corrections = {
		r.decor: r
		for r in frappe.get_all(OVERRIDE, filters={"sales_order": sales_order},
								fields=["decor", "film_m", "reason", "modified_by", "layout_json", "parts_key"])
	}
	films = []
	for decor, parts in groups.items():
		textured = is_textured(decor, order.company)
		loads, too_big = best_plan(parts, press, rotate=not textured)
		layout_m = round(sum(load.film_m for load in loads), 2)
		# What the plain layout would take — the smart one's saving is shown.
		plain_m = round(sum(load.film_m for load in plan(parts, press, rotate=not textured)[0]), 2)
		fix = corrections.get(decor)
		# A layout a person made (owner, 12.11.2026) holds while the parts are
		# the ones it was made for; the order changed — it is the press's again.
		manual = None
		if fix and fix.layout_json:
			manual = _stored_loads(fix.layout_json) if fix.parts_key == parts_key(parts) else None
			if manual is None:
				fix = None
			else:
				loads = manual
		films.append(
			{
				"decor": decor,
				"title": f"№{sales_order} {order.customer_name or order.customer} {decor}",
				"textured": textured,
				"layout_m": layout_m,
				"plain_m": plain_m,
				"film_m": flt(fix.film_m) if fix else layout_m,
				"corrected": bool(fix),
				"manual": manual is not None,
				"reason": fix.reason if fix else None,
				"loads": [
					{
						"film_m": load.film_m,
						"length_mm": load.length_mm,
						"placed": [vars(p) for p in load.placed],
					}
					for load in loads
				],
				"too_big": [p.pos for p in too_big],
			}
		)
	return {
		"sales_order": sales_order,
		"press": {k: press[k] for k in DEFAULT_PRESS},
		"films": films,
		"can_correct": material_stock.can_edit(),
		"approved": approval(sales_order, groups),
	}


# --------------------------------------------------------------------------
# A layout made by hand, and the manager's «проверено» (owner, 12.11.2026)
# --------------------------------------------------------------------------

_APPROVED = "korkem_press_approved"


def parts_key(parts: list[Part]) -> str:
	"""What the parts are — a layout made for them holds only while it is so."""
	return _digest(";".join(sorted(f"{p.pos}:{p.width}x{p.height}" for p in parts)))


def _order_key(groups: dict[str, list[Part]]) -> str:
	return _digest("|".join(f"{d}={parts_key(ps)}" for d, ps in sorted(groups.items())))


def _digest(text: str) -> str:
	return hashlib.sha1(text.encode()).hexdigest()[:16]


def _stored_loads(raw: str) -> list[Load] | None:
	try:
		rows = json.loads(raw)
		return [
			Load(film_m=flt(r["film_m"]), length_mm=cint(r["length_mm"]),
				 placed=[Placed(cint(p["pos"]), cint(p["x"]), cint(p["y"]), cint(p["width"]), cint(p["height"]),
								bool(p.get("rotated"))) for p in r["placed"]])
			for r in rows
		]
	except (ValueError, KeyError, TypeError):
		return None


def check_layout(parts: list[Part], loads, press: dict, rotate: bool) -> list[Load]:
	"""A layout a person made, checked: every part once, each on the table of
	its load's section, none nearer another than the gap, none turned when
	the film is textured. The section of a load is the shortest that holds it
	unless a longer one is named."""
	if isinstance(loads, str):
		loads = json.loads(loads)
	if not isinstance(loads, list) or not loads:
		frappe.throw("Раскладка пустая.")
	sections = sorted(press["press_sections"], key=lambda s: flt(s["length_mm"]))
	margin, gap, width = cint(press["press_margin_mm"]), cint(press["press_gap_mm"]), cint(press["press_width_mm"])
	left: dict[int, list[Part]] = {}
	for p in parts:
		left.setdefault(p.pos, []).append(p)
	result: list[Load] = []
	for n, row in enumerate(loads, 1):
		placed: list[Placed] = []
		for item in (row or {}).get("placed") or []:
			pos = cint(item.get("pos"))
			if not left.get(pos):
				frappe.throw(f"Загрузка {n}: позиции {pos} в заказе нет или она уже разложена.")
			part = left[pos].pop()
			rotated = bool(item.get("rotated"))
			if rotated and not rotate:
				frappe.throw(f"Загрузка {n}: текстурную плёнку не поворачивают (позиция {pos}).")
			w, h = (part.height, part.width) if rotated else (part.width, part.height)
			x, y = cint(item.get("x")), cint(item.get("y"))
			if x < margin or y < margin or y + h > width - margin:
				frappe.throw(f"Загрузка {n}: позиция {pos} выходит за край стола.")
			for o in placed:
				apart_x = x >= o.x + o.width + gap or o.x >= x + w + gap
				apart_y = y >= o.y + o.height + gap or o.y >= y + h + gap
				if not (apart_x or apart_y):
					frappe.throw(f"Загрузка {n}: позиции {pos} и {o.pos} ближе {gap} мм друг к другу.")
			placed.append(Placed(pos, x, y, w, h, rotated))
		if not placed:
			continue
		reach = max(p.x + p.width for p in placed) + margin
		asked = cint((row or {}).get("length_mm"))
		section = next((s for s in sections if cint(s["length_mm"]) >= max(reach, asked)), None)
		if section is None:
			frappe.throw(f"Загрузка {n}: детали выходят за край стола.")
		result.append(Load(film_m=flt(section["film_m"]), length_mm=cint(section["length_mm"]), placed=placed))
	missing = sorted(pos for pos, ps in left.items() if ps)
	if missing:
		frappe.throw("Не разложены позиции: " + ", ".join(str(m) for m in missing) + ".")
	if not result:
		frappe.throw("Раскладка пустая.")
	return result


def save_layout(sales_order: str, decor: str, loads=None, press=None) -> dict:
	"""Keep a layout a person made for one film of an order — its metres are
	the order's from now on; empty — back to the press's own layout. `press`
	— the press panel's own figures for this order alone (a wider gap for
	thick facades): the layout is checked against them, not the press's."""
	if not material_stock.can_edit():
		frappe.throw("Раскладку меняют администратор и менеджеры.", frappe.PermissionError)
	ensure_company("Sales Order", sales_order)
	decor = (decor or "").strip()
	parts = _parts_by_decor(sales_order).get(decor)
	if not parts:
		frappe.throw(f"В заказе нет плёнки «{decor}».")
	existing = frappe.db.get_value(OVERRIDE, {"sales_order": sales_order, "decor": decor}, "name")
	if loads in (None, "", []):
		if existing:
			frappe.delete_doc(OVERRIDE, existing, ignore_permissions=True)
		audit.record_audit(action="stock.press_layout_cleared", entity_type="Sales Order", entity_id=sales_order,
						   diff={"decor": decor})
		return order_layout(sales_order)
	company = frappe.db.get_value("Sales Order", sales_order, "company")
	checked = check_layout(parts, loads, tuned_press(press_settings(company), press),
						   rotate=not is_textured(decor, company))
	metres = round(sum(load.film_m for load in checked), 2)
	doc = frappe.get_doc(OVERRIDE, existing) if existing else frappe.new_doc(OVERRIDE)
	doc.update({
		"sales_order": sales_order, "decor": decor, "film_m": metres, "reason": "своя раскладка",
		"parts_key": parts_key(parts),
		"layout_json": json.dumps([{"film_m": load.film_m, "length_mm": load.length_mm,
									"placed": [vars(p) for p in load.placed]} for load in checked]),
	})
	doc.save(ignore_permissions=True)
	audit.record_audit(action="stock.press_layout_saved", entity_type="Sales Order", entity_id=sales_order,
					   diff={"decor": decor, "film_m": metres, "loads": len(checked)})
	return order_layout(sales_order)


# --------------------------------------------------------------------------
# The press panel: what-if, before anything is kept (owner, 13.11.2026)
# --------------------------------------------------------------------------

#: How hard the layout looks: one order of the parts; the smart search; five
#: times the smart search.
LEVELS = {"fast": 0, "smart": 1, "max": 5}
#: How parts lie: as the layout finds best; the long side along the table;
#: the long side across it.
DIRECTIONS = ("any", "along", "across")


def tuned_press(base: dict, tuned) -> dict:
	"""The press with the panel's figures over it, checked as the press's
	own settings are — nothing is kept."""
	if isinstance(tuned, str):
		tuned = json.loads(tuned) if tuned.strip() else None
	if not tuned:
		return base
	if not isinstance(tuned, dict):
		frappe.throw("Настройки пресса — не те.")
	result = dict(base)
	for key in ("press_length_mm", "press_width_mm", "press_margin_mm", "press_gap_mm"):
		if tuned.get(key) not in (None, ""):
			number = cint(tuned[key])
			if number < 0 or (key in ("press_length_mm", "press_width_mm") and number < 100):
				frappe.throw("Размеры пресса — в миллиметрах, больше 100; зазор и отступ — не меньше нуля.")
			result[key] = number
	if tuned.get("press_sections") not in (None, ""):
		sections = _sections(tuned["press_sections"])
		if not sections:
			frappe.throw("Секции — список «метров плёнки : рабочая длина, мм», хотя бы одна.")
		result["press_sections"] = sections
	if any(s["length_mm"] > result["press_length_mm"] for s in result["press_sections"]):
		frappe.throw("Рабочая длина секции не может быть больше стола.")
	return result


def preview(sales_order: str, decor: str, press=None, level: str = "smart", direction: str = "any",
			rotate=True) -> dict:
	"""One film of an order laid out with the panel's figures: the loads, the
	metres, and the metres it takes now — to compare. Nothing is kept."""
	ensure_company("Sales Order", sales_order)
	company = frappe.db.get_value("Sales Order", sales_order, "company")
	decor = (decor or "").strip()
	parts = _parts_by_decor(sales_order).get(decor)
	if not parts:
		frappe.throw(f"В заказе нет плёнки «{decor}».")
	if level not in LEVELS:
		frappe.throw("Уровень расчёта — быстрый, умный или максимум.")
	if direction not in DIRECTIONS:
		frappe.throw("Укладка — как выгоднее, вдоль или поперёк.")
	tuned = tuned_press(press_settings(company), press)
	textured = is_textured(decor, company)
	turn = not textured and str(rotate).lower() not in ("0", "false", "")
	# Laid one way: each part turned so its long side runs as asked, and
	# then not turned again. A textured film keeps the order's way always.
	swapped: set[int] = set()
	if direction != "any" and not textured:
		laid = []
		for p in parts:
			long_first = p.width >= p.height
			if long_first != (direction == "along"):
				swapped.add(p.pos)
				laid.append(Part(p.pos, p.height, p.width))
			else:
				laid.append(p)
		parts, turn = laid, False
	if LEVELS[level]:
		loads, too_big = best_plan(parts, tuned, rotate=turn, effort=LEVELS[level])
	else:
		loads, too_big = plan(parts, tuned, rotate=turn)
	for load in loads:
		for p in load.placed:
			if p.pos in swapped:
				# Turned against the order's way, as the map and the check read it.
				p.rotated = not p.rotated
	now = next((f for f in order_layout(sales_order)["films"] if f["decor"] == decor), None)
	return {
		"decor": decor,
		"textured": textured,
		"press": {k: tuned[k] for k in DEFAULT_PRESS},
		"film_m": round(sum(load.film_m for load in loads), 2),
		"now_m": now["film_m"] if now else None,
		"loads": [
			{"film_m": load.film_m, "length_mm": load.length_mm, "placed": [vars(p) for p in load.placed]}
			for load in loads
		],
		"too_big": [p.pos for p in too_big],
	}


def approval(sales_order: str, groups: dict[str, list[Part]] | None = None) -> dict | None:
	"""Who checked the order's layout and when — while the order's parts are
	the ones checked."""
	raw = frappe.db.get_default(f"{_APPROVED}:{sales_order}")
	if not raw:
		return None
	try:
		row = json.loads(raw)
	except ValueError:
		return None
	groups = _parts_by_decor(sales_order) if groups is None else groups
	return {"by": row.get("by"), "at": row.get("at")} if row.get("key") == _order_key(groups) else None


def approve(sales_order: str, approved: bool = True) -> dict:
	"""«Раскрой проверен»: the manager looked at the map and the metres."""
	if not material_stock.can_edit():
		frappe.throw("Раскрой проверяют администратор и менеджеры.", frappe.PermissionError)
	ensure_company("Sales Order", sales_order)
	groups = _parts_by_decor(sales_order)
	if not groups:
		frappe.throw("В заказе нет плёнки — проверять нечего.")
	row = {"by": get_fullname(frappe.session.user), "at": str(now_datetime())[:16], "key": _order_key(groups)}
	frappe.db.set_default(f"{_APPROVED}:{sales_order}", json.dumps(row, ensure_ascii=False) if approved else "")
	audit.record_audit(action="stock.press_layout_approved" if approved else "stock.press_layout_unapproved",
					   entity_type="Sales Order", entity_id=sales_order)
	short = _supply(sales_order) if approved else []
	result = order_layout(sales_order)
	result["short"] = short
	return result


def _supply(sales_order: str) -> list[dict]:
	"""The checked layout's film: what is free is held for the order, what
	is still lacking goes on «К заказу» for its customer — once."""
	from korkem_manufacturing.services import facade_materials, film_orders

	customer = frappe.db.get_value("Sales Order", sales_order, "customer")
	note = f"заказ {sales_order}"
	short = []
	for row in facade_materials.reserve(sales_order)["materials"]:
		if row["kind"] != material_stock.FILM or not row["item"] or not row["short"]:
			continue
		listed = frappe.db.exists(
			"Film Order Line", {"item": row["item"], "note": note, "status": ["in", list(film_orders.WANTED)]}
		)
		if not listed:
			film_orders.add(row["item"], row["short"], customer=customer, note=note)
		short.append({"decor": row["key"], "item": row["item"], "short_m": row["short"]})
	return short


def film_metres(sales_order: str) -> dict[str, float]:
	"""Metres of film per decor for the order — the correction where one is set."""
	return {f["decor"]: f["film_m"] for f in order_layout(sales_order)["films"]}


def set_film_metres(sales_order: str, decor: str, film_m=None, reason: str | None = None) -> dict:
	"""Correct the metres for one decor of an order — or clear the correction."""
	if not material_stock.can_edit():
		frappe.throw("Метраж поправляют администратор и менеджеры.", frappe.PermissionError)
	ensure_company("Sales Order", sales_order)
	decor = (decor or "").strip()
	if decor not in _parts_by_decor(sales_order):
		frappe.throw(f"В заказе нет плёнки «{decor}».")
	existing = frappe.db.get_value(OVERRIDE, {"sales_order": sales_order, "decor": decor}, "name")
	if film_m in (None, ""):
		if existing:
			frappe.delete_doc(OVERRIDE, existing, ignore_permissions=True)
		audit.record_audit(action="stock.film_metres_cleared", entity_type="Sales Order", entity_id=sales_order, diff={"decor": decor})
		return order_layout(sales_order)
	metres = flt(film_m)
	reason = (reason or "").strip()
	if metres <= 0:
		frappe.throw("Метраж — больше нуля.")
	if not reason:
		frappe.throw("Укажите, почему метраж не по раскладке.")
	doc = frappe.get_doc(OVERRIDE, existing) if existing else frappe.new_doc(OVERRIDE)
	doc.update({"sales_order": sales_order, "decor": decor, "film_m": metres, "reason": reason[:300]})
	doc.save(ignore_permissions=True)
	audit.record_audit(
		action="stock.film_metres_set", entity_type="Sales Order", entity_id=sales_order,
		diff={"decor": decor, "film_m": metres, "reason": reason},
	)
	return order_layout(sales_order)


def is_textured(decor: str, company: str) -> bool:
	"""A film of this decor marked «Текстурная» on its card: its parts never turn."""
	return bool(
		frappe.db.exists(
			"Item",
			{"korkem_material_company": company, "korkem_material_kind": material_stock.FILM, "korkem_color": decor,
			 "korkem_film_textured": 1, "disabled": 0},
		)
	)


def _parts_by_decor(sales_order: str) -> dict[str, list[Part]]:
	groups: dict[str, list[Part]] = {}
	for line in frappe.get_all(
		"Sales Order Item",
		filters={"parent": sales_order, "parenttype": "Sales Order", "korkem_width_mm": [">", 0]},
		fields=["idx", "qty", "korkem_width_mm", "korkem_height_mm", "korkem_finish", "korkem_double_sided",
				"korkem_customer_material", "korkem_decor_top", "korkem_decor_bottom"],
		order_by="idx",
	):
		film = facade_prices.is_film(line.korkem_finish) or (not line.korkem_finish and line.korkem_decor_top)
		if line.korkem_customer_material or not film:
			continue
		faces = [line.korkem_decor_top]
		if line.korkem_double_sided:
			faces.append(line.korkem_decor_bottom or line.korkem_decor_top)
		for decor in faces:
			if not decor:
				continue
			groups.setdefault(decor, []).extend(
				Part(cint(line.idx), cint(line.korkem_width_mm), cint(line.korkem_height_mm)) for _ in range(cint(line.qty))
			)
	return groups
