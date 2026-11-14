# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Склад краски — тонкая обёртка над services/paint_stock.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import paint_stock as service


@frappe.whitelist(methods=["GET"])
def stock() -> dict:
	"""Краски на складе, хватит ли на очередь, долги за краску."""
	return service.stock()


@frappe.whitelist(methods=["GET"])
def history(item: str) -> dict:
	"""Приходы одной краски: когда, сколько, почём, от кого, откуда."""
	return service.history(item)


@frappe.whitelist(methods=["POST"])
def receive(colour: str, kg: float | str, price_kg: float | str, supplier: str, base: str | None = None,
			received_on: str | None = None, note: str | None = None, delivery: str | dict | None = None,
			received_by: str | None = None, supplier_pay: str | dict | None = None) -> dict:
	"""Приход краски: цвет, что это, кг, цена за кг, поставщик; доставка, оплата, кто принял."""
	return service.receive(colour, kg, price_kg, supplier, base=base, received_on=received_on, note=note,
						   delivery=delivery, received_by=received_by, supplier_pay=supplier_pay)


@frappe.whitelist(methods=["POST"])
def set_kg_per_m2(value: float | str) -> dict:
	"""Расход краски, кг на м²."""
	return service.set_kg_per_m2(value)


@frappe.whitelist(methods=["POST"])
def pay_supplier(receipt: str, method: str | None = None) -> dict:
	"""Оплатили долг за краску — сегодня."""
	return service.pay_supplier(receipt, method)


@frappe.whitelist(methods=["POST"])
def add_supplier(name: str) -> dict:
	"""Новый поставщик краски."""
	return service.add_supplier(name)


@frappe.whitelist(methods=["POST"])
def count(item: str, kg: float | str) -> dict:
	"""Пересчёт: сколько кг этой краски на самом деле."""
	return service.count(item, kg)
