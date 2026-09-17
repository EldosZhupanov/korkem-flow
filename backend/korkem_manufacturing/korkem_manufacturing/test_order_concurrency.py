# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Concurrency, optimistic locking, and race-condition tests for Order State Machine."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.api import order_state as order_state_api
from korkem_manufacturing.services import order_state


class TestOrderConcurrency(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.company = "KORKEM"
		self.order = self._create_test_order()

	def tearDown(self):
		frappe.db.rollback()

	def _create_test_order(self):
		name = f"SO-CONC-{frappe.generate_hash(length=8)}"
		doc = frappe.get_doc(
			{
				"doctype": "Sales Order",
				"name": name,
				"company": self.company,
				"customer": "Павлодар Уют",
				"transaction_date": nowdate(),
				"delivery_date": add_days(nowdate(), 7),
				"korkem_state": "Draft",
				"items": [
					{
						"item_code": "ДСП 16мм",
						"qty": 1,
						"rate": 15000,
						"delivery_date": add_days(nowdate(), 7),
						"warehouse": "Stores - KRK",
					}
				],
			}
		).insert(ignore_permissions=True)
		return doc

	def test_stale_client_state_optimistic_conflict(self):
		"""When client UI provides an outdated expected_state, transition must be refused."""
		# 1. First transition moves Draft -> Lead
		order_state.transition(
			sales_order=self.order.name,
			target_state="Lead",
			expected_state="Draft",
		)
		curr_state = frappe.db.get_value("Sales Order", self.order.name, "korkem_state")
		self.assertEqual(curr_state, "Lead")

		# 2. Second user (stale UI thinking order is still 'Draft') tries to transition to 'Cancelled'
		with self.assertRaises(frappe.ValidationError) as caught:
			order_state.transition(
				sales_order=self.order.name,
				target_state="Cancelled",
				expected_state="Draft",  # Stale!
			)
		self.assertIn("Конфликт конкурентного обновления", str(caught.exception))

	def test_transition_and_cancellation_conflict(self):
		"""Two conflicting operations on the same order: first wins, second fails on stale expected state."""
		# Move to Lead first
		order_state.transition(
			sales_order=self.order.name,
			target_state="Lead",
		)

		# User A transitions to Measurement Pending
		res_a = order_state.transition(
			sales_order=self.order.name,
			target_state="Measurement Pending",
			expected_state="Lead",
		)
		self.assertEqual(res_a["new_state"], "Measurement Pending")

		# User B concurrently tried to cancel with expected_state='Lead'
		with self.assertRaises(frappe.ValidationError):
			order_state.transition(
				sales_order=self.order.name,
				target_state="Cancelled",
				expected_state="Lead",
			)

	def test_duplicate_production_release_is_idempotent(self):
		"""Calling transition with idempotency key multiple times returns identical result."""
		idem_key = "idem-prod-rel-" + frappe.generate_hash(length=8)

		# 1. First call transitions Draft -> Lead
		res1 = order_state_api.transition(
			sales_order=self.order.name,
			target_state="Lead",
			idempotency_key=idem_key,
		)
		self.assertEqual(res1["status"], "success")

		# 2. Duplicate concurrent/retried call with same key
		res2 = order_state_api.transition(
			sales_order=self.order.name,
			target_state="Lead",
			idempotency_key=idem_key,
		)
		self.assertEqual(res2["status"], "success")
		self.assertEqual(res2["new_state"], "Lead")

	def test_rollback_after_failed_side_effect(self):
		"""If side effect or outbox recording fails, state transition rolls back completely."""
		initial_state = frappe.db.get_value("Sales Order", self.order.name, "korkem_state")
		self.assertEqual(initial_state, "Draft")

		savepoint = "test_rollback_sp"
		frappe.db.savepoint(savepoint)

		def broken_audit(*args, **kwargs):
			raise RuntimeError("Audit disk failure simulation")

		with patch("korkem_manufacturing.services.audit.record_audit", side_effect=broken_audit):
			try:
				order_state.transition(
					sales_order=self.order.name,
					target_state="Lead",
				)
			except RuntimeError:
				frappe.db.rollback(save_point=savepoint)

		# State must remain Draft!
		curr_state = frappe.db.get_value("Sales Order", self.order.name, "korkem_state")
		self.assertEqual(curr_state, "Draft")
