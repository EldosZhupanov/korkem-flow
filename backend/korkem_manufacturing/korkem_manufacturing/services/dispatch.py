# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Shipping finished goods to the customer.

Horizon 1's fifth and last action of the planned set. Moved out of
`korkem_ai/tools/delivery.py` unchanged.

This is where the chain finally reaches the person who ordered. Everything
before it — planning, buying, cutting, painting, assembling — produces stock
sitting on a shelf; a Delivery Note is what turns that into something the
customer has.

## Two rules that survive the move

**Only what is physically on the shelf ships.** A finished quantity on a work
order is not the same as goods in the warehouse: they can have been consumed,
reserved, or never received. The lines are built from actual stock, so a
delivery cannot promise what is not there.

**ERPNext's own mapper writes it.** `sales_order/mapper.py:make_delivery_note`
carries the pricing, the taxes and the item detail across, and its submit is
what moves the ledger. Writing a Delivery Note by hand would be a second
shipping system, and the accounts would disagree with the loading bay.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, nowdate

from korkem_manufacturing.services.scope import ensure_company

#: Sales Order statuses that can no longer be shipped against.
UNSHIPPABLE = ("Closed", "Cancelled", "On Hold")


def _on_hand(item_code: str, warehouse: str) -> float:
	"""What is physically in that warehouse. Never projected."""
	if not warehouse:
		return 0.0
	return flt(
		frappe.db.get_value("Bin", {"item_code": item_code, "warehouse": warehouse}, "actual_qty")
	)


def _lines_for(sales_order: str) -> list[dict]:
	rows = frappe.get_all(
		"Sales Order Item",
		filters={"parent": sales_order},
		fields=["name", "item_code", "item_name", "qty", "delivered_qty", "warehouse", "stock_uom"],
		order_by="idx asc",
	)
	lines = []
	for row in rows:
		pending = round(max(0.0, flt(row["qty"]) - flt(row["delivered_qty"])), 3)
		available = _on_hand(row["item_code"], row["warehouse"])
		lines.append(
			{
				"row": row["name"],
				"item_code": row["item_code"],
				"item_name": row["item_name"],
				"ordered_qty": flt(row["qty"]),
				"delivered_qty": flt(row["delivered_qty"]),
				"pending_qty": pending,
				"available_qty": available,
				"shippable_now": round(min(pending, available), 3),
				"short_by": round(max(0.0, pending - available), 3),
				"warehouse": row["warehouse"],
				"uom": row["stock_uom"],
			}
		)
	return lines


def create_delivery(sales_order: str, items: list | None = None):
	"""Ship what is on the shelf against a sales order.

	Owns a savepoint because the write is not one document: a Delivery Note is
	inserted and then submitted, and a committed draft is stock promised to a
	customer that never left the building.

	An outer HTTP transaction is not the boundary: `korkem_ai/tools/registry.py`
	catches `Exception` and returns it **as data** rather than re-raising.
	"""
	savepoint = "korkem_ship_" + frappe.generate_hash(length=8)
	frappe.db.savepoint(savepoint)
	try:
		result = _create_delivery(sales_order, items)
	except Exception:
		frappe.db.rollback(save_point=savepoint)
		raise
	frappe.db.release_savepoint(savepoint)
	return result


def _create_delivery(sales_order: str, items: list | None = None):
	"""Ship what is owed and on the shelf, through ERPNext's own mapper.

	Everything is re-read here. A shipment is stock leaving the building, and
	between the proposal and the tap somebody else may have loaded the same
	cabinets onto another lorry.
	"""
	from erpnext.selling.doctype.sales_order.mapper import make_delivery_note

	if not frappe.db.exists("Sales Order", sales_order):
		frappe.throw(f"Sales order {sales_order} not found.")
	ensure_company("Sales Order", sales_order)

	order = frappe.get_doc("Sales Order", sales_order)
	order.check_permission("read")
	if order.docstatus != 1:
		frappe.throw(f"{sales_order} is not submitted, so nothing can be shipped against it.")
	if order.status in UNSHIPPABLE:
		frappe.throw(f"{sales_order} is {order.status}.")

	lines = {line["row"]: line for line in _lines_for(sales_order)}
	if not any(line["pending_qty"] > 0 for line in lines.values()):
		# Everything is already out. Not an error, and not a second note
		# either — a delivery for nothing is a document somebody has to explain.
		return {
			"status": "already_delivered",
			"sales_order": sales_order,
			"customer": order.customer,
			"message": "Everything on this order has already been delivered.",
		}

	asked = {}
	for row in items or []:
		code = row.get("item_code")
		if not any(line["item_code"] == code for line in lines.values()):
			frappe.throw(f"{sales_order} has no line for {code}.")
		qty = flt(row.get("qty"))
		if qty <= 0:
			frappe.throw(f"Quantity for {code} must be greater than zero.")
		asked[code] = asked.get(code, 0.0) + qty

	if not frappe.has_permission("Delivery Note", "submit"):
		frappe.throw(
			"You can prepare a delivery note but not submit one, and an "
			"unsubmitted note ships nothing. Ask someone with submit rights."
		)

	note = frappe.get_doc(make_delivery_note(sales_order))
	note.posting_date = nowdate()

	adjusted, keep = [], []
	for row in note.items:
		line = lines.get(row.so_detail)
		if not line or line["shippable_now"] <= 0:
			continue

		wanted = asked.get(row.item_code, line["shippable_now"]) if asked else line["shippable_now"]
		shipping = round(min(wanted, line["shippable_now"]), 3)
		if shipping <= 0:
			continue
		if wanted > line["shippable_now"] + 0.001:
			adjusted.append(
				{"item_code": row.item_code, "asked": wanted, "shipped": shipping}
			)

		row.qty = shipping
		keep.append(row)

	if not keep:
		short = [line for line in lines.values() if line["short_by"] > 0]
		return {
			"status": "nothing_shippable",
			"sales_order": sales_order,
			"customer": order.customer,
			"blocking_items": short,
			"message": (
				"Nothing is on the shelf to send: "
				+ ", ".join(f"{line['item_code']} short {line['short_by']} {line['uom']}" for line in short)
			),
		}

	note.set("items", keep)
	note.insert()
	note.submit()

	# Read back what ERPNext now says rather than what was intended.
	order.reload()
	after = _lines_for(sales_order)
	return {
		"status": "delivered",
		"delivery_note": note.name,
		"sales_order": sales_order,
		"customer": order.customer,
		"delivered_on": str(note.posting_date),
		"erpnext_status": order.status,
		"delivered_percent": flt(order.per_delivered),
		"fully_delivered": all(line["pending_qty"] <= 0 for line in after),
		"adjusted": adjusted,
		"items": [
			{
				"item_code": row.item_code,
				"qty": flt(row.qty),
				"uom": row.stock_uom,
				"warehouse": row.warehouse,
			}
			for row in note.items
		],
		"order_lines": [
			{
				"item_code": line["item_code"],
				"ordered_qty": line["ordered_qty"],
				"delivered_qty": line["delivered_qty"],
				"pending_qty": line["pending_qty"],
			}
			for line in after
		],
	}
