# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Shipping to the customer, published. The last of the five.

The end of the chain. Everything upstream produces stock on a shelf; this is
what turns it into something the customer has — and, like the four before it,
it now happens through one function that a dispatcher, a desktop, a terminal
and the model all reach.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import dispatch as service
from korkem_manufacturing.services.scope import ensure_company

#: Who may ship. `Stock` roles because a delivery is a stock movement, and
#: `Delivery Manager`/`Sales Manager` because it is also a commitment to a
#: customer — ERPNext's own division, kept rather than reinvented (ADR-0013).
MAY_SHIP = (
	"Stock Manager",
	"Stock User",
	"Delivery Manager",
	"Delivery User",
	"Sales Manager",
	"System Manager",
)


@frappe.whitelist()
def create_delivery(sales_order: str, items: list | str | None = None) -> dict:
	"""Ship what is on the shelf against a sales order.

	Only physically available stock is shipped. A finished quantity on a work
	order is not goods in a warehouse — they can have been consumed, reserved
	or never received — so a delivery cannot promise what is not there.
	"""
	if not isinstance(sales_order, str) or not sales_order.strip():
		frappe.throw("Which sales order? A name is required.")
	sales_order = sales_order.strip()

	ensure_company("Sales Order", sales_order)

	if not any(role in frappe.get_roles() for role in MAY_SHIP):
		frappe.throw(
			"You do not have dispatch rights, so you cannot ship an order. "
			"Ask a stock or delivery manager.",
			frappe.PermissionError,
		)

	result = service.create_delivery(sales_order, _items(items))
	_audit(sales_order, result)
	return result


def _items(value) -> list | None:
	"""The narrowing list, from whichever shape the caller sent.

	Refused rather than ignored when unreadable: dropping it would ship the
	**whole** order, which is the opposite of what a partial dispatch means and
	rather harder to undo than a purchase receipt.
	"""
	if value is None or value == "":
		return None
	if isinstance(value, str):
		try:
			value = frappe.parse_json(value)
		except Exception:
			frappe.throw("items is not valid JSON.")
	if not isinstance(value, list):
		frappe.throw("items must be a list of lines.")
	return value


def _audit(sales_order: str, result: dict) -> None:
	"""Who shipped what, on the order. Guarded like every other audit here."""
	savepoint = "korkem_ship_audit_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "Sales Order",
				"reference_name": sales_order,
				"content": (
					f"KORKEM: {frappe.session.user} — отгрузка, статус "
					f"{result.get('status')}, накладная {result.get('delivery_note')}."
				),
			}
		).insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title="Could not record who shipped an order",
			message=frappe.get_traceback(with_context=True),
		)
