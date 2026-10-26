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
def save(milling: str, finish: str, price_per_m2, enabled: bool | int | str = True) -> dict:
	"""Изменить одну ячейку или добавить новую фрезеровку."""
	return service.set_price(milling, finish, price_per_m2, enabled)


@frappe.whitelist(methods=["GET"])
def read_settings() -> dict:
	"""Правила расчёта: двусторонние, материал заказчика, демонтаж, предоплата."""
	from korkem_manufacturing.services import facade_quote

	return facade_quote.read_settings()


@frappe.whitelist(methods=["POST"])
def save_settings(
	double_sided_factor=None,
	customer_material_offered=None,
	customer_material_discount_percent=None,
	demolition_unit=None,
	demolition_rate=None,
	prepayment_percent=None,
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
def quote(lines, demolition=0, prepayment_amount=None) -> dict:
	"""Расчёт заказа фасадов: штуки, м², сумма, предоплата, остаток. Ничего не записывает."""
	from korkem_manufacturing.services import facade_quote

	return facade_quote.quote(lines, demolition=demolition, prepayment_amount=prepayment_amount)

