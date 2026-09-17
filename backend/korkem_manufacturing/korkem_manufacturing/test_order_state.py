# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Unit and integration tests for Canonical Order State Machine & API."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing import setup
from korkem_manufacturing.api import order_state as api
from korkem_manufacturing.services import order_state


class TestOrderStateGraph(IntegrationTestCase):
	"""Verify structure and completeness of canonical state machine graph."""

	def test_all_20_states_defined(self):
		self.assertEqual(len(order_state.ALL_STATES), 20)
		self.assertIn("Draft", order_state.ALL_STATES)
		self.assertIn("Lead", order_state.ALL_STATES)
		self.assertIn("Measurement Pending", order_state.ALL_STATES)
		self.assertIn("Measured", order_state.ALL_STATES)
		self.assertIn("Design Pending", order_state.ALL_STATES)
		self.assertIn("Design Approved", order_state.ALL_STATES)
		self.assertIn("Quote Pending", order_state.ALL_STATES)
		self.assertIn("Quote Sent", order_state.ALL_STATES)
		self.assertIn("Contract Pending", order_state.ALL_STATES)
		self.assertIn("Deposit Pending", order_state.ALL_STATES)
		self.assertIn("Ready for Production", order_state.ALL_STATES)
		self.assertIn("In Production", order_state.ALL_STATES)
		self.assertIn("Quality Control", order_state.ALL_STATES)
		self.assertIn("Ready for Delivery", order_state.ALL_STATES)
		self.assertIn("Delivery", order_state.ALL_STATES)
		self.assertIn("Installation", order_state.ALL_STATES)
		self.assertIn("Acceptance Pending", order_state.ALL_STATES)
		self.assertIn("Completed", order_state.ALL_STATES)
		self.assertIn("Warranty", order_state.ALL_STATES)
		self.assertIn("Cancelled", order_state.ALL_STATES)

	def test_cancelled_is_terminal(self):
		self.assertEqual(order_state.ALLOWED_TRANSITIONS[order_state.CANCELLED], set())

	def test_draft_transitions(self):
		self.assertEqual(
			order_state.ALLOWED_TRANSITIONS[order_state.DRAFT],
			{order_state.LEAD, order_state.CANCELLED},
		)


class TestOrderStateExecution(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		setup.provision()

	def setUp(self):
		frappe.set_user("Administrator")
		self.order = self._create_test_order()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def _create_test_order(self):
		# Look for existing seeded order or create draft
		name = frappe.db.get_value("Sales Order", {"company": "KORKEM", "docstatus": 0}, "name")
		if not name:
			name = frappe.db.get_value("Sales Order", {"company": "KORKEM", "docstatus": 1}, "name")
			if name:
				doc = frappe.copy_doc(frappe.get_doc("Sales Order", name))
				doc.docstatus = 0
				doc.transaction_date = nowdate()
				doc.delivery_date = add_days(nowdate(), 14)
				doc.korkem_state = order_state.DRAFT
				doc.insert(ignore_permissions=True)
				return doc
		doc = frappe.get_doc("Sales Order", name)
		doc.db_set("korkem_state", order_state.DRAFT)
		return doc

	def test_get_order_state(self):
		state_info = order_state.get_order_state(self.order.name)
		self.assertEqual(state_info["sales_order"], self.order.name)
		self.assertEqual(state_info["current_state"], order_state.DRAFT)
		self.assertIn(order_state.LEAD, state_info["allowed_next_states"])
		self.assertIn(order_state.CANCELLED, state_info["allowed_next_states"])

	def test_can_transition_validation(self):
		# Valid transition: Draft -> Lead
		ok, reason = order_state.can_transition(self.order.name, order_state.LEAD)
		self.assertTrue(ok)
		self.assertIsNone(reason)

		# Invalid transition: Draft -> Completed (cannot jump across lifecycle)
		ok, reason = order_state.can_transition(self.order.name, order_state.COMPLETED)
		self.assertFalse(ok)
		self.assertIn("недопустим по технологическому графу", reason)

	def test_transition_executes_and_logs(self):
		# Transition Draft -> Lead
		res = order_state.transition(
			sales_order=self.order.name,
			target_state=order_state.LEAD,
			reason="Client qualified via call",
			channel="Test",
		)
		self.assertEqual(res["status"], "success")
		self.assertEqual(res["new_state"], order_state.LEAD)

		# Check DB updated
		curr_db_state = frappe.db.get_value("Sales Order", self.order.name, "korkem_state")
		self.assertEqual(curr_db_state, order_state.LEAD)

		# Check Order State Log
		logs = frappe.get_all(
			"Order State Log",
			filters={"sales_order": self.order.name, "to_state": order_state.LEAD},
			fields=["from_state", "to_state", "reason"],
		)
		self.assertTrue(len(logs) > 0)
		self.assertEqual(logs[0].from_state, order_state.DRAFT)
		self.assertEqual(logs[0].to_state, order_state.LEAD)

		# Check Domain Audit Event
		audits = frappe.get_all(
			"Domain Audit Event",
			filters={"entity_id": self.order.name, "action": "order.state_transition"},
		)
		self.assertTrue(len(audits) > 0)

		# Check Transactional Outbox Event
		outbox_events = frappe.get_all(
			"Domain Outbox Event",
			filters={"aggregate_id": self.order.name, "event_name": "order.lead"},
		)
		self.assertTrue(len(outbox_events) > 0)

	def test_list_available_transitions(self):
		transitions = order_state.list_available_transitions(self.order.name)
		targets = [t["target_state"] for t in transitions]
		self.assertIn(order_state.LEAD, targets)
		self.assertIn(order_state.CANCELLED, targets)
		for t in transitions:
			if t["target_state"] == order_state.LEAD:
				self.assertTrue(t["available"])

	def test_api_endpoints_and_idempotency(self):
		# 1. API get_state
		state_res = api.get_state(self.order.name)
		self.assertEqual(state_res["sales_order"], self.order.name)

		# 2. API list_available_transitions
		list_res = api.list_available_transitions(self.order.name)
		self.assertTrue(len(list_res) >= 2)

		# 3. API transition with idempotency key
		idem_key = "test-trans-idem-" + frappe.generate_hash(length=8)
		first = api.transition(
			sales_order=self.order.name,
			target_state=order_state.LEAD,
			reason="First attempt",
			idempotency_key=idem_key,
		)
		self.assertEqual(first["status"], "success")

		# Repeated call with same idempotency key
		second = api.transition(
			sales_order=self.order.name,
			target_state=order_state.LEAD,
			reason="First attempt",
			idempotency_key=idem_key,
		)
		self.assertEqual(second["status"], "success")
		self.assertEqual(second["new_state"], first["new_state"])
