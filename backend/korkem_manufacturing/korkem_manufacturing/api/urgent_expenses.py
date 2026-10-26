# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Срочные расходы — тонкая обёртка над services/urgent_expenses.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import urgent_expenses as service


@frappe.whitelist(methods=["POST"])
def file(amount: float | str, purpose: str, category: str = "Другое", sales_order: str | None = None) -> dict:
	"""Записать срочный расход на себя."""
	return service.file(amount, purpose, category, sales_order)


@frappe.whitelist(methods=["POST"])
def attach_receipt(expense: str) -> dict:
	"""Приложить фото чека (поле «file» в теле запроса)."""
	uploaded = (frappe.request.files or {}).get("file") if frappe.request else None
	if uploaded is None:
		frappe.throw("В запросе нет файла. Ожидается поле «file».")
	return service.attach_receipt(expense, uploaded.filename or "", uploaded.stream.read())


@frappe.whitelist(methods=["POST"])
def decide(expense: str, approve: bool | int | str, note: str | None = None) -> dict:
	"""Одобрить или отклонить (администратор, бухгалтерия; не свой)."""
	return service.decide(expense, approve, note)


@frappe.whitelist(methods=["GET"])
def listing(status: str | None = None, mine_only: bool | int | str = False, limit: int = 100) -> dict:
	"""Свои расходы; для администратора и бухгалтерии — все по компании."""
	return service.listing(status=status, mine_only=mine_only, limit=limit)
