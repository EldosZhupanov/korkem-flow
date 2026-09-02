# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Принятие КП — тонкая обёртка над services/acceptance.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import acceptance as service


@frappe.whitelist(methods=["POST"])
def accept(quotation: str, deliver_on: str) -> dict:
	"""Клиент согласился: провести предложение и собрать по нему заказ."""
	return service.accept(quotation=quotation, deliver_on=deliver_on)
