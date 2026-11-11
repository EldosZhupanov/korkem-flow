# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Отдел плёнки — тонкая обёртка над services/film_dept.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import film_dept as service


@frappe.whitelist(methods=["GET"])
def stock() -> dict:
	"""Склад отдела: плёнки с остатком в метрах, сначала те, которых мало."""
	return service.stock()


@frappe.whitelist(methods=["GET"])
def history(item: str, limit: int | str = 100) -> list[dict]:
	"""Что пришло и что ушло по одной плёнке."""
	return service.history(item, limit=int(limit or 100))


@frappe.whitelist(methods=["POST"])
def receive(item: str, metres: float | str, price_m: float | str, supplier: str,
			received_on: str | None = None, note: str | None = None, update_price: str | bool = True) -> dict:
	"""Приход: рулон или отрез от оптовика, метры и цена за метр; закуп в карточке обновляется."""
	return service.receive(
		item, metres, price_m, supplier, received_on=received_on, note=note, update_price=update_price
	)


@frappe.whitelist(methods=["POST"])
def sell(customer: str, lines: str | list, paid: float | str = 0, method: str | None = None,
		 bank: str | None = None, sold_on: str | None = None, note: str | None = None,
		 payments: str | list | None = None) -> dict:
	"""Продажа плёнки клиенту: одна или несколько плёнок, оплата одним или несколькими способами, или долг."""
	return service.sell(
		customer, lines, paid=paid, method=method, bank=bank, sold_on=sold_on, note=note, payments=payments
	)


@frappe.whitelist(methods=["POST"])
def to_shop(item: str, metres: float | str, order: str | None = None, note: str | None = None) -> dict:
	"""Выдать плёнку в свой цех."""
	return service.to_shop(item, metres, order=order, note=note)


@frappe.whitelist(methods=["POST"])
def write_off(item: str, metres: float | str, reason: str) -> dict:
	"""Списать метры с обязательной причиной."""
	return service.write_off(item, metres, reason)


@frappe.whitelist(methods=["POST"])
def pay(entry: str, amount: float | str | None = None, method: str | None = None, bank: str | None = None,
		payments: str | list | None = None) -> dict:
	"""Доплата по продаже, оставшейся в долг: одним способом или несколькими."""
	return service.pay(entry, amount, method=method, bank=bank, payments=payments)


@frappe.whitelist(methods=["POST"])
def cancel(entry: str, reason: str) -> dict:
	"""Отменить запись, внесённую по ошибке: метры возвращаются на склад."""
	return service.cancel(entry, reason)


@frappe.whitelist(methods=["GET"])
def sales(since: str | None = None, until: str | None = None, customer: str | None = None) -> list[dict]:
	"""Продажи отдела."""
	return service.sales(since=since, until=until, customer=customer)


@frappe.whitelist(methods=["GET"])
def price_for(item: str, customer: str | None = None) -> dict:
	"""Цена метра этой плёнки для этого клиента."""
	return service.price_for(item, customer)


@frappe.whitelist(methods=["GET"])
def customers() -> list[dict]:
	"""Клиенты плёнки: за месяц, всего, последняя покупка, «уснул»."""
	return service.customers()


@frappe.whitelist(methods=["POST"])
def set_customer(customer: str, tier: str | None = None, discount: float | str | None = None,
				 buys_film: bool | int | str = 1) -> dict:
	"""Условия клиента по плёнке: розница или опт, скидка."""
	return service.set_customer(customer, tier=tier, discount=discount, buys_film=buys_film)
