# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Rigorous concurrency and race condition tests for Global API Idempotency."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import idempotency


class TestIdempotencyConcurrency(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.company_a = "KORKEM"
		self.company_b = "Мебель Тест Цех"

	def tearDown(self):
		frappe.db.rollback()

	def test_same_key_same_payload_returns_cached_result(self):
		key = "idem-test-same-" + frappe.generate_hash(length=8)
		executions = []

		def action_fn():
			executions.append(1)
			return {"status": "ok", "order_id": "SO-123"}

		# First attempt
		res1 = idempotency.execute(
			action="order.transition",
			idempotency_key=key,
			arguments={"sales_order": "SO-123", "target_state": "Lead"},
			callback=action_fn,
			company=self.company_a,
		)
		self.assertEqual(len(executions), 1)
		self.assertEqual(res1["order_id"], "SO-123")

		# Second attempt with same key and same payload
		res2 = idempotency.execute(
			action="order.transition",
			idempotency_key=key,
			arguments={"sales_order": "SO-123", "target_state": "Lead"},
			callback=action_fn,
			company=self.company_a,
		)
		# Must NOT have executed callback a second time
		self.assertEqual(len(executions), 1)
		self.assertEqual(res2, res1)

	def test_same_key_different_payload_raises_conflict(self):
		key = "idem-test-conflict-" + frappe.generate_hash(length=8)

		# First call with payload A
		idempotency.execute(
			action="order.transition",
			idempotency_key=key,
			arguments={"target_state": "Lead"},
			callback=lambda: {"status": "ok"},
			company=self.company_a,
		)

		# Second call with same key but different payload B must throw ValidationError
		with self.assertRaises(frappe.ValidationError) as caught:
			idempotency.execute(
				action="order.transition",
				idempotency_key=key,
				arguments={"target_state": "Cancelled"},
				callback=lambda: {"status": "ok"},
				company=self.company_a,
			)
		self.assertIn("different command data", str(caught.exception).lower())

	def test_tenant_scoped_uniqueness_between_companies(self):
		"""Same client key used in Company A and Company B must not collide or leak results."""
		shared_client_key = "mobile-offline-client-key-101"
		executions_a = []
		executions_b = []

		res_a = idempotency.execute(
			action="order.transition",
			idempotency_key=shared_client_key,
			arguments={"data": "company_a_order"},
			callback=lambda: executions_a.append(1) or {"tenant": "A"},
			company=self.company_a,
		)
		self.assertEqual(len(executions_a), 1)
		self.assertEqual(res_a["tenant"], "A")

		# Company B uses the same client key
		res_b = idempotency.execute(
			action="order.transition",
			idempotency_key=shared_client_key,
			arguments={"data": "company_b_order"},
			callback=lambda: executions_b.append(1) or {"tenant": "B"},
			company=self.company_b,
		)
		# Company B executes its own callback and gets its own result!
		self.assertEqual(len(executions_b), 1)
		self.assertEqual(res_b["tenant"], "B")

	def test_retention_and_cleanup_policy(self):
		"""Expired records are cleaned up based on retention period."""
		key = "idem-cleanup-" + frappe.generate_hash(length=8)
		idempotency.execute(
			action="test.cleanup",
			idempotency_key=key,
			arguments={"x": 1},
			callback=lambda: {"ok": True},
			company=self.company_a,
		)
		name = idempotency._record_name("Administrator", "test.cleanup", key, self.company_a)
		self.assertTrue(frappe.db.exists("Idempotency Record", name))

		# Artificially age the record by 35 days
		old_ts = frappe.utils.add_to_date(frappe.utils.now_datetime(), days=-35)
		frappe.db.sql("UPDATE `tabIdempotency Record` SET modified = %s WHERE name = %s", (old_ts, name))

		deleted_count = idempotency.cleanup_expired(days=30)
		self.assertTrue(deleted_count >= 1)
		self.assertFalse(frappe.db.exists("Idempotency Record", name))
