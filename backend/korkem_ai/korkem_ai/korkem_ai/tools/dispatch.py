# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Telling somebody to do the work, and finding out whether they will.

## What this adds to a factory that already has Job Cards

A Job Card says a cabinet needs cutting. It does not say that Иван was asked on
Telegram at nine, has not replied, and that the order it belongs to is due
Friday. That gap is where a shop actually loses days, and it is the whole of
what this module does.

Nothing here produces anything. `manufacturing.*` remains the only way work
reaches ERPNext; an instruction points at the order and the job and stops there.

## Who can be dispatched

A `User` in the same company with an employee's own roles, resolved from the
database — `crm.search_users` already answers "who is Иван" the same way. A name
typed into a chat is matched against real users and refused when it matches
more than one, for the same reason two work orders are never picked between
silently.

## How the employee answers

Through the button protocol that already exists. `deliver(..., confirm_for=…)`
renders inline buttons on Telegram and interactive buttons on WhatsApp, and a
press comes back as `CONFIRM <name>` — text a person could have typed. The
confirmation layer resolves that name against a `Pending Action` first and a
`Work Instruction` second, so there is one protocol, one set of buttons and two
kinds of thing that can be answered with them.

In the app there are no such buttons — the app confirms *proposals*, and an
instruction is not one — so `respond_to_instruction` is how the same answer is
given there. It is not a second state machine: it calls the same
`acknowledge`/`refuse`, and therefore the same single conditional UPDATE that
makes a double-tap harmless.
"""

from __future__ import annotations

import frappe
from frappe.utils import getdate, now_datetime, nowdate

from korkem_ai.korkem_ai.doctype.work_instruction import work_instruction as instructions
from korkem_ai.korkem_ai.notifications import events, service
from korkem_ai.korkem_ai.tools import policy, scope
from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register
from korkem_ai.korkem_ai.tools.scope import ensure_company, scoped

INSTRUCTION = "Work Instruction"


def _company_users() -> list[str]:
	"""Users this company's work may be given to.

	Company membership is a `User Permission` on Company, which is ERPNext's own
	way of saying it. A user with no company permission at all belongs to
	whatever the site's default is — the same rule `scope.current_company`
	applies to the caller — so they are included rather than silently excluded.
	"""
	company = scope.current_company()
	restricted = frappe.get_all(
		"User Permission",
		filters={"allow": "Company"},
		fields=["user", "for_value"],
	)
	elsewhere = {
		row["user"]
		for row in restricted
		if row["for_value"] != company
	}
	here = {row["user"] for row in restricted if row["for_value"] == company}

	candidates = frappe.get_all(
		"User", filters={"enabled": 1, "user_type": "System User"}, pluck="name"
	)
	return [
		user
		for user in candidates
		if user not in ("Administrator", "Guest")
		and (user in here or user not in elsewhere)
		and policy._from_roles(user) in (policy.EMPLOYEE, policy.ADMIN)
	]


def _resolve_employee(named: str) -> dict:
	"""One user, or an honest refusal to choose between several."""
	allowed = _company_users()
	if not allowed:
		frappe.throw("В этой компании не найдено сотрудников.")

	rows = frappe.get_all(
		"User",
		filters={"name": ["in", allowed]},
		fields=["name", "full_name", "first_name", "last_name"],
	)
	needle = (named or "").strip().casefold()
	if not needle:
		return {"status": "ambiguous", "candidates": rows}

	exact = [row for row in rows if row["name"].casefold() == needle]
	if len(exact) == 1:
		return {"status": "resolved", "user": exact[0]}

	partial = [
		row
		for row in rows
		if needle in (row["full_name"] or "").casefold()
		or needle in (row["first_name"] or "").casefold()
		or needle in (row["name"] or "").casefold()
	]
	if len(partial) == 1:
		return {"status": "resolved", "user": partial[0]}
	if not partial:
		return {"status": "not_found", "candidates": rows}
	return {"status": "ambiguous", "candidates": partial}


def _identity_for(user: str) -> dict | None:
	"""Where this person can be reached, if an administrator has linked them."""
	rows = frappe.get_all(
		"Channel Identity",
		filters={"user": user, "enabled": 1},
		fields=["name", "channel", "external_id"],
		order_by="last_seen_on desc",
	)
	return rows[0] if rows else None


def _message_for(doc) -> str:
	"""What the employee reads. Built here, not by the model."""
	lines = ["Задание от KORKEM AI:", ""]
	if doc.sales_order:
		customer = frappe.db.get_value("Sales Order", doc.sales_order, "customer")
		lines.append(f"Заказ: {doc.sales_order}")
		if customer:
			lines.append(f"Клиент: {customer}")
	if doc.work_order:
		job = frappe.db.get_value(
			"Work Order", doc.work_order, ["production_item", "qty"], as_dict=True
		)
		lines.append(f"Производство: {doc.work_order}")
		if job:
			lines.append(f"Изделие: {job.production_item} — {job.qty:g} шт.")
	if doc.due_date:
		lines.append(f"Срок: {getdate(doc.due_date).strftime('%d.%m.%Y')}")
	lines += [
		"",
		doc.instruction,
		"",
		"Принять задание? Если что-то неясно — «Уточнить», и вопрос уйдёт "
		"тому, кто его поставил.",
	]
	return "\n".join(lines)


def assign_work(
	employee: str | None = None,
	instruction: str | None = None,
	sales_order: str | None = None,
	work_order: str | None = None,
	due_date: str | None = None,
):
	"""Send one person one instruction, and record that it was sent."""
	if not instruction:
		return {"status": "incomplete", "missing": ["instruction"]}

	resolved = _resolve_employee(employee or "")
	if resolved["status"] != "resolved":
		return {
			"status": resolved["status"],
			"asked_for": employee,
			"candidates": resolved["candidates"],
			"message": (
				"Такого сотрудника нет в этой компании."
				if resolved["status"] == "not_found"
				else "Под это имя подходит несколько сотрудников — уточните."
			),
		}
	user = resolved["user"]["name"]

	# Both references are checked against the caller's own company before the
	# row exists, so a refusal writes nothing.
	if sales_order:
		if not frappe.db.exists("Sales Order", sales_order):
			frappe.throw(f"Sales Order {sales_order} not found.")
		ensure_company("Sales Order", sales_order)
	if work_order:
		if not frappe.db.exists("Work Order", work_order):
			frappe.throw(f"Work Order {work_order} not found.")
		ensure_company("Work Order", work_order)

	# An instruction that is still waiting for an answer is *updated* rather than
	# duplicated. «Тогда сделай завтра до 12:00» is the same job with a new
	# deadline, and a shop floor with two live cards for one piece of work is a
	# shop floor where one of them gets done twice.
	#
	# Only while it is open: once somebody has accepted or refused, changing the
	# thing they answered would rewrite what they agreed to, so that becomes a
	# new instruction.
	existing = frappe.get_all(
		INSTRUCTION,
		filters={
			"employee_user": user,
			"company": scope.current_company(),
			"sales_order": sales_order or ["is", "not set"],
			"status": ["in", instructions.OPEN],
		},
		pluck="name",
		order_by="creation desc",
		limit=1,
	)
	updated = bool(existing)
	if updated:
		doc = frappe.get_doc(INSTRUCTION, existing[0])
		doc.instruction = instruction
		if work_order:
			doc.work_order = work_order
		if due_date:
			doc.due_date = getdate(due_date)
		doc.save()
	else:
		doc = frappe.get_doc(
			{
				"doctype": INSTRUCTION,
				"company": scope.current_company(),
				"employee_user": user,
				"instruction": instruction,
				"sales_order": sales_order,
				"work_order": work_order,
				"due_date": getdate(due_date) if due_date else None,
				"status": instructions.DRAFT,
			}
		)
		doc.insert()

	# Sent through the notification service, which knows how to reach a person
	# and this tool does not. Three buttons, because being given work has three
	# honest answers: yes, no, and "what exactly".
	#
	# It is queued, so a provider that is down cannot fail the dispatch: the
	# decision is recorded either way and the message retries on its own.
	identity = _identity_for(user)
	created = service.emit(
		events.INSTRUCTION_ASSIGNED,
		recipients=[user],
		body=_message_for(doc),
		reference_doctype=INSTRUCTION,
		reference_name=doc.name,
		company=doc.company,
		confirm_for=doc.name,
		ask=True,
		# An updated instruction is a new thing to be told about, so the event
		# key carries what changed — otherwise the second message would be
		# suppressed as a duplicate of the first.
		key_suffix=f"{doc.instruction[:30]}:{doc.due_date or ''}",
	)
	if identity and created:
		doc.mark_sent(channel=identity["channel"], identity=identity["name"])
	delivery = {
		"queued": bool(created),
		"delivered": bool(identity and created),
		"channel": identity["channel"] if identity else None,
		"reason": None if identity else "employee has no linked chat channel",
	}

	return {
		"status": "updated" if updated else "assigned",
		"instruction": doc.name,
		"employee": user,
		"employee_name": resolved["user"]["full_name"],
		"sales_order": sales_order,
		"work_order": work_order,
		"due_date": str(doc.due_date) if doc.due_date else None,
		"instruction_status": doc.status,
		"delivery": delivery,
	}


def summarise_assignment(
	employee: str | None = None,
	instruction: str | None = None,
	sales_order: str | None = None,
	work_order: str | None = None,
	due_date: str | None = None,
) -> str | None:
	"""What the administrator is agreeing to send, and to whom."""
	if not employee or not instruction:
		return None
	resolved = _resolve_employee(employee)
	if resolved["status"] != "resolved":
		return None
	lines = [f"Передать задание: {resolved['user']['full_name']}", "", instruction]
	if sales_order:
		lines.append(f"Заказ: {sales_order}")
	if work_order:
		lines.append(f"Производство: {work_order}")
	if due_date:
		lines.append(f"Срок: {getdate(due_date).strftime('%d.%m.%Y')}")
	return "\n".join(lines)


def list_instructions(
	status: str | None = None, employee: str | None = None, limit: int | None = None
):
	"""What has been handed out, and what nobody has picked up.

	Read through `get_list`, so an employee sees what their own permissions
	allow and an administrator sees the company's.
	"""
	filters = {}
	# An employee sees their own work; somebody who hands work out sees the
	# company's. Expressed as "may this person create an instruction", which is
	# ERPNext's own answer to "are you the one giving orders" — rather than a
	# second role list here that could disagree with the doctype's permissions.
	if not frappe.has_permission(INSTRUCTION, "create"):
		filters["employee_user"] = frappe.session.user
	if status:
		filters["status"] = status
	if employee:
		resolved = _resolve_employee(employee)
		if resolved["status"] != "resolved":
			return {
				"status": resolved["status"],
				"candidates": resolved["candidates"],
				"instructions": [],
				"count": 0,
			}
		if filters.get("employee_user", resolved["user"]["name"]) != resolved["user"]["name"]:
			# Asking about somebody else's work when you may only see your own.
			return {"status": "not_permitted", "instructions": [], "count": 0}
		filters["employee_user"] = resolved["user"]["name"]

	rows = frappe.get_list(
		INSTRUCTION,
		filters=scoped(filters),
		fields=[
			"name",
			"employee_user",
			"status",
			"instruction",
			"sales_order",
			"work_order",
			"due_date",
			"sent_at",
			"acknowledged_at",
			"rejected_at",
			"response",
			"owner",
		],
		order_by="creation desc",
		limit_page_length=min(int(limit or 20), 50),
	)

	waiting = [row for row in rows if row["status"] in instructions.OPEN]
	overdue = [
		row
		for row in waiting
		if row["due_date"] and getdate(row["due_date"]) < getdate(nowdate())
	]
	return {
		"as_of": now_datetime().strftime("%Y-%m-%d %H:%M"),
		"summary": {
			"total": len(rows),
			"awaiting_acknowledgement": len(waiting),
			"acknowledged": len([row for row in rows if row["status"] == instructions.ACKNOWLEDGED]),
			"rejected": len([row for row in rows if row["status"] == instructions.REJECTED]),
			"overdue_and_unanswered": len(overdue),
		},
		"instructions": rows,
		"count": len(rows),
	}


def _verdict_of(result: str) -> str | None:
	"""Accepted or refused, from what the person actually wrote.

	Refusal is checked first and separately, for the reason Phase 24 learned the
	hard way: «не могу принять» contains «принять», and of the two ways to be
	wrong here only one leaves a job nobody is doing.
	"""
	text = (result or "").strip().casefold()
	if not text:
		return None
	for word in ("не могу", "не буду", "отказ", "не возьм", "reject", "decline"):
		if word in text:
			return "rejected"
	for word in ("принял", "принима", "принято", "беру", "готов взять", "accept", "ок", "да"):
		if word in text:
			return "acknowledged"
	return None


def respond_to_instruction(result: str, instruction: str | None = None):
	"""Accept or refuse a job from the app, the way a button does from a chat.

	Not a second confirmation system: this reaches the same
	`Work Instruction.acknowledge`/`refuse` — the same single conditional UPDATE
	— that a Telegram button reaches. What differs is only how the person said
	it, which is what a channel is.
	"""
	verdict = _verdict_of(result)
	if not verdict:
		return {
			"status": "unclear",
			"message": "Не понял ответ: принимаете задание или нет?",
		}

	user = frappe.session.user
	if instruction:
		if not frappe.db.exists(INSTRUCTION, instruction):
			frappe.throw(f"Задание {instruction} не найдено.")
		doc = frappe.get_doc(INSTRUCTION, instruction)
		if doc.employee_user != user:
			# Somebody else's job is refused in the words of absence.
			frappe.throw(f"Задание {instruction} не найдено.")
	else:
		open_jobs = instructions.open_for(user)
		if not open_jobs:
			# Nothing open. If the last job they were given has already been
			# answered, say that rather than "you have no jobs" — the second
			# reads as though the first answer was lost.
			last = instructions.latest_for(user)
			if last:
				return {
					"status": "already_answered",
					"instruction": last["name"],
					"instruction_status": last["status"],
				}
			return {"status": "nothing_open", "message": "У вас нет открытых заданий."}
		if len(open_jobs) > 1:
			# Two jobs is a question, not a coin toss.
			return {
				"status": "ambiguous",
				"instructions": open_jobs,
				"message": "У вас несколько заданий — укажите, о каком речь.",
			}
		doc = frappe.get_doc(INSTRUCTION, open_jobs[0]["name"])

	answered = doc.refuse(result) if verdict == "rejected" else doc.acknowledge(result)
	if not answered:
		return {
			"status": "already_answered",
			"instruction": doc.name,
			"instruction_status": doc.status,
		}

	return {
		"status": verdict,
		"instruction": doc.name,
		"instruction_status": doc.status,
		"sales_order": doc.sales_order,
		"work_order": doc.work_order,
	}


def summarise_response(result: str, instruction: str | None = None) -> str | None:
	verdict = _verdict_of(result)
	if not verdict:
		return None
	return (
		"Принять задание?" if verdict == "acknowledged" else "Отказаться от задания?"
	)


register(
	ToolSpec(
		name="dispatch.assign_work",
		description=(
			"Send an employee an instruction about an order or a work order, "
			"through whichever chat channel they are linked on, and record it. "
			"Use for «передай Ивану…», «сообщи Ивану, что…». Does not start or "
			"change production — the manufacturing tools do that."
		),
		input_schema={
			"type": "object",
			"properties": {
				"employee": {"type": "string"},
				"instruction": {"type": "string"},
				"sales_order": {"type": "string"},
				"work_order": {"type": "string"},
				"due_date": {"type": "string"},
			},
			"required": ["employee", "instruction"],
		},
		risk=Risk.WRITE,
		handler=assign_work,
		summarise=summarise_assignment,
		doctypes=(INSTRUCTION,),
		audit_category="dispatch",
	)
)

register(
	ToolSpec(
		name="dispatch.list_instructions",
		description=(
			"Instructions given to employees and what they answered — who has "
			"accepted, who has not replied, who refused. Answers «какие задания "
			"не приняты»."
		),
		input_schema={
			"type": "object",
			"properties": {
				"status": {"type": "string"},
				"employee": {"type": "string"},
				"limit": {"type": "integer"},
			},
		},
		risk=Risk.READ,
		handler=list_instructions,
		doctypes=(INSTRUCTION,),
		audit_category="dispatch",
	)
)


register(
	ToolSpec(
		name="dispatch.respond_to_instruction",
		description=(
			"Record that you accept or refuse a job you were given — «принял», "
			"«не могу выполнить». Names the instruction only when more than one "
			"is open."
		),
		input_schema={
			"type": "object",
			"properties": {
				"result": {"type": "string"},
				"instruction": {"type": "string"},
			},
			"required": ["result"],
		},
		risk=Risk.WRITE,
		handler=respond_to_instruction,
		summarise=summarise_response,
		doctypes=(INSTRUCTION,),
		# `write`, not `create`. Answering a job you were given changes a row
		# that already exists; an employee holds that permission and does not
		# hold the one that would let them hand work out.
		permission="write",
		audit_category="dispatch",
	)
)
