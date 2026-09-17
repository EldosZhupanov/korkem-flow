# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Negative security tests for Domain Tool Registry and Approval Gates (R10)."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools.domain_registry import (
	DomainToolRegistry,
	DomainToolSpec,
	QuoteSendInput,
	RiskLevel,
	ToolSecurityError,
)


class TestRegistrySecurity(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.company = "KORKEM"
		self.foreign_company = "Мебель Тест Цех"

	def tearDown(self):
		frappe.db.rollback()

	def test_call_unknown_tool_fails_closed(self):
		"""Attempting to invoke an unapproved or hallucinated tool fails closed."""
		with self.assertRaises(ToolSecurityError) as caught:
			DomainToolRegistry.execute(
				name="arbitrary_system_execute",
				arguments={"cmd": "drop database"},
				company=self.company,
			)
		self.assertIn("Unknown tool", str(caught.exception))

	def test_cross_tenant_target_fails_closed(self):
		"""Attempting to execute an operation targeting another tenant fails closed."""
		with self.assertRaises(ToolSecurityError) as caught:
			DomainToolRegistry.execute(
				name="order.cancel",
				arguments={
					"sales_order": "SO-001",
					"reason": "Security exploit attempt",
					"company": self.foreign_company,
				},
				company=self.company,
			)
		self.assertIn("Cross-tenant violation", str(caught.exception))

	def test_critical_tool_without_approval_creates_pending_action_and_stops(self):
		"""Critical write tools CANNOT execute side effects directly without human approval."""
		res = DomainToolRegistry.execute(
			name="quote.send",
			arguments={
				"quotation_id": "QTN-2026-001",
				"recipient_email": "client@example.com",
				"amount": 500000.0,
			},
			company=self.company,
		)
		self.assertFalse(res["ok"])
		self.assertEqual(res["status"], "approval_required")
		self.assertTrue(res["requires_approval"])
		action_id = res["pending_action_id"]

		# Verify a real Pending Action was created
		self.assertTrue(frappe.db.exists("Pending Action", action_id))
		doc = frappe.get_doc("Pending Action", action_id)
		self.assertEqual(doc.status, "Pending")
		self.assertIn("quote.send", doc.action_class)

	def test_negative_amounts_rejected_by_typed_schema(self):
		"""Pydantic schema validation rejects negative amounts or quantities."""
		with self.assertRaises(frappe.ValidationError):
			DomainToolRegistry.execute(
				name="payment.record",
				arguments={
					"sales_order": "SO-001",
					"amount": -15000.0,  # Negative payment forbidden!
					"reference": "fraud-attempt",
				},
				company=self.company,
			)

	def test_repeat_tool_call_is_idempotent(self):
		"""Repeated execution with same idempotency key returns cached output."""
		called = []

		# Register temporary test write tool
		class TestWriteInput(QuoteSendInput):
			pass

		spec = DomainToolSpec(
			name="test.safe_write",
			description="Safe write operation",
			risk_level=RiskLevel.REVERSIBLE_WRITE,
			input_model=TestWriteInput,
			handler=lambda **kwargs: called.append(1) or {"saved": True},
		)
		DomainToolRegistry.register(spec)

		key = "tool-idem-key-" + frappe.generate_hash(length=8)
		args = {"quotation_id": "Q-1", "recipient_email": "a@b.com", "amount": 1000.0}

		res1 = DomainToolRegistry.execute(
			name="test.safe_write",
			arguments=args,
			company=self.company,
			idempotency_key=key,
		)
		self.assertEqual(len(called), 1)

		# Second attempt with same key
		res2 = DomainToolRegistry.execute(
			name="test.safe_write",
			arguments=args,
			company=self.company,
			idempotency_key=key,
		)
		self.assertEqual(len(called), 1)  # Handler NOT called again!
		self.assertEqual(res2["data"], res1["data"])

	def test_approved_pending_action_executes_cleanly(self):
		"""When a human approves the Pending Action, tool execution proceeds."""
		executed = []

		class TestApprovalInput(QuoteSendInput):
			pass

		spec = DomainToolSpec(
			name="test.critical_with_approval",
			description="Critical operation requiring approval",
			risk_level=RiskLevel.CRITICAL_WRITE,
			input_model=TestApprovalInput,
			handler=lambda **kwargs: executed.append(kwargs["amount"]) or {"success": True},
		)
		DomainToolRegistry.register(spec)

		args = {"quotation_id": "Q-99", "recipient_email": "boss@korkem.kz", "amount": 750000.0}

		# 1. First call without approval token -> gets Pending Action
		res1 = DomainToolRegistry.execute(
			name="test.critical_with_approval",
			arguments=args,
			company=self.company,
		)
		self.assertEqual(res1["status"], "approval_required")
		action_id = res1["pending_action_id"]

		# 2. Human supervisor approves the Pending Action
		frappe.db.set_value("Pending Action", action_id, "status", "Approved")

		# 3. Execution with valid approval token proceeds!
		res2 = DomainToolRegistry.execute(
			name="test.critical_with_approval",
			arguments=args,
			company=self.company,
			approval_token=action_id,
		)
		self.assertTrue(res2["ok"])
		self.assertEqual(len(executed), 1)
		self.assertEqual(executed[0], 750000.0)
