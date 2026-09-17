# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Piece-rate Payroll Domain Service (Сдельная оплата труда).

Учет выработки и сдельной оплаты цеховых рабочих (станочников, сборщиков, кромщиков):
- Привязка к JobCard и конкретной технологической операции;
- Тарифные сетки:
    * KZT_PER_PART (за деталь);
    * KZT_PER_M2 (за м² раскроя/фрезеровки);
    * KZT_PER_METER (за погонный метр кромкооблицовки);
    * FIXED_PER_OPERATION (фикс за операцию);
- Идемпотентность по завершению JobCard (нельзя начислить дважды);
- Человеческий шлюз одобрения (Human Approval Gate, CRITICAL_WRITE);
- Сторнирование (Reversal) через компенсирующие проводки вместо физического удаления;
- Сводная ведомость начислений по сотрудникам.
"""

from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import flt, now_datetime

from korkem_manufacturing.services import audit, outbox
from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope

DOCTYPE = "Piece Work Entry"

VALID_RATE_TYPES = {
	"KZT_PER_PART": "за деталь",
	"KZT_PER_M2": "за м²",
	"KZT_PER_METER": "за пог. м",
	"FIXED_PER_OPERATION": "фикс за операцию",
}


def record_piece_work(
	*,
	company: str | None = None,
	employee: str,
	operation: str,
	rate_type: str,
	quantity: float,
	rate: float,
	unit: str = "pcs",
	job_card: str | None = None,
	sales_order: str | None = None,
	work_order: str | None = None,
	employee_name: str | None = None,
	correlation_id: str | None = None,
	idempotency_key: str | None = None,
	actor: str | None = None,
	notes: str | None = None,
) -> Any:
	"""Зафиксировать сдельную выработку по операции в статусе 'Pending Approval'."""
	comp = company or current_company()
	enforce_tenant_scope(comp)
	user_actor = actor or frappe.session.user or "Administrator"

	# 1. Защита от дублирования выработки (Idempotency)
	if idempotency_key:
		existing = frappe.db.get_value(
			DOCTYPE,
			{"company": comp, "idempotency_key": idempotency_key},
			"name",
		)
		if existing:
			return frappe.get_doc(DOCTYPE, existing)

	if rate_type not in VALID_RATE_TYPES:
		frappe.throw(
			f"Недопустимый тип тарифа: {rate_type}. Допустимы: {list(VALID_RATE_TYPES.keys())}",
			frappe.ValidationError,
		)

	qty = flt(quantity)
	r = flt(rate)
	if qty <= 0:
		frappe.throw(f"Количество выработки должно быть больше нуля (передано: {quantity}).", frappe.ValidationError)
	if r < 0:
		frappe.throw(f"Тариф не может быть отрицательным (передан: {rate}).", frappe.ValidationError)

	amount = round(qty * r, 2)

	doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"company": comp,
			"employee": employee,
			"employee_name": employee_name,
			"operation": operation,
			"job_card": job_card,
			"sales_order": sales_order,
			"work_order": work_order,
			"rate_type": rate_type,
			"quantity": qty,
			"unit": unit,
			"rate": r,
			"amount": amount,
			"status": "Pending Approval",
			"correlation_id": correlation_id,
			"idempotency_key": idempotency_key,
			"notes": notes,
		}
	)
	doc.insert(ignore_permissions=True)

	audit.record_audit(
		action="payroll.piece_work_recorded",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={
			"employee": employee,
			"operation": operation,
			"quantity": qty,
			"rate": r,
			"amount": amount,
			"rate_type": rate_type,
		},
		company=comp,
		actor=user_actor,
	)

	outbox.record_event(
		event_name="payroll.piece_work_recorded",
		aggregate_type=DOCTYPE,
		aggregate_id=doc.name,
		payload={
			"entry": doc.name,
			"company": comp,
			"employee": employee,
			"operation": operation,
			"job_card": job_card,
			"sales_order": sales_order,
			"amount": amount,
			"rate_type": rate_type,
		},
		company=comp,
		actor=user_actor,
	)

	return doc


def approve_piece_work(
	entry_name: str,
	approved_by: str | None = None,
	notes: str | None = None,
) -> Any:
	"""Утвердить начисление сдельной оплаты (Human Approval Gate)."""
	actor = approved_by or frappe.session.user or "Administrator"

	# Pessimistic row lock
	locked = frappe.db.get_value(
		DOCTYPE,
		entry_name,
		["name", "company", "status", "employee", "amount"],
		as_dict=True,
		for_update=True,
	)
	if not locked:
		frappe.throw(f"Запись начисления {entry_name} не найдена.", frappe.DoesNotExistError)

	enforce_tenant_scope(locked.company)

	if locked.status != "Pending Approval":
		frappe.throw(
			f"Запись {entry_name} не может быть утверждена (текущий статус: '{locked.status}').",
			frappe.ValidationError,
		)

	now_ts = now_datetime()
	doc = frappe.get_doc(DOCTYPE, entry_name)
	doc.status = "Approved"
	doc.approved_by = actor
	doc.approved_at = now_ts
	if notes:
		doc.notes = f"{doc.notes or ''}\nОдобрено: {notes}".strip()
	doc.save(ignore_permissions=True)

	audit.record_audit(
		action="payroll.piece_work_approved",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={"status": "Approved", "approved_by": actor, "amount": locked.amount},
		company=doc.company,
		actor=actor,
	)

	outbox.record_event(
		event_name="payroll.piece_work_approved",
		aggregate_type=DOCTYPE,
		aggregate_id=doc.name,
		payload={
			"entry": doc.name,
			"company": doc.company,
			"employee": locked.employee,
			"amount": locked.amount,
			"approved_by": actor,
		},
		company=doc.company,
		actor=actor,
	)

	return doc


def reverse_piece_work(
	entry_name: str,
	reason: str,
	actor: str | None = None,
) -> Any:
	"""Сторнировать начисление (создается компенсирующая запись с отрицательной суммой)."""
	user_actor = actor or frappe.session.user or "Administrator"

	locked = frappe.db.get_value(
		DOCTYPE,
		entry_name,
		[
			"name",
			"company",
			"employee",
			"employee_name",
			"operation",
			"job_card",
			"sales_order",
			"work_order",
			"rate_type",
			"quantity",
			"unit",
			"rate",
			"amount",
			"status",
		],
		as_dict=True,
		for_update=True,
	)
	if not locked:
		frappe.throw(f"Запись {entry_name} не найдена для сторнирования.", frappe.DoesNotExistError)

	enforce_tenant_scope(locked.company)

	if locked.status in ("Reversed", "Paid"):
		frappe.throw(
			f"Запись {entry_name} не может быть сторнирована (текущий статус: '{locked.status}').",
			frappe.ValidationError,
		)

	# 1. Помечаем исходную запись как сторнированную
	frappe.db.set_value(
		DOCTYPE,
		entry_name,
		{"status": "Reversed", "reversal_reason": reason},
		update_modified=True,
	)

	# 2. Создаем компенсирующую запись
	comp_doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"company": locked.company,
			"employee": locked.employee,
			"employee_name": locked.employee_name,
			"operation": locked.operation,
			"job_card": locked.job_card,
			"sales_order": locked.sales_order,
			"work_order": locked.work_order,
			"rate_type": locked.rate_type,
			"quantity": -flt(locked.quantity),
			"unit": locked.unit,
			"rate": flt(locked.rate),
			"amount": -flt(locked.amount),
			"status": "Reversed",
			"reversed_entry": locked.name,
			"reversal_reason": reason,
			"approved_by": user_actor,
			"approved_at": now_datetime(),
		}
	)
	comp_doc.insert(ignore_permissions=True)

	audit.record_audit(
		action="payroll.piece_work_reversed",
		entity_type=DOCTYPE,
		entity_id=entry_name,
		diff={"status": "Reversed", "reversal_entry": comp_doc.name, "reason": reason},
		company=locked.company,
		actor=user_actor,
	)

	outbox.record_event(
		event_name="payroll.piece_work_reversed",
		aggregate_type=DOCTYPE,
		aggregate_id=entry_name,
		payload={
			"original_entry": entry_name,
			"reversal_entry": comp_doc.name,
			"company": locked.company,
			"employee": locked.employee,
			"amount": -flt(locked.amount),
			"reason": reason,
		},
		company=locked.company,
		actor=user_actor,
	)

	return comp_doc


def mark_paid(
	entry_name: str,
	actor: str | None = None,
) -> Any:
	"""Отметить утвержденную сдельную оплату как выплаченную."""
	user_actor = actor or frappe.session.user or "Administrator"

	locked = frappe.db.get_value(
		DOCTYPE,
		entry_name,
		["name", "company", "status", "employee", "amount"],
		as_dict=True,
		for_update=True,
	)
	if not locked:
		frappe.throw(f"Запись {entry_name} не найдена.", frappe.DoesNotExistError)

	enforce_tenant_scope(locked.company)

	if locked.status != "Approved":
		frappe.throw(
			f"Только утвержденные начисления (Approved) могут быть помечены как выплаченные (текущий: '{locked.status}').",
			frappe.ValidationError,
		)

	doc = frappe.get_doc(DOCTYPE, entry_name)
	doc.status = "Paid"
	doc.save(ignore_permissions=True)

	audit.record_audit(
		action="payroll.piece_work_paid",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={"status": "Paid"},
		company=doc.company,
		actor=user_actor,
	)

	outbox.record_event(
		event_name="payroll.piece_work_paid",
		aggregate_type=DOCTYPE,
		aggregate_id=doc.name,
		payload={
			"entry": doc.name,
			"company": doc.company,
			"employee": locked.employee,
			"amount": locked.amount,
		},
		company=doc.company,
		actor=user_actor,
	)

	return doc


def get_employee_payroll_summary(
	company: str | None,
	employee: str,
	from_date: Any = None,
	to_date: Any = None,
) -> dict[str, Any]:
	"""Сводная ведомость начислений по сотруднику."""
	comp = company or current_company()
	enforce_tenant_scope(comp)

	conditions = ["company = %(company)s", "employee = %(employee)s"]
	params: dict[str, Any] = {"company": comp, "employee": employee}

	if from_date:
		conditions.append("creation >= %(from_date)s")
		params["from_date"] = from_date
	if to_date:
		conditions.append("creation <= %(to_date)s")
		params["to_date"] = to_date

	where_clause = " AND ".join(conditions)

	rows = frappe.db.sql(
		f"""
		SELECT status, COALESCE(SUM(amount), 0) as total_amount, COUNT(name) as count
		FROM `tabPiece Work Entry`
		WHERE {where_clause}
		GROUP BY status
		""",
		params,
		as_dict=True,
	)

	summary = {
		"company": comp,
		"employee": employee,
		"Pending Approval": 0.0,
		"Approved": 0.0,
		"Paid": 0.0,
		"Reversed": 0.0,
		"counts": {},
	}

	for r in rows:
		st = r.status
		amt = flt(r.total_amount)
		summary[st] = amt
		summary["counts"][st] = r.count

	summary["payable_total"] = summary["Approved"]
	summary["total_earned"] = summary["Approved"] + summary["Paid"]

	return summary
