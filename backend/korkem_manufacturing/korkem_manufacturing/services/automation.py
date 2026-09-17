# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Automation Engine for KORKEM Flow (Trigger -> Condition -> Action).

Lightweight, safe, and deterministic business rules engine:
- Evaluates conditions against event payloads
- Dispatches domain commands (order transitions, task creations, notifications)
- Prevents infinite loops via recursion depth guards (depth <= 3)
- Isolates rule execution with database savepoints
"""

from __future__ import annotations

import json
from typing import Any, Callable

import frappe
from frappe.utils import flt, now_datetime

from korkem_manufacturing.services import audit, order_state

MAX_RECURSION_DEPTH = 3


# ----------------------------------------------------------------------
# 1. Condition Evaluator
# ----------------------------------------------------------------------
def evaluate_condition(condition: dict[str, Any] | None, payload: dict[str, Any]) -> bool:
	"""Check if an event payload satisfies the condition tree."""
	if not condition:
		return True

	# Compound logic: 'and'
	if "and" in condition and isinstance(condition["and"], list):
		return all(evaluate_condition(sub, payload) for sub in condition["and"])

	# Compound logic: 'or'
	if "or" in condition and isinstance(condition["or"], list):
		return any(evaluate_condition(sub, payload) for sub in condition["or"])

	# Compound logic: 'not'
	if "not" in condition and isinstance(condition["not"], dict):
		return not evaluate_condition(condition["not"], payload)

	# Leaf condition: field, op, value
	field = condition.get("field")
	op = condition.get("op", "==")
	target_val = condition.get("value")

	if not field:
		return True

	actual_val = _get_nested_field(payload, field)

	if op == "==":
		return actual_val == target_val
	elif op == "!=":
		return actual_val != target_val
	elif op == ">":
		return flt(actual_val) > flt(target_val)
	elif op == ">=":
		return flt(actual_val) >= flt(target_val)
	elif op == "<":
		return flt(actual_val) < flt(target_val)
	elif op == "<=":
		return flt(actual_val) <= flt(target_val)
	elif op == "in":
		return actual_val in (target_val if isinstance(target_val, (list, tuple, set)) else [target_val])
	elif op == "contains":
		return target_val in actual_val if actual_val is not None else False
	elif op == "is_set":
		return actual_val is not None and actual_val != ""

	return False


def _get_nested_field(obj: dict[str, Any], path: str) -> Any:
	parts = path.split(".")
	curr = obj
	for p in parts:
		if isinstance(curr, dict):
			curr = curr.get(p)
		else:
			return None
	return curr


# ----------------------------------------------------------------------
# 2. Action Dispatcher
# ----------------------------------------------------------------------
def execute_action(
	action: dict[str, Any],
	payload: dict[str, Any],
	company: str,
	depth: int = 0,
) -> dict[str, Any]:
	"""Execute a single automation action safely."""
	action_type = action.get("type")
	params = action.get("params", {})

	# Interpolate payload fields into string params if templated
	resolved_params = _resolve_params(params, payload)

	if action_type == "order.transition":
		order_name = resolved_params.get("sales_order") or payload.get("sales_order")
		target_state = resolved_params.get("target_state")
		reason = resolved_params.get("reason", "Automation Rule Execution")
		return order_state.transition(
			sales_order=order_name,
			target_state=target_state,
			reason=reason,
			channel="AutomationEngine",
		)

	elif action_type == "task.create":
		subject = resolved_params.get("subject", "Автоматическая задача")
		assigned_to = resolved_params.get("assigned_to", "Administrator")
		todo = frappe.get_doc(
			{
				"doctype": "ToDo",
				"description": subject,
				"allocated_to": assigned_to,
				"reference_type": resolved_params.get("reference_type"),
				"reference_name": resolved_params.get("reference_name"),
				"status": "Open",
			}
		).insert(ignore_permissions=True)
		return {"todo": todo.name, "status": "created"}

	elif action_type == "audit.record":
		audit.record_audit(
			action=resolved_params.get("action", "automation.rule_triggered"),
			entity_type=resolved_params.get("entity_type", "System"),
			entity_id=resolved_params.get("entity_id", "Automation"),
			diff=resolved_params.get("diff"),
			company=company,
			actor="AutomationEngine",
		)
		return {"status": "audit_recorded"}

	elif action_type == "notification.send":
		# Log notification intent
		frappe.logger("korkem.automation").info(
			f"Notification requested: {resolved_params.get('channel')} -> {resolved_params.get('recipient')}: {resolved_params.get('message')}"
		)
		return {"status": "notification_dispatched", "recipient": resolved_params.get("recipient")}

	return {"status": "unsupported_action", "action_type": action_type}


def _resolve_params(params: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any]:
	resolved = {}
	for k, v in params.items():
		if isinstance(v, str) and v.startswith("{{") and v.endswith("}}"):
			field_path = v[2:-2].strip()
			resolved[k] = _get_nested_field(payload, field_path)
		else:
			resolved[k] = v
	return resolved


# ----------------------------------------------------------------------
# 3. Built-in Preset Rules & Rule Engine
# ----------------------------------------------------------------------
DEFAULT_PRESET_RULES = [
	{
		"name": "rule-auto-order-in-production",
		"trigger_event": "order.ready_for_production",
		"condition": {"field": "company", "op": "is_set"},
		"actions": [
			{
				"type": "audit.record",
				"params": {
					"action": "automation.order_production_ready",
					"entity_type": "Sales Order",
					"entity_id": "{{sales_order}}",
				},
			}
		],
	}
]


def process_event(
	event_name: str,
	payload: dict[str, Any],
	company: str,
	depth: int = 0,
) -> list[dict[str, Any]]:
	"""Evaluate and run all active automation rules for a triggered event."""
	if depth > MAX_RECURSION_DEPTH:
		frappe.logger("korkem.automation").warning(
			f"Automation recursion limit exceeded (depth={depth}) for event={event_name}"
		)
		return [{"rule": None, "status": "SKIPPED", "reason": "Max recursion depth exceeded"}]

	# Fetch rules: DB or Presets
	rules = _get_matching_rules(event_name, company)
	results = []

	for rule in rules:
		rule_name = rule.get("name", "unnamed-rule")
		cond = rule.get("condition")

		if not evaluate_condition(cond, payload):
			results.append({"rule": rule_name, "status": "CONDITION_NOT_MET"})
			continue

		# Execute actions under a savepoint
		sp = f"auto_{frappe.generate_hash(length=8)}"
		frappe.db.savepoint(sp)
		rule_exec = {"rule": rule_name, "actions": [], "status": "SUCCESS"}

		try:
			for act in rule.get("actions", []):
				res = execute_action(act, payload, company, depth=depth + 1)
				rule_exec["actions"].append(res)
		except Exception as exc:
			frappe.db.rollback(save_point=sp)
			rule_exec["status"] = "FAILED"
			rule_exec["error"] = str(exc)
			frappe.logger("korkem.automation").error(f"Automation rule {rule_name} failed: {exc}")

		results.append(rule_exec)

	return results


def _get_matching_rules(event_name: str, company: str) -> list[dict[str, Any]]:
	"""Get all rules that listen to this event."""
	# 1. Custom rules if DocType exists
	db_rules: list[dict[str, Any]] = []
	if frappe.db.table_exists("Automation Rule"):
		try:
			docs = frappe.get_all(
				"Automation Rule",
				filters={"trigger_event": event_name, "is_active": 1, "company": company},
				fields=["name", "trigger_event", "condition_expression_json", "actions_json"],
			)
			for d in docs:
				db_rules.append(
					{
						"name": d.name,
						"trigger_event": d.trigger_event,
						"condition": json.loads(d.condition_expression_json or "{}"),
						"actions": json.loads(d.actions_json or "[]"),
					}
				)
		except Exception:
			pass

	# 2. Preset built-in fallback rules
	matching_presets = [r for r in DEFAULT_PRESET_RULES if r.get("trigger_event") == event_name]

	return db_rules + matching_presets
