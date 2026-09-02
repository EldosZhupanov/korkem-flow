# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Задача дизайнеру — этап 5 цепочки, и место, где «готово» обычно врёт.

Между заказом и производством стоит чертёж. Пока его нет, цех не знает, что
пилить, а закупка — что покупать. В цепочке владельца этот шаг записан так:
задача дизайнеру → дедлайн → **проверка наличия результата** → напоминание.

Три слова «проверка наличия результата» и есть весь смысл этого файла.

**Закрыть задачу дизайна без приложенного файла нельзя.** Задача, отмеченная
выполненной, но без чертежа, — самый дорогой вид лжи в производстве: система
считает, что можно начинать, закупка уходит по несуществующей спецификации, а
выясняется это в цехе. Поэтому «готово» здесь требует доказательства, и
доказательство — файл, приложенный к заказу.

**Файл прикладывается к заказу, а не к задаче.** Задача — про то, кто и когда;
заказ — про то, что делают. Через полгода, когда придёт рекламация, чертёж
будут искать на заказе, а задача к тому времени закрыта и забыта.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped

TASK_DOCTYPE = "CRM Task"


def assign(*, sales_order: str, designer: str, due_on: str) -> dict:
	"""Поручить дизайн по заказу, со сроком.

	Повторный вызов возвращает уже поставленную задачу: у одного заказа один
	дизайн, и второй исполнитель на том же чертеже — это два чертежа.
	"""
	order = _visible_order(sales_order)

	if not designer:
		frappe.throw("Некому поручить: назовите дизайнера.")
	if not due_on:
		frappe.throw(
			"Задача без срока — это пожелание. Назовите дату, к которой нужен чертёж."
		)

	existing = _task_for(order.name)
	if existing:
		return {"sales_order": order.name, "task": existing, "status": "already_assigned"}

	task = frappe.get_doc(
		{
			"doctype": TASK_DOCTYPE,
			"title": f"Дизайн по заказу {order.name}",
			"description": f"Чертёж и спецификация по заказу {order.name}.",
			"assigned_to": designer,
			"status": "Todo",
			"due_date": due_on,
			"reference_doctype": "Sales Order",
			"reference_docname": order.name,
		}
	)
	task.insert()

	return {
		"sales_order": order.name,
		"task": str(task.name),
		"designer": designer,
		"due_on": str(due_on),
		"status": "assigned",
	}


def deliver(*, sales_order: str) -> dict:
	"""Принять дизайн — но только если он существует.

	Здесь и живёт «проверка наличия результата»: без файла на заказе задача не
	закрывается. Отказ намеренно объясняет, чего не хватает, а не сообщает
	«ошибка»: дизайнер, увидевший «приложите чертёж», приложит его за минуту.
	"""
	order = _visible_order(sales_order)

	attachments = _attachments(order.name)
	if not attachments:
		frappe.throw(
			"К заказу не приложено ни одного файла. Дизайн считается готовым, "
			"когда чертёж есть, а не когда о нём сказали."
		)

	task = _task_for(order.name)
	if task:
		frappe.db.set_value(TASK_DOCTYPE, task, "status", "Done")

	return {
		"sales_order": order.name,
		"task_closed": task,
		"files": attachments,
		"status": "delivered",
	}


def _visible_order(name: str):
	if not frappe.get_list("Sales Order", filters=scoped({"name": name}), pluck="name"):
		frappe.throw("Нет такого заказа в этой компании.", frappe.PermissionError)
	return frappe.get_doc("Sales Order", name)


def _task_for(sales_order: str) -> str | None:
	rows = frappe.get_list(
		TASK_DOCTYPE,
		filters={
			"reference_doctype": "Sales Order",
			"reference_docname": sales_order,
			"title": ["like", "Дизайн по заказу%"],
		},
		pluck="name",
		limit_page_length=1,
	)
	return str(rows[0]) if rows else None


def _attachments(sales_order: str) -> list[str]:
	"""Файлы, приложенные к заказу. Пусто — значит дизайна нет."""
	return frappe.get_all(
		"File",
		filters={"attached_to_doctype": "Sales Order", "attached_to_name": sales_order},
		pluck="file_name",
	)
