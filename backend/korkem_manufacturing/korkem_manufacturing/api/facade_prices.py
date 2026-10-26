# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Матрица цен фасадов — тонкая обёртка над services/facade_prices.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import facade_prices as service


@frappe.whitelist(methods=["GET"])
def read() -> dict:
	"""Вся матрица «фрезеровка × отделка» компании."""
	return service.table()


@frappe.whitelist(methods=["POST"])
def save(milling: str, finish: str, price_per_m2: float | str, enabled: bool | int | str = True) -> dict:
	"""Изменить одну ячейку или добавить новую фрезеровку."""
	return service.set_price(milling, finish, price_per_m2, enabled)


@frappe.whitelist(methods=["GET"])
def read_settings() -> dict:
	"""Правила расчёта: двусторонние, материал заказчика, демонтаж, предоплата."""
	from korkem_manufacturing.services import facade_quote

	return facade_quote.read_settings()


@frappe.whitelist(methods=["POST"])
def save_settings(
	double_sided_factor: float | str | None = None,
	customer_material_offered: int | str | None = None,
	customer_material_discount_percent: float | str | None = None,
	demolition_unit: str | None = None,
	demolition_rate: float | str | None = None,
	prepayment_percent: float | str | None = None,
) -> dict:
	"""Изменить правила расчёта; не присланное поле не меняется."""
	from korkem_manufacturing.services import facade_quote

	sent = {
		key: value
		for key, value in {
			"double_sided_factor": double_sided_factor,
			"customer_material_offered": customer_material_offered,
			"customer_material_discount_percent": customer_material_discount_percent,
			"demolition_unit": demolition_unit,
			"demolition_rate": demolition_rate,
			"prepayment_percent": prepayment_percent,
		}.items()
		if value is not None
	}
	return facade_quote.save_settings(**sent)


@frappe.whitelist(methods=["POST"])
def quote(
	lines: str | list,
	demolition: int | str = 0,
	prepayment_amount: float | str | None = None,
) -> dict:
	"""Расчёт заказа фасадов: штуки, м², сумма, предоплата, остаток. Ничего не записывает."""
	from korkem_manufacturing.services import facade_quote

	return facade_quote.quote(lines, demolition=demolition, prepayment_amount=prepayment_amount)


@frappe.whitelist(methods=["POST"])
def create_order(
	customer: str,
	delivery_date: str,
	lines: str | list,
	demolition: int | str = 0,
	prepayment_amount: float | str | None = None,
	notes: str | None = None,
	idempotency_key: str | None = None,
) -> dict:
	"""Создать заказ из расчёта. Цены пересчитываются на сервере, а не берутся у клиента.

	Повторное нажатие с тем же idempotency_key не создаёт второй заказ.
	"""
	from korkem_manufacturing.services import facade_order
	from korkem_manufacturing.services.idempotency import execute as execute_idempotently

	parsed = frappe.parse_json(lines) if isinstance(lines, str) else lines
	arguments = {
		"customer": customer,
		"delivery_date": delivery_date,
		"lines": parsed,
		"demolition": demolition,
		"prepayment_amount": prepayment_amount,
		"notes": notes,
	}
	return execute_idempotently(
		"sales.create_facade_order",
		idempotency_key,
		arguments,
		lambda: facade_order.create_order(**arguments),
	)


@frappe.whitelist(methods=["GET"])
def customers(search: str | None = None, limit: int = 20) -> list[dict]:
	"""Клиенты (ERPNext Customer), на которых можно оформить заказ."""
	from korkem_manufacturing.services import facade_order

	return facade_order.customers(search=search, limit=limit)

