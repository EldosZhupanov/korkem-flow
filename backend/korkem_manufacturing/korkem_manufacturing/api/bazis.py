# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Чтение выгрузки БАЗИС — тонкая обёртка над services/bazis.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import bazis as service


@frappe.whitelist(methods=["POST"])
def inspect() -> dict:
	"""Разобрать присланную выгрузку и рассказать, что в ней. Ничего не пишет."""
	uploaded = (frappe.request.files or {}).get("file")
	if uploaded is None:
		frappe.throw("В запросе нет файла. Ожидается поле «file».")

	return service.inspect(content=uploaded.stream.read())


@frappe.whitelist(methods=["POST"])
def import_specification(sales_order: str | None = None) -> dict:
	"""Собрать спецификацию и маршрут из присланной выгрузки."""
	uploaded = (frappe.request.files or {}).get("file")
	if uploaded is None:
		frappe.throw("В запросе нет файла. Ожидается поле «file».")

	return service.import_specification(
		content=uploaded.stream.read(), sales_order=sales_order
	)


@frappe.whitelist(methods=["POST"])
def accept(bom: str) -> dict:
	"""Согласиться со спецификацией — после этого её видит расчёт дефицита."""
	return service.accept(bom=bom)
