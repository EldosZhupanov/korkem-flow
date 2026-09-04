# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Лента того, что завод заметил сам.

## Чем это отличается от дневной сводки

Сводка отвечает на вопрос. Лента задаёт его: «срок послезавтра, а работа не
начата» — это не то, о чём кто-то спрашивает, это то, что должно найти
человека само.

## Почему «скрыть» — это «не сегодня», а не «навсегда»

Скрытый просроченный заказ остаётся просроченным. Кнопка, убирающая тревогу
насовсем, однажды уберёт ту единственную, ради которой всё это писалось —
человек нажмёт её в спешке и вспомнит о заказе от клиента.

Поэтому событие прячется на сутки. Если условие за сутки исчезло — заказ
запустили, счёт оплатили — событие не вернётся само собой, потому что его
больше нет. Если не исчезло, оно вернётся, и это правильно.

Скрытие принадлежит человеку, а не заводу: мастер, отложивший своё, не убирает
тревогу у владельца.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai.events import detectors
from korkem_ai.korkem_ai.tools import scope

DOCTYPE = "Factory Event Dismissal"

#: На сколько прячется событие. Сутки — чтобы «не сегодня» означало ровно это.
HIDE_HOURS = 24


@frappe.whitelist()
def pending() -> dict:
	"""Всё, что требует человека прямо сейчас, кроме скрытого им самим."""
	company = scope.current_company()
	hidden = _hidden_for(frappe.session.user, company)
	events = [e for e in detectors.all_for(company) if e["id"] not in hidden]
	return {"events": events}


@frappe.whitelist()
def dismiss(event_id: str) -> dict:
	"""Спрятать событие у этого человека на сутки."""
	event_id = (event_id or "").strip()
	if not event_id:
		frappe.throw("Не указано, какое событие скрыть")

	company = scope.current_company()
	until = frappe.utils.add_to_date(frappe.utils.now_datetime(), hours=HIDE_HOURS)

	existing = frappe.db.get_value(
		DOCTYPE,
		{"user": frappe.session.user, "event_id": event_id, "company": company},
		"name",
	)
	if existing:
		# Повторное нажатие продлевает, а не заводит вторую строку: одна и та
		# же кнопка, нажатая дважды, значит одно и то же.
		frappe.db.set_value(DOCTYPE, existing, "hidden_until", until)
	else:
		frappe.get_doc(
			{
				"doctype": DOCTYPE,
				"user": frappe.session.user,
				"company": company,
				"event_id": event_id,
				"hidden_until": until,
			}
		).insert(ignore_permissions=True)

	return {"hidden_until": str(until)}


def _hidden_for(user: str, company: str) -> set[str]:
	"""Что этот человек прячет прямо сейчас.

	Срок сравнивается в запросе, а не после выборки: просроченное скрытие не
	должно даже доезжать до кода, который решает, показывать ли событие.
	"""
	rows = frappe.get_all(
		DOCTYPE,
		filters={
			"user": user,
			"company": company,
			"hidden_until": [">", frappe.utils.now_datetime()],
		},
		pluck="event_id",
	)
	return set(rows)
