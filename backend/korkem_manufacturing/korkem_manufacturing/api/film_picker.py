# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Окно выбора плёнки в заказе; обёртка над services/film_picker.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import film_picker as service


@frappe.whitelist(methods=["GET"])
def extras(customer: str | None = None) -> dict:
	"""Декоры каталогов поставщиков, ещё не заведённые, и недавние плёнки клиента."""
	return service.extras(customer)


@frappe.whitelist(methods=["POST"])
def take(decor: str) -> dict:
	"""Декор из каталога поставщика выбран в заказ: заводится плёнкой, ответ — её название."""
	return service.take(decor)
