# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.agents import production_agent, sales_agent


class TestProductionAgent(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		from korkem_manufacturing import setup

		setup.provision()

	def tearDown(self):
		frappe.db.rollback()

	def _deal(self, organization_name="Production Buyer LLC"):
		organization = sales_agent.find_or_create_organization(organization_name)
		return sales_agent.create_deal(organization=organization, product_description="facades")

	# --- proposal ---

	def test_proposal_targets_the_deal(self):
		"""Anchoring to the Deal is what makes invariant-9 re-validation meaningful."""
		deal = self._deal()

		action = production_agent.propose_production_order(deal=deal, qty=4)

		self.assertEqual(action.entity_type, "CRM Deal")
		self.assertEqual(action.entity_name, deal)
		self.assertEqual(action.status, "Pending")
		data = frappe.parse_json(action.action_data)
		self.assertEqual(data["deal"], deal)
		self.assertEqual(data["qty"], 4)

	def test_proposal_is_human_readable(self):
		deal = self._deal()

		action = production_agent.propose_production_order(deal=deal)

		display = frappe.parse_json(action.display_data)
		self.assertIn("Production Buyer LLC", display["summary"])

	def test_nothing_is_manufactured_before_approval(self):
		deal = self._deal()

		production_agent.propose_production_order(deal=deal)

		self.assertFalse(frappe.db.exists("Work Order", {"originating_deal": deal}))

	# --- approval ---

	def test_approval_creates_work_order_and_task(self):
		deal = self._deal()
		action = production_agent.propose_production_order(deal=deal, qty=2)

		action.approve()

		result = frappe.parse_json(action.result_data)
		work_order = frappe.get_doc("Work Order", result["work_order"])
		self.assertEqual(work_order.originating_deal, deal)
		self.assertEqual(work_order.qty, 2)
		self.assertEqual(work_order.docstatus, 1)

		task = frappe.get_doc("CRM Task", result["task"])
		self.assertEqual(task.reference_docname, work_order.name)

	def test_rejection_manufactures_nothing(self):
		deal = self._deal()
		action = production_agent.propose_production_order(deal=deal)

		action.reject(reason="Customer not yet paid deposit")

		self.assertFalse(frappe.db.exists("Work Order", {"originating_deal": deal}))
		action.reload()
		self.assertEqual(action.status, "Rejected")

	def test_approval_blocked_when_deal_deleted(self):
		"""Invariant 9: a stale proposal must not succeed against a vanished target."""
		deal = self._deal()
		action = production_agent.propose_production_order(deal=deal)
		frappe.delete_doc("CRM Deal", deal, force=True, ignore_permissions=True)

		with self.assertRaises(frappe.exceptions.ValidationError):
			action.approve()

	# --- chaining from the sales gate ---

	def test_quote_approval_raises_a_production_proposal(self):
		"""The two gates must chain: approving a quote proposes production next."""
		conversation = frappe.get_doc(
			{"doctype": "Agent Conversation", "contact_phone": "77015554433", "channel": "WhatsApp"}
		).insert()
		quote_action = sales_agent.handle_inquiry(
			conversation.name,
			{
				"intent": "new_order_inquiry",
				"customer_name": "Chained Customer LLC",
				"product_description": "kitchen facades",
				"quantity": 6,
			},
		)

		quote_action.approve()

		result = frappe.parse_json(quote_action.result_data)
		proposal = frappe.get_doc("Pending Action", result["production_proposal"])
		self.assertEqual(proposal.status, "Pending")
		self.assertEqual(proposal.entity_name, result["deal"])
		self.assertEqual(proposal.agent_skill, production_agent.SKILL_NAME)
		# Quantity must carry through from the original customer message.
		self.assertEqual(frappe.parse_json(proposal.action_data)["qty"], 6)
		# Still nothing manufactured -- production needs its own approval.
		self.assertFalse(frappe.db.exists("Work Order", {"originating_deal": result["deal"]}))
