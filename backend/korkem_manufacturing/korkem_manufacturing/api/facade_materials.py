# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Материалы фасадного заказа — тонкая обёртка над services/facade_materials.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import facade_materials as service
from korkem_manufacturing.services import material_stock


@frappe.whitelist(methods=["GET"])
def need(sales_order: str) -> dict:
	"""Что заказу нужно со склада: МДФ по толщине, плёнка по декору; удержано, списано, свободно, не хватает."""
	material_stock._ensure_staff()
	return service.need(sales_order)


@frappe.whitelist(methods=["POST"])
def reserve(sales_order: str) -> dict:
	"""Удержать свободный материал под то, чего заказу ещё не хватает. Повтор безопасен."""
	if not material_stock.can_edit():
		frappe.throw("Резервирует склад или менеджеры.", frappe.PermissionError)
	return service.reserve(sales_order)


@frappe.whitelist(methods=["GET"])
def norms() -> dict:
	"""Размер листа МДФ и запасы на раскрой и плёнку."""
	material_stock._ensure_staff()
	return service.norms()


@frappe.whitelist(methods=["POST"])
def save_norms(
	sheet_length_mm: int | str | None = None,
	sheet_width_mm: int | str | None = None,
	mdf_waste_percent: float | str | None = None,
	film_waste_percent: float | str | None = None,
) -> dict:
	"""Сохранить нормы расхода (администратор, менеджеры)."""
	return service.save_norms(
		sheet_length_mm=sheet_length_mm,
		sheet_width_mm=sheet_width_mm,
		mdf_waste_percent=mdf_waste_percent,
		film_waste_percent=film_waste_percent,
	)
