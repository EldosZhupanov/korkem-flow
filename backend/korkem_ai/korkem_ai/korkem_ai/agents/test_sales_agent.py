# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.agents import sales_agent


class TestSalesAgent(IntegrationTestCase):
	def tearDown(self):
		frappe.db.rollback()

	def _conversation(self, phone="77011234567"):
		return frappe.get_doc(
			{"doctype": "Agent Conversation", "contact_phone": phone, "channel": "WhatsApp"}
		).insert()

	def _intent(self, **overrides):
		data = {
			"intent": "new_order_inquiry",
			"customer_name": "Altay Sadykov",
			"product_description": "kitchen facades",
			"quantity": 12,
		}
		data.update(overrides)
		return data

	# --- proposal ---

	def test_proposal_carries_extracted_details(self):
		conversation = self._conversation()

		action = sales_agent.handle_inquiry(conversation.name, self._intent())

		data = frappe.parse_json(action.action_data)
		self.assertEqual(data["organization_name"], "Altay Sadykov")
		self.assertEqual(data["product_description"], "kitchen facades")
		self.assertEqual(data["quantity"], 12)
		self.assertEqual(data["contact_phone"], "77011234567")

	def test_proposal_has_human_readable_display_data(self):
		"""ADR-0014/0015: the approver must see what will change."""
		conversation = self._conversation()

		action = sales_agent.handle_inquiry(conversation.name, self._intent())

		display = frappe.parse_json(action.display_data)
		self.assertIn("Altay Sadykov", display["summary"])
		self.assertTrue(any(c["field"] == "Customer" for c in display["changes"]))

	def test_falls_back_to_phone_when_no_name_given(self):
		"""Never invent a customer name."""
		conversation = self._conversation(phone="77019998877")

		action = sales_agent.handle_inquiry(conversation.name, self._intent(customer_name=None))

		data = frappe.parse_json(action.action_data)
		self.assertEqual(data["organization_name"], "WhatsApp 77019998877")

	def test_handles_missing_product_description(self):
		conversation = self._conversation()

		action = sales_agent.handle_inquiry(
			conversation.name, self._intent(product_description=None)
		)

		data = frappe.parse_json(action.action_data)
		self.assertEqual(data["product_description"], "Unspecified furniture")

	# --- execution on approval ---

	def test_approval_creates_organization_and_deal(self):
		conversation = self._conversation()
		action = sales_agent.handle_inquiry(conversation.name, self._intent())

		action.approve()

		result = frappe.parse_json(action.result_data)
		self.assertEqual(result["organization"], "Altay Sadykov")
		self.assertTrue(frappe.db.exists("CRM Organization", "Altay Sadykov"))

		deal = frappe.get_doc("CRM Deal", result["deal"])
		self.assertEqual(deal.organization, "Altay Sadykov")
		self.assertEqual(deal.status, sales_agent.QUOTED_STATUS)
		self.assertEqual(deal.mobile_no, "77011234567")
		self.assertIn("kitchen facades", deal.next_step)
		self.assertIn("12", deal.next_step)

	def test_approval_reuses_existing_organization(self):
		"""A repeat customer must not get a duplicate record."""
		existing = frappe.get_doc(
			{"doctype": "CRM Organization", "organization_name": "Repeat Customer LLC"}
		).insert()

		conversation = self._conversation()
		action = sales_agent.handle_inquiry(
			conversation.name, self._intent(customer_name="Repeat Customer LLC")
		)
		action.approve()

		self.assertEqual(
			frappe.db.count("CRM Organization", {"organization_name": "Repeat Customer LLC"}), 1
		)
		result = frappe.parse_json(action.result_data)
		self.assertEqual(result["organization"], existing.name)

	def test_approval_logs_outcome_to_conversation(self):
		conversation = self._conversation()
		action = sales_agent.handle_inquiry(conversation.name, self._intent())

		action.approve()

		messages = frappe.get_all(
			"Agent Conversation Message",
			filters={"conversation": conversation.name},
			fields=["content"],
		)
		self.assertTrue(any("Quote created" in m.content for m in messages))

	def test_rejection_creates_nothing(self):
		conversation = self._conversation()
		action = sales_agent.handle_inquiry(
			conversation.name, self._intent(customer_name="Rejected Customer LLC")
		)

		action.reject(reason="Spam")

		self.assertFalse(frappe.db.exists("CRM Organization", "Rejected Customer LLC"))
		action.reload()
		self.assertEqual(action.status, "Rejected")
