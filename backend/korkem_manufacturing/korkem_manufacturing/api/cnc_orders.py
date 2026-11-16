# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Услуги ЧПУ — тонкая обёртка над services/cnc_orders.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import cnc_orders as service


@frappe.whitelist(methods=["GET"])
def services(include_disabled: bool | int | str = 0) -> list[dict]:
	"""Прайс услуг ЧПУ."""
	return service.services(include_disabled)


@frappe.whitelist(methods=["POST"])
def save_service(title: str, unit: str, group: str | None = None, price: float | str | None = None,
				 price_trade: float | str | None = None, minutes: float | str | None = None,
				 service_id: str | None = None, enabled: bool | int | str = 1) -> list[dict]:
	"""Добавить услугу в прайс или изменить."""
	return service.save_service(title, unit, group=group, price=price, price_trade=price_trade, minutes=minutes,
								service=service_id, enabled=enabled)


@frappe.whitelist(methods=["GET"])
def settings() -> dict:
	return service.settings()


@frappe.whitelist(methods=["POST"])
def set_settings(urgent_pct: float | str | None = None, min_order: float | str | None = None,
				 day_minutes: float | str | None = None) -> dict:
	"""Наценка за срочность, минимальный заказ, минут работы станка в день."""
	return service.set_settings(urgent_pct=urgent_pct, min_order=min_order, day_minutes=day_minutes)


@frappe.whitelist(methods=["GET"])
def materials() -> list[dict]:
	"""Наши листы, которые можно продать вместе с работой."""
	return service.materials()


@frappe.whitelist(methods=["POST"])
def price(lines: str | list, customer: str | None = None, tags: str | list | None = None) -> dict:
	"""Посчитать заказ, ничего не сохраняя."""
	from korkem_manufacturing.services import facade_prices

	facade_prices.ensure_editor()
	return service.price(lines, customer=customer, tags=tags)


@frappe.whitelist(methods=["POST"])
def save_draft(customer: str, lines: str | list, delivery_date: str | None = None, intake: str | list | None = None,
			   terms: bool | int | str = 0, tags: str | list | None = None, notes: str | None = None,
			   order: str | None = None) -> dict:
	return service.save_draft(customer=customer, delivery_date=delivery_date, lines=lines, intake=intake,
							  terms=terms, tags=tags, notes=notes, order=order)


@frappe.whitelist(methods=["POST"])
def accept(order: str) -> dict:
	return service.accept(order)


@frappe.whitelist(methods=["POST"])
def start(order: str) -> dict:
	return service.start(order)


@frappe.whitelist(methods=["POST"])
def ready(order: str, done: bool | int | str = 1) -> dict:
	return service.ready(order, done)


@frappe.whitelist(methods=["POST"])
def hold(order: str, reason: str | None = None) -> dict:
	return service.hold(order, reason)


@frappe.whitelist(methods=["POST"])
def hand_over(order: str, comment: str | None = None, taken_by: str | None = None,
			  taken_phone: str | None = None) -> dict:
	return service.hand_over(order, comment=comment, taken_by=taken_by, taken_phone=taken_phone)


@frappe.whitelist(methods=["POST"])
def cancel(order: str, reason: str | None = None) -> dict:
	return service.cancel(order, reason or "")


@frappe.whitelist(methods=["GET"])
def card(order: str) -> dict:
	return service.card(order)


@frappe.whitelist(methods=["GET"])
def listing(status: str | None = None, search: str | None = None) -> dict:
	return service.listing(status=status, search=search)


@frappe.whitelist(methods=["POST"])
def add_payment(order: str, amount: float | str, method: str = "Наличные", bank: str | None = None,
				paid_on: str | None = None, idempotency_key: str | None = None) -> dict:
	"""Оплата по заказу ЧПУ — как по заказу фасадов."""
	from korkem_manufacturing.api.mdf_orders import _method_bank
	from korkem_manufacturing.services import facade_prices, mdf_payments, payments

	facade_prices.ensure_editor()
	method, bank = _method_bank(method, bank)
	doc = service._accepted(order)
	payments.record_payment(sales_order=doc.name, amount=amount,
							payment_type="Deposit" if float(doc.advance_paid or 0) == 0 else "Final",
							mode_of_payment=method, bank=bank, paid_on=paid_on, idempotency_key=idempotency_key)
	doc.add_comment("Comment", f"Оплата: {mdf_payments._words(float(amount), method, bank)}.")
	return service.card(doc.name)
