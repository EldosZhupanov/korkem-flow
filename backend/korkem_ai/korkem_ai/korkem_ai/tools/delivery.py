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

# Shipping moved to the domain in Horizon 1's fifth action. `_lines_for` and
# `_on_hand` are imported back because `delivery_status` — a read tool that
# stays here — asks the same question about the same shelf, and two answers to
# "how much can go out" is one too many.
from korkem_manufacturing.services.dispatch import (  # noqa: E402,F401
	_lines_for,
	_on_hand,
	create_delivery,
)


def _api():
	"""The published endpoint the dispatch tool is an alias for."""
	from korkem_manufacturing.api import dispatch

	return dispatch


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
		handler=_api().create_delivery,
		risk=Risk.WRITE,
		doctypes=("Delivery Note",),
		audit_category="sales",
		timeout=60,
	)
)
