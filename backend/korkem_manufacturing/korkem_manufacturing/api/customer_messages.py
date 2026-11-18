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
