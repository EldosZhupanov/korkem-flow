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
			received_on: str | None = None, note: str | None = None, update_price: str | bool = True,
			delivery: str | dict | None = None, received_by: str | None = None,
			arrives_on: str | None = None) -> dict:
	"""Приход: метры и цена за метр; как пришла, за сколько привезли, кто принял;
	когда прибудет — если ещё в пути."""
	return service.receive(
		item, metres, price_m, supplier, received_on=received_on, note=note, update_price=update_price,
		delivery=delivery, received_by=received_by, arrives_on=arrives_on,
	)


@frappe.whitelist(methods=["POST"])
def arrived(entry: str, metres: float | str | None = None) -> dict:
	"""Плёнка в пути пришла: на склад сегодня; метры — если пришло не столько."""
	return service.arrived(entry, metres=metres)


@frappe.whitelist(methods=["POST"])
def reschedule(entry: str, arrives_on: str) -> dict:
	"""Плёнка в пути задерживается: новая дата прибытия."""
	return service.reschedule(entry, arrives_on)


@frappe.whitelist(methods=["POST"])
def drop_coming(entry: str, reason: str) -> dict:
	"""Плёнка в пути не придёт — с причиной."""
	return service.drop_coming(entry, reason)


@frappe.whitelist(methods=["POST"])
def sell(customer: str, lines: str | list, paid: float | str = 0, method: str | None = None,
		 bank: str | None = None, sold_on: str | None = None, note: str | None = None,
		 payments: str | list | None = None, seller: str | None = None) -> dict:
	"""Продажа плёнки клиенту: плёнки, оплата одним или несколькими способами, продавец."""
	return service.sell(
		customer, lines, paid=paid, method=method, bank=bank, sold_on=sold_on, note=note, payments=payments,
		seller=seller,
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


@frappe.whitelist(methods=["GET"])
def delivery_options() -> dict:
	"""Как пришла, из какого города, кто принял; сотрудники для продавца."""
	return service.delivery_options()


@frappe.whitelist(methods=["POST"])
def correct(entry: str, item: str, reason: str, metres: float | str | None = None,
			price_m: float | str | None = None, supplier: str | None = None, order: str | None = None,
			why: str | None = None) -> dict:
	"""Исправить запись: старая зачёркивается, новая вносится тем же днём, с причиной."""
	return service.correct(entry, item, reason, metres=metres, price_m=price_m, supplier=supplier,
						   order=order, why=why)


@frappe.whitelist(methods=["POST"])
def correct(entry: str, item: str, reason: str, metres: float | str | None = None,
			price_m: float | str | None = None, supplier: str | None = None, order: str | None = None,
			why: str | None = None) -> dict:
	"""Исправить запись: старая зачёркивается, новая вносится тем же днём, с причиной."""
	return service.correct(entry, item, reason, metres=metres, price_m=price_m, supplier=supplier,
						   order=order, why=why)


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
