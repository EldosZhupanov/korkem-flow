# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""What happened, who should hear it, and in what words.

## Why the tools call this and not a channel

A production tool's job is to move a work order. The moment it also knows what a
Telegram chat id is, the business rule and the transport are in the same place
and the next channel copies both. So a tool emits an event here, and this module
is the only thing that decides *who* — from the documents, never from a role
broadcast and never from a message.

## The recipient policy, in one table

| event | staff | customer |
|---|---|---|
| order accepted | — | the order's own portal users |
| production started / stopped / resumed | whoever started the job | the order's customer |
| material short | whoever started the job | the order's customer |
| operation completed with loss | whoever started the job | — |
| quality failed · rework | whoever started the job | — |
| production completed | whoever started the job | the order's customer |
| instruction assigned | the employee | — |
| instruction answered | the person who gave it | — |

A customer hears about *their own order* and about nothing else — no stock
figure, no work order number, no other customer, no internal cost. What they are
told is written here, in full, so that what a customer can learn is one file
somebody can read rather than a template a model fills in.

## Nothing here raises

An event that cannot be delivered must not fail the transaction that caused it.
Every function returns the delivery names it created, and an empty list is a
legitimate answer: nobody to tell.
"""

from __future__ import annotations

import frappe
from frappe.utils import getdate

from korkem_ai.korkem_ai.notifications import recipients, service

# Staff events
PRODUCTION_STARTED = "production.started"
PRODUCTION_STOPPED = "production.stopped"
PRODUCTION_RESUMED = "production.resumed"
PRODUCTION_COMPLETED = "production.completed"
MATERIAL_SHORT = "production.material_short"
PROCESS_LOSS = "production.process_loss"
QUALITY_FAILED = "production.quality_failed"
REWORK_RESULT = "production.rework_result"
INSTRUCTION_ASSIGNED = "instruction.assigned"
INSTRUCTION_ANSWERED = "instruction.answered"

# Customer events
ORDER_ACCEPTED = "order.accepted"
ORDER_IN_PRODUCTION = "order.in_production"
ORDER_PAUSED = "order.paused"
ORDER_READY = "order.ready"
ORDER_WAITING_MATERIAL = "order.waiting_material"


def _job(work_order: str) -> dict:
	return (
		frappe.db.get_value(
			"Work Order",
			work_order,
			["name", "sales_order", "production_item", "qty", "produced_qty", "company", "status"],
			as_dict=True,
		)
		or {}
	)


def _order_line(sales_order: str | None) -> str:
	return f" по заказу {sales_order}" if sales_order else ""


# --------------------------------------------------------------------------
# Production
# --------------------------------------------------------------------------


def production_started(work_order: str) -> list[str]:
	job = _job(work_order)
	if not job:
		return []

	sent = service.emit(
		PRODUCTION_STARTED,
		recipients=recipients.staff_for_work_order(work_order),
		body=(
			f"Производство запущено{_order_line(job.sales_order)}: "
			f"{job.production_item} — {job.qty:g} шт."
		),
		reference_doctype="Work Order",
		reference_name=work_order,
		company=job.company,
	)
	if job.sales_order:
		sent += service.send_to_customer(
			ORDER_IN_PRODUCTION,
			job.sales_order,
			f"Ваш заказ {job.sales_order} передан в производство.",
			key_suffix=work_order,
		)
	return sent


def production_stopped(work_order: str, resumed: bool = False, reason: str | None = None) -> list[str]:
	job = _job(work_order)
	if not job:
		return []

	staff_body = (
		f"Производство возобновлено{_order_line(job.sales_order)}: {job.production_item}."
		if resumed
		else f"Производство остановлено{_order_line(job.sales_order)}: {job.production_item}."
	)
	if reason and not resumed:
		staff_body += f"\nПричина: {reason}"

	sent = service.emit(
		PRODUCTION_RESUMED if resumed else PRODUCTION_STOPPED,
		recipients=recipients.staff_for_work_order(work_order),
		body=staff_body,
		reference_doctype="Work Order",
		reference_name=work_order,
		company=job.company,
		# A job can legitimately be stopped and restarted more than once, and
		# each is its own event — so the state is part of the key.
		key_suffix=f"{'resumed' if resumed else 'stopped'}:{job.status}",
	)
	if job.sales_order:
		sent += service.send_to_customer(
			ORDER_IN_PRODUCTION if resumed else ORDER_PAUSED,
			job.sales_order,
			(
				f"Работа по заказу {job.sales_order} продолжена."
				if resumed
				# Deliberately no reason: why a factory stopped a machine is the
				# factory's business, and "нет материала" tells a customer more
				# about the shop than about their order.
				else f"Работа по заказу {job.sales_order} временно приостановлена. "
				"Менеджер свяжется с вами, если сроки изменятся."
			),
			key_suffix=f"{work_order}:{'resumed' if resumed else 'paused'}:{job.status}",
		)
	return sent


def material_short(work_order: str, blocking: list[dict], sales_order: str | None = None) -> list[str]:
	"""A job that cannot start for want of material.

	Staff are told which item and how much — that is the whole point of the
	message. The customer is told only that their order is waiting, because a
	shortage figure is a fact about the factory's shelf.
	"""
	job = _job(work_order) if work_order else {}
	order = sales_order or job.get("sales_order")
	short = ", ".join(
		f"{row.get('item_code')} — не хватает {row.get('shortage_qty') or row.get('physical_shortage_qty')} "
		f"{row.get('uom') or ''}".strip()
		for row in (blocking or [])[:5]
	)

	sent = []
	if work_order:
		sent += service.emit(
			MATERIAL_SHORT,
			recipients=recipients.staff_for_work_order(work_order),
			body=f"Не хватает материала{_order_line(order)}:\n{short}",
			reference_doctype="Work Order",
			reference_name=work_order,
			company=job.get("company"),
			key_suffix=short[:40],
		)
	if order:
		sent += service.send_to_customer(
			ORDER_WAITING_MATERIAL,
			order,
			f"По заказу {order} ожидается поступление материала. "
			"Как только он придёт, производство продолжится.",
			key_suffix=(work_order or "") + short[:20],
		)
	return sent


def process_loss(work_order: str, operation: str, good: float, lost: float) -> list[str]:
	job = _job(work_order)
	if not job or not lost:
		return []
	return service.emit(
		PROCESS_LOSS,
		recipients=recipients.staff_for_work_order(work_order),
		body=(
			f"{operation}{_order_line(job.sales_order)}: "
			f"годных {good:g}, брак {lost:g}."
		),
		reference_doctype="Work Order",
		reference_name=work_order,
		company=job.company,
		key_suffix=f"{operation}:{good:g}:{lost:g}",
	)


def quality_failed(work_order: str, operation: str, detail: str | None = None) -> list[str]:
	job = _job(work_order)
	if not job:
		return []
	return service.emit(
		QUALITY_FAILED,
		recipients=recipients.staff_for_work_order(work_order),
		body=f"ОТК не принял{_order_line(job.sales_order)} на операции {operation}."
		+ (f"\n{detail}" if detail else ""),
		reference_doctype="Work Order",
		reference_name=work_order,
		company=job.company,
		key_suffix=operation,
	)


def rework_result(work_order: str, outcome: str, operation: str | None = None) -> list[str]:
	job = _job(work_order)
	if not job:
		return []
	return service.emit(
		REWORK_RESULT,
		recipients=recipients.staff_for_work_order(work_order),
		body=f"Исправление брака{_order_line(job.sales_order)}: {outcome}.",
		reference_doctype="Work Order",
		reference_name=work_order,
		company=job.company,
		key_suffix=f"{operation or ''}:{outcome}",
	)


def production_completed(work_order: str) -> list[str]:
	job = _job(work_order)
	if not job:
		return []

	sent = service.emit(
		PRODUCTION_COMPLETED,
		recipients=recipients.staff_for_work_order(work_order),
		body=(
			f"Производство завершено{_order_line(job.sales_order)}: "
			f"{job.production_item} — выпущено {job.produced_qty:g} из {job.qty:g}."
		),
		reference_doctype="Work Order",
		reference_name=work_order,
		company=job.company,
		key_suffix=f"{job.produced_qty:g}",
	)
	if job.sales_order:
		sent += service.send_to_customer(
			ORDER_READY,
			job.sales_order,
			f"Заказ {job.sales_order} готов: {job.produced_qty:g} шт.",
			key_suffix=f"{work_order}:{job.produced_qty:g}",
		)
	return sent


# --------------------------------------------------------------------------
# Sales
# --------------------------------------------------------------------------


def order_accepted(sales_order: str) -> list[str]:
	order = frappe.db.get_value(
		"Sales Order", sales_order, ["delivery_date", "grand_total", "currency"], as_dict=True
	)
	if not order:
		return []
	due = getdate(order.delivery_date).strftime("%d.%m.%Y") if order.delivery_date else None
	body = f"Заказ {sales_order} принят."
	if due:
		body += f" Ожидаемая дата: {due}."
	return service.send_to_customer(ORDER_ACCEPTED, sales_order, body)


# --------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------


def instruction_answered(instruction, answer: str) -> list[str]:
	"""Tell whoever gave the instruction what the employee said.

	The employee's own words, because a paraphrase of "станок занят" is worth
	nothing to the person who has to decide what to do about it.
	"""
	who = (
		frappe.db.get_value("User", instruction.employee_user, "full_name")
		or instruction.employee_user
	)
	body = f"{who} — задание {instruction.name}"
	if instruction.sales_order:
		body += f" (заказ {instruction.sales_order})"
	body += f":\n\n{answer}"

	return service.send_to_instruction_owner(
		INSTRUCTION_ANSWERED,
		instruction,
		body,
		# The same instruction is answered once, but a question can be asked
		# repeatedly — the status it moved to is what makes each its own event.
		key_suffix=f"{instruction.status}:{answer[:30]}",
	)
