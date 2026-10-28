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

import json
from dataclasses import dataclass, field

import frappe
from frappe.utils import cint, flt

from korkem_manufacturing.services import audit, facade_prices, material_stock
from korkem_manufacturing.services.scope import current_company, ensure_company

NORMS = "Facade Material Norms"
OVERRIDE = "Facade Film Metres"
#: The shop's Yellow 3013: working area inside, and its sections — film ordered
#: (m) against the working length it gives (mm). The whole table: 3.1 m of film
#: for 2 850 mm inside, the rest goes over the frame. The two shorter sections'
#: working lengths are a first guess with the same 250 mm over the frame.
DEFAULT_PRESS = {
	"press_length_mm": 2850,
	"press_width_mm": 1210,
	"press_margin_mm": 50,
	"press_gap_mm": 60,
	"press_sections": [
		{"film_m": 1.1, "length_mm": 850},
		{"film_m": 2.1, "length_mm": 1850},
		{"film_m": 3.1, "length_mm": 2850},
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


def plan(parts: list[Part], press: dict, rotate: bool) -> tuple[list[Load], list[Part]]:
	"""Loads for `parts`, shortest section each time; and the parts no load can take."""
	sections = sorted(press["press_sections"], key=lambda s: flt(s["length_mm"]))
	margin, gap, width = cint(press["press_margin_mm"]), cint(press["press_gap_mm"]), cint(press["press_width_mm"])
	left = sorted(parts, key=lambda p: (p.width * p.height, max(p.width, p.height)), reverse=True)
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
		for r in frappe.get_all(OVERRIDE, filters={"sales_order": sales_order}, fields=["decor", "film_m", "reason", "modified_by"])
	}
	films = []
	for decor, parts in groups.items():
		textured = is_textured(decor, order.company)
		loads, too_big = plan(parts, press, rotate=not textured)
		layout_m = round(sum(load.film_m for load in loads), 2)
		fix = corrections.get(decor)
		films.append(
			{
				"decor": decor,
				"title": f"№{sales_order} {order.customer_name or order.customer} {decor}",
				"textured": textured,
				"layout_m": layout_m,
				"film_m": flt(fix.film_m) if fix else layout_m,
				"corrected": bool(fix),
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
	}


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
		if line.korkem_customer_material or line.korkem_finish != facade_prices.PVC:
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
