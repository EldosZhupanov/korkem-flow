# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Склады — тонкая обёртка над services/warehouses.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import warehouses as service


@frappe.whitelist(methods=["GET"])
def listing() -> list[dict]:
	"""Склады компании и что на них лежит."""
	return service.listing()


@frappe.whitelist(methods=["POST"])
def create(name: str) -> dict:
	"""Завести склад."""
	return service.create(name=name)


@frappe.whitelist(methods=["POST"])
def set_shipping_default(warehouse: str) -> dict:
	"""Назначить склад, с которого уходит готовая мебель."""
	return service.set_shipping_default(warehouse=warehouse)


@frappe.whitelist(methods=["POST"])
def set_disabled(warehouse: str, disabled: bool = True) -> dict:
	"""Убрать место из выбора, не трогая историю."""
	return service.set_disabled(
		warehouse=warehouse, disabled=frappe.utils.sbool(disabled)
	)
