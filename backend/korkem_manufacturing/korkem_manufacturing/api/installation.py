# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Монтаж — тонкая обёртка над services/installation.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import installation as service


@frappe.whitelist(methods=["POST"])
def schedule(sales_order: str, installer: str, install_on: str) -> dict:
	"""Назначить монтаж — если по заказу уже что-то отгружено."""
	return service.schedule(
		sales_order=sales_order, installer=installer, install_on=install_on
	)


@frappe.whitelist(methods=["POST"])
def complete(sales_order: str, notes: str | None = None) -> dict:
	"""Закрыть монтаж, с заметками бригады, если они есть."""
	return service.complete(sales_order=sales_order, notes=notes)
