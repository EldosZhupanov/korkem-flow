# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Номенклатура и цены — тонкая обёртка над services/catalogue.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import catalogue as service


@frappe.whitelist(methods=["GET"])
def units() -> list[dict]:
	"""Единицы измерения, которые имеет смысл предлагать."""
	return service.units()


@frappe.whitelist(methods=["GET"])
def items(query: str | None = None, limit: int = 50) -> list[dict]:
	"""Номенклатура с ценами; `query` ищет по коду и названию."""
	return service.items(query=query, limit=frappe.utils.cint(limit) or 50)


@frappe.whitelist(methods=["POST"])
def create(
	name: str,
	unit: str,
	code: str | None = None,
	description: str | None = None,
	price: float | None = None,
) -> dict:
	"""Завести позицию; цена необязательна."""
	return service.create(
		name=name, unit=unit, code=code, description=description, price=price
	)


@frappe.whitelist(methods=["POST"])
def set_price(code: str, price: float) -> dict:
	"""Назвать цену позиции."""
	return service.set_price(code=code, price=price)
