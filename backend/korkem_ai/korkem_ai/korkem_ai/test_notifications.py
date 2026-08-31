# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import notifications
from korkem_ai.korkem_ai.agents import sales_agent

CUSTOMER_PHONE = "77012223344"


class TestNotifications(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		from korkem_manufacturing import setup

		setup.provision()

	def tearDown(self):
		frappe.db.rollback()

	def _deal(self, phone=CUSTOMER_PHONE, organization_name="Notified Customer LLC"):
		organization = sales_agent.find_or_create_organization(organization_name)
		return sales_agent.create_deal(
			organization=organization, product_description="facades", contact_phone=phone
		)

	def _order(self, deal):
		from korkem_manufacturing import production

		return production.create_production_order_for_deal(deal=deal)

	# --- addressing ---

	def test_finds_customer_phone_through_the_deal(self):
		deal = self._deal()

		self.assertEqual(notifications.get_customer_phone(deal), CUSTOMER_PHONE)

	def test_message_names_the_customer_and_the_order(self):
		deal = self._deal()
		result = self._order(deal)

		message = notifications.build_completion_message(result["work_order"], deal)

		self.assertIn("Notified Customer LLC", message)
		self.assertIn(result["work_order"], message)
		self.assertIn("Kitchen Facade", message)

	# --- sending ---

	def test_completion_sends_whatsapp_to_the_customer(self):
		from korkem_manufacturing import shop_floor

		deal = self._deal()
		result = self._order(deal)

		with patch.object(notifications.whatsapp, "queue_send_message") as send:
			shop_floor.complete_task(result["task"])

		send.assert_called_once()
		to, body = send.call_args.args if send.call_args.args else (
			send.call_args.kwargs["to"],
			send.call_args.kwargs["body"],
		)
		self.assertEqual(to, CUSTOMER_PHONE)
		self.assertIn(result["work_order"], body)

	def test_notification_is_logged_to_the_conversation(self):
		from korkem_manufacturing import shop_floor

		deal = self._deal()
		result = self._order(deal)

		with patch.object(notifications.whatsapp, "queue_send_message"):
			shop_floor.complete_task(result["task"])

		conversation = frappe.get_all(
			"Agent Conversation", filters={"contact_phone": CUSTOMER_PHONE}, pluck="name"
		)
		self.assertTrue(conversation)
		messages = frappe.get_all(
			"Agent Conversation Message",
			filters={"conversation": conversation[0]},
			fields=["content"],
		)
		self.assertTrue(any("finished production" in m.content for m in messages))

	# --- the quiet cases ---

	def test_work_order_without_a_deal_notifies_nobody(self):
		"""A Work Order made by hand in the Desk is legitimate, not an error."""
		from korkem_manufacturing import production

		work_order = frappe.get_doc("Work Order", production.create_production_order(deal=self._deal()))
		work_order.db_set("originating_deal", None)

		with patch.object(notifications.whatsapp, "queue_send_message") as send:
			result = notifications.notify_customer_of_completion(work_order.name)

		self.assertIsNone(result)
		send.assert_not_called()

	def test_deal_without_a_phone_does_not_break_completion(self):
		from korkem_manufacturing import shop_floor

		deal = self._deal(phone=None, organization_name="Phoneless Customer LLC")
		result = self._order(deal)

		with patch.object(notifications.whatsapp, "queue_send_message") as send:
			shop_floor.complete_task(result["task"])  # must not raise

		send.assert_not_called()
		self.assertEqual(frappe.db.get_value("CRM Task", result["task"], "status"), "Done")

	def test_unfinished_task_notifies_nobody(self):
		deal = self._deal()
		result = self._order(deal)

		with patch.object(notifications.whatsapp, "queue_send_message") as send:
			task = frappe.get_doc("CRM Task", result["task"])
			task.status = "In Progress"
			task.save()

		send.assert_not_called()
