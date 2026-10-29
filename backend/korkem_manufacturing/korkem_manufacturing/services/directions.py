# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Two lines of business on one floor: facades and furniture.

Facades are a service sold by the square metre, mostly to other workshops; an
order is days long. Furniture is a project for an end customer that runs from
measuring to warranty over weeks. They share the stock, the people and the
customers, so they live in one system — but every order says which line it is,
and the lists, the shop floor and the owner's reports split by it.

The direction is the server's to set: an order made from a facade quote is a
facade order (`facade_order.create_order`), everything else is furniture. It is
not a field a screen may change.

Two marks ride along, both from the KORKEM brief: an **urgent** order goes to
the head of every queue, and a customer's **tier** (new, regular, VIP) is shown
wherever their name is.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import audit
from korkem_manufacturing.services.scope import ensure_company

FURNITURE = "Furniture"
FACADES = "Facades"
DIRECTIONS = (FURNITURE, FACADES)

NEW, REGULAR, VIP = "New", "Regular", "VIP"
TIERS = (NEW, REGULAR, VIP)

#: Urgency reorders the floor's queue, so the people who plan the floor and the
#: people who promised the customer may set it.
MAY_MARK_URGENT = frozenset(
	{"System Manager", "Sales Manager", "Sales User", "Manufacturing Manager"}
)
#: A tier is a commercial judgement about a customer.
MAY_SET_TIER = frozenset({"System Manager", "Sales Manager"})


def direction_of(sales_order: str) -> str:
	return frappe.db.get_value("Sales Order", sales_order, "korkem_direction") or FURNITURE


def validate_direction(direction: str | None) -> str | None:
	"""A filter value from a screen: one of the two, or nothing."""
	if direction in (None, ""):
		return None
	if direction not in DIRECTIONS:
		frappe.throw(f"Направление должно быть одним из: {', '.join(DIRECTIONS)}.")
	return direction


def set_urgent(sales_order: str, urgent: bool) -> dict:
	"""Mark an order urgent, or take the mark off."""
	if not MAY_MARK_URGENT.intersection(frappe.get_roles()):
		frappe.throw("Срочность заказа ставят продажи или начальник производства.", frappe.PermissionError)
	if not frappe.db.exists("Sales Order", sales_order):
		frappe.throw("Такого заказа нет.", frappe.DoesNotExistError)
	# Another company's order reads exactly like a missing one.
	ensure_company("Sales Order", sales_order)
	if frappe.db.get_value("Sales Order", sales_order, "docstatus") == 2:
		frappe.throw("Заказ отменён.")

	urgent = flag(urgent)
	before = bool(frappe.db.get_value("Sales Order", sales_order, "korkem_urgent"))
	if before != urgent:
		frappe.db.set_value("Sales Order", sales_order, "korkem_urgent", 1 if urgent else 0)
		audit.record_audit(
			action="sales.order_urgency",
			entity_type="Sales Order",
			entity_id=sales_order,
			diff={"before": before, "after": urgent},
		)
	return {"sales_order": sales_order, "urgent": urgent, "changed": before != urgent}


def set_tier(customer: str, tier: str | None) -> dict:
	"""Put a customer in a tier: new, regular or VIP — or clear it."""
	if not MAY_SET_TIER.intersection(frappe.get_roles()):
		frappe.throw("Категорию клиента ставит руководитель продаж.", frappe.PermissionError)
	tier = tier or ""
	if tier and tier not in TIERS:
		frappe.throw(f"Категория должна быть одной из: {', '.join(TIERS)}.")
	if not frappe.db.exists("Customer", customer):
		frappe.throw("Такого клиента нет.", frappe.DoesNotExistError)

	before = frappe.db.get_value("Customer", customer, "korkem_tier") or ""
	if before != tier:
		frappe.db.set_value("Customer", customer, "korkem_tier", tier)
		audit.record_audit(
			action="sales.customer_tier",
			entity_type="Customer",
			entity_id=customer,
			diff={"before": before or None, "after": tier or None},
		)
	return {"customer": customer, "tier": tier or None, "changed": before != tier}


def flag(value) -> bool:
	"""A flag as a form or JSON sends it: 1, "1", true, "true"."""
	if isinstance(value, str):
		return value.strip().lower() in ("1", "true", "yes")
	return bool(value)
