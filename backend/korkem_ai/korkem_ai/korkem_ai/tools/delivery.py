# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Getting the finished goods to the customer — the end of the chain.

## What ERPNext already does

`selling/doctype/sales_order/mapper.py:make_delivery_note` builds the document:
it validates the order is submitted, maps the lines, carries the link back to
the sales order, and accepts `filtered_children` for a partial shipment.
Submitting it is what moves the stock ledger and updates `delivered_qty` on the
order. None of that is reimplemented here.

## Two quantities, and shipping is bounded by both

A line can only go out if it is both **still owed** and **actually on the
shelf**:

    pending   = ordered − delivered            (ERPNext's own running total)
    available = Bin.actual_qty in the order's warehouse
    shippable = min(pending, available)

`available` is `actual_qty`, never `projected_qty`. Projected counts goods on
order and production not yet finished, and a lorry cannot be loaded with either.

## The model never supplies a quantity that reaches ERPNext

`create_delivery` takes an order and, at most, a list of items the user named.
Every quantity is recomputed from the two numbers above at execution — not at
proposal — and trimmed down to what is genuinely shippable. "Отгрузи 400
шкафов" against an order for ten that has six on the shelf ships six, and says
it adjusted. Between a model proposing a shipment and a person agreeing to it,
somebody else may have loaded the same cabinets.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, getdate, nowdate

from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register
from korkem_ai.korkem_ai.tools import scope
from korkem_ai.korkem_ai.tools.scope import ensure_company, scoped

#: Sales Order statuses that can no longer be shipped against.
UNSHIPPABLE = ("Closed", "Cancelled", "On Hold")

#: Statuses that mean the order is finished with.
SETTLED = ("Completed", "Closed", "Cancelled")


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


def _notes_for(order_names: list[str]) -> dict[str, list[dict]]:
	if not order_names:
		return {}
	found: dict[str, list[dict]] = {}
	for row in frappe.get_all(
		"Delivery Note Item",
		filters={"against_sales_order": ["in", order_names], "docstatus": 1},
		fields=["parent", "against_sales_order", "item_code", "qty"],
	):
		found.setdefault(row["against_sales_order"], []).append(
			{
				"delivery_note": row["parent"],
				"item_code": row["item_code"],
				"qty": flt(row["qty"]),
				"delivered_on": str(
					frappe.db.get_value("Delivery Note", row["parent"], "posting_date")
				),
			}
		)
	return found


def _state(order: dict, lines: list[dict]) -> tuple[str, str]:
	"""Our reading of the order, beside ERPNext's own status."""
	pending = sum(line["pending_qty"] for line in lines)
	shippable = sum(line["shippable_now"] for line in lines)

	if order["status"] in ("Cancelled", "Closed"):
		return "CLOSED", f"the order is {order['status']}"
	if pending <= 0:
		return "DELIVERED", "everything ordered has been delivered"
	if shippable <= 0:
		missing = ", ".join(
			f"{line['item_code']} short {line['short_by']} {line['uom']}"
			for line in lines
			if line["short_by"] > 0
		)
		return "BLOCKED", f"nothing is on the shelf to send — {missing}"
	if shippable < pending:
		return "PARTIAL", f"{shippable} of {round(pending, 3)} outstanding units are on the shelf"
	return "READY", "everything still owed is on the shelf"


def delivery_status(customer: str | None = None, sales_order: str | None = None):
	"""What can be shipped, and what is stopping the rest.

	One reading for both «что готово к отгрузке» across the factory and «можно
	ли отгрузить этот заказ» for one of them — the same question at two
	scopes, so one tool rather than two that could disagree.
	"""
	today = getdate(nowdate())

	# Pinned before anything is read. For staff this is the customer they asked
	# about; for a customer it is the one they are, and a named order they do
	# not own is refused as absent.
	customer = scope.pin_customer(customer)
	if sales_order:
		scope.owns_or_absent("Sales Order", sales_order)

	filters = {"docstatus": 1}
	if sales_order:
		ensure_company("Sales Order", sales_order)
		filters["name"] = sales_order
	else:
		filters["status"] = ["not in", SETTLED]
	if customer:
		filters["customer"] = customer

	orders = frappe.get_list(
		"Sales Order",
		filters=scoped(filters),
		fields=["name", "customer", "status", "delivery_date", "per_delivered"],
		order_by="delivery_date asc",
		limit_page_length=0,
	)
	if sales_order and not orders:
		frappe.throw(f"Sales order {sales_order} not found.")

	notes = _notes_for([row["name"] for row in orders])

	reported = []
	for order in orders:
		lines = _lines_for(order["name"])
		state, why = _state(order, lines)
		due = getdate(order["delivery_date"]) if order["delivery_date"] else None
		reported.append(
			{
				"sales_order": order["name"],
				"customer": order["customer"],
				# ERPNext's own status, and our reading of it, side by side.
				"erpnext_status": order["status"],
				"delivery_state": state,
				"reason": why,
				"delivery_date": str(due) if due else None,
				"days_until_due": (due - today).days if due else None,
				"overdue": bool(due and due < today and flt(order["per_delivered"]) < 100),
				"delivered_percent": flt(order["per_delivered"]),
				"ordered_qty": round(sum(line["ordered_qty"] for line in lines), 3),
				"delivered_qty": round(sum(line["delivered_qty"] for line in lines), 3),
				"pending_qty": round(sum(line["pending_qty"] for line in lines), 3),
				"shippable_now": round(sum(line["shippable_now"] for line in lines), 3),
				"items": lines,
				"blocking_items": [line for line in lines if line["short_by"] > 0],
				"delivery_notes": notes.get(order["name"], []),
			}
		)

	return {
		"as_of": str(today),
		"summary": {
			"orders": len(reported),
			"ready": len([row for row in reported if row["delivery_state"] == "READY"]),
			"partially_shippable": len([row for row in reported if row["delivery_state"] == "PARTIAL"]),
			"blocked": len([row for row in reported if row["delivery_state"] == "BLOCKED"]),
			"delivered": len([row for row in reported if row["delivery_state"] == "DELIVERED"]),
			"overdue": len([row for row in reported if row["overdue"]]),
		},
		"orders": reported,
	}


def create_delivery(sales_order: str, items: list | None = None):
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


register(
	ToolSpec(
		name="sales.delivery_status",
		description=(
			"What can be shipped to customers: how much of each order is still "
			"owed, how much is on the shelf, what is blocking the rest, and the "
			"delivery notes already sent. Use for «что готово к отгрузке», «что "
			"нужно доставить сегодня», «сколько осталось доставить», «можно ли "
			"отгрузить заказ X», «что уже доставили». Report its numbers as given."
		),
		input_schema={
			"type": "object",
			"properties": {
				"customer": {"type": "string", "description": "Narrow to one customer."},
				"sales_order": {"type": "string", "description": "Narrow to one order."},
			},
			"required": [],
		},
		handler=delivery_status,
		risk=Risk.READ,
		doctypes=("Sales Order", "Delivery Note", "Bin"),
		audit_category="sales",
		timeout=60,
	)
)

register(
	ToolSpec(
		name="sales.create_delivery",
		description=(
			"Ship finished goods to the customer against a sales order — "
			"«отгрузи», «отправь заказ». Quantities come from what is still owed "
			"and what is on the shelf; pass items only if the user named "
			"specific ones, and never a number they did not give you. Partial "
			"shipments are normal. Requires confirmation."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {"type": "string", "description": "The order to ship against"},
				"items": {
					"type": "array",
					"description": "Only for a partial shipment the user asked for by item.",
					"items": {
						"type": "object",
						"properties": {
							"item_code": {"type": "string"},
							"qty": {"type": "number", "description": "How many the user said to send"},
						},
						"required": ["item_code", "qty"],
					},
				},
			},
			"required": ["sales_order"],
		},
		handler=create_delivery,
		risk=Risk.WRITE,
		doctypes=("Delivery Note",),
		audit_category="sales",
		timeout=60,
	)
)
