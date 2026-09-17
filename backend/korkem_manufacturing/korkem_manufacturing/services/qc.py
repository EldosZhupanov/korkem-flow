# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Furniture Quality Control (ОТК) Domain Service.

Контроль качества готовой мебельной продукции перед отгрузкой клиенту:
- Мебельный чек-лист из 7 пунктов (геометрия, кромка, сколы, присадка, фасады, фурнитура, упаковка);
- Жесткий шлюз (Gate): статус Ready for Delivery доступен ТОЛЬКО при успешном прохождении ОТК;
- При выявлении брака:
  * Создается задача на переделку (Rework Task);
  * Испускается событие qc.failed;
  * Заказ блокируется от отгрузки.
"""

from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import now_datetime

from korkem_manufacturing.services import audit, outbox
from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope

QC_DOCTYPE = "Quality Inspection"
TASK_DOCTYPE = "CRM Task"

CHECKLIST_FIELDS = [
	"dimensions_accurate",  # Точность габаритов
	"edge_quality",        # Качество кромки (без свесов/клея)
	"no_chips",            # Отсутствие сколов ЛДСП
	"drilling_accurate",   # Соосность присадки/отверстий
	"facades_aligned",     # Ровность зазоров фасадов
	"hardware_tested",     # Плавность петель и направляющих
	"packaging_ready",     # Защита углов и упаковка
]


def submit_furniture_qc(
	*,
	sales_order: str,
	checklist: dict[str, bool],
	inspector: str,
	comments: str | None = None,
	company: str | None = None,
) -> dict[str, Any]:
	"""Провести проверку качества заказа по 7 критериям мебельного цеха."""
	if not frappe.db.exists("Sales Order", sales_order):
		frappe.throw(f"Заказ {sales_order} не найден.", frappe.DoesNotExistError)

	order = frappe.get_doc("Sales Order", sales_order)
	comp = company or order.company or current_company()
	enforce_tenant_scope(comp)

	# Проверка чек-листа
	failed_checks = [k for k in CHECKLIST_FIELDS if not checklist.get(k, False)]
	passed = len(failed_checks) == 0

	now_ts = now_datetime()
	status_str = "Accepted" if passed else "Rejected"

	# Создаем запись Quality Inspection (если доступна) или сохраняем аудит
	qi_name = f"QI-{sales_order}-{frappe.generate_hash(length=6)}"
	try:
		qi_doc = frappe.get_doc(
			{
				"doctype": QC_DOCTYPE,
				"name": qi_name,
				"inspection_type": "In Process",
				"reference_type": "Sales Order",
				"reference_name": sales_order,
				"status": status_str,
				"inspected_by": inspector,
				"company": comp,
				"remarks": comments or ("Все проверки пройдены" if passed else f"Дефекты: {', '.join(failed_checks)}"),
			}
		)
		qi_doc.flags.ignore_mandatory = True
		qi_doc.insert(ignore_permissions=True)
		qi_name = qi_doc.name
	except Exception:
		pass

	rework_task = None
	if not passed:
		# Создаем задачу на исправление брака
		task = frappe.get_doc(
			{
				"doctype": TASK_DOCTYPE,
				"title": f"Устранение дефектов ОТК по заказу {sales_order}",
				"description": f"Выявлены несоответствия ОТК: {', '.join(failed_checks)}.\nКомментарий инспектора: {comments or 'Не указан'}",
				"assigned_to": inspector,
				"status": "Todo",
				"priority": "High",
				"reference_doctype": "Sales Order",
				"reference_docname": sales_order,
			}
		)
		task.insert(ignore_permissions=True)
		rework_task = task.name

	# Аудит
	audit.record_audit(
		action="order.qc_evaluated",
		entity_type="Sales Order",
		entity_id=sales_order,
		diff={
			"passed": passed,
			"failed_checks": failed_checks,
			"quality_inspection": qi_name,
			"rework_task": rework_task,
			"inspector": inspector,
		},
		reason=f"ОТК: {'Пройден' if passed else 'Брак обнаружен'}",
		company=comp,
		actor=inspector,
	)

	# Outbox Event
	event_name = "qc.passed" if passed else "qc.failed"
	outbox.record_event(
		event_name=event_name,
		aggregate_type="Sales Order",
		aggregate_id=sales_order,
		payload={
			"sales_order": sales_order,
			"company": comp,
			"passed": passed,
			"failed_checks": failed_checks,
			"quality_inspection": qi_name,
			"rework_task": rework_task,
			"inspector": inspector,
			"timestamp": str(now_ts),
		},
		company=comp,
		actor=inspector,
	)

	return {
		"sales_order": sales_order,
		"passed": passed,
		"failed_checks": failed_checks,
		"quality_inspection": qi_name,
		"rework_task": rework_task,
		"status": "Accepted" if passed else "Rejected",
	}


def is_qc_passed_for_order(sales_order: str) -> bool:
	"""Проверяет, пройден ли ОТК по заказу."""
	# Проверяем наличие положительного события в аудите или последнем Quality Inspection
	last_audit = frappe.get_all(
		"Domain Audit Event",
		filters={"entity_type": "Sales Order", "entity_id": sales_order, "action": "order.qc_evaluated"},
		order_by="creation desc",
		limit=1,
		fields=["diff_json"],
	)
	if not last_audit:
		return False

	import json
	diff = json.loads(last_audit[0].diff_json) if last_audit[0].diff_json else {}
	return bool(diff.get("passed"))
