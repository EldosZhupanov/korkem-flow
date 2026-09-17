# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Integrity and tamper-resistance tests for Domain Audit Trail."""

from __future__ import annotations

import json

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import audit


class TestAuditIntegrity(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.company = "KORKEM"

	def tearDown(self):
		frappe.db.rollback()

	def test_audit_event_is_append_only_prevent_update(self):
		"""Existing audit event cannot be modified via document save."""
		event_id = audit.record_audit(
			action="order.state_transition",
			entity_type="Sales Order",
			entity_id="SO-AUDIT-001",
			diff={"from": "Draft", "to": "Lead"},
			company=self.company,
		)
		self.assertTrue(frappe.db.exists("Domain Audit Event", event_id))

		doc = frappe.get_doc("Domain Audit Event", event_id)
		doc.reason = "Tampered reason by unauthorized party"

		with self.assertRaises(frappe.PermissionError) as caught:
			doc.save()
		self.assertIn("append-only", str(caught.exception).lower())

	def test_audit_event_is_immutable_prevent_delete(self):
		"""Audit event cannot be deleted via document delete."""
		event_id = audit.record_audit(
			action="payment.recorded",
			entity_type="Sales Order",
			entity_id="SO-AUDIT-002",
			diff={"amount": 100000},
			company=self.company,
		)
		doc = frappe.get_doc("Domain Audit Event", event_id)

		with self.assertRaises(frappe.PermissionError) as caught:
			doc.delete()
		self.assertIn("immutable", str(caught.exception).lower())

	def test_all_audit_fields_captured_faithfully(self):
		"""All required audit dimensions are captured accurately."""
		diff_payload = {"old_price": 50000, "new_price": 45000}
		event_id = audit.record_audit(
			action="pricing.override",
			entity_type="Sales Order",
			entity_id="SO-AUDIT-003",
			diff=diff_payload,
			reason="Client loyalty discount",
			channel="DesktopUI",
			correlation_id="corr-xyz-123",
			trace_id="trace-ai-888",
			company=self.company,
			actor="Administrator",
		)
		doc = frappe.get_doc("Domain Audit Event", event_id)

		self.assertEqual(doc.action, "pricing.override")
		self.assertEqual(doc.company, self.company)
		self.assertEqual(doc.entity_type, "Sales Order")
		self.assertEqual(doc.entity_id, "SO-AUDIT-003")
		self.assertEqual(doc.actor, "Administrator")
		self.assertEqual(doc.channel, "DesktopUI")
		self.assertEqual(doc.reason, "Client loyalty discount")
		self.assertEqual(doc.correlation_id, "corr-xyz-123")
		self.assertEqual(doc.trace_id, "trace-ai-888")
		self.assertEqual(json.loads(doc.diff_json), diff_payload)
		self.assertIsNotNone(doc.creation)
