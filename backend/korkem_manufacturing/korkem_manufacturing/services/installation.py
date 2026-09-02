# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Монтаж — последнее, что клиент видит, и первое, о чём он рассказывает.

Мебель на заказ заканчивается не отгрузкой, а установленной кухней. Между
складом и довольным клиентом стоит бригада, и именно на этом шаге срываются
сроки, о которых потом пишут отзывы.

Правило, ради которого этот файл отдельный, а не ещё одна задача со сроком:

**Монтаж нельзя назначить раньше отгрузки.** Бригада, приехавшая к клиенту без
мебели, — это потерянный день бригады, испорченный день клиента и разговор,
после которого рекомендаций не будет. Отгрузка есть — можно ехать; отгрузки нет
— система отказывается ставить дату и говорит, чего ждёт.

Формально это можно было бы разрешить «на всякий случай», и обычно так и
делают. Но всякий случай здесь наступает регулярно.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped

TASK_DOCTYPE = "CRM Task"
TITLE_PREFIX = "Монтаж по заказу"


def schedule(*, sales_order: str, installer: str, install_on: str) -> dict:
	"""Назначить монтаж — если есть что монтировать."""
	order = _visible_order(sales_order)

	if not installer:
		frappe.throw("Некому ехать: назовите монтажника или бригаду.")
	if not install_on:
		frappe.throw("Назовите дату монтажа — клиент должен знать, когда его ждать.")

	delivered = _delivered_quantity(order.name)
	if delivered <= 0:
		frappe.throw(
			"По этому заказу ещё ничего не отгружено. Бригада, приехавшая без "
			"мебели, теряет день, а клиент — доверие."
		)

	existing = _task_for(order.name)
	if existing:
		return {
			"sales_order": order.name,
			"task": existing,
			"status": "already_scheduled",
		}

	task = frappe.get_doc(
		{
			"doctype": TASK_DOCTYPE,
			"title": f"{TITLE_PREFIX} {order.name}",
			"description": f"Монтаж по заказу {order.name}.",
			"assigned_to": installer,
			"status": "Todo",
			"due_date": install_on,
			"reference_doctype": "Sales Order",
			"reference_docname": order.name,
		}
	)
	task.insert()

	return {
		"sales_order": order.name,
		"task": str(task.name),
		"installer": installer,
		"install_on": str(install_on),
		"delivered_qty": delivered,
		"status": "scheduled",
	}


def complete(*, sales_order: str, notes: str | None = None) -> dict:
	"""Закрыть монтаж.

	Заметки не обязательны, но если они есть — остаются на заказе. Через год,
	когда придёт гарантийный случай, фраза «стена оказалась кривой, ставили
	с доборным элементом» стоит дороже, чем факт «монтаж закрыт».
	"""
	order = _visible_order(sales_order)

	task = _task_for(order.name)
	if not task:
		frappe.throw("Монтаж по этому заказу не назначался — нечего закрывать.")

	frappe.db.set_value(TASK_DOCTYPE, task, "status", "Done")

	if notes and notes.strip():
		_note(order.name, notes.strip())

	return {"sales_order": order.name, "task_closed": task, "status": "completed"}


def _visible_order(name: str):
	if not frappe.get_list("Sales Order", filters=scoped({"name": name}), pluck="name"):
		frappe.throw("Нет такого заказа в этой компании.", frappe.PermissionError)
	return frappe.get_doc("Sales Order", name)


def _delivered_quantity(sales_order: str) -> float:
	"""Сколько по заказу фактически отгружено.

	Считается по строкам заказа, а не по накладным: накладная может быть
	черновиком, а `delivered_qty` ERPNext обновляет только по проведённым.
	"""
	rows = frappe.get_all(
		"Sales Order Item",
		filters={"parent": sales_order, "parenttype": "Sales Order"},
		parent_doctype="Sales Order",
		pluck="delivered_qty",
	)
	return sum(frappe.utils.flt(value) for value in rows)


def _task_for(sales_order: str) -> str | None:
	rows = frappe.get_list(
		TASK_DOCTYPE,
		filters={
			"reference_doctype": "Sales Order",
			"reference_docname": sales_order,
			"title": ["like", f"{TITLE_PREFIX}%"],
		},
		pluck="name",
		limit_page_length=1,
	)
	return str(rows[0]) if rows else None


def _note(sales_order: str, notes: str) -> None:
	savepoint = "korkem_install_note_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "Sales Order",
				"reference_name": sales_order,
				"content": f"KORKEM: монтаж — {notes}",
			}
		).insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title="Could not store an installation note",
			message=frappe.get_traceback(with_context=True),
		)
