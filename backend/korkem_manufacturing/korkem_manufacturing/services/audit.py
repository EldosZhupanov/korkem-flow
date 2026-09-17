# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Domain Audit Trail: Неизменяемый журнал всех бизнес-мутаций.

Записывает каждое значимое действие в системе (переход статуса заказа,
резервирование плит, изменение цен, списание брака). Каждая запись
содержит снимок изменений (diff), инициатора, роль, канал и correlation ID.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any

import frappe
from frappe.utils import now_datetime

from korkem_manufacturing.services.scope import current_company, scoped


def record_audit(
	*,
	action: str,
	entity_type: str,
	entity_id: str,
	diff: dict[str, Any] | None = None,
	reason: str | None = None,
	channel: str = "System",
	correlation_id: str | None = None,
	trace_id: str | None = None,
	company: str | None = None,
	actor: str | None = None,
	actor_role: str | None = None,
) -> str | None:
	"""Атомарно записать событие в журнал аудита.
	
	Никогда не роняет основную транзакцию при внутренних сбоях форматирования.
	"""
	try:
		active_company = company or current_company()
		active_actor = actor or frappe.session.user
		active_role = actor_role or (
			frappe.get_roles(active_actor)[0] if active_actor and active_actor != "Guest" else "Guest"
		)

		timestamp_str = str(now_datetime())
		seed = f"{active_company}:{entity_type}:{entity_id}:{action}:{timestamp_str}:{frappe.generate_hash(length=8)}"
		record_name = f"aud-{hashlib.sha256(seed.encode()).hexdigest()[:16]}"

		diff_serialized = None
		if diff:
			diff_serialized = json.dumps(diff, ensure_ascii=False, default=str)

		doc = frappe.get_doc(
			{
				"doctype": "Domain Audit Event",
				"name": record_name,
				"company": active_company,
				"action": action,
				"entity_type": entity_type,
				"entity_id": str(entity_id),
				"actor": active_actor,
				"actor_role": active_role,
				"channel": channel,
				"reason": (reason or "").strip() or None,
				"correlation_id": correlation_id,
				"trace_id": trace_id,
				"diff_json": diff_serialized,
			}
		)
		doc.insert(ignore_permissions=True)
		return doc.name
	except Exception:
		frappe.log_error(
			title=f"Failed to record audit event for {action} on {entity_type}:{entity_id}",
			message=frappe.get_traceback(with_context=True),
		)
		return None


def get_audit_trail(
	*,
	entity_type: str,
	entity_id: str,
	company: str | None = None,
	limit: int = 50,
) -> list[dict[str, Any]]:
	"""Получить историю аудита по конкретной сущности."""
	filters = {
		"entity_type": entity_type,
		"entity_id": str(entity_id),
	}
	if company:
		filters["company"] = company
	else:
		filters = scoped(filters)

	rows = frappe.get_all(
		"Domain Audit Event",
		filters=filters,
		fields=[
			"name",
			"company",
			"action",
			"entity_type",
			"entity_id",
			"actor",
			"actor_role",
			"channel",
			"reason",
			"correlation_id",
			"diff_json",
			"creation",
		],
		order_by="creation desc",
		limit=limit,
	)

	result = []
	for row in rows:
		parsed_diff = None
		if row.get("diff_json"):
			try:
				parsed_diff = json.loads(row["diff_json"])
			except Exception:
				parsed_diff = row["diff_json"]
		result.append(
			{
				"id": row["name"],
				"action": row["action"],
				"entity_type": row["entity_type"],
				"entity_id": row["entity_id"],
				"actor": row["actor"],
				"actor_role": row.get("actor_role"),
				"channel": row.get("channel"),
				"reason": row.get("reason"),
				"correlation_id": row.get("correlation_id"),
				"diff": parsed_diff,
				"timestamp": str(row["creation"]),
			}
		)
	return result
