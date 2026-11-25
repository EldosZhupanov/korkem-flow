# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Карточка клиента, «Кому написать» и «Итоги дня» — тонкая обёртка над сервисами
customer_card, customer_messages и daily_summary."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import customer_card, customer_messages, daily_summary


@frappe.whitelist(methods=["GET"])
def card(customer: str) -> dict:
	"""Клиент на одной странице: заказы фасадов и ЧПУ, плёнка, оплаты, долг."""
	return customer_card.card(customer)


@frappe.whitelist(methods=["POST"])
def pay(customer: str, amount: float | str, method: str = "Перевод", bank: str | None = None,
		idempotency_key: str | None = None, invoice: str | None = None) -> dict:
	"""Одна оплата на весь долг клиента: закрывает самые старые заказы первыми;
	по счёту на долг — его номер, и оплата идёт в счёт."""
	from korkem_manufacturing.api.mdf_orders import _method_bank

	method, bank = _method_bank(method, bank)
	return customer_card.pay(customer, amount, method, bank, idempotency_key, invoice)


@frappe.whitelist(methods=["POST"])
def invoice_issue(customer: str, amount: float | str | None = None, payer: str | None = None,
				  bin: str | None = None, due_on: str | None = None, vat: str | int | None = None) -> dict:
	"""Счёт на долг клиента: весь долг или своя сумма, по заказам — сначала самые старые.
	Ответ — счёт с реквизитами для печати и карточка клиента."""
	return customer_card.invoice_issue(customer, amount, payer, bin, due_on, vat)


@frappe.whitelist(methods=["GET"])
def invoice_print(customer: str, no: str) -> dict:
	"""Выставленный счёт на долг, как был, с реквизитами."""
	return customer_card.invoice_print(customer, no)


@frappe.whitelist(methods=["POST"])
def invoice_cancel(customer: str, no: str, reason: str) -> dict:
	"""Счёт на долг выставлен по ошибке: отменён, номер больше не используется."""
	return customer_card.invoice_cancel(customer, no, reason)


@frappe.whitelist(methods=["GET"])
def debt_text(customer: str) -> dict:
	"""Напоминание о всём долге клиента: текст и телефон."""
	return customer_card.debt_text(customer)


@frappe.whitelist(methods=["POST"])
def reminded(customer: str) -> dict:
	"""Напоминание о долге отправлено: запомнить день по каждому заказу с долгом."""
	return customer_card.reminded(customer)


@frappe.whitelist(methods=["GET"])
def history(customer: str) -> list[dict]:
	"""История клиента одной лентой: заказы, оплаты, счета, сообщения, заметки."""
	return customer_card.history(customer)


@frappe.whitelist(methods=["POST"])
def add_note(customer: str, text: str) -> list[dict]:
	"""Заметка о клиенте — в его историю."""
	return customer_card.add_note(customer, text)


@frappe.whitelist(methods=["GET"])
def reconciliation(customer: str, since: str | None = None, until: str | None = None) -> dict:
	"""Акт сверки: продажи и оплаты клиента за период, сальдо на начало и конец."""
	return customer_card.reconciliation(customer, since, until)


@frappe.whitelist(methods=["GET"])
def todo() -> dict:
	"""Кому написать сегодня: готовые заказы без извещения, долги к напоминанию, должники плёнки."""
	return customer_messages.todo()


@frappe.whitelist(methods=["GET"])
def text_for(order: str, kind: str = customer_messages.READY) -> dict:
	"""Готовый текст сообщения по заказу и телефон клиента."""
	return customer_messages.text_for(order, kind)


@frappe.whitelist(methods=["POST"])
def mark(kind: str, order: str | None = None, customer: str | None = None) -> dict:
	"""Менеджер отправил сообщение — запомнить день, чтобы не напоминать дважды."""
	return customer_messages.mark(kind, order, customer)


@frappe.whitelist(methods=["GET"])
def templates() -> dict:
	"""Тексты сообщений: свои владельца и исходные."""
	return customer_messages.templates()


@frappe.whitelist(methods=["POST"])
def set_template(kind: str, text: str | None = None) -> dict:
	"""Свой текст сообщения; пустой — вернуть исходный."""
	return customer_messages.set_template(kind, text)


@frappe.whitelist(methods=["GET"])
def summary_preview(day: str | None = None) -> dict:
	"""Итоги дня — как их получит владелец, и настройки отправки."""
	return daily_summary.preview(day)


@frappe.whitelist(methods=["POST"])
def summary_settings(enabled: str | None = None, hour: str | None = None, morning: str | None = None) -> dict:
	"""Включить или выключить вечернюю сводку, выбрать час; утренний список «Пора заказать»."""
	return daily_summary.set_settings(enabled, hour, morning)
