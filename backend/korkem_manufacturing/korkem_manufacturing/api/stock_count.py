# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Пересчёт склада и расход месяца — тонкая обёртка над services/stock_count.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import stock_count as service


@frappe.whitelist(methods=["POST"])
def record(
	counted: dict | str,
	counted_on: str | None = None,
	note: str | None = None,
	idempotency_key: str | None = None,
) -> dict:
	"""Что насчитали на полке. Расхождения проводятся одним документом ERPNext."""
	from korkem_manufacturing.services.idempotency import execute as execute_idempotently

	arguments = {"counted": counted, "counted_on": counted_on, "note": note}
	return execute_idempotently(
		"stock.counted", idempotency_key, arguments, lambda: service.record(**arguments)
	)


@frappe.whitelist(methods=["GET"])
def counts(month: str | None = None) -> list:
	"""Пересчёты месяца."""
	return service.counts(month=month)


@frappe.whitelist(methods=["GET"])
def month_usage(month: str | None = None) -> dict:
	"""Расход месяца: было, пришло, осталось, ушло по факту, по заказам, не объяснено."""
	return service.month_usage(month=month)
