# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Плёнки нет — где взять: филиалы поставщика, похожие у других; обёртка над services/film_sourcing.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import film_sourcing as service


@frappe.whitelist(methods=["GET"])
def where(order: str) -> dict:
	"""Плёнки, которых заказу не хватает: где купить, сколько стоит с доставкой, успеет ли, похожие."""
	return service.where(order)


@frappe.whitelist(methods=["POST"])
def order(order: str, item: str, supplier: str, metres: float, price_m: float | None = None,
		  comes_on: str | None = None, said_by: str | None = None) -> dict:
	"""«Есть — заказать»: в «К заказу» у этого поставщика, под этот заказ."""
	return service.order(order, item, supplier, metres, price_m, comes_on, said_by)


@frappe.whitelist(methods=["POST"])
def nowhere(order: str, item: str) -> dict:
	"""Обзвонили — нет нигде."""
	return service.nowhere(order, item)


@frappe.whitelist(methods=["POST"])
def replace(order: str, old: str, new: str, reason: str | None = None) -> dict:
	"""Клиент согласился на похожую: плёнка в заказе заменена."""
	return service.replace(order, old, new, reason)
