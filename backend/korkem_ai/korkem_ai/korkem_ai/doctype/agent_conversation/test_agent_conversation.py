# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase

#: `Agent Conversation.user` and `Pending Action.resolved_by` are Links to
#: `User`, but no test here uses a generated user — they all pass
#: "Administrator", which exists on every Frappe site by construction.
#:
#: Left undeclared, the dependency walk goes User -> Email Account -> Company,
#: and loading Company's *test* module imports `erpnext/tests/utils.py`, which
#: runs `BootStrapTestData()` at import time. Its price-list guard matches on
#: five fields including `currency="INR"` while `Price List` autonames from
#: `price_list_name` alone — so on this Kazakh site, where Standard Buying is
#: in KZT, the guard finds nothing and the insert collides on the primary key.
#: Every suite reaching Company then died in setUpClass, on a clean volume,
#: before its first assertion.
#:
#: This states a fact about these tests rather than suppressing that error.
#: See `korkem_ai/korkem_ai/test_fixture_isolation.py`, which fails if a new
#: Link field reopens the path.
IGNORE_TEST_RECORD_DEPENDENCIES = ["User"]


class TestAgentConversation(IntegrationTestCase):
	def tearDown(self) -> None:
		frappe.db.rollback()

	def test_conversation_creation_defaults(self):
		conversation = frappe.get_doc(
			{
				"doctype": "Agent Conversation",
				"user": "Administrator",
				"channel": "WhatsApp",
			}
		).insert()

		self.assertTrue(conversation.name)
		self.assertEqual(conversation.status, "Active")
		self.assertTrue(conversation.started_on)

	def test_add_message_creates_linked_message(self):
		conversation = frappe.get_doc(
			{
				"doctype": "Agent Conversation",
				"user": "Administrator",
				"channel": "Web",
			}
		).insert()

		message = conversation.add_message("User", "Hello, I need a quote for a kitchen facade.")

		self.assertEqual(message.conversation, conversation.name)
		self.assertEqual(message.sender, "User")
		self.assertEqual(
			frappe.db.count("Agent Conversation Message", {"conversation": conversation.name}), 1
		)

	def test_add_message_rejects_invalid_sender(self):
		conversation = frappe.get_doc(
			{
				"doctype": "Agent Conversation",
				"user": "Administrator",
				"channel": "Web",
			}
		).insert()

		with self.assertRaises(frappe.ValidationError):
			conversation.add_message("Nobody", "This should fail")

	def test_close(self):
		conversation = frappe.get_doc(
			{
				"doctype": "Agent Conversation",
				"user": "Administrator",
				"channel": "Web",
			}
		).insert()

		conversation.close()
		conversation.reload()
		self.assertEqual(conversation.status, "Closed")

	def test_requires_user_or_contact_phone(self):
		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc({"doctype": "Agent Conversation", "channel": "WhatsApp"}).insert()

	def test_contact_phone_without_user_is_valid(self):
		conversation = frappe.get_doc(
			{
				"doctype": "Agent Conversation",
				"contact_phone": "+77011234567",
				"channel": "WhatsApp",
			}
		).insert()

		self.assertFalse(conversation.user)
		self.assertEqual(conversation.contact_phone, "+77011234567")

	def test_get_or_create_for_contact_reuses_active_conversation(self):
		from korkem_ai.korkem_ai.doctype.agent_conversation.agent_conversation import (
			AgentConversation,
		)

		first = AgentConversation.get_or_create_for_contact("+77019998877")
		second = AgentConversation.get_or_create_for_contact("+77019998877")

		self.assertEqual(first.name, second.name)

	def test_get_or_create_for_contact_starts_new_after_close(self):
		from korkem_ai.korkem_ai.doctype.agent_conversation.agent_conversation import (
			AgentConversation,
		)

		first = AgentConversation.get_or_create_for_contact("+77015554433")
		first.close()

		second = AgentConversation.get_or_create_for_contact("+77015554433")

		self.assertNotEqual(first.name, second.name)
