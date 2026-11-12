# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Касса отдела плёнки — тонкая обёртка над services/film_cash.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import film_cash as service


@frappe.whitelist(methods=["GET"])
def book(since: str | None = None, until: str | None = None) -> dict:
	"""Пришло и ушло за период; что вернуть сотрудникам и что должны перевозчикам."""
	return service.book(since, until)


@frappe.whitelist(methods=["POST"])
def settle(receipt: str, method: str | None = None) -> dict:
	"""Вернули сотруднику или оплатили перевозчику — из кассы отдела, сегодня."""
	return service.settle(receipt, method)


@frappe.whitelist(methods=["POST"])
def close_day(counted: float | str, reason: str | None = None, day: str | None = None) -> dict:
	"""Закрыть день: сколько наличных насчитали; расхождение — с причиной."""
	return service.close_day(counted, reason=reason, day=day)
