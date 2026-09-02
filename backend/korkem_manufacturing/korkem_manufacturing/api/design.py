# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Дизайн по заказу — тонкая обёртка над services/design.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import design as service


@frappe.whitelist(methods=["POST"])
def assign(sales_order: str, designer: str, due_on: str) -> dict:
	"""Поручить дизайн по заказу, со сроком."""
	return service.assign(sales_order=sales_order, designer=designer, due_on=due_on)


@frappe.whitelist(methods=["POST"])
def deliver(sales_order: str) -> dict:
	"""Принять дизайн — только если чертёж приложен к заказу."""
	return service.deliver(sales_order=sales_order)
