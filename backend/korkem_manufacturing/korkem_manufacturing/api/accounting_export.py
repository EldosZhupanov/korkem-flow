# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Обмен с 1С — тонкая обёртка над services/accounting_export.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import accounting_export as service


@frappe.whitelist(methods=["GET"])
def settings() -> dict:
	"""Включён ли обмен с 1С и какие таблицы выгружаются."""
	return service.settings()


@frappe.whitelist(methods=["POST"])
def set_enabled(enabled: bool | int | str) -> dict:
	"""Включить или выключить обмен с 1С для компании."""
	return service.set_enabled(enabled)


@frappe.whitelist(methods=["GET"])
def export(table: str, from_date: str | None = None, to_date: str | None = None) -> dict:
	"""Таблица за период — текстом, который загружает 1С («Загрузка данных из табличного документа»)."""
	return service.export(table, from_date=from_date, to_date=to_date)
