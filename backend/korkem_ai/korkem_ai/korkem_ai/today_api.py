# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Что сегодня важно — одним ответом.

Чтобы понять положение дел, владелец открывал четыре экрана и считал в голове.
Утром в цехе на это нет ни минуты, и первым делом человек смотрит не в систему,
а на телефон, чтобы позвонить и спросить.

## Почему это считает сервер

Определение слова «просрочено» должно жить в одном месте. Стоит посчитать
просрочку в приложении — и появится второе, а расходятся такие места молча: на
экране одно число, в отчёте другое, и никто не знает, какое верное.

## Почему это не снимок в базе

Числа берутся из ERPNext при каждом запросе, а не из сохранённой таблицы.
Сохранённый снимок устаревает между построениями, и человек, увидевший
«просрочено: 3» через час после того, как два заказа закрыли, поверит числу.
Считать при запросе дороже; неверное число дороже во много раз.

Если это станет медленным — а станет оно на тысячах заказов, — снимок появится
вместе с отметкой времени на экране: «на 7:15». Пока заказов сотни, честнее
считать.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai.tools import scope


@frappe.whitelist()
def get_summary() -> dict:
	"""Одно число на каждый вопрос, который владелец задаёт утром."""
	company = scope.current_company()
	today = frappe.utils.nowdate()
	week_end = frappe.utils.add_days(today, 7)

	return {
		"overdue_orders": _orders(company, ["<", today]),
		"due_today_orders": _orders(company, ["=", today]),
		"due_this_week_orders": _orders(company, ["between", [today, week_end]]),
		"unpaid_amount": _unpaid(company),
		"material_deficit_count": _deficit(),
		"installations_today": _installations(company, today),
		"pending_approvals": _approvals(),
	}


def _orders(company: str | None, delivery_date) -> int:
	"""Заказы в работе с таким сроком.

	Только не закрытые и не отменённые: закрытый заказ со вчерашним сроком не
	просрочен, он сделан. Считать его просрочкой значит показывать владельцу
	тревогу там, где всё хорошо, — и он перестанет смотреть на это число.
	"""
	filters = {
		"docstatus": 1,
		"status": ["not in", ("Closed", "Completed", "Cancelled")],
		"delivery_date": delivery_date,
	}
	if company:
		filters["company"] = company
	try:
		return frappe.db.count("Sales Order", filters)
	except Exception:
		return 0


def _unpaid(company: str | None) -> float:
	"""Сколько нам должны — по выставленным счетам.

	Не «сколько мы не выставили»: невыставленный счёт это наша недоработка, а
	не долг клиента, и смешивать их в одном числе значит не понимать ни того,
	ни другого.
	"""
	filters = {"docstatus": 1, "outstanding_amount": [">", 0]}
	if company:
		filters["company"] = company
	try:
		rows = frappe.get_all(
			"Sales Invoice", filters=filters, fields=["outstanding_amount"],
			limit_page_length=0,
		)
	except Exception:
		return 0.0
	return round(sum(row["outstanding_amount"] or 0 for row in rows), 2)


def _deficit() -> int:
	"""Позиций, которых не хватает на принятые заказы.

	Через тот же расчёт, что показывает экран дефицита: два способа посчитать
	нехватку разойдутся, и человек увидит на главном экране одно, а внутри
	другое.
	"""
	try:
		from korkem_ai.korkem_ai.tools import procurement

		shortage = procurement.factory_shortage()
	except Exception:
		# Расчёт дефицита тяжёлый и зависит от спецификаций. Ноль здесь значит
		# «посчитать не удалось», и это лучше, чем уронить весь экран: остальные
		# шесть чисел человеку по-прежнему нужны.
		return 0
	rows = shortage.get("items") if isinstance(shortage, dict) else shortage
	if isinstance(rows, dict):
		return len(rows)
	return len(rows or [])


def _installations(company: str | None, today: str) -> int:
	filters = {"docstatus": 1, "schedule_date": today}
	if company:
		filters["company"] = company
	try:
		return frappe.db.count("Warranty Claim", filters)
	except Exception:
		return 0


def _approvals() -> int:
	"""Сколько предложений ждут решения этого человека."""
	try:
		return frappe.db.count(
			"Pending Action", {"status": "Pending", "owner": frappe.session.user}
		)
	except Exception:
		return 0
