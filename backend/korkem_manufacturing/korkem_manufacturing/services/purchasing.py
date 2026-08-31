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
from frappe.utils import flt, getdate, nowdate

from korkem_manufacturing.services.scope import ensure_company


def receive_purchase_order(purchase_order: str, items: list | None = None):
	"""Book a delivery in against its purchase order.

	Owns a savepoint because the write is not one document. A Purchase Receipt is inserted and then submitted; a failure between the two commits a draft that nothing has received against.

	An outer HTTP transaction is not the boundary: `korkem_ai/tools/registry.py`
	catches `Exception` and returns it **as data** rather than re-raising, so
	through the AI adapter a failed submit leaves the draft committed and the
	next call makes another one.
	"""
	savepoint = "korkem_receive_" + frappe.generate_hash(length=8)
	frappe.db.savepoint(savepoint)
	try:
		result = _receive_purchase_order(purchase_order, items)
	except Exception:
		frappe.db.rollback(save_point=savepoint)
		raise
	frappe.db.release_savepoint(savepoint)
	return result


def _receive_purchase_order(purchase_order: str, items: list | None = None):
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


# --------------------------------------------------------------------------
# Ordering from a supplier
# --------------------------------------------------------------------------
#
# Prices, taxes and terms come from ERPNext's `get_party_details` and the
# supplier's price list — never from the request and never from a model. A
# purchase order carries money somebody has to pay, and the only defensible
# source for that figure is the one the accounts already agree with.


def _supplier_for(item_codes: list[str], company: str) -> tuple[str | None, list[str]]:
	"""Who this material is bought from, according to ERPNext.

	Never chosen at random and never invented. An item with no default supplier
	and no supplier list has no answer here, and the caller says so instead of
	picking one — a purchase order sent to the wrong company is a real letter to
	a real business.
	"""
	found: dict[str, set[str]] = {}
	for code in item_codes:
		suppliers = set(
			frappe.get_all(
				"Item Default",
				filters={"parent": code, "company": company, "default_supplier": ["is", "set"]},
				pluck="default_supplier",
			)
		)
		suppliers |= set(frappe.get_all("Item Supplier", filters={"parent": code}, pluck="supplier"))
		found[code] = suppliers

	without = sorted(code for code, suppliers in found.items() if not suppliers)
	if without:
		return None, without

	shared = set.intersection(*found.values()) if found else set()
	return (sorted(shared)[0] if shared else None), []


def create_purchase_order(
	material_request: str,
	supplier: str | None = None,
	schedule_date: str | None = None,
):
	"""Turn a material request into an order with a supplier.

	Owns a savepoint because the write is not one document: a Purchase Order is
	inserted and then submitted, and a committed draft leaves `ordered_qty` at
	zero on the request — so the next call creates a second one for the same
	material.

	An outer HTTP transaction is not the boundary: `korkem_ai/tools/registry.py`
	catches `Exception` and returns it **as data** rather than re-raising, so
	through the AI adapter the draft survives.
	"""
	savepoint = "korkem_order_" + frappe.generate_hash(length=8)
	frappe.db.savepoint(savepoint)
	try:
		result = _create_purchase_order(material_request, supplier, schedule_date)
	except Exception:
		frappe.db.rollback(save_point=savepoint)
		raise
	frappe.db.release_savepoint(savepoint)
	return result


def _create_purchase_order(
	material_request: str,
	supplier: str | None = None,
	schedule_date: str | None = None,
):
	"""Order what a material request still needs, from ERPNext's own mapper.

	Everything is re-read here rather than taken from the proposal. Between a
	model suggesting this and a human agreeing to it, somebody else may have
	ordered the same material, closed the request, or received it — and a
	purchase order is a letter to a supplier, not a draft note.
	"""
	from erpnext.stock.doctype.material_request.mapper import make_purchase_order

	if not frappe.db.exists("Material Request", material_request):
		frappe.throw(f"Material request {material_request} not found.")

	ensure_company("Material Request", material_request)
	request = frappe.get_doc("Material Request", material_request)
	request.check_permission("read")

	if request.docstatus != 1:
		frappe.throw(f"{material_request} is not submitted, so nothing can be ordered against it.")
	if request.material_request_type != "Purchase":
		frappe.throw(
			f"{material_request} is a {request.material_request_type} request, not a purchase."
		)
	if request.status in ("Stopped", "Cancelled"):
		frappe.throw(f"{material_request} is {request.status}.")

	pending = [
		row for row in request.items if flt(row.stock_qty) - flt(row.ordered_qty) > 0
	]
	if not pending:
		# Somebody else got there first. Not an error, and not a document
		# either — a purchase order for nothing is a letter nobody wanted sent.
		return {
			"status": "not_needed",
			"material_request": material_request,
			"message": "Everything on this request is already on order — no purchase order was created.",
		}

	chosen, unknown = _supplier_for([row.item_code for row in pending], request.company)
	if supplier:
		if not frappe.db.exists("Supplier", supplier):
			frappe.throw(f"Supplier {supplier} does not exist.")
		chosen = supplier
	elif unknown:
		return {
			"status": "supplier_unknown",
			"material_request": material_request,
			"items": unknown,
			"message": (
				"No supplier is set for " + ", ".join(unknown) + ". Choose one, or set a "
				"default supplier on the item first."
			),
		}
	elif not chosen:
		return {
			"status": "supplier_unknown",
			"material_request": material_request,
			"items": [row.item_code for row in pending],
			"message": (
				"These materials do not share a supplier, so they cannot go on one "
				"purchase order. Order them separately, naming a supplier."
			),
		}

	if not frappe.has_permission("Purchase Order", "submit"):
		frappe.throw(
			"You can create a purchase order but not submit one, and an unsubmitted "
			"order never reaches the supplier. Ask someone with submit rights."
		)

	order = make_purchase_order(
		material_request, args={"filtered_children": [row.name for row in pending]}
	)
	order.supplier = chosen
	order.transaction_date = nowdate()

	# The supplier's own terms — price list, currency, exchange rate — pulled
	# through ERPNext's party helper rather than left at the site default. The
	# mapper resolves these before it knows who the supplier is, and on a KZT
	# company inheriting an INR `Standard Buying` list every rate comes back
	# zero, which reads as "this material has no price" when it has one.
	from erpnext.accounts.party import get_party_details

	terms = get_party_details(
		party=chosen,
		party_type="Supplier",
		company=order.company,
		doctype="Purchase Order",
	)
	for field in ("buying_price_list", "currency", "conversion_rate", "price_list_currency", "plc_conversion_rate"):
		if terms.get(field):
			order.set(field, terms.get(field))
	if schedule_date:
		order.schedule_date = schedule_date
	for row in order.items:
		# A required-by date in the past is refused by ERPNext, and rightly —
		# the material was wanted before the order was written.
		if not row.schedule_date or getdate(row.schedule_date) < getdate(nowdate()):
			row.schedule_date = schedule_date or nowdate()

	# Cleared so ERPNext will fill them. `set_missing_item_details` only writes
	# a field that is `None`, and the mapper leaves `rate` and `price_list_rate`
	# at 0.0 — so the price list is consulted and its answer discarded, and
	# every order comes out free. Blanking them first is what makes the
	# maintained price resolution actually run.
	for row in order.items:
		row.rate = None
		row.price_list_rate = None

	order.run_method("set_missing_values")
	# `set_missing_values` resolves `price_list_rate` from the price list; `rate`
	# is derived from it a step later, during totals. Checking for a price
	# before that step finds zero on every line and refuses orders that are
	# perfectly well priced.
	order.run_method("calculate_taxes_and_totals")

	unpriced = [
		row.item_code
		for row in order.items
		if flt(row.rate) <= 0 and flt(row.price_list_rate) <= 0
	]
	if unpriced:
		# Refused rather than sent at zero. A price is a commitment, and a
		# purchase order that says nothing about money is one somebody has to
		# chase — or worse, one a supplier reads as free.
		return {
			"status": "price_unknown",
			"material_request": material_request,
			"supplier": chosen,
			"items": unpriced,
			"message": (
				"No buying price is set for " + ", ".join(unpriced) + ". Add a price "
				"or agree a rate with the supplier before ordering."
			),
		}

	order.insert()
	order.submit()

	return {
		"status": "created",
		"purchase_order": order.name,
		"material_request": material_request,
		"supplier": chosen,
		"expected_on": str(order.schedule_date) if order.schedule_date else None,
		"currency": order.currency,
		"total": flt(order.grand_total),
		"items": [
			{
				"item_code": row.item_code,
				"qty": flt(row.qty),
				"uom": row.uom,
				"rate": flt(row.rate),
				"amount": flt(row.amount),
				"expected_on": str(row.schedule_date) if row.schedule_date else None,
				"sales_order": row.sales_order,
			}
			for row in order.items
		],
	}
