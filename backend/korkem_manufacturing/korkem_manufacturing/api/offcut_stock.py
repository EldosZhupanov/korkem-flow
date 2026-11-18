# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Обрезки МДФ на полке и подсказка «из обрезков» для заказа; обёртка над services/offcut_stock.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import offcut_stock as service


@frappe.whitelist(methods=["GET"])
def listing() -> dict:
	"""Обрезки на полке (свободные и отложенные), толщины МДФ."""
	return service.listing()


@frappe.whitelist(methods=["POST"])
def add(thickness_mm: float, length_mm: float, width_mm: float, cell: str | None = None,
		source_order: str | None = None, note: str | None = None) -> dict:
	"""Положить обрезок на полку: толщина, размер, ячейка."""
	return service.add(thickness_mm, length_mm, width_mm, cell, source_order, note)


@frappe.whitelist(methods=["POST"])
def use(offcut: str, order: str | None = None) -> dict:
	"""Обрезок взят в работу (для заказа, если есть)."""
	return service.use(offcut, order)


@frappe.whitelist(methods=["POST"])
def scrap(offcut: str, reason: str | None = None) -> dict:
	"""Обрезок в утиль."""
	return service.scrap(offcut, reason)


@frappe.whitelist(methods=["GET"])
def suggest(order: str) -> dict:
	"""Детали заказа, которые можно выкроить из обрезков."""
	return service.suggest(order)


@frappe.whitelist(methods=["POST"])
def take(offcut: str, order: str) -> dict:
	"""«Взять»: предложенный обрезок — в этот заказ."""
	return service.take(offcut, order)
