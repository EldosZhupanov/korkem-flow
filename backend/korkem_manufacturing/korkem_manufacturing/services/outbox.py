# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Transactional Outbox: At-Least-Once Delivery with Per-Consumer Delivery Ledger.

Архитектура:
1. `Domain Outbox Event` — агрегат события (ACID коммит вместе с бизнес-данными).
2. `Domain Outbox Delivery` — журнал доставки каждому отдельному подписчику (per-consumer ledger).
   UNIQUE(event_id, consumer_name) через детерминированный первичный ключ.
3. Worker Leasing / Distributed Lock: защита от двух параллельных воркеров-диспетчеров.
4. Retry Schedule: экспоненциальный backoff с джиттером.
5. Dead-Letter Queue (DLQ): изолирование сбойных событий после исчерпания попыток.
6. Replay: ручной или программный перезапуск из DLQ.
7. Metrics: сбор статистики состояния очереди и задержек доставки.
"""

from __future__ import annotations

import hashlib
import json
import random
from typing import Any

import frappe
from frappe.utils import add_to_date, now_datetime

from korkem_manufacturing.services.scope import current_company

MAX_RETRIES = 5
BASE_RETRY_DELAY_SEC = 5
HOOK_NAME = "korkem_domain_events"
LEASE_DURATION_SEC = 60


def record_event(
	*,
	event_name: str,
	aggregate_type: str,
	aggregate_id: str,
	payload: dict[str, Any],
	company: str | None = None,
	correlation_id: str | None = None,
	actor: str | None = None,
) -> str:
	"""Зафиксировать событие и создать per-consumer delivery rows в единой ACID транзакции."""
	active_company = company or current_company()
	active_actor = actor or frappe.session.user

	seed = f"{active_company}:{event_name}:{aggregate_id}:{str(now_datetime())}:{frappe.generate_hash(length=8)}"
	event_id = f"evt-{hashlib.sha256(seed.encode()).hexdigest()[:16]}"

	doc = frappe.get_doc(
		{
			"doctype": "Domain Outbox Event",
			"name": event_id,
			"event_name": event_name,
			"company": active_company,
			"aggregate_type": aggregate_type,
			"aggregate_id": str(aggregate_id),
			"actor": active_actor,
			"correlation_id": correlation_id,
			"status": "Pending",
			"retry_count": 0,
			"payload_json": json.dumps(payload, ensure_ascii=False, default=str),
		}
	)
	doc.insert(ignore_permissions=True)

	# 1. Поиск зарегистрированных подписчиков в hooks.py
	subscribers: list[str] = []
	try:
		subscribers = frappe.get_hooks(HOOK_NAME).get(event_name) or []
	except Exception:
		pass

	# 2. Создание per-consumer delivery записей
	for consumer in subscribers:
		_create_delivery_record(
			event_id=event_id,
			consumer_name=consumer,
			company=active_company,
			correlation_id=correlation_id,
		)

	# Если подписчиков в hooks нет, добавляем fallback consumer
	if not subscribers:
		_create_delivery_record(
			event_id=event_id,
			consumer_name="automation.evaluator",
			company=active_company,
			correlation_id=correlation_id,
		)

	return doc.name


def _create_delivery_record(
	*,
	event_id: str,
	consumer_name: str,
	company: str,
	correlation_id: str | None,
) -> str:
	"""Создает строку Domain Outbox Delivery с гарантией UNIQUE(event_id, consumer_name)."""
	raw_key = f"{event_id}:{consumer_name}"
	delivery_name = f"del-{hashlib.sha256(raw_key.encode()).hexdigest()[:20]}"

	delivery = frappe.get_doc(
		{
			"doctype": "Domain Outbox Delivery",
			"name": delivery_name,
			"event_id": event_id,
			"consumer_name": consumer_name,
			"company": company,
			"status": "Pending",
			"attempts": 0,
			"max_attempts": MAX_RETRIES,
			"correlation_id": correlation_id,
		}
	)
	delivery.insert(ignore_permissions=True)
	return delivery.name


def register_delivery_attempt(
	event_id: str,
	consumer_name: str,
	company: str,
	correlation_id: str | None = None,
) -> Any:
	"""Публичная регистрация доставки события конкретному подписчику."""
	delivery_name = _create_delivery_record(
		event_id=event_id,
		consumer_name=consumer_name,
		company=company,
		correlation_id=correlation_id,
	)
	return frappe.get_doc("Domain Outbox Delivery", delivery_name)


def dispatch_pending(
	limit: int = 50,
	worker_id: str | None = None,
) -> dict[str, Any]:
	"""Диспетчеризовать ожидающие доставки с конкурентной блокировкой (Worker Leasing)."""
	active_worker = worker_id or f"worker-{frappe.generate_hash(length=8)}"
	now_ts = now_datetime()

	# Ищем доставки, готовые к выполнению
	pending_deliveries = frappe.db.sql(
		"""
		SELECT name, event_id, consumer_name, company, attempts, max_attempts
		FROM `tabDomain Outbox Delivery`
		WHERE (status IN ('Pending', 'Failed') OR (status = 'Processing' AND lease_expires_at <= %(now)s))
		  AND attempts < max_attempts
		  AND (next_retry_at IS NULL OR next_retry_at <= %(now)s)
		  AND (lease_expires_at IS NULL OR lease_expires_at <= %(now)s)
		ORDER BY creation ASC
		LIMIT %(limit)s
		""",
		{"now": now_ts, "limit": limit},
		as_dict=True,
	)

	succeeded = 0
	failed = 0
	dead_letter = 0
	skipped_conflict = 0

	for row in pending_deliveries:
		delivery_name = row["name"]
		lease_until = add_to_date(now_datetime(), seconds=LEASE_DURATION_SEC)

		# Конкурентный захват лизинга с row lock (FOR UPDATE)
		locked = frappe.db.get_value(
			"Domain Outbox Delivery",
			delivery_name,
			["status", "lease_token", "lease_expires_at"],
			as_dict=True,
			for_update=True,
		)
		if not locked:
			continue

		if locked.lease_expires_at and locked.lease_expires_at > now_ts and locked.lease_token != active_worker:
			skipped_conflict += 1
			continue

		frappe.db.set_value(
			"Domain Outbox Delivery",
			delivery_name,
			{
				"lease_token": active_worker,
				"lease_expires_at": lease_until,
				"status": "Processing",
			},
			update_modified=False,
		)

		# Загружаем событие
		event_doc = frappe.get_doc("Domain Outbox Event", row["event_id"])
		try:
			payload = json.loads(event_doc.payload_json or "{}")
		except Exception:
			payload = {}

		consumer_name = row["consumer_name"]
		savepoint = f"del_{frappe.generate_hash(length=8)}"
		exec_ok = False
		err_msg = None

		try:
			frappe.db.savepoint(savepoint)
			_invoke_consumer(consumer_name, event_doc.event_name, payload, row["company"])
			frappe.db.release_savepoint(savepoint)
			exec_ok = True
		except Exception as exc:
			try:
				frappe.db.rollback(save_point=savepoint)
			except Exception:
				pass
			err_msg = str(exc)
			frappe.log_error(
				title=f"Outbox delivery failed: {consumer_name} on {event_doc.event_name}",
				message=frappe.get_traceback(with_context=True),
			)

		# Обновление состояния доставки
		new_attempts = row["attempts"] + 1
		if exec_ok:
			frappe.db.set_value(
				"Domain Outbox Delivery",
				delivery_name,
				{
					"status": "Completed",
					"attempts": new_attempts,
					"processed_at": now_datetime(),
					"lease_token": None,
					"lease_expires_at": None,
					"error_message": None,
				},
				update_modified=False,
			)
			succeeded += 1
		else:
			if new_attempts >= row["max_attempts"]:
				frappe.db.set_value(
					"Domain Outbox Delivery",
					delivery_name,
					{
						"status": "Dead Letter",
						"attempts": new_attempts,
						"lease_token": None,
						"lease_expires_at": None,
						"error_message": err_msg[:500] if err_msg else "Max attempts reached",
					},
					update_modified=False,
				)
				dead_letter += 1
			else:
				# Exponential backoff with jitter
				delay_sec = (2 ** new_attempts) * BASE_RETRY_DELAY_SEC + random.uniform(1.0, 3.0)
				retry_time = add_to_date(now_datetime(), seconds=int(delay_sec))
				frappe.db.set_value(
					"Domain Outbox Delivery",
					delivery_name,
					{
						"status": "Failed",
						"attempts": new_attempts,
						"next_retry_at": retry_time,
						"lease_token": None,
						"lease_expires_at": None,
						"error_message": err_msg[:500] if err_msg else "Failed execution",
					},
					update_modified=False,
				)
				failed += 1

		# Синхронизация статуса агрегата Domain Outbox Event
		_sync_parent_event_status(row["event_id"])

	return {
		"succeeded": succeeded,
		"failed": failed,
		"dead_letter": dead_letter,
		"skipped_conflicts": skipped_conflict,
		"processed": succeeded + failed + dead_letter,
	}


def _invoke_consumer(consumer_name: str, event_name: str, payload: dict[str, Any], company: str) -> None:
	"""Вызов подписчика с проверкой скоупа компании."""
	if consumer_name == "automation.evaluator":
		from korkem_manufacturing.services.automation import process_event
		process_event(event_name=event_name, payload=payload, company=company)
		return

	fn = frappe.get_attr(consumer_name)
	fn(**payload)


def _sync_parent_event_status(event_id: str) -> None:
	"""Вычисляет сводный статус события на основе всех его доставок."""
	deliveries = frappe.get_all(
		"Domain Outbox Delivery",
		filters={"event_id": event_id},
		fields=["status", "attempts"],
	)
	if not deliveries:
		return

	statuses = {d["status"] for d in deliveries}
	max_att = max(d["attempts"] for d in deliveries)

	if statuses == {"Completed"}:
		new_status = "Completed"
	elif "Dead Letter" in statuses:
		new_status = "Dead Letter"
	elif "Failed" in statuses or "Processing" in statuses:
		new_status = "Failed"
	else:
		new_status = "Pending"

	frappe.db.set_value(
		"Domain Outbox Event",
		event_id,
		{
			"status": new_status,
			"retry_count": max_att,
			"processed_at": now_datetime() if new_status == "Completed" else None,
		},
		update_modified=False,
	)


def replay_delivery(delivery_name: str) -> bool:
	"""Ручной или программный повтор конкретной доставки из DLQ."""
	if not frappe.db.exists("Domain Outbox Delivery", delivery_name):
		frappe.throw(f"Delivery {delivery_name} not found.")

	frappe.db.set_value(
		"Domain Outbox Delivery",
		delivery_name,
		{
			"status": "Pending",
			"attempts": 0,
			"next_retry_at": None,
			"lease_token": None,
			"lease_expires_at": None,
			"error_message": None,
		},
		update_modified=True,
	)

	event_id = frappe.db.get_value("Domain Outbox Delivery", delivery_name, "event_id")
	if event_id:
		_sync_parent_event_status(event_id)
	return True


def replay_event(event_id: str, consumer_name: str | None = None) -> int:
	"""Перезапустить доставку события из DLQ для всех или конкретного подписчика."""
	filters = {"event_id": event_id}
	if consumer_name:
		filters["consumer_name"] = consumer_name

	deliveries = frappe.get_all("Domain Outbox Delivery", filters=filters, pluck="name")
	for del_name in deliveries:
		replay_delivery(del_name)

	return len(deliveries)


def get_outbox_metrics(company: str | None = None) -> dict[str, Any]:
	"""Сбор метрик очереди доставки для мониторинга и алертинга."""
	conds = ""
	params = []
	if company:
		conds = "WHERE company = %s"
		params.append(company)

	deliveries = frappe.db.sql(
		f"""
		SELECT status, count(name) as count
		FROM `tabDomain Outbox Delivery`
		{conds}
		GROUP BY status
		""",
		tuple(params) if params else None,
		as_dict=True,
	)
	metrics = {
		"Pending": 0,
		"Processing": 0,
		"Completed": 0,
		"Failed": 0,
		"Dead Letter": 0,
	}
	for row in deliveries:
		if row["status"] in metrics:
			metrics[row["status"]] = row["count"]

	total = sum(metrics.values())
	return {
		"company": company or "All",
		"total_deliveries": total,
		"pending": metrics["Pending"],
		"processing": metrics["Processing"],
		"completed": metrics["Completed"],
		"failed": metrics["Failed"],
		"dead_letter": metrics["Dead Letter"],
	}


def claim_delivery_lease(
	delivery_name: str,
	worker_token: str,
	lease_duration_sec: int = 60,
) -> bool:
	"""Конкурентный захват лизинга доставки Outbox с row lock."""
	now_ts = now_datetime()
	lease_until = add_to_date(now_ts, seconds=lease_duration_sec)
	locked = frappe.db.get_value(
		"Domain Outbox Delivery",
		delivery_name,
		["status", "lease_token", "lease_expires_at"],
		as_dict=True,
		for_update=True,
	)
	if not locked:
		return False
	if locked.lease_expires_at and locked.lease_expires_at > now_ts and locked.lease_token != worker_token:
		return False
	frappe.db.set_value(
		"Domain Outbox Delivery",
		delivery_name,
		{
			"lease_token": worker_token,
			"lease_expires_at": lease_until,
			"status": "Processing",
		},
		update_modified=False,
	)
	return True


def mark_delivery_success(delivery_name: str) -> None:
	"""Отметить успешную доставку события подписчику."""
	row = frappe.db.get_value("Domain Outbox Delivery", delivery_name, ["event_id", "attempts"], as_dict=True)
	if not row:
		return
	new_attempts = (row.attempts or 0) + 1
	frappe.db.set_value(
		"Domain Outbox Delivery",
		delivery_name,
		{
			"status": "Completed",
			"attempts": new_attempts,
			"processed_at": now_datetime(),
			"lease_token": None,
			"lease_expires_at": None,
			"error_message": None,
		},
		update_modified=False,
	)
	_sync_parent_event_status(row.event_id)


def mark_delivery_failure(delivery_name: str, error_message: str) -> tuple[str, Any]:
	"""Отметить ошибку выполнения доставки подписчиком с расчетом retry backoff."""
	row = frappe.db.get_value(
		"Domain Outbox Delivery",
		delivery_name,
		["event_id", "attempts", "max_attempts"],
		as_dict=True,
	)
	if not row:
		return "Failed", None
	new_attempts = (row.attempts or 0) + 1
	if new_attempts >= (row.max_attempts or MAX_RETRIES):
		status = "Dead Letter"
		next_retry = None
		frappe.db.set_value(
			"Domain Outbox Delivery",
			delivery_name,
			{
				"status": "Dead Letter",
				"attempts": new_attempts,
				"lease_token": None,
				"lease_expires_at": None,
				"error_message": (error_message or "")[:500],
			},
			update_modified=False,
		)
	else:
		status = "Failed"
		delay_sec = (2 ** new_attempts) * BASE_RETRY_DELAY_SEC + random.uniform(1.0, 3.0)
		next_retry = add_to_date(now_datetime(), seconds=int(delay_sec))
		frappe.db.set_value(
			"Domain Outbox Delivery",
			delivery_name,
			{
				"status": "Failed",
				"attempts": new_attempts,
				"next_retry_at": next_retry,
				"lease_token": None,
				"lease_expires_at": None,
				"error_message": (error_message or "")[:500],
			},
			update_modified=False,
		)
	_sync_parent_event_status(row.event_id)
	return status, next_retry

