# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Логистика — тонкая обёртка над services/logistics.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import logistics as service


@frappe.whitelist(methods=["POST"])
def record(
	amount: float | str,
	from_city: str,
	transport: str,
	category: str | None = None,
	delivered_on: str | None = None,
	ordered_on: str | None = None,
	carrier: str | None = None,
	urgent: bool | int | str = 0,
	supplier: str | None = None,
	sales_order: str | None = None,
	receipt: str | None = None,
	item: str | None = None,
	what: str | None = None,
	qty: float | str | None = None,
	unit: str | None = None,
	note: str | None = None,
	idempotency_key: str | None = None,
) -> dict:
	"""Записать доставку: сколько стоила, откуда, чем, что привезли."""
	from korkem_manufacturing.services.idempotency import execute as execute_idempotently

	arguments = {
		"amount": amount, "from_city": from_city, "transport": transport, "category": category,
		"delivered_on": delivered_on, "ordered_on": ordered_on, "carrier": carrier, "urgent": urgent,
		"supplier": supplier, "sales_order": sales_order, "receipt": receipt, "item": item,
		"what": what, "qty": qty, "unit": unit, "note": note,
	}
	return execute_idempotently(
		"logistics.recorded", idempotency_key, arguments, lambda: service.record(**arguments)
	)


@frappe.whitelist(methods=["POST"])
def cancel(delivery: str, reason: str) -> dict:
	"""Отменить ошибочную доставку с причиной. Ничего не удаляется."""
	return service.cancel(delivery, reason)


@frappe.whitelist(methods=["GET"])
def listing(
	month: str | None = None,
	category: str | None = None,
	sales_order: str | None = None,
	include_cancelled: bool | int | str = 0,
	limit: int = 200,
) -> dict:
	"""Доставки месяца (или одного заказа)."""
	return service.listing(
		month=month, category=category, sales_order=sales_order, include_cancelled=include_cancelled, limit=limit
	)


@frappe.whitelist(methods=["GET"])
def summary(month: str | None = None) -> dict:
	"""Итоги месяца: всего, по МДФ и плёнке, по городам, способам, за единицу."""
	return service.summary(month=month)


@frappe.whitelist(methods=["GET"])
def for_order(sales_order: str) -> dict:
	"""Логистика одного заказа."""
	return service.for_order(sales_order)


@frappe.whitelist(methods=["GET"])
def suggestions() -> dict:
	"""Города, способы доставки и перевозчики для формы."""
	return service.suggestions()
