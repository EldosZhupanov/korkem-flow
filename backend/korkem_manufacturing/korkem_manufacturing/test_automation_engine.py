# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Unit tests for KORKEM Automation Engine."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import automation


class TestAutomationEngine(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")

	def tearDown(self):
		frappe.db.rollback()

	def test_condition_evaluator_leaf_operators(self):
		payload = {"amount": 150000, "status": "Ready", "items": ["Board", "Edge"]}

		# Equal
		self.assertTrue(automation.evaluate_condition({"field": "status", "op": "==", "value": "Ready"}, payload))
		self.assertFalse(automation.evaluate_condition({"field": "status", "op": "==", "value": "Draft"}, payload))

		# Comparison
		self.assertTrue(automation.evaluate_condition({"field": "amount", "op": ">=", "value": 100000}, payload))
		self.assertTrue(automation.evaluate_condition({"field": "amount", "op": ">", "value": 50000}, payload))
		self.assertFalse(automation.evaluate_condition({"field": "amount", "op": "<", "value": 100000}, payload))

		# In & contains
		self.assertTrue(automation.evaluate_condition({"field": "status", "op": "in", "value": ["Ready", "Approved"]}, payload))
		self.assertTrue(automation.evaluate_condition({"field": "items", "op": "contains", "value": "Board"}, payload))
		self.assertFalse(automation.evaluate_condition({"field": "items", "op": "contains", "value": "Hinge"}, payload))

		# is_set
		self.assertTrue(automation.evaluate_condition({"field": "amount", "op": "is_set"}, payload))
		self.assertFalse(automation.evaluate_condition({"field": "non_existing", "op": "is_set"}, payload))

	def test_compound_conditions(self):
		payload = {"role": "Designer", "rating": 5, "active": True}

		# AND
		cond_and = {
			"and": [
				{"field": "role", "op": "==", "value": "Designer"},
				{"field": "rating", "op": ">=", "value": 4},
			]
		}
		self.assertTrue(automation.evaluate_condition(cond_and, payload))

		# OR
		cond_or = {
			"or": [
				{"field": "role", "op": "==", "value": "Manager"},
				{"field": "rating", "op": ">=", "value": 5},
			]
		}
		self.assertTrue(automation.evaluate_condition(cond_or, payload))

		# NOT
		cond_not = {"not": {"field": "role", "op": "==", "value": "Installer"}}
		self.assertTrue(automation.evaluate_condition(cond_not, payload))

	def test_parameter_templating(self):
		payload = {"order_id": "ORD-999", "client": "Алихан"}
		params = {"sales_order": "{{order_id}}", "prefix": "Order for: {{client}}", "static": 123}
		resolved = automation._resolve_params(params, payload)
		self.assertEqual(resolved["sales_order"], "ORD-999")
		self.assertEqual(resolved["static"], 123)

	def test_recursion_guard(self):
		results = automation.process_event(
			event_name="test.recursive_event",
			payload={},
			company="KORKEM",
			depth=4,  # Exceeds max depth 3
		)
		self.assertEqual(len(results), 1)
		self.assertEqual(results[0]["status"], "SKIPPED")
		self.assertIn("recursion", results[0]["reason"].lower())

	def test_action_execution_audit_record(self):
		action = {
			"type": "audit.record",
			"params": {
				"action": "automation.test_action",
				"entity_type": "TestDoc",
				"entity_id": "{{id}}",
			},
		}
		payload = {"id": "TEST-001"}
		res = automation.execute_action(action, payload, company="KORKEM")
		self.assertEqual(res["status"], "audit_recorded")
