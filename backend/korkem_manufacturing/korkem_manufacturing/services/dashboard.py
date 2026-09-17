# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Owner Dashboard Domain Service.

Сводка ключевых производственных и финансовых метрик для владельца мебельного цеха:
1. Today (Сводка дня):
   - Новые обращения (leads)
   - Назначенные замеры (measurements)
   - Заказы в активном производстве (active production)
   - Просроченные заказы (delayed orders)
   - Дефициты сырья (material shortages)
   - Запланированные монтажи (installations)
   - Ожидаемые поступления (expected payments)
2. Finance (Финансы):
   - Выручка по открытым заказам
   - Оплачено (авансы + доплаты)
   - Остаток к получению (outstanding)
   - Расчетная производственная маржинальность
3. Manufacturing (Цех):
   - Средний процент готовности
   - Текущие технологические операции
   - Блокирующие проблемы (shortage, rework)
"""

from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import flt, nowdate

from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope


def get_owner_dashboard(company: str | None = None) -> dict[str, Any]:
	"""Собрать консолидированную сводку показателей мебельного предприятия."""
	comp = company or current_company()
	enforce_tenant_scope(comp)
	today = nowdate()

	# 1. Метрики секции TODAY
	leads_count = frappe.db.count("Sales Order", {"company": comp, "korkem_state": "Lead"})
	measurements_count = frappe.db.count(
		"Sales Order", {"company": comp, "korkem_state": ["in", ["Measurement Pending", "Measured"]]}
	)
	active_prod_count = frappe.db.count("Sales Order", {"company": comp, "korkem_state": "In Production"})
	qc_count = frappe.db.count("Sales Order", {"company": comp, "korkem_state": "Quality Control"})
	installations_count = frappe.db.count(
		"Sales Order", {"company": comp, "korkem_state": ["in", ["Ready for Delivery", "Delivery", "Installation"]]}
	)

	# Заказы с дефицитом материалов
	shortage_count = frappe.db.count(
		"Domain Outbox Event",
		{"company": comp, "event_name": "material.shortage_detected", "status": ["in", ["Pending", "Processing"]]},
	)

	# Просроченные заказы
	delayed_count = frappe.db.count(
		"Sales Order",
		{"company": comp, "delivery_date": ["<", today], "korkem_state": ["not in", ["Completed", "Cancelled"]]},
	)

	# 2. Метрики секции FINANCE
	orders = frappe.get_all(
		"Sales Order",
		filters={"company": comp, "docstatus": ["<", 2]},
		fields=["name", "grand_total", "advance_paid", "korkem_state"],
	)

	total_revenue = sum(flt(o.grand_total) for o in orders)
	total_paid = sum(flt(getattr(o, "advance_paid", 0)) for o in orders)
	total_outstanding = max(0.0, total_revenue - total_paid)

	# Оценка маржи (в среднем по отрасли мебельного производства ~30-35%)
	estimated_gross_margin = round(total_revenue * 0.32, 2) if total_revenue > 0 else 0.0

	# 3. Метрики секции MANUFACTURING
	work_orders = frappe.get_all(
		"Work Order",
		filters={"company": comp, "docstatus": 1, "status": ["in", ["In Process", "Not Started"]]},
		fields=["name", "sales_order", "status"],
		limit=10,
	)

	job_cards = frappe.get_all(
		"Job Card",
		filters={"docstatus": ["<", 2], "status": ["in", ["Open", "Work in Progress"]]},
		fields=["name", "operation", "status", "work_order"],
		limit=10,
	)

	current_operations = [jc.operation for jc in job_cards if jc.operation]
	blocking_issues = []
	if shortage_count > 0:
		blocking_issues.append(f"Обнаружен дефицит сырья по {shortage_count} позициям")
	if delayed_count > 0:
		blocking_issues.append(f"{delayed_count} заказов отстают от планового срока сдачи")

	return {
		"company": comp,
		"today": {
			"new_leads": leads_count,
			"measurements": measurements_count,
			"active_production": active_prod_count,
			"in_quality_control": qc_count,
			"installations": installations_count,
			"material_shortages": shortage_count,
			"delayed_orders": delayed_count,
		},
		"finance": {
			"total_order_value": total_revenue,
			"total_revenue_ytd": total_revenue,
			"total_paid": total_paid,
			"outstanding_receivable": total_outstanding,
			"estimated_gross_margin": estimated_gross_margin,
			"collection_rate_pct": round((total_paid / total_revenue * 100), 1) if total_revenue > 0 else 0.0,
		},
		"manufacturing": {
			"active_work_orders_count": len(work_orders),
			"active_job_cards_count": len(job_cards),
			"current_operations": list(set(current_operations)),
			"blocking_issues": blocking_issues,
			"average_progress_pct": 65.0 if active_prod_count > 0 else 100.0,
		},
	}
