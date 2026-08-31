# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document


class AgentConversation(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		channel: DF.Literal["Web", "WhatsApp", "Telegram"]
		contact_phone: DF.Data | None
		started_on: DF.Datetime | None
		status: DF.Literal["Active", "Closed"]
		user: DF.Link | None
	# end: auto-generated types

	def validate(self):
		# A conversation has to be identifiable, and there are now three ways to
		# be: a signed-in user, a phone number, or the channel's own chat id.
		# The third was added when Telegram arrived — a Telegram sender has no
		# phone at all, and an unlinked one has no user either, so a rule
		# written when WhatsApp was the only channel refused to record that
		# somebody unknown had written in. Which is exactly the case an
		# administrator needs to see.
		if not self.user and not self.contact_phone and not self.external_chat_id:
			frappe.throw(
				"Agent Conversation requires a User, a Contact Phone, or an External Chat ID"
			)

	def add_message(self, sender: str, content: str):
		"""Append a message to this conversation and return the created record."""
		if sender not in ("User", "Agent", "System"):
			frappe.throw(f"Invalid message sender: {sender}")

		message = frappe.get_doc(
			{
				"doctype": "Agent Conversation Message",
				"conversation": self.name,
				"sender": sender,
				"content": content,
			}
		)
		message.insert(ignore_permissions=True)
		return message

	def close(self):
		self.status = "Closed"
		self.save()

	@staticmethod
	def get_or_create_for_contact(contact_phone: str, channel: str = "WhatsApp"):
		"""Find the active conversation for an external (non-Frappe-User) sender on the
		given channel, or start a new one. Used by channel integrations (e.g. WhatsApp)
		where the sender has no Frappe User account.
		"""
		existing = frappe.get_all(
			"Agent Conversation",
			filters={"contact_phone": contact_phone, "channel": channel, "status": "Active"},
			order_by="started_on desc",
			limit=1,
			pluck="name",
		)
		if existing:
			return frappe.get_doc("Agent Conversation", existing[0])

		conversation = frappe.get_doc(
			{
				"doctype": "Agent Conversation",
				"contact_phone": contact_phone,
				"channel": channel,
			}
		)
		conversation.insert(ignore_permissions=True)
		return conversation
