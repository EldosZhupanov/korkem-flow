# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Rigorous security tests for Fail-Closed Tenant Isolation across Domain Services."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_ai.korkem_ai.tools.domain_registry import DomainToolRegistry, ToolSecurityError
from korkem_manufacturing.api import order_state as order_state_api
from korkem_manufacturing.services import automation, order_state, outbox
from korkem_manufacturing.services.scope import (
	belongs_to_company,
	enforce_tenant_scope,
	ensure_company,
)


class TestTenantIsolation(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		cls.company_a = "KORKEM"
		cls.company_b = "Мебель Тест Цех"

	def setUp(self):
		frappe.set_user("Administrator")
		frappe.defaults.set_user_default("Company", self.company_a)
		self.order_a = self._create_order(self.company_a, "Cust-A")
		self.order_b = self._create_order(self.company_b, "Cust-B")

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.defaults.set_user_default("Company", self.company_a)
		frappe.db.rollback()

	def _create_order(self, company: str, customer: str):
		wh = frappe.db.get_value("Warehouse", {"company": company}, "name")
		if not wh:
			wh = frappe.get_doc(
				{
					"doctype": "Warehouse",
					"warehouse_name": f"Stores - {company[:3]}",
					"company": company,
				}
			).insert(ignore_permissions=True).name

		doc = frappe.get_doc(
			{
				"doctype": "Sales Order",
				"company": company,
				"customer": "Павлодар Уют",
				"transaction_date": nowdate(),
				"delivery_date": add_days(nowdate(), 7),
				"korkem_state": "Draft",
				"items": [
					{
						"item_code": "ДСП 16мм",
						"qty": 1,
						"rate": 10000,
						"delivery_date": add_days(nowdate(), 7),
						"warehouse": wh,
					}
				],
			}
		)
		doc.insert(ignore_permissions=True)
		return doc

	def test_company_a_cannot_read_company_b_order(self):
		"""User scoped to Company A cannot read Company B's order: ensure_company fails closed."""
		frappe.defaults.set_user_default("Company", self.company_a)

		# Belongs to Company A?
		self.assertTrue(belongs_to_company("Sales Order", self.order_a.name))
		# Belongs to Company B? Must be False for Company A session!
		self.assertFalse(belongs_to_company("Sales Order", self.order_b.name))

		# ensure_company must raise PermissionError
		with self.assertRaises(frappe.PermissionError):
			ensure_company("Sales Order", self.order_b.name)

	def test_company_a_cannot_mutate_company_b_order(self):
		"""Attempting to transition Company B's order from Company A session must be denied."""
		frappe.defaults.set_user_default("Company", self.company_a)

		# API level check
		with self.assertRaises(frappe.PermissionError):
			order_state_api.transition(
				sales_order=self.order_b.name,
				target_state="Lead",
			)

		# Service level check
		with self.assertRaises(frappe.PermissionError):
			order_state.transition(
				sales_order=self.order_b.name,
				target_state="Lead",
			)

	def test_guessed_ids_fail_closed(self):
		"""Probing or guessing nonexistent entity IDs must fail closed, never return True."""
		guessed_id = "SAL-ORD-GUESSED-99999"
		self.assertFalse(belongs_to_company("Sales Order", guessed_id))

		with self.assertRaises(frappe.PermissionError):
			ensure_company("Sales Order", guessed_id)

	def test_enforce_tenant_scope_fail_closed_on_missing_context(self):
		"""enforce_tenant_scope raises PermissionError when company context is missing or mismatched."""
		# Missing company
		with self.assertRaises(frappe.PermissionError):
			enforce_tenant_scope("")

		# Cross-tenant mismatch
		with self.assertRaises(frappe.PermissionError):
			enforce_tenant_scope(self.company_b, caller_company=self.company_a)

	def test_ai_tool_registry_cannot_cross_tenant(self):
		"""AI tool execution fails closed if caller specifies a different company."""
		# Attempting to execute tool targeting Company B from Company A context
		with self.assertRaises(ToolSecurityError) as caught:
			DomainToolRegistry.execute(
				name="order.cancel",
				arguments={
					"sales_order": self.order_b.name,
					"reason": "Cancellation test",
					"company": self.company_b,
				},
				company=self.company_a,
			)
		self.assertIn("Cross-tenant violation", str(caught.exception))

	def test_automation_rules_cannot_cross_tenant(self):
		"""Automation engine only matches rules belonging to the event's company."""
		payload = {"sales_order": self.order_b.name, "company": self.company_b}
		# Event emitted in Company B: rules for Company A must not process it
		results = automation.process_event(
			event_name="order.ready_for_production",
			payload=payload,
			company=self.company_a,  # Caller is Company A
		)
		# Any executed action must remain bounded
		for r in results:
			self.assertNotEqual(r.get("company"), self.company_b)

	def test_outbox_event_preserves_tenant_context(self):
		"""Outbox delivery inherits company and dispatches to consumer in the same company scope."""
		event_id = outbox.record_event(
			event_name="test.tenant_event",
			aggregate_type="Sales Order",
			aggregate_id=self.order_a.name,
			payload={"sales_order": self.order_a.name},
			company=self.company_a,
		)
		delivery = frappe.get_doc("Domain Outbox Delivery", {"event_id": event_id})
		self.assertEqual(delivery.company, self.company_a)
