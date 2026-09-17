# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""API endpoints for Canonical Furniture Order Lifecycle State Machine.

Single public interface for Flutter Mobile, Desktop, Web Portal, and AI tools:
- get_state: returns current canonical state, progress percentages, and allowed targets.
- list_available_transitions: returns list of possible target states with feasibility and block reasons.
- transition: executes an atomic state transition with RBAC, preconditions, audit log, outbox event, and idempotency.
"""

from __future__ import annotations

from typing import Any

import frappe

from korkem_manufacturing.services import order_state
from korkem_manufacturing.services.idempotency import execute as execute_idempotently
from korkem_manufacturing.services.scope import ensure_company


@frappe.whitelist(methods=["GET", "POST"])
def get_state(sales_order: str) -> dict[str, Any]:
	"""Get canonical lifecycle state of a furniture sales order."""
	if not sales_order or not isinstance(sales_order, str):
		frappe.throw("sales_order must be a non-empty string.")
	sales_order = sales_order.strip()
	ensure_company("Sales Order", sales_order)
	return order_state.get_order_state(sales_order)


@frappe.whitelist(methods=["GET", "POST"])
def list_available_transitions(sales_order: str) -> list[dict[str, Any]]:
	"""List valid next state transitions for the given sales order."""
	if not sales_order or not isinstance(sales_order, str):
		frappe.throw("sales_order must be a non-empty string.")
	sales_order = sales_order.strip()
	ensure_company("Sales Order", sales_order)
	return order_state.list_available_transitions(sales_order)


@frappe.whitelist(methods=["POST"])
def transition(
	sales_order: str,
	target_state: str,
	expected_state: str | None = None,
	reason: str | None = None,
	idempotency_key: str | None = None,
) -> dict[str, Any]:
	"""Transition the sales order into a new canonical state."""
	if not sales_order or not isinstance(sales_order, str):
		frappe.throw("sales_order must be a non-empty string.")
	if not target_state or not isinstance(target_state, str):
		frappe.throw("target_state must be a non-empty string.")

	sales_order = sales_order.strip()
	target_state = target_state.strip()
	expected_state = (expected_state or "").strip() or None
	reason = (reason or "").strip() or None

	ensure_company("Sales Order", sales_order)

	def perform() -> dict[str, Any]:
		return order_state.transition(
			sales_order=sales_order,
			target_state=target_state,
			expected_state=expected_state,
			reason=reason,
			channel="API",
		)

	return execute_idempotently(
		"order.transition",
		idempotency_key,
		{
			"sales_order": sales_order,
			"target_state": target_state,
			"expected_state": expected_state,
			"reason": reason,
		},
		perform,
	)

