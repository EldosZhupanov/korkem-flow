# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Раскладка фасадов на мембранно-вакуумном прессе — тонкая обёртка над services/press_layout.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import press_layout as service


@frappe.whitelist(methods=["GET"])
def settings() -> dict:
	"""Рабочее поле пресса, отступ, зазор, секции."""
	return service.press_settings()


@frappe.whitelist(methods=["POST"])
def save_settings(
	press_length_mm: int | str | None = None,
	press_width_mm: int | str | None = None,
	press_margin_mm: int | str | None = None,
	press_gap_mm: int | str | None = None,
	press_sections: str | list | None = None,
) -> dict:
	"""Сохранить настройки пресса (администратор, менеджеры)."""
	return service.save_press_settings(
		press_length_mm=press_length_mm,
		press_width_mm=press_width_mm,
		press_margin_mm=press_margin_mm,
		press_gap_mm=press_gap_mm,
		press_sections=press_sections,
	)


@frappe.whitelist(methods=["GET"])
def order_layout(sales_order: str) -> dict:
	"""Раскладка заказа по плёнкам: загрузки пресса, метраж, поправки."""
	return service.order_layout(sales_order)


@frappe.whitelist(methods=["POST"])
def set_film_metres(sales_order: str, decor: str, film_m: float | str | None = None, reason: str | None = None) -> dict:
	"""Поправить метраж плёнки по заказу вручную — с причиной; пусто — вернуть к раскладке."""
	return service.set_film_metres(sales_order, decor, film_m=film_m, reason=reason)
