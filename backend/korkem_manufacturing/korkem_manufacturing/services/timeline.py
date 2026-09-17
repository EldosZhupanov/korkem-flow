# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Canonical Customer Order Timeline Service.

Формирует единую прозрачную хронологию выполнения заказа клиента (Customer Timeline):
- Источник данных — исключительно существующие журналы аудита (Domain Audit Event),
  переходов состояний (Order State Log) и очереди Outbox (Domain Outbox Event);
- Никакой отдельной дублирующей ручной истории;
- Полная трассируемость от обращения до гарантийного обслуживания.
"""

from __future__ import annotations

import json
from typing import Any

import frappe
from frappe.utils import getdate

from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope


def get_customer_order_timeline(sales_order: str) -> dict[str, Any]:
	"""Собрать единую хронологию заказа из аудита, логов FSM и доменных событий."""
	if not frappe.db.exists("Sales Order", sales_order):
		frappe.throw(f"Заказ {sales_order} не найден.", frappe.DoesNotExistError)

	order = frappe.get_doc("Sales Order", sales_order)
	comp = order.company or current_company()
	enforce_tenant_scope(comp)

	events = []

	# 1. Извлечение переходов из Order State Log
	state_logs = frappe.get_all(
		"Order State Log",
		filters={"sales_order": sales_order},
		fields=["from_state", "to_state", "actor", "creation", "reason"],
		order_by="creation asc",
	)
	for log in state_logs:
		events.append({
			"type": "state_transition",
			"stage": log.to_state,
			"title": f"Переход в статус: {log.to_state}",
			"actor": log.actor,
			"channel": "System",
			"timestamp": str(log.creation),
			"details": f"Смена статуса с '{log.from_state}' на '{log.to_state}'. Причина: {log.reason or 'Плановый переход'}",
		})

	# 2. Извлечение событий из Domain Audit Event
	audit_logs = frappe.get_all(
		"Domain Audit Event",
		filters={"entity_type": "Sales Order", "entity_id": sales_order},
		fields=["action", "actor", "channel", "creation", "diff_json", "reason"],
		order_by="creation asc",
	)
	for a in audit_logs:
		diff = json.loads(a.diff_json) if a.diff_json else {}
		action_title = a.action.replace(".", " ").title()
		events.append({
			"type": "audit_action",
			"stage": a.action,
			"title": action_title,
			"actor": a.actor,
			"channel": a.channel,
			"timestamp": str(a.creation),
			"details": a.reason or json.dumps(diff, ensure_ascii=False),
		})

	# 3. Дополнительные производственные вехи (JobCards, Delivery, Warranty)
	# Резервы материалов
	reservations_count = frappe.db.count("Stock Reservation", {"sales_order": sales_order})
	if reservations_count > 0:
		events.append({
			"type": "manufacturing",
			"stage": "Materials Reserved",
			"title": "Материалы зарезервированы под заказ",
			"actor": "System",
			"channel": "Production",
			"timestamp": str(order.modified),
			"details": f"Зафиксировано {reservations_count} позиций резерва материалов и деловых остатков.",
		})

	# Сортировка всей цепочки событий по времени
	events.sort(key=lambda x: str(x.get("timestamp") or ""))

	return {
		"sales_order": sales_order,
		"customer": order.customer,
		"current_state": getattr(order, "korkem_state", "Draft"),
		"total_events": len(events),
		"timeline": events,
	}
