# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Гарантия — тонкая обёртка над services/warranty.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import warranty as service


@frappe.whitelist(methods=["GET"])
def status(sales_order: str) -> dict:
	"""С какого дня и по какой действует гарантия по заказу."""
	return service.status(sales_order=sales_order)


@frappe.whitelist(methods=["POST"])
def claim(sales_order: str, item_code: str, complaint: str) -> dict:
	"""Принять рекламацию — если гарантия ещё действует."""
	return service.claim(
		sales_order=sales_order, item_code=item_code, complaint=complaint
	)
