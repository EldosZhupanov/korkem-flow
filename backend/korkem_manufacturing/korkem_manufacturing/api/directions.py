# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Срочность заказа и категория клиента — тонкая обёртка над services/directions.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import directions as service


@frappe.whitelist(methods=["POST"])
def set_urgent(sales_order: str, urgent: int | str | bool) -> dict:
	"""Отметить заказ срочным или снять отметку."""
	return service.set_urgent(sales_order=sales_order, urgent=urgent)


@frappe.whitelist(methods=["POST"])
def set_customer_tier(customer: str, tier: str | None = None) -> dict:
	"""Категория клиента: New, Regular, VIP — или пусто."""
	return service.set_tier(customer=customer, tier=tier)
