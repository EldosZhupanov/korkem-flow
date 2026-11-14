# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Счёт на оплату за плёнку — тонкая обёртка над services/film_invoice.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import film_invoice as service


@frappe.whitelist(methods=["GET"])
def requisites() -> dict:
	"""Реквизиты компании для счёта."""
	return service.requisites()


@frappe.whitelist(methods=["POST"])
def set_requisites(values: str | dict) -> dict:
	"""Сохранить реквизиты компании."""
	return service.set_requisites(values)


@frappe.whitelist(methods=["POST"])
def invoice(sale: str, due_on: str | None = None) -> dict:
	"""Счёт на оплату по продаже: номер, дата, срок, реквизиты, покупатель."""
	return service.invoice(sale, due_on)
