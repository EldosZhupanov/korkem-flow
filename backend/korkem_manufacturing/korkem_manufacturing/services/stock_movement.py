# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Domain Stock Movement Service (Double-entry Material Ledger).

Неизменяемый (Append-only) журнал учета перемещений материалов и деловых остатков:
- Двойная запись: каждое перемещение имеет `from_location` и `to_location`;
- Баланс на любой локации восстанавливается детерминированно:
    Balance(L, Item) = SUM(qty WHERE to_location = L) - SUM(qty WHERE from_location = L);
- Никаких обновлений и удалений: ошибки исправляются только сторнированием (компенсацией);
- Интеграция с Transactional Outbox и аутентификацией арендаторов.
"""

from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import flt, now_datetime

from korkem_manufacturing.services import outbox
from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope

DOCTYPE = "Domain Stock Movement"


def record_movement(
	*,
	company: str | None = None,
	from_location: str,
	to_location: str,
	item_code: str,
	qty: float,
	reason: str,
	sales_order: str | None = None,
	work_order: str | None = None,
	job_card: str | None = None,
	offcut: str | None = None,
	correlation_id: str | None = None,
	actor: str | None = None,
	timestamp: Any = None,
	is_compensation: int = 0,
	compensated_movement: str | None = None,
) -> Any:
	"""Зафиксировать перемещение материала в append-only регистре двойной записи."""
	comp = company or current_company()
	enforce_tenant_scope(comp)

	q = flt(qty)
	if q <= 0:
		frappe.throw(f"Количество перемещения должно быть строго больше нуля (передано: {qty}).", frappe.ValidationError)

	user_actor = actor or frappe.session.user or "Administrator"
	ts = timestamp or now_datetime()

	doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"company": comp,
			"from_location": from_location,
			"to_location": to_location,
			"item_code": item_code,
			"qty": q,
			"reason": reason,
			"sales_order": sales_order,
			"work_order": work_order,
			"job_card": job_card,
			"offcut": offcut,
			"correlation_id": correlation_id,
			"actor": user_actor,
			"timestamp": ts,
			"is_compensation": 1 if is_compensation else 0,
			"compensated_movement": compensated_movement,
		}
	)
	doc.insert(ignore_permissions=True)

	outbox.record_event(
		event_name="stock.movement_recorded",
		aggregate_type=DOCTYPE,
		aggregate_id=doc.name,
		payload={
			"movement": doc.name,
			"company": comp,
			"from_location": from_location,
			"to_location": to_location,
			"item_code": item_code,
			"qty": q,
			"reason": reason,
			"sales_order": sales_order,
			"offcut": offcut,
			"is_compensation": bool(is_compensation),
		},
		company=comp,
		actor=user_actor,
	)

	return doc


def get_balance(company: str | None, location: str, item_code: str) -> float:
	"""Восстановить точный баланс номенклатуры на локации из регистра двойной записи."""
	comp = company or current_company()
	enforce_tenant_scope(comp)

	# Sum of receipts (incoming)
	incoming = frappe.db.sql(
		"""
		SELECT COALESCE(SUM(qty), 0)
		FROM `tabDomain Stock Movement`
		WHERE company = %s AND to_location = %s AND item_code = %s
		""",
		(comp, location, item_code),
	)[0][0]

	# Sum of issues (outgoing)
	outgoing = frappe.db.sql(
		"""
		SELECT COALESCE(SUM(qty), 0)
		FROM `tabDomain Stock Movement`
		WHERE company = %s AND from_location = %s AND item_code = %s
		""",
		(comp, location, item_code),
	)[0][0]

	return flt(incoming) - flt(outgoing)


def compensate_movement(
	movement_name: str,
	reason: str = "Сторнирование проводки",
	actor: str | None = None,
) -> Any:
	"""Создать зеркальную сторнирующую проводку (compensation) для отмены ошибочного движения."""
	orig = frappe.db.get_value(
		DOCTYPE,
		movement_name,
		[
			"name",
			"company",
			"from_location",
			"to_location",
			"item_code",
			"qty",
			"sales_order",
			"work_order",
			"job_card",
			"offcut",
			"correlation_id",
		],
		as_dict=True,
	)
	if not orig:
		frappe.throw(f"Движение {movement_name} не найдено для сторнирования.", frappe.DoesNotExistError)

	enforce_tenant_scope(orig.company)
	user_actor = actor or frappe.session.user or "Administrator"

	return record_movement(
		company=orig.company,
		from_location=orig.to_location,
		to_location=orig.from_location,
		item_code=orig.item_code,
		qty=orig.qty,
		reason=f"{reason} (Сторно: {movement_name})",
		sales_order=orig.sales_order,
		work_order=orig.work_order,
		job_card=orig.job_card,
		offcut=orig.offcut,
		correlation_id=orig.correlation_id,
		actor=user_actor,
		is_compensation=1,
		compensated_movement=orig.name,
	)
