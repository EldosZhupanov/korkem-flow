# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Receiving a delivery, published. The store keeper, the desktop and the model.

Third endpoint of Horizon 1, and the first that a **warehouse** role reaches
rather than a production one — which is the point of publishing them at all: a
store keeper booking in a pallet should not need a language model, and should
not need production rights either.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import purchasing as service
from korkem_manufacturing.services.scope import ensure_company

#: Who may book stock in. Deliberately not the production roles: receiving is
#: the store's job, and a cutting operator has no business creating a Purchase
#: Receipt. `Stock Manager` and `Purchase User` are ERPNext's own names for
#: exactly these two responsibilities (ADR-0013).
MAY_RECEIVE = (
	"Stock Manager",
	"Stock User",
	"Purchase Manager",
	"Purchase User",
	"System Manager",
)


@frappe.whitelist()
def receive_purchase_order(purchase_order: str, items: list | str | None = None) -> dict:
	"""Book a delivery in against its purchase order.

	`items` narrows a partial delivery. It arrives as a list from a tool and as
	a JSON string from a form, and both mean the same thing — parsed here so
	the service sees one shape and neither caller has to know about the other.
	"""
	if not isinstance(purchase_order, str) or not purchase_order.strip():
		frappe.throw("Which purchase order? A name is required.")
	purchase_order = purchase_order.strip()

	# Company first, from the session. Booking stock into another factory's
	# warehouse is exactly what this prevents.
	ensure_company("Purchase Order", purchase_order)

	if not any(role in frappe.get_roles() for role in MAY_RECEIVE):
		frappe.throw(
			"You do not have warehouse rights, so you cannot receive a "
			"delivery. Ask a stock manager.",
			frappe.PermissionError,
		)

	result = service.receive_purchase_order(purchase_order, _items(items))
	_audit(purchase_order, result)
	return result


def _items(value) -> list | None:
	"""The narrowing list, from whichever shape the caller sent.

	A malformed string is refused rather than silently ignored: dropping it
	would book the **whole** order in, which is the opposite of what somebody
	asking for a partial delivery meant.
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


def _audit(purchase_order: str, result: dict) -> None:
	"""Who booked in what, on the order itself. Guarded like every other audit.

	The receipt is already submitted by this point and the stock has already
	moved; failing to write a note must not undo either.
	"""
	savepoint = "korkem_recv_audit_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "Purchase Order",
				"reference_name": purchase_order,
				"content": (
					f"KORKEM: {frappe.session.user} — приёмка, статус "
					f"{result.get('status')}, поступление {result.get('purchase_receipt')}."
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
			title="Could not record who received a delivery",
			message=frappe.get_traceback(with_context=True),
		)
