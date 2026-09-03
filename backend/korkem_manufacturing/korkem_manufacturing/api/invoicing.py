# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Счёт по заказу — тонкая обёртка над services/invoicing.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import invoicing as service


@frappe.whitelist(methods=["POST"])
def draft(sales_order: str) -> dict:
	"""Собрать черновик счёта по фактически отгруженному."""
	return service.draft(sales_order=sales_order)
