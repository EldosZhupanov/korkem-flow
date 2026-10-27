# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""What a facade order needs from the warehouse, held for it, and written off.

**Need.** A facade order's lines carry area, thickness and decor
(`facade_spec`). The need is summed per order — MDF by thickness, film by
decor — and only then turned into stock units, so an order of ten small
facades asks for one sheet, not ten fractions of one:

- MDF: area × (1 + MDF waste) ÷ sheet area, rounded **up** to whole sheets
  (a material counted in m² takes the area itself);
- film (only for a «ПВХ плёнка» finish): area × faces × (1 + film waste) —
  a double-sided facade is wrapped on both — divided by the film width when
  the film is counted in running metres, or the area when counted in m².

Sheet size and the two waste figures are the factory's own
(`Facade Material Norms`, per company). A line with the customer's own
material needs nothing from our shelf.

**Which material.** The warehouse's own Items (`material_stock`): an MDF of
that thickness, a film of that colour. When several match, the one already
held for this order wins, then the one with most free stock.

**Held** is a `Stock Reservation` — a promise, not a movement (see
`stock_reservation`): what is free is ERPNext's quantity on hand minus what is
promised. Short material is reported, not invented.

**Written off** when the first facade of the order goes into work: one ERPNext
Material Issue (`Stock Entry`) per order, marked with the order, out of the
warehouse the material was held in. ERPNext's own ledger therefore drops — the
one place stock is counted. A write-off made by mistake is cancelled in
ERPNext, which puts the material back.
"""

from __future__ import annotations

import math
from decimal import ROUND_HALF_UP, Decimal

import frappe
from frappe.utils import cint, flt

from korkem_manufacturing.services import audit, facade_prices, material_stock, stock_reservation
from korkem_manufacturing.services.scope import current_company, ensure_company

NORMS = "Facade Material Norms"
DEFAULTS = {"sheet_length_mm": 2800, "sheet_width_mm": 2070, "mdf_waste_percent": 15, "film_waste_percent": 10}
SHEET_UNITS = {"лист"}
AREA_UNITS = {"м²", "м2"}
LENGTH_UNITS = {"м"}
#: Marks a write-off made for a facade order (`add_facade_material_fields`).
ORDER_FIELD = "korkem_sales_order"


# --------------------------------------------------------------------------
# Norms
# --------------------------------------------------------------------------


def norms(company: str | None = None) -> dict:
	company = company or current_company()
	row = (
		frappe.db.get_value(NORMS, company, list(DEFAULTS), as_dict=True)
		if frappe.db.exists(NORMS, company)
		else None
	)
	values = {key: (row.get(key) if row and row.get(key) not in (None, "") else default) for key, default in DEFAULTS.items()}
	return {
		"sheet_length_mm": cint(values["sheet_length_mm"]),
		"sheet_width_mm": cint(values["sheet_width_mm"]),
		"mdf_waste_percent": flt(values["mdf_waste_percent"]),
		"film_waste_percent": flt(values["film_waste_percent"]),
		"saved": bool(row),
		"can_edit": material_stock.can_edit(),
	}


def save_norms(**values) -> dict:
	if not material_stock.can_edit():
		frappe.throw("Нормы расхода меняют администратор и менеджеры.", frappe.PermissionError)
	company = current_company()
	doc = frappe.get_doc(NORMS, company) if frappe.db.exists(NORMS, company) else frappe.new_doc(NORMS)
	doc.company = company
	before = {key: doc.get(key) for key in DEFAULTS}
	for key in DEFAULTS:
		if key in values and values[key] not in (None, ""):
			doc.set(key, values[key])
	doc.save(ignore_permissions=True)
	audit.record_audit(
		action="stock.facade_norms_saved",
		entity_type=NORMS,
		entity_id=doc.name,
		diff={"before": before, "after": {key: doc.get(key) for key in DEFAULTS}},
	)
	return norms(company)


# --------------------------------------------------------------------------
# Need
# --------------------------------------------------------------------------


def need(sales_order: str) -> dict:
	"""The order's materials: needed, held, written off, free, short."""
	company = _order_company(sales_order)
	rules = norms(company)
	groups, unresolved = _demand(sales_order, rules)
	held = _held(sales_order)
	issued = _issued(sales_order)

	materials = []
	for (kind, key), area in sorted(groups.items(), key=lambda kv: (kv[0][0], str(kv[0][1]))):
		item = _pick_item(kind, key, company, held)
		row = {
			"kind": kind,
			"key": str(key),
			"area_m2": _round(area, "0.01"),
			"item": item.name if item else None,
			"title": item.item_name if item else None,
			"unit": item.stock_uom if item else None,
			"needed": None,
			"held": 0.0,
			"issued": 0.0,
			"free": 0.0,
			"short": None,
			"note": None,
		}
		if not item:
			row["note"] = (
				f"На складе нет МДФ {key} мм — добавьте материал."
				if kind == material_stock.MDF
				else f"На складе нет плёнки «{key}» — добавьте материал."
			)
		else:
			qty = _in_stock_units(kind, area, item, rules)
			row["held"] = round(held.get(item.name, 0.0), 3)
			row["issued"] = round(issued.get(item.name, 0.0), 3)
			row["free"] = round(sum(_free_by_warehouse(item.name, company).values()), 3)
			if qty is None:
				row["note"] = f"Единица «{item.stock_uom}» не переводится из м² — укажите материал в листах, м² или метрах."
			else:
				row["needed"] = qty
				row["short"] = max(0.0, round(qty - row["held"] - row["issued"], 3))
		materials.append(row)

	return {
		"sales_order": sales_order,
		"materials": materials,
		"unresolved": unresolved,
		"norms": {key: rules[key] for key in DEFAULTS},
		"fully_held": bool(materials) and not unresolved and all(m["short"] == 0 for m in materials),
	}


def _demand(sales_order: str, rules: dict) -> tuple[dict, list[str]]:
	"""Square metres per (kind, thickness-or-decor), and lines that cannot be placed."""
	groups: dict[tuple[str, object], Decimal] = {}
	unresolved: list[str] = []
	mdf_factor = Decimal(1) + Decimal(str(rules["mdf_waste_percent"])) / 100
	film_factor = Decimal(1) + Decimal(str(rules["film_waste_percent"])) / 100
	for line in frappe.get_all(
		"Sales Order Item",
		filters={"parent": sales_order, "parenttype": "Sales Order", "korkem_width_mm": [">", 0]},
		fields=[
			"idx", "korkem_area_m2", "korkem_finish", "korkem_double_sided", "korkem_customer_material",
			"korkem_thickness_mm", "korkem_decor_top", "korkem_decor_bottom",
		],
		order_by="idx",
	):
		if line.korkem_customer_material:
			continue
		area = Decimal(str(flt(line.korkem_area_m2)))
		if line.korkem_thickness_mm:
			key = (material_stock.MDF, cint(line.korkem_thickness_mm))
			groups[key] = groups.get(key, Decimal(0)) + area * mdf_factor
		else:
			unresolved.append(f"Позиция {line.idx}: не указана толщина МДФ.")
		if line.korkem_finish != facade_prices.PVC:
			continue
		faces = [line.korkem_decor_top]
		if line.korkem_double_sided:
			faces.append(line.korkem_decor_bottom or line.korkem_decor_top)
		for decor in faces:
			if not decor:
				unresolved.append(f"Позиция {line.idx}: не выбран декор плёнки.")
				continue
			key = (material_stock.FILM, decor)
			groups[key] = groups.get(key, Decimal(0)) + area * film_factor
	return groups, list(dict.fromkeys(unresolved))


def _in_stock_units(kind: str, area: Decimal, item, rules: dict) -> float | None:
	unit = (item.stock_uom or "").strip().lower()
	if unit in AREA_UNITS:
		return _round(area, "0.01")
	if kind == material_stock.MDF and unit in SHEET_UNITS:
		sheet = Decimal(rules["sheet_length_mm"]) * Decimal(rules["sheet_width_mm"]) / Decimal(1_000_000)
		return float(math.ceil(area / sheet)) if sheet else None
	if kind == material_stock.FILM and unit in LENGTH_UNITS:
		width = flt(item.korkem_film_width_mm)
		if width <= 0:
			return None
		return _round(area / (Decimal(str(width)) / 1000), "0.01")
	return None


def _pick_item(kind: str, key, company: str, held: dict):
	filters = {"korkem_material_company": company, "korkem_material_kind": kind, "disabled": 0}
	if kind == material_stock.MDF:
		filters["korkem_thickness_mm"] = str(key)
	else:
		filters["korkem_color"] = key
	items = frappe.get_all(
		"Item", filters=filters, fields=["name", "item_name", "stock_uom", "korkem_film_width_mm"], order_by="name"
	)
	if not items:
		return None
	for item in items:
		if item.name in held:
			return item
	return max(items, key=lambda i: sum(_free_by_warehouse(i.name, company).values()))


# --------------------------------------------------------------------------
# Hold
# --------------------------------------------------------------------------


def reserve(sales_order: str) -> dict:
	"""Hold what is free for whatever the order still lacks. Safe to repeat."""
	company = _order_company(sales_order)
	before = need(sales_order)
	created = []
	for row in before["materials"]:
		short = row["short"] or 0
		if not row["item"] or short <= 0:
			continue
		for warehouse, free in sorted(_free_by_warehouse(row["item"], company).items(), key=lambda kv: -kv[1]):
			if short <= 0:
				break
			take = min(short, free)
			if row["unit"] and material_stock._whole_units(row["unit"]):
				take = math.floor(take)
			if take <= 0:
				continue
			held_so_far = _held(sales_order).get(row["item"], 0.0)
			doc = stock_reservation.reserve_stock(
				company=company,
				sales_order=sales_order,
				item_code=row["item"],
				qty=take,
				warehouse=warehouse,
				reservation_type="Other",
				idempotency_key=f"facade-{sales_order}-{row['item']}-{warehouse}-{held_so_far:g}",
				strict_stock_check=True,
			)
			created.append(doc.name)
			short = round(short - take, 3)
	result = need(sales_order)
	result["reservations_created"] = created
	return result


# --------------------------------------------------------------------------
# Write off
# --------------------------------------------------------------------------


def write_off(sales_order: str) -> str | None:
	"""Issue everything held for the order into production, as one ERPNext document.

	Called when the order's first facade goes into work. Nothing held → nothing
	to write off. The floor may move facades but may not post stock, so the
	issue is written by the system on its behalf, and audited.
	"""
	company = _order_company(sales_order)
	held = frappe.get_all(
		"Stock Reservation",
		filters={"sales_order": sales_order, "status": "Active", "offcut": ["is", "not set"]},
		fields=["name", "item_code", "qty", "warehouse"],
	)
	if not held:
		return None
	entry = frappe.get_doc(
		{
			"doctype": "Stock Entry",
			"stock_entry_type": "Material Issue",
			"purpose": "Material Issue",
			"company": company,
			ORDER_FIELD: sales_order,
			"remarks": f"Списание на фасады по заказу {sales_order}",
			"items": [
				{"item_code": r.item_code, "qty": flt(r.qty), "s_warehouse": r.warehouse} for r in held
			],
		}
	)
	entry.insert(ignore_permissions=True)
	entry.submit()
	stock_reservation.consume_reservations_for_order(sales_order)
	audit.record_audit(
		action="stock.facade_written_off",
		entity_type="Sales Order",
		entity_id=sales_order,
		diff={"stock_entry": entry.name, "items": {r.item_code: flt(r.qty) for r in held}},
	)
	return entry.name


def on_order_cancelled(doc, method=None) -> None:
	"""A cancelled order holds nothing: its promises go back to the shelf."""
	if frappe.db.exists("Stock Reservation", {"sales_order": doc.name, "status": "Active"}):
		stock_reservation.release_reservations_for_order(doc.name, reason="Заказ отменён")


# --------------------------------------------------------------------------
# Readings
# --------------------------------------------------------------------------


def _held(sales_order: str) -> dict[str, float]:
	result: dict[str, float] = {}
	for r in frappe.get_all(
		"Stock Reservation",
		filters={"sales_order": sales_order, "status": "Active"},
		fields=["item_code", "qty"],
	):
		result[r.item_code] = result.get(r.item_code, 0.0) + flt(r.qty)
	return result


def _issued(sales_order: str) -> dict[str, float]:
	entries = frappe.get_all(
		"Stock Entry",
		filters={ORDER_FIELD: sales_order, "docstatus": 1, "purpose": "Material Issue"},
		pluck="name",
	)
	result: dict[str, float] = {}
	if entries:
		for d in frappe.get_all(
			"Stock Entry Detail", filters={"parent": ["in", entries]}, fields=["item_code", "transfer_qty"]
		):
			result[d.item_code] = result.get(d.item_code, 0.0) + flt(d.transfer_qty)
	return result


def _free_by_warehouse(item: str, company: str) -> dict[str, float]:
	warehouses = frappe.get_all(
		"Bin",
		filters={"item_code": item, "actual_qty": [">", 0]},
		pluck="warehouse",
	)
	result = {}
	for warehouse in warehouses:
		if frappe.db.get_value("Warehouse", warehouse, "company") != company:
			continue
		free = stock_reservation.get_available_unreserved_qty(company, warehouse, item)
		if free > 0:
			result[warehouse] = round(free, 3)
	return result


def _order_company(sales_order: str) -> str:
	ensure_company("Sales Order", sales_order)
	return frappe.db.get_value("Sales Order", sales_order, "company")


def _round(value: Decimal, places: str) -> float:
	return float(Decimal(value).quantize(Decimal(places), rounding=ROUND_HALF_UP))
