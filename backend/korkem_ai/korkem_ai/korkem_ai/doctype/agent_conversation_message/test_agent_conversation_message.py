# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase


class TestAgentConversationMessage(IntegrationTestCase):
	def tearDown(self) -> None:
		frappe.db.rollback()

	def test_message_creation(self):
		conversation = frappe.get_doc(
			{"doctype": "Agent Conversation", "user": "Administrator", "channel": "Web"}
		).insert()

		message = frappe.get_doc(
			{
				"doctype": "Agent Conversation Message",
				"conversation": conversation.name,
				"sender": "Agent",
				"content": "How can I help today?",
			}
		).insert()

		self.assertTrue(message.name)
		self.assertTrue(message.sent_at)

	def test_message_requires_conversation(self):
		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc(
				{
					"doctype": "Agent Conversation Message",
					"sender": "Agent",
					"content": "Orphan message",
				}
			).insert()
