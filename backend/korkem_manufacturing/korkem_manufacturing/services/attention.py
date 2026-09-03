# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Что требует внимания сегодня — работа администратора, сложенная в один ответ.

Вся цепочка построена, и у неё появилось свойство, которого не было у частей:
по ней можно пройти и найти всё, что застряло. Ровно это делает администратор
каждое утро — обходит список и спрашивает «а что с этим».

Четыре вопроса, и все четыре взяты из интервью, а не придуманы:

1. **Что сказано и никому не передано.** Та самая потеря из блокнота, только
   теперь её видно.
2. **Что просрочено** — замер, дизайн, монтаж. Срок прошёл, задача открыта.
3. **Какие заказы стоят без дизайна.** Цех не знает, что пилить, а никто не
   заметил, потому что заказ выглядит живым.
4. **Что отгружено и не выставлено.** Деньги, о которых забыли, — самая тихая
   потеря из всех: клиент доволен, мебель у него, а счёта нет.

Не путать с `korkem_ai.dashboard`: тот считает CRM — сделки, лиды, задачи
пользователя. Этот идёт по производственной цепочке и отвечает на другой
вопрос. Сливать их не надо: у них разные читатели и разная частота.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped

TASK_DOCTYPE = "CRM Task"

#: Сколько часов сказанное может лежать, пока это ещё не потеря. Сутки —
#: потому что владелец сказал это вечером, а разбирает утром.
STALE_AFTER_HOURS = 24


def today() -> dict:
	"""Всё, что застряло, одним ответом."""
	return {
		"unassigned_captures": _unassigned_captures(),
		"overdue_tasks": _overdue_tasks(),
		"orders_without_design": _orders_without_design(),
		"delivered_not_invoiced": _delivered_not_invoiced(),
	}


def _unassigned_captures() -> list[dict]:
	"""Сказанное, которое никому не передали, и лежит дольше суток."""
	cutoff = frappe.utils.add_to_date(frappe.utils.now_datetime(), hours=-STALE_AFTER_HOURS)
	rows = frappe.get_list(
		"Capture",
		filters=scoped(
			{
				"task": ["is", "not set"],
				"status": ["in", ["Recorded", "Understood"]],
				"creation": ["<", cutoff],
			}
		),
		fields=["name", "spoken_text", "customer_hint", "creation"],
		order_by="creation asc",
		limit_page_length=20,
	)
	return [
		{
			"capture": row["name"],
			"said": row["spoken_text"],
			"customer": row.get("customer_hint"),
			"since": str(row["creation"]),
		}
		for row in rows
	]


def _overdue_tasks() -> list[dict]:
	"""Замеры, дизайны и монтажи, у которых срок прошёл.

	Читается по нашим задачам — тем, что ссылаются на захват или заказ.
	Чужие задачи CRM сюда не попадают: администратор смотрит на производство.
	"""
	rows = frappe.get_list(
		TASK_DOCTYPE,
		filters=[
			[TASK_DOCTYPE, "status", "!=", "Done"],
			# Срок должен быть задан, и это приходится сказать отдельно.
			# `due_date` у задачи — Datetime, и сравнение «меньше даты» пропускает
			# строки, где срока нет вовсе: и `get_list`, и `get_all` возвращают
			# их наравне с настоящими. На экране владельца это выглядело как
			# двадцать просроченных задач без единого дедлайна, вытеснявших
			# настоящие — список показывает двадцать самых старых. Найдено
			# прогоном на стенде, где таких задач накопилось.
			[TASK_DOCTYPE, "due_date", "is", "set"],
			[TASK_DOCTYPE, "due_date", "<", frappe.utils.nowdate()],
			[TASK_DOCTYPE, "reference_doctype", "in", ["Capture", "Sales Order"]],
		],
		fields=["name", "title", "assigned_to", "due_date", "reference_doctype", "reference_docname"],
		order_by="due_date asc",
		limit_page_length=20,
	)
	return [
		{
			"task": str(row["name"]),
			"title": row.get("title"),
			"who": row.get("assigned_to"),
			"was_due": str(row["due_date"]),
			"on": row.get("reference_docname"),
		}
		for row in rows
		if _visible_reference(row)
	]


def _orders_without_design() -> list[dict]:
	"""Проведённые заказы, по которым не поручен дизайн.

	Заказ выглядит живым, а цех не знает, что пилить. Заметить это до того, как
	спросят «почему стоит», и есть смысл этого списка.
	"""
	orders = frappe.get_list(
		"Sales Order",
		filters=scoped({"docstatus": 1, "status": ["not in", ["Closed", "Completed"]]}),
		fields=["name", "customer", "delivery_date"],
		order_by="delivery_date asc",
		limit_page_length=50,
	)
	if not orders:
		return []

	with_design = set(
		frappe.get_all(
			TASK_DOCTYPE,
			filters={
				"reference_doctype": "Sales Order",
				"reference_docname": ["in", [row["name"] for row in orders]],
				"title": ["like", "Дизайн по заказу%"],
			},
			pluck="reference_docname",
		)
	)
	return [
		{
			"sales_order": row["name"],
			"customer": row.get("customer"),
			"due": str(row["delivery_date"]) if row.get("delivery_date") else None,
		}
		for row in orders
		if row["name"] not in with_design
	][:20]


def _delivered_not_invoiced() -> list[dict]:
	"""Отгружено, а счёта нет. Самая тихая потеря: клиент доволен и не платит."""
	orders = frappe.get_list(
		"Sales Order",
		filters=scoped({"docstatus": 1, "per_delivered": [">", 0], "per_billed": ["<", 100]}),
		fields=["name", "customer", "grand_total", "per_delivered", "per_billed"],
		order_by="modified asc",
		limit_page_length=20,
	)
	return [
		{
			"sales_order": row["name"],
			"customer": row.get("customer"),
			"total": frappe.utils.flt(row.get("grand_total")),
			"delivered_percent": frappe.utils.flt(row.get("per_delivered")),
			"billed_percent": frappe.utils.flt(row.get("per_billed")),
		}
		for row in orders
	]


def _visible_reference(row: dict) -> bool:
	"""Задача видна, только если виден документ, на котором она висит.

	`CRM Task` не имеет компании — это её и делает опасной. Проверка идёт по
	родителю, как и везде в этой цепочке.
	"""
	doctype = row.get("reference_doctype")
	name = row.get("reference_docname")
	if not doctype or not name:
		return False
	return bool(frappe.get_list(doctype, filters=scoped({"name": name}), pluck="name"))
