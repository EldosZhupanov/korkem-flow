# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Обрезки МДФ (owner, 18.11.2026): a piece left from a sheet is put on the
shelf with its size, and a new order's small parts are offered it first.

The ledger is `offcuts` (Stock Offcut, ADR on business remnants): this
module is the shop's door to it — who may, which MDF item a thickness is,
which shelf — and the matching: for each of an order's positions, the
smallest free offcut of its thickness that holds the part with `MARGIN_MM`
to trim, rotated if need be, one offcut per part.

An offcut is a suggestion: «взять» marks it used for that order; nothing is
cut or written off by itself.
"""

from __future__ import annotations

import frappe
from frappe.utils import cint, flt

from korkem_manufacturing.services import audit, material_stock, offcuts
from korkem_manufacturing.services.scope import current_company

#: What a part needs around it to be trimmed true.
MARGIN_MM = 10
#: Smaller than this is not worth a place on the shelf.
MIN_MM = 100

_FIELDS = ["name", "thickness_mm", "length_mm", "width_mm", "area_m2", "storage_cell", "decor", "source_order",
		   "status", "reserved_for_order", "creation", "notes", "material_item"]


def _row(r) -> dict:
	return {
		"offcut": r.name, "thickness_mm": flt(r.thickness_mm), "length_mm": flt(r.length_mm),
		"width_mm": flt(r.width_mm), "area_m2": flt(r.area_m2, 3), "cell": r.storage_cell, "decor": r.decor,
		"source_order": r.source_order, "status": r.status, "for_order": r.reserved_for_order,
		"created_on": str(r.creation)[:10], "note": r.notes,
	}


def _thicknesses(company: str) -> dict[int, str]:
	"""Each MDF thickness the shop keeps, and its item."""
	out: dict[int, str] = {}
	for i in frappe.get_all("Item", filters={"korkem_material_company": company,
											 "korkem_material_kind": material_stock.MDF, "disabled": 0},
							fields=["name", "korkem_thickness_mm"], order_by="name", limit_page_length=0):
		mm = cint(flt(i.korkem_thickness_mm))
		if mm and mm not in out:
			out[mm] = i.name
	return out


def listing() -> dict:
	"""The offcuts on the shelf, newest first, and the thicknesses one may add."""
	material_stock._ensure_staff()
	company = current_company()
	rows = frappe.get_all(offcuts.DOCTYPE, filters={"company": company, "status": ["in", ["Available", "Reserved"]]},
						  fields=_FIELDS, order_by="creation desc", limit_page_length=1000)
	return {
		"offcuts": [_row(r) for r in rows],
		"thicknesses": sorted(_thicknesses(company)),
		"area_m2": round(sum(flt(r.area_m2) for r in rows), 2),
	}


def add(thickness_mm, length_mm, width_mm, cell: str | None = None, source_order: str | None = None,
		note: str | None = None) -> dict:
	"""A piece put on the shelf: its thickness, its size, where it lies."""
	material_stock._ensure_staff()
	company = current_company()
	thickness = cint(flt(thickness_mm))
	item = _thicknesses(company).get(thickness)
	if not item:
		frappe.throw(f"МДФ {thickness} мм в справочнике материалов нет.")
	length, width = sorted((flt(length_mm), flt(width_mm)), reverse=True)
	if width < MIN_MM:
		frappe.throw(f"Обрезок меньше {MIN_MM} мм не храним.")
	if length > 3000 or width > 2100:
		frappe.throw("Обрезок больше листа — проверьте размеры.")
	if source_order and frappe.db.get_value("Sales Order", source_order, "company") != company:
		source_order = None
	doc = offcuts.create_offcut(
		company=company, material_item=item, length_mm=length, width_mm=width, thickness_mm=thickness,
		warehouse=material_stock._receiving_warehouse(company, None),
		storage_cell=(cell or "").strip()[:40] or None, source_order=source_order,
		notes=" ".join(str(note or "").split())[:140] or None,
	)
	return listing() | {"added": doc.name}


def use(offcut: str, order: str | None = None) -> dict:
	"""Taken from the shelf — for this order, when there is one."""
	material_stock._ensure_staff()
	_own(offcut)
	if order and frappe.db.get_value("Sales Order", order, "company") != current_company():
		frappe.throw("Такого заказа нет.", frappe.DoesNotExistError)
	offcuts.consume_offcut(offcut, sales_order=order)
	return listing()


def scrap(offcut: str, reason: str | None = None) -> dict:
	"""Off the shelf: broken, damp, too small after all."""
	material_stock._ensure_staff()
	_own(offcut)
	offcuts.scrap_offcut(offcut, (reason or "").strip()[:140] or "в утиль")
	return listing()


def _own(offcut: str) -> None:
	if frappe.db.get_value(offcuts.DOCTYPE, offcut, "company") != current_company():
		frappe.throw("Такого обрезка нет.", frappe.DoesNotExistError)


def _fits(piece: tuple[float, float], cut: dict) -> bool:
	h, w = piece
	big, small = max(h, w) + MARGIN_MM, min(h, w) + MARGIN_MM
	return cut["length_mm"] >= big and cut["width_mm"] >= small


def suggest(order: str) -> dict:
	"""An order's parts that can be cut from offcuts on the shelf: each part
	the smallest free offcut of its thickness that holds it."""
	material_stock._ensure_staff()
	company = current_company()
	if frappe.db.get_value("Sales Order", order, "company") != company:
		frappe.throw("Такого заказа нет.", frappe.DoesNotExistError)
	out = parts_for(order, company)
	return {"order": order, "parts": out, "area_m2": round(sum(p["height_mm"] * p["width_mm"] for p in out) / 1e6, 3)}


def parts_for(order: str, company: str) -> list[dict]:
	"""The matching itself, asked by whoever has checked the reader: the
	order's card counts them for its hint."""
	if not frappe.db.exists(offcuts.DOCTYPE, {"company": company, "status": "Available"}):
		return []
	free = [_row(r) for r in frappe.get_all(offcuts.DOCTYPE, filters={"company": company, "status": "Available"},
											 fields=_FIELDS, limit_page_length=0)]
	free.sort(key=lambda c: c["area_m2"])
	taken: set[str] = set()
	out = []
	for line in frappe.get_all("Sales Order Item",
							   filters={"parent": order, "parenttype": "Sales Order", "korkem_width_mm": [">", 0]},
							   fields=["idx", "korkem_height_mm", "korkem_width_mm", "qty", "korkem_thickness_mm",
									   "korkem_client_mdf", "korkem_customer_material"],
							   order_by="idx", limit_page_length=0):
		if line.korkem_client_mdf or line.korkem_customer_material:
			continue
		piece = (flt(line.korkem_height_mm), flt(line.korkem_width_mm))
		thickness = cint(flt(line.korkem_thickness_mm))
		for _ in range(cint(line.qty)):
			cut = next((c for c in free if c["offcut"] not in taken and cint(c["thickness_mm"]) == thickness
						and _fits(piece, c)), None)
			if not cut:
				break
			taken.add(cut["offcut"])
			out.append({"position": line.idx, "height_mm": piece[0], "width_mm": piece[1],
						"thickness_mm": thickness, "offcut": cut})
	return out


def take(offcut: str, order: str) -> dict:
	"""«Взять»: an offered offcut used for the order."""
	use(offcut, order)
	audit.record_audit(action="offcut.taken", entity_type="Sales Order", entity_id=order, diff={"offcut": offcut})
	return suggest(order)
