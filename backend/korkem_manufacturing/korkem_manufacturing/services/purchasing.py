# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Booking a delivery in against its purchase order.

Horizon 1's third action, moved out of `korkem_ai/tools/buying.py` unchanged.
Smaller than the two before it because the shortage computation it stands on
moved with the first — one action paying for the next is what "one action at a
time" is supposed to look like once the foundation is down.

## Two rules that survive the move, and both are about not being a second ERP

**Stock moves through ERPNext's own Purchase Receipt.** Writing `Bin.actual_qty`
would leave the ledger disagreeing with the shelf and every valuation built on
it wrong, and it would be a second stock system living beside the first.

**Quantities are the order's, never the caller's.** `items` may narrow what is
booked in — a partial delivery is ordinary — but every line is trimmed to what
is genuinely still outstanding. "Прими 400 листов" against an order for four
receives four, because the order is the fact and the sentence is not.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, nowdate

from korkem_manufacturing.services.scope import ensure_company


def receive_purchase_order(purchase_order: str, items: list | None = None):
	"""Book a delivery in against its purchase order.

	Through ERPNext's own Purchase Receipt, which is what actually moves the
	stock ledger. Writing `Bin.actual_qty` would leave the ledger disagreeing
	with the shelf and every valuation built on it wrong — and it would be a
	second stock system living beside the ERP's.

	Quantities are the order's, never the model's. `items` may narrow what is
	being booked in — a partial delivery — but each line is trimmed down to
	what is genuinely still outstanding, so "прими 400 листов" against an order
	for four receives four.
	"""
	from erpnext.buying.doctype.purchase_order.mapper import make_purchase_receipt

	if not frappe.db.exists("Purchase Order", purchase_order):
		frappe.throw(f"Purchase order {purchase_order} not found.")

	ensure_company("Purchase Order", purchase_order)
	order = frappe.get_doc("Purchase Order", purchase_order)
	order.check_permission("read")

	if order.docstatus != 1:
		frappe.throw(
			f"{purchase_order} is not submitted, so nothing can be received against it."
		)
	if order.status in ("Closed", "Cancelled", "On Hold"):
		frappe.throw(f"{purchase_order} is {order.status}.")

	outstanding = {
		row.name: round(flt(row.qty) - flt(row.received_qty), 3)
		for row in order.items
		if flt(row.qty) - flt(row.received_qty) > 0
	}
	if not outstanding:
		# Already fully received. Not an error, and not a second receipt
		# either — booking the same delivery twice invents stock.
		return {
			"status": "not_needed",
			"purchase_order": purchase_order,
			"supplier": order.supplier,
			"message": "Everything on this order has already been received.",
		}

	# What the caller asked for, by item. Absent means "all of it".
	asked = {}
	for line in items or []:
		code = line.get("item_code")
		if not frappe.db.exists("Item", code):
			frappe.throw(f"Item {code} does not exist.")
		qty = flt(line.get("qty"))
		if qty <= 0:
			frappe.throw(f"Quantity for {code} must be greater than zero.")
		asked[code] = asked.get(code, 0.0) + qty

	if not frappe.has_permission("Purchase Receipt", "submit"):
		frappe.throw(
			"You can create a receipt but not submit one, and an unsubmitted "
			"receipt never reaches the warehouse. Ask someone with submit rights."
		)

	receipt = make_purchase_receipt(purchase_order)
	receipt.posting_date = nowdate()

	adjusted = []
	keep = []
	for row in receipt.items:
		pending = outstanding.get(row.purchase_order_item, 0.0)
		if pending <= 0:
			continue

		wanted = asked.get(row.item_code, pending) if asked else pending
		booked = round(min(wanted, pending), 3)
		if booked <= 0:
			continue
		if asked and wanted > pending + 0.001:
			adjusted.append({"item_code": row.item_code, "asked": wanted, "received": booked})

		row.received_qty = booked
		row.qty = booked
		row.rejected_qty = 0
		keep.append(row)

	if not keep:
		return {
			"status": "not_needed",
			"purchase_order": purchase_order,
			"supplier": order.supplier,
			"message": "Nothing on this order is still outstanding.",
		}

	receipt.set("items", keep)
	missing = [row.item_code for row in receipt.items if not row.warehouse]
	if missing:
		# ERPNext would refuse this too, later and less clearly. Stock has to
		# land somewhere nameable.
		frappe.throw("No warehouse is set for " + ", ".join(missing) + ".")

	receipt.insert()
	receipt.submit()

	# Read back from the database rather than reported from memory: the point
	# of a receipt is what the ledger now says.
	order.reload()
	return {
		"status": "created",
		"purchase_receipt": receipt.name,
		"purchase_order": purchase_order,
		"supplier": order.supplier,
		"received_on": str(receipt.posting_date),
		"fully_received": all(flt(r.qty) - flt(r.received_qty) <= 0 for r in order.items),
		"adjusted": adjusted,
		"items": [
			{
				"item_code": row.item_code,
				"received_qty": flt(row.received_qty),
				"uom": row.uom,
				"warehouse": row.warehouse,
			}
			for row in receipt.items
		],
		"order_lines": [
			{
				"item_code": row.item_code,
				"ordered_qty": flt(row.qty),
				"received_qty": flt(row.received_qty),
				"remaining_qty": round(max(0.0, flt(row.qty) - flt(row.received_qty)), 3),
			}
			for row in order.items
		],
	}
