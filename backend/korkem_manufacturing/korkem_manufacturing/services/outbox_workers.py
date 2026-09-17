# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Outbox Automation Workers and Event Consumers.

Асинхронные воркеры-обработчики событий Transactional Outbox:
- Автоматическая диспетчеризация при возникновении дефицита материалов (material.shortage_detected)
  с запуском долговечной задачи закупки (material.procure_shortage_batch);
- Уведомления об изменении статусов заказов (Order Notifications);
- Per-consumer распределенный лизинг (Worker Leasing) и Dead Letter Queue (DLQ);
- Крон-точка входа для планировщика Frappe (hooks.py).
"""

from __future__ import annotations

import json
from typing import Any, Callable

import frappe
from frappe.utils import now_datetime

from korkem_manufacturing.services import durable_jobs, outbox
from korkem_manufacturing.services.scope import enforce_tenant_scope

CONSUMERS: dict[str, list[Callable[[dict[str, Any], str], None]]] = {}


def register_consumer(event_pattern: str, handler: Callable[[dict[str, Any], str], None]) -> None:
	"""Зарегистрировать подписчика на событие Outbox."""
	CONSUMERS.setdefault(event_pattern, []).append(handler)


# ----------------------------------------------------------------------
# 1. Реальные производственные подписчики (Domain Consumers)
# ----------------------------------------------------------------------

def shortage_automation_consumer(payload: dict[str, Any], company: str) -> None:
	"""Автоматическая реакция на дефицит: постановка durable-задачи формирования заявок на закупку."""
	sales_order = payload.get("sales_order")
	shortages = payload.get("shortages", [])

	if not sales_order or not shortages:
		return

	# Идемпотентный запуск долговечной задачи закупки дефицита
	job_key = f"procure-shortage-{sales_order}"
	durable_jobs.submit_durable_job(
		job_type="material.procure_shortage_batch",
		payload={
			"sales_order": sales_order,
			"shortages": shortages,
		},
		company=company,
		idempotency_key=job_key,
	)


def order_audit_consumer(payload: dict[str, Any], company: str) -> None:
	"""Логирование и трассировка переходов заказа."""
	sales_order = payload.get("sales_order")
	to_state = payload.get("to_state")
	# Фиксация в системном логе
	frappe.logger("korkem_manufacturing.outbox").info(
		f"[OrderEvent] Company: {company} | Order: {sales_order} | State: {to_state}"
	)


def deposit_received_consumer(payload: dict[str, Any], company: str) -> None:
	"""Автоматическая реакция на получение аванса: автоматическое бронирование сырья под заказ."""
	sales_order = payload.get("sales_order")
	if not sales_order:
		return

	from korkem_manufacturing.services import stock_reservation
	try:
		stock_reservation.reserve_materials_for_order(sales_order)
	except Exception as exc:
		frappe.logger("korkem_manufacturing.outbox").error(
			f"Ошибка автобронирования материалов по заказу {sales_order}: {exc}"
		)


# Регистрируем подписчиков
register_consumer("material.shortage_detected", shortage_automation_consumer)
register_consumer("order.*", order_audit_consumer)
register_consumer("payment.deposit_received", deposit_received_consumer)


# ----------------------------------------------------------------------
# 2. Диспетчер доставки Outbox-воркера (Dispatcher)
# ----------------------------------------------------------------------

def dispatch_outbox_batch(
	batch_size: int = 50,
	worker_id: str | None = None,
	delivery_name: str | None = None,
) -> dict[str, int]:
	"""Выполнить пакетную обработку ожидающих доставок Outbox с защитой Worker Leasing."""
	worker = worker_id or f"outbox-worker-{frappe.generate_hash(length=8)}"
	now_ts = now_datetime()

	conds = "status IN ('Pending', 'Failed') AND (lease_expires_at IS NULL OR lease_expires_at <= %s) AND (next_retry_at IS NULL OR next_retry_at <= %s)"
	params: list[Any] = [now_ts, now_ts]
	if delivery_name:
		conds += " AND name = %s"
		params.append(delivery_name)
	params.append(batch_size)

	# 1. Поиск доставок, готовых к обработке
	deliveries = frappe.db.sql(
		f"""
		SELECT name, event_id, consumer_name, company, status, attempts, max_attempts
		FROM `tabDomain Outbox Delivery`
		WHERE {conds}
		ORDER BY creation ASC
		LIMIT %s
		FOR UPDATE SKIP LOCKED
		""",
		tuple(params),
		as_dict=True,
	)

	metrics = {"processed": 0, "succeeded": 0, "failed": 0, "dead_letter": 0}

	for deliv in deliveries:
		metrics["processed"] += 1
		# Захват лизинга
		outbox.claim_delivery_lease(deliv.name, worker_token=worker, lease_duration_sec=30)
		frappe.db.commit()

		# Получение полезной нагрузки исходного события
		evt = frappe.db.get_value(
			"Domain Outbox Event",
			deliv.event_id,
			["event_name", "payload_json", "company"],
			as_dict=True,
		)
		if not evt:
			continue

		payload = json.loads(evt.payload_json) if evt.payload_json else {}

		try:
			# Поиск подходящих обработчиков
			matched_handlers = _get_handlers_for_event(evt.event_name)
			for h in matched_handlers:
				h(payload, evt.company)

			# Доставка подтверждена
			outbox.mark_delivery_success(deliv.name)
			metrics["succeeded"] += 1
			frappe.db.commit()

		except Exception as exc:
			metrics["failed"] += 1
			status, _ = outbox.mark_delivery_failure(deliv.name, str(exc))
			if status == "Dead Letter":
				metrics["dead_letter"] += 1
			frappe.db.commit()

	return metrics


def cron_dispatch_outbox() -> None:
	"""Периодическая точка входа планировщика (Cron Hook)."""
	try:
		dispatch_outbox_batch(batch_size=50)
	except Exception as e:
		frappe.logger("korkem_manufacturing.outbox").error(f"Cron dispatch error: {e}")


def _get_handlers_for_event(event_name: str) -> list[Callable[[dict[str, Any], str], None]]:
	"""Сопоставление имени события с зарегистрированными шаблонами."""
	handlers = []
	for pattern, funcs in CONSUMERS.items():
		if pattern == event_name:
			handlers.extend(funcs)
		elif pattern.endswith(".*"):
			prefix = pattern[:-2]
			if event_name.startswith(prefix):
				handlers.extend(funcs)
	return handlers
