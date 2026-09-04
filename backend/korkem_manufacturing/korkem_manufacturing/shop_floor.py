# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Shop-floor task completion.

The worker-facing end of the Production Order lifecycle: a worker finishes the
task attached to a Work Order, and that completion becomes an auditable event
other parts of the system react to.

Scope note (Sprint 1): completing the task records shop-floor progress; it does
not post the Stock Entry that consumes raw materials and receives finished
goods. Stock posting requires real material stock and is a separate slice --
rather than fake it, the Work Order's own ERPNext status is left to ERPNext.
"""

import frappe

from korkem_manufacturing.services import authority

TASK_DOCTYPE = "CRM Task"
DONE = "Done"


# CRM Task uses naming_rule "Autoincrement", so its name is an int, not a str.
# @frappe.whitelist() enforces these annotations at runtime, so a plain `str`
# here rejects every real task name.
TaskName = str | int


@frappe.whitelist()
def complete_task(task: TaskName, notes: str | None = None) -> TaskName:
	"""Mark a shop-floor task finished.

	The completion event is not fired from here: it is fired by on_task_update()
	below, so that a worker changing the status directly in the Desk UI produces
	exactly the same effects as calling this method. One path, fired once.
	"""
	doc = frappe.get_doc(TASK_DOCTYPE, task)

	# До 4 сентября здесь не было ни одной проверки, а сохранение шло с
	# `ignore_permissions=True`: любой вошедший мог закрыть чужую задачу в
	# чужой компании. Нашлось не чтением кода, а вопросом «а что видит
	# рабочий», заданным про экран.
	#
	# Проверка доменная, а не ролевая, потому что правило «своя задача или ты
	# старший» ролью невыразимо: роль не знает, кому назначена строка.
	authority.require_can_finish_task(doc)

	if doc.status == DONE:
		frappe.throw(f"Task {task} is already complete")

	doc.status = DONE
	if notes:
		doc.description = f"{doc.description or ''}\n{notes}".strip()
	doc.save(ignore_permissions=True)
	return doc.name


def on_task_update(doc, method=None):
	"""doc_events hook: react to a production task becoming Done.

	Guarded on has_value_changed so re-saving an already-complete task does not
	re-fire the event (CRM Task is edited for many reasons besides completion).
	"""
	if not is_production_task(doc):
		return
	if doc.status != DONE or not doc.has_value_changed("status"):
		return

	record_completion(doc)


def is_production_task(doc) -> bool:
	return doc.reference_doctype == "Work Order" and bool(doc.reference_docname)


def record_completion(doc):
	"""Write the completion into the Work Order's own audit trail.

	frappe.get_doc(...).add_comment() is Frappe's native timeline mechanism, so
	this shows up for anyone looking at the Work Order in the Desk -- no parallel
	logging system invented for it.

	## Кто закрыл — это тот, кто нажал

	Раньше здесь стояло `doc.assigned_to or frappe.session.user`, то есть в
	журнал шёл тот, **на кого задача была назначена**. Пока закрыть мог только
	он сам, разница не проявлялась. Как только старший смены получил право
	закрывать за ушедшего домой, запись стала неверной ровно в том случае, ради
	которого она и ведётся: «кто на самом деле это сделал».

	Назначенный не выброшен — он остаётся в строке, когда закрыл не он. Иначе
	пропала бы вторая половина ответа: за кого.
	"""
	work_order = frappe.get_doc("Work Order", doc.reference_docname)
	who = frappe.session.user
	assigned = (doc.assigned_to or "").strip()
	on_behalf = f" (за {assigned})" if assigned and assigned != who else ""
	work_order.add_comment(
		"Info",
		f"Production task completed by {who}{on_behalf}: {doc.title}",
	)


def get_tasks_for_work_order(work_order: str) -> list[TaskName]:
	"""All shop-floor tasks attached to a Work Order."""
	return frappe.get_all(
		TASK_DOCTYPE,
		filters={"reference_doctype": "Work Order", "reference_docname": work_order},
		pluck="name",
	)
