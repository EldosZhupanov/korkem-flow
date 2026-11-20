# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Каталог красок (owner, 19.11.2026: «каталог красок тоже с карточками,
группами, цветом со своим родным, примерно как каталог ПВХ плёнок — самые
ходовые, топовые, трендовые; добавлять их, редактировать»).

The catalogue is the colour systems the shop keeps («Система цвета»), and in
each the colours a customer picks from:

- **RAL Classic** — all 216, from `ral_classic`, with the shop's own on top;
- **RAL Design** — those on the «Краска» list, their shade read off the code
  itself (RAL 210 50 15 is hue 210°, lightness 50, chroma 15);
- every other system — its colours on the «Краска» list.

Each colour says what the shop knows of it: kilograms on the shelf and how
many m² that paints, the m² and orders of it over 90 days («ходовые»), and
whether it is among the furniture top or this year's trends. Picking a
colour from the catalogue puts it on the «Краска» list, where orders take it
from. A colour's shade, a star, a note — or hiding it — is the shop's own,
kept in «Paint Colour».

`similar` finds the colours nearest a shade — for «Похожие», a photo of a
sample, and a colour no supplier has (`paint_swap`).
"""

from __future__ import annotations

import base64
import math
import re
from collections import defaultdict

import frappe
from frappe.utils import add_days, cint, flt, nowdate

from korkem_manufacturing.services import (
	audit,
	decor_colors,
	directions,
	material_stock,
	mdf_paint,
	mdf_paints,
	paint_recipe,
	paint_stock,
	ral_classic,
)
from korkem_manufacturing.services.scope import current_company

DOCTYPE = "Paint Colour"
USAGE_DAYS = 90
_HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
_DESIGN = re.compile(r"^RAL\s*(\d{3})\s*(\d{2})\s*(\d{2})\b", re.I)
_CLASSIC = re.compile(r"^RAL\s*(\d{4})\b", re.I)

#: ΔE between two shades, and what a customer sees of it.
SAME, CLOSE = 2.5, 6.0
SIMILAR_SHOWN = 8


def key(value: str | None) -> str:
	"""«RAL 9010 Чисто-белый» and «RAL 9010» are one colour: «ral9010»."""
	return mdf_paints._number(mdf_paint.colour_only(value or ""))


def look(delta: float) -> str:
	"""What a ΔE means to the eye: «same», «close» (seen up close), «other»."""
	return "same" if delta < SAME else "close" if delta < CLOSE else "other"


def design_hex(code: str) -> str | None:
	"""RAL Design «RAL 210 50 15» — CIE LCh — as sRGB."""
	m = _DESIGN.match(code.strip())
	if not m:
		return None
	h, lum, c = (int(g) for g in m.groups())
	a, b = c * math.cos(math.radians(h)), c * math.sin(math.radians(h))
	fy = (lum + 16) / 116
	fx, fz = fy + a / 500, fy - b / 200

	def inv(t: float) -> float:
		return t ** 3 if t ** 3 > 0.008856 else (t - 16 / 116) / 7.787

	x, y, z = 0.95047 * inv(fx), inv(fy), 1.08883 * inv(fz)
	rgb = (3.2406 * x - 1.5372 * y - 0.4986 * z, -0.9689 * x + 1.8758 * y + 0.0415 * z,
		   0.0557 * x - 0.2040 * y + 1.0570 * z)

	def gamma(v: float) -> int:
		v = 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055
		return max(0, min(255, round(v * 255)))

	return "#" + "".join(f"{gamma(v):02X}" for v in rgb)


def _lab(hexcode: str | None) -> dict | None:
	return decor_colors.from_hex(hexcode) if hexcode else None


def _delta(one: dict, other: dict) -> float:
	return math.sqrt(sum((one[k] - other[k]) ** 2 for k in ("l", "a", "b")))


# --------------------------------------------------------------------------
# What the shop knows of each colour
# --------------------------------------------------------------------------


def _usage(company: str) -> dict[str, dict]:
	"""Colour → m² and orders over the last 90 days."""
	names = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "transaction_date": [">=", add_days(nowdate(), -USAGE_DAYS)]},
		pluck="name", limit_page_length=0,
	)
	out: dict[str, dict] = defaultdict(lambda: {"area_m2": 0.0, "orders": 0})
	for colours in mdf_paint._colours(names)[0].values():
		seen = set()
		for colour, m2 in colours.items():
			k = key(colour)
			if not k or colour == mdf_paint.NO_COLOUR:
				continue
			out[k]["area_m2"] += float(m2)
			if k not in seen:
				out[k]["orders"] += 1
				seen.add(k)
	return out


def _shelf(company: str) -> dict[str, float]:
	"""Colour → kilograms of its paint on hand (not hardener or thinner)."""
	items = frappe.get_all(
		"Item",
		filters={"korkem_material_company": company, "korkem_material_kind": material_stock.PAINT, "disabled": 0},
		fields=["name", "korkem_color", "korkem_paint_base"], limit_page_length=0,
	)
	on_hand = material_stock._stock([i.name for i in items], company)
	out: dict[str, float] = defaultdict(float)
	for i in items:
		if i.korkem_color and not paint_stock.component(i.korkem_paint_base, company):
			out[key(i.korkem_color)] += on_hand.get(i.name, (0.0, 0.0))[0]
	return out


def _kg_m2_colour(company: str) -> float:
	"""Kilograms of coloured paint one m² takes, by the shop's recipe."""
	rec = paint_recipe.recipe(company)
	return sum(r["kg"] for r in paint_recipe.materials(1, rec) if r["colour"])


def _own(company: str) -> dict[str, dict]:
	return {r.number: r for r in frappe.get_all(
		DOCTYPE, filters={"company": company},
		fields=["name", "number", "title", "hex", "starred", "hidden", "note"], limit_page_length=0)}


def _listed(company: str) -> list[dict]:
	"""The «Краска» list: each colour, its system."""
	return [
		{"value": o.value, "system": mdf_paints.system_of(o.note) or mdf_paints.guess_system(o.value)}
		for o in frappe.get_all("Material Option", filters={"company": company, "kind": mdf_paints.PAINT_LIST,
															  "enabled": 1}, fields=["value", "note"],
								order_by="value asc", limit_page_length=0)
	]


def _colours(company: str) -> list[dict]:
	listed = _listed(company)
	by_key = {key(p["value"]): p for p in listed}
	own = _own(company)
	usage = _usage(company)
	shelf = _shelf(company)
	per_m2 = _kg_m2_colour(company)
	out = []

	def row(k: str, code: str, name: str, system: str | None, hexcode: str | None, family: str | None,
			top: bool = False, trend: bool = False) -> dict:
		mine = own.get(k)
		on_list = by_key.get(k)
		kg = round(shelf.get(k, 0.0), 3)
		use = usage.get(k) or {"area_m2": 0.0, "orders": 0}
		shade = (mine.hex if mine and mine.hex else None) or hexcode
		return {
			"key": k, "code": code, "name": (mine.title if mine and mine.title else None) or name,
			"value": on_list["value"] if on_list else f"{code} {name}".strip(),
			"system": system, "hex": shade, "family": family,
			"on_list": bool(on_list), "kg": kg,
			"enough_m2": round(kg / per_m2, 1) if per_m2 > 0 and kg > 0 else None,
			"area_m2": round(use["area_m2"], 2), "orders": use["orders"],
			"top": top, "trend": trend,
			"starred": bool(mine and mine.starred), "hidden": bool(mine and mine.hidden),
			"note": mine.note if mine else None,
		}

	classic_keys = set()
	for number, name, hexcode in ral_classic.COLOURS:
		k = key(f"RAL {number}")
		classic_keys.add(k)
		out.append(row(k, f"RAL {number}", name, mdf_paints.RAL_CLASSIC, hexcode, ral_classic.FAMILIES[number[0]],
					   top=number in ral_classic.TOP, trend=number in ral_classic.TRENDS))
	for p in listed:
		k = key(p["value"])
		if k in classic_keys:
			continue
		m = re.match(r"^(RAL\s*\d{3}\s*\d{2}\s*\d{2}|RAL\s*\d{3}-[\dM]|NCS\s*\S+(?:\s\S+)?)\s*(.*)$", p["value"], re.I)
		code, name = (m.group(1), m.group(2)) if m else ("", p["value"])
		out.append(row(k, code, name or code, p["system"], design_hex(p["value"]), None))
	return out


#: How many of a customer's latest orders say what he painted.
CUSTOMER_ORDERS = 20


def _customer(company: str, customer: str | None) -> list[str]:
	"""The colours a customer had painted, the latest first (owner,
	20.11.2026: «этот клиент красил раньше» on the order's paint window)."""
	if not customer:
		return []
	rows = frappe.db.sql(
		"""select i.korkem_decor_top, i.korkem_decor_bottom, i.korkem_double_sided
		from `tabSales Order Item` i join `tabSales Order` o on o.name = i.parent
		where o.company = %s and o.customer = %s and o.docstatus < 2
			and o.korkem_direction = %s and coalesce(i.korkem_line_coating, '') = %s
		order by o.transaction_date desc, o.creation desc limit 400""",
		(company, customer, directions.FACADES, mdf_paint.PAINT),
		as_dict=True,
	)
	out: list[str] = []
	for r in rows:
		for colour in (r.korkem_decor_top, r.korkem_decor_bottom if r.korkem_double_sided else None):
			k = key(colour) if colour else None
			if k and k not in out:
				out.append(k)
	return out[:CUSTOMER_ORDERS]


def catalogue(customer: str | None = None) -> dict:
	"""Every colour by system, with what the shop knows of it — and, for an
	order, what its customer had painted before."""
	material_stock._ensure_staff()
	company = current_company()
	colours = _colours(company)
	systems = mdf_paints._systems(company)
	counts = defaultdict(int)
	for c in colours:
		if not c["hidden"]:
			counts[c["system"]] += 1
	return {
		"systems": [{"name": s, "count": counts.get(s, 0)} for s in systems]
		+ ([{"name": None, "count": counts[None]}] if counts.get(None) else []),
		"families": list(ral_classic.FAMILIES.values()),
		"colours": colours,
		"customer": _customer(company, customer),
		"kg_per_m2": round(_kg_m2_colour(company), 4),
		"usage_days": USAGE_DAYS,
		"can_edit": material_stock.can_edit(),
	}


# --------------------------------------------------------------------------
# Changing the catalogue
# --------------------------------------------------------------------------


def _clean_hex(value: str | None) -> str | None:
	value = (value or "").strip()
	if not value:
		return None
	value = value if value.startswith("#") else f"#{value}"
	if not _HEX.match(value):
		frappe.throw("Цвет — в виде #RRGGBB.")
	return value.upper()


def _upsert(company: str, k: str, **values) -> None:
	name = frappe.db.get_value(DOCTYPE, {"company": company, "number": k}, "name")
	if name:
		frappe.db.set_value(DOCTYPE, name, values)
	else:
		frappe.get_doc({"doctype": DOCTYPE, "company": company, "number": k, **values}).insert(ignore_permissions=True)


def take(value: str, system: str | None = None) -> dict:
	"""A catalogue colour into work: on the «Краска» list, for orders."""
	material_stock._ensure_editor()
	return listed(value, system)


def pick(value: str, system: str | None = None) -> dict:
	"""A colour picked for an order — any of the 216, say — put into work on
	the way: whoever takes orders may (owner, 20.11.2026)."""
	from korkem_manufacturing.services import facade_prices

	facade_prices.ensure_editor()
	return listed(value, system)


def listed(value: str, system: str | None = None) -> dict:
	"""The colour as the «Краска» list names it — put there if it is not.
	The caller has checked who may."""
	value = " ".join((value or "").split())[:140]
	if len(value) < 2:
		frappe.throw("Название краски слишком короткое.")
	company = current_company()
	k = key(value)
	there = next((p for p in _listed(company) if key(p["value"]) == k), None)
	if there:
		return {"value": there["value"], "key": k}
	systems = mdf_paints._systems(company)
	system = system or mdf_paints.guess_system(value) or mdf_paints.SAMPLE
	if system in systems:
		taken = mdf_paints.add_paint(value, system)
	else:
		taken = mdf_paints._put(company, value, None)
	return {"value": taken, "key": key(taken)}


def add_colour(name: str, system: str, code: str | None = None, hexcode: str | None = None,
			   note: str | None = None) -> dict:
	"""A colour of the shop's own, or one by its number in a system."""
	material_stock._ensure_editor()
	name = " ".join((name or "").split())[:120]
	code = " ".join((code or "").split())[:40]
	if len(name) < 2 and len(code) < 2:
		frappe.throw("Назовите цвет или укажите его код.")
	value = f"{code} {name}".strip() if code else name
	taken = take(value, system)
	shade = _clean_hex(hexcode) or design_hex(taken["value"])
	_upsert(current_company(), taken["key"], hex=shade, note=(note or "").strip()[:500] or None)
	audit.record_audit(action="paint.colour_added", entity_type=DOCTYPE, entity_id=taken["key"],
					   diff={"value": taken["value"], "system": system, "hex": shade})
	return taken


def set_colour(colour_key: str, title: str | None = None, hexcode: str | None = None, starred=None, hidden=None,
			   note: str | None = None) -> dict:
	"""A colour's own card: its name, its shade, a star, hidden, a note. A
	field left out stays; an empty one is cleared."""
	material_stock._ensure_editor()
	colour_key = (colour_key or "").strip()
	if not colour_key:
		frappe.throw("Какой цвет?")
	values = {}
	if title is not None:
		values["title"] = " ".join(title.split())[:120] or None
	if hexcode is not None:
		values["hex"] = _clean_hex(hexcode)
	if starred is not None:
		values["starred"] = cint(starred in (True, 1, "1", "true", "True"))
	if hidden is not None:
		values["hidden"] = cint(hidden in (True, 1, "1", "true", "True"))
	if note is not None:
		values["note"] = note.strip()[:500] or None
	if values:
		_upsert(current_company(), colour_key, **values)
		audit.record_audit(action="paint.colour_set", entity_type=DOCTYPE, entity_id=colour_key, diff=values)
	return next((c for c in _colours(current_company()) if c["key"] == colour_key), {"key": colour_key})


# --------------------------------------------------------------------------
# Nearest shades
# --------------------------------------------------------------------------


def _nearest(target: dict, colours: list[dict], skip: str | None = None, limit: int = SIMILAR_SHOWN,
			 in_stock: bool = False) -> list[dict]:
	found = []
	for c in colours:
		lab = _lab(c["hex"])
		if not lab or c["key"] == skip or c["hidden"] or (in_stock and c["kg"] <= 0):
			continue
		d = _delta(target, lab)
		found.append({**c, "delta": round(d, 1), "look": look(d)})
	found.sort(key=lambda c: (c["delta"], -c["kg"]))
	return found[:limit]


def similar(colour: str | None = None, hexcode: str | None = None, in_stock=False) -> dict:
	"""The colours nearest one colour (by its name or number) or a shade."""
	material_stock._ensure_staff()
	company = current_company()
	colours = _colours(company)
	k = key(colour) if colour else None
	base = next((c for c in colours if c["key"] == k), None) if k else None
	shade = _clean_hex(hexcode) or (base["hex"] if base else None) or (design_hex(colour) if colour else None)
	target = _lab(shade)
	if not target:
		return {"colour": base, "hex": shade, "similar": []}
	stock_only = in_stock in (True, 1, "1", "true", "True")
	return {"colour": base, "hex": shade,
			"similar": _nearest(target, colours, skip=k, in_stock=stock_only)}


def match_photo(content_b64: str) -> dict:
	"""A photo of a sample the customer brought: the nearest colours."""
	material_stock._ensure_staff()
	try:
		content = base64.b64decode((content_b64 or "").split(",")[-1])
	except (ValueError, TypeError):
		frappe.throw("Фото не прочиталось.")
	if not content or len(content) > decor_colors.PHOTO_MAX:
		frappe.throw("Фото пустое или слишком большое.")
	# The middle of the picture: the sample, not the table it lies on.
	tone = decor_colors.signature(content, centre=0.5)
	l_, a, b = tone["l"], tone["a"], tone["b"]
	return {"tone": tone, "similar": _nearest({"l": l_, "a": a, "b": b}, _colours(current_company()))}
