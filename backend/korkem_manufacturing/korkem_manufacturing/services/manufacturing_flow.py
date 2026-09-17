# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Canonical Manufacturing Shop-Floor Flow Service.

Оркестрирует завершение технологических операций на рабочих местах:
1. Завершение JobCard с учетом годных деталей и брака (Scrap);
2. Складские проводки двойной записи (Stock Movement):
   - Stores -> Work in Progress (расход сырья);
   - Work in Progress -> Offcut Storage (оприходование пригодных деловых остатков);
   - Work in Progress -> Scrap (списание технологических потерь);
3. Автоматическое начисление сдельной оплаты (Piece Work Entry) со статусом 'Pending Approval';
4. Защита от повторного списания/начисления при сбоях (Идемпотентность по JobCard).
"""

from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import flt, now_datetime

from korkem_manufacturing.services import audit, offcuts, outbox, piece_work, stock_movement
from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope


def complete_operation_flow(
	*,
	job_card: str,
	operator: str,
	employee: str,
	completed_qty: float,
	scrap_qty: float = 0.0,
	rate_type: str = "KZT_PER_PART",
	rate: float = 350.0,
	offcut_data: dict[str, Any] | None = None,
	company: str | None = None,
	comments: str | None = None,
) -> dict[str, Any]:
	"""Атомарно завершить технологическую операцию с фиксацией выработки, движения материалов и остатков."""
	if not frappe.db.exists("Job Card", job_card):
		frappe.throw(f"Технологическая карта {job_card} не найдена.", frappe.DoesNotExistError)

	card = frappe.get_doc("Job Card", job_card)
	comp = company or card.company or current_company()
	enforce_tenant_scope(comp)
	now_ts = now_datetime()

	idempotency_key = f"jobcard-complete-{job_card}"

	# 1. Проверка идемпотентности: не начислялась ли уже сдельная оплата по этой карте
	existing_payout = frappe.db.get_value(
		"Piece Work Entry",
		{"idempotency_key": idempotency_key, "company": comp},
		"name",
	)
	if existing_payout:
		return {
			"job_card": job_card,
			"piece_work_entry": existing_payout,
			"status": "already_completed",
		}

	# 2. Обновление статуса Job Card
	c_qty = flt(completed_qty)
	s_qty = flt(scrap_qty)
	if c_qty <= 0:
		frappe.throw("Количество годных деталей должно быть больше нуля.", frappe.ValidationError)

	card.db_set(
		{
			"status": "Completed",
			"total_completed_qty": c_qty,
			"process_loss_qty": s_qty,
			"actual_end_date": now_ts,
			"remarks": comments or f"Выполнено оператором {operator}",
		},
		update_modified=True,
	)

	# 3. Фиксация складских перемещений двойной записи (Domain Stock Movement)
	work_order = card.work_order
	sales_order = frappe.db.get_value("Work Order", work_order, "sales_order") if work_order else None

	# Проводка: Списание сырья в производство
	stock_movement.record_movement(
		item_code=card.production_item or "LDSP-16-WHT",
		from_location="Stores",
		to_location="Work in Progress",
		qty=c_qty + s_qty,
		reason=f"Списание в производство под наряд {work_order}, операция {card.operation}",
		company=comp,
		actor=operator,
	)

	# Если был зафиксирован брак: перевод в Scrap
	if s_qty > 0:
		stock_movement.record_movement(
			item_code=card.production_item or "LDSP-16-WHT",
			from_location="Work in Progress",
			to_location="Scrap",
			qty=s_qty,
			reason=f"Технологический брак по наряду {work_order}, операция {card.operation}",
			company=comp,
			actor=operator,
		)

	# 4. Оприходование делового остатка (если это раскрой и передан offcut_data)
	created_offcut = None
	if offcut_data:
		created_offcut = offcuts.create_offcut(
			company=comp,
			material_item=offcut_data.get("material_item", "LDSP-16-WHT"),
			length_mm=offcut_data.get("length_mm", 1200),
			width_mm=offcut_data.get("width_mm", 600),
			thickness_mm=offcut_data.get("thickness_mm", 16),
			decor=offcut_data.get("decor", "Белый"),
			warehouse=offcut_data.get("warehouse", "Stores"),
			source_order=sales_order,
			source_work_order=work_order,
			source_job_card=job_card,
		)
		# Складская проводка перемещения остатка
		stock_movement.record_movement(
			item_code=offcut_data.get("material_item", "LDSP-16-WHT"),
			from_location="Work in Progress",
			to_location="Offcut Storage",
			qty=created_offcut.area_m2,
			reason=f"Оприходование делового остатка {created_offcut.name} ({created_offcut.length_mm}x{created_offcut.width_mm}мм)",
			company=comp,
			actor=operator,
		)

	# 5. Автоматическое начисление сдельной оплаты (Piece Work Entry)
	pw_entry = piece_work.record_piece_work(
		company=comp,
		employee=employee,
		operation=card.operation or "Раскрой",
		rate_type=rate_type,
		quantity=c_qty,
		rate=rate,
		job_card=job_card,
		sales_order=sales_order,
		work_order=work_order,
		idempotency_key=idempotency_key,
		actor=operator,
	)

	# 6. Аудит и Outbox
	audit.record_audit(
		action="manufacturing.operation_completed",
		entity_type="Job Card",
		entity_id=job_card,
		diff={
			"completed_qty": c_qty,
			"scrap_qty": s_qty,
			"piece_work_entry": pw_entry.name,
			"offcut_created": created_offcut.name if created_offcut else None,
		},
		reason=f"Операция '{card.operation}' завершена. Выработка: {c_qty}",
		company=comp,
		actor=operator,
	)

	outbox.record_event(
		event_name="operation.completed",
		aggregate_type="Job Card",
		aggregate_id=job_card,
		payload={
			"job_card": job_card,
			"work_order": work_order,
			"sales_order": sales_order,
			"operation": card.operation,
			"completed_qty": c_qty,
			"scrap_qty": s_qty,
			"piece_work_entry": pw_entry.name,
			"offcut": created_offcut.name if created_offcut else None,
			"operator": operator,
			"company": comp,
		},
		company=comp,
		actor=operator,
	)

	return {
		"job_card": job_card,
		"status": "Completed",
		"completed_qty": c_qty,
		"scrap_qty": s_qty,
		"piece_work_entry": pw_entry.name,
		"piece_work_amount": pw_entry.amount,
		"offcut": created_offcut.name if created_offcut else None,
	}
