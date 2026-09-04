# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Что завод замечает сам.

## Почему событий мало, и почему это правило, а не этап

Лента, в которой каждый день двадцать строк, перестаёт читаться на третий день.
Дальше её пролистывают не глядя — и настоящая тревога проезжает вместе с шумом.
Поэтому событие добавляется сюда только если на него **есть что ответить
сегодня**. «Заказ большой» — не событие. «Срок послезавтра, а работа не начата»
— событие: можно запустить.

## Почему события не хранятся

По той же причине, что и дневная сводка: сохранённое событие переживает
условие, из которого возникло. Заказ запустили — событие про «не начата» ещё
лежит в таблице и просит человека сделать то, что уже сделано. Такую ленту
перестают читать быстрее, чем шумную.

Считается при запросе. Станет медленным на тысячах заказов — появится снимок с
отметкой времени на экране, как и в сводке.

## Откуда берётся «с каких пор»

Не из момента, когда мы посмотрели, — это было бы не «заметил», а «взглянул».
У каждого события время выводится из самих данных и потому точно: заказ стал
просроченным в день срока, вошёл в зону риска — за три дня до него, оплата
стала ожидаемой в день отгрузки.

Детектор, для которого честного времени нет, сюда не попадает.
"""

from __future__ import annotations

import frappe

#: За сколько дней до срока незапущенный заказ становится тревогой.
#:
#: Три дня — не круглое число, а срок, за который в мебельном цехе ещё можно
#: раскроить, окромить и собрать. За два уже нельзя, и событие было бы
#: сообщением о случившемся, а не поводом действовать.
RISK_DAYS = 3

HIGH = "high"
MEDIUM = "medium"
LOW = "low"

#: Заказы, которые считаются живыми. Закрытый заказ со вчерашним сроком не
#: просрочен — он сделан.
LIVE = ("Closed", "Completed", "Cancelled")


def all_for(company: str) -> list[dict]:
	"""Все события компании, в порядке от самого срочного."""
	events: list[dict] = []
	for detector in (overdue_orders, deadlines_at_risk, unpaid_after_delivery):
		try:
			events.extend(detector(company))
		except Exception:
			# Один сломавшийся детектор не должен уносить ленту целиком: человек
			# скорее останется без одной строки, чем без всех.
			frappe.log_error(title="Factory event detector failed", message=frappe.get_traceback())
	order = {HIGH: 0, MEDIUM: 1, LOW: 2}
	events.sort(key=lambda e: (order.get(e["severity"], 3), e["noticed_at"]))
	return events


def overdue_orders(company: str) -> list[dict]:
	"""Срок прошёл, заказ не закрыт."""
	today = frappe.utils.nowdate()
	rows = frappe.get_all(
		"Sales Order",
		filters={
			"company": company,
			"docstatus": 1,
			"status": ["not in", LIVE],
			"delivery_date": ["<", today],
		},
		fields=["name", "customer", "delivery_date"],
		order_by="delivery_date asc",
		limit_page_length=20,
	)
	return [
		{
			"id": _fingerprint("overdue_order", row.name),
			"kind": "overdue_order",
			"severity": HIGH,
			"title": f"{row.customer}: срок прошёл {frappe.utils.formatdate(row.delivery_date)}",
			"detail": f"Заказ {row.name} не закрыт, а срок был {_days_ago(row.delivery_date)}",
			"noticed_at": str(row.delivery_date),
			"subject": {"doctype": "Sales Order", "name": row.name},
			"actions": [],
		}
		for row in rows
	]


def deadlines_at_risk(company: str) -> list[dict]:
	"""Срок близко, а производство не начиналось.

	Единственное событие здесь, на которое можно ответить кнопкой: запустить.
	"""
	today = frappe.utils.nowdate()
	horizon = frappe.utils.add_days(today, RISK_DAYS)
	rows = frappe.get_all(
		"Sales Order",
		filters={
			"company": company,
			"docstatus": 1,
			"status": ["not in", LIVE],
			"delivery_date": ["between", [today, horizon]],
		},
		fields=["name", "customer", "delivery_date"],
		order_by="delivery_date asc",
		limit_page_length=20,
	)

	started = _orders_with_production({row.name for row in rows})
	return [
		{
			"id": _fingerprint("deadline_at_risk", row.name),
			"kind": "deadline_at_risk",
			"severity": HIGH,
			"title": f"{row.customer}: срок {frappe.utils.formatdate(row.delivery_date)}, работа не начата",
			"detail": f"Заказ {row.name}, ни одного производственного задания",
			"noticed_at": str(frappe.utils.add_days(row.delivery_date, -RISK_DAYS)),
			"subject": {"doctype": "Sales Order", "name": row.name},
			"actions": [{"id": "start_production", "label": "Запустить производство"}],
		}
		for row in rows
		if row.name not in started
	]


def unpaid_after_delivery(company: str) -> list[dict]:
	"""Отгружено, счёт выставлен, деньги не пришли."""
	rows = frappe.get_all(
		"Sales Invoice",
		filters={
			"company": company,
			"docstatus": 1,
			"outstanding_amount": [">", 0],
			"due_date": ["<", frappe.utils.nowdate()],
		},
		fields=["name", "customer", "outstanding_amount", "due_date", "currency"],
		order_by="due_date asc",
		limit_page_length=20,
	)
	return [
		{
			"id": _fingerprint("unpaid_after_delivery", row.name),
			"kind": "unpaid_after_delivery",
			"severity": MEDIUM,
			"title": f"{row.customer}: не оплачено {frappe.utils.fmt_money(row.outstanding_amount, currency=row.currency)}",
			"detail": f"Счёт {row.name}, срок оплаты был {frappe.utils.formatdate(row.due_date)}",
			"noticed_at": str(row.due_date),
			"subject": {"doctype": "Sales Invoice", "name": row.name},
			"actions": [],
		}
		for row in rows
	]


def _orders_with_production(names: set[str]) -> set[str]:
	"""Заказы, по которым уже есть производственное задание."""
	if not names:
		return set()
	rows = frappe.get_all(
		"Work Order",
		filters={"sales_order": ["in", list(names)], "docstatus": ["<", 2]},
		pluck="sales_order",
	)
	return set(rows)


def _fingerprint(kind: str, subject: str) -> str:
	"""Устойчивый ключ события.

	Тот же заказ и та же причина дают тот же ключ при каждом пересчёте — иначе
	«скрыть» скрывало бы событие на один запрос, и оно возвращалось бы
	следующим.
	"""
	return f"{kind}:{subject}"


def _days_ago(date) -> str:
	days = frappe.utils.date_diff(frappe.utils.nowdate(), date)
	if days == 1:
		return "вчера"
	return f"{days} дн. назад"
