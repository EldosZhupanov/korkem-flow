# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Договор по заказу — тонкая обёртка над services/contract.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import contract as service


@frappe.whitelist(methods=["POST"])
def draft(sales_order: str, terms: str | None = None) -> dict:
	"""Собрать договор по заказу."""
	return service.draft(sales_order=sales_order, terms=terms)


@frappe.whitelist(methods=["POST"])
def sign(contract: str, signee: str, signed_on: str | None = None) -> dict:
	"""Отметить, что договор подписан — кем и когда."""
	return service.sign(contract=contract, signee=signee, signed_on=signed_on)


@frappe.whitelist(methods=["GET"])
def status(sales_order: str) -> dict:
	"""Что с договором по заказу."""
	return service.status(sales_order=sales_order)
