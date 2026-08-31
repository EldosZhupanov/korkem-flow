# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Customer notification on production progress.

Closes the Sprint 1 loop: the customer who messaged on WhatsApp is told when
their order is built. Reaching them means walking the chain the earlier phases
established -- Task -> Work Order -> originating Deal -> Contact -> phone.

This lives in korkem_ai because it is an outbound-channel concern (ADR-0011:
integrations go through gateways). korkem_manufacturing hooks the same doctype
for its own shop-floor concerns; neither app imports the other.
"""

import frappe

from korkem_ai.korkem_ai.integrations import whatsapp

DONE = "Done"


def on_task_update(doc, method=None):
	"""doc_events hook: notify the customer when their production task is done."""
	if doc.reference_doctype != "Work Order" or not doc.reference_docname:
		return
	if doc.status != DONE or not doc.has_value_changed("status"):
		return

	notify_customer_of_completion(doc.reference_docname)


def notify_customer_of_completion(work_order: str) -> str | None:
	"""Send the order-ready message. Returns the phone notified, or None.

	Returns None rather than raising when there is nobody to notify: a Work Order
	created by hand in the Desk has no originating deal, and that is a legitimate
	state, not an error that should fail the worker's save.
	"""
	deal = frappe.db.get_value("Work Order", work_order, "originating_deal")
	if not deal:
		return None

	phone = get_customer_phone(deal)
	if not phone:
		frappe.log_error(
			title="Production notification skipped",
			message=f"Work Order {work_order} (deal {deal}) has no contact phone to notify.",
		)
		return None

	whatsapp.queue_send_message(phone, build_completion_message(work_order, deal))
	log_to_conversation(phone, work_order)
	return phone


def get_customer_phone(deal: str) -> str | None:
	"""The deal's primary contact phone.

	CRM Deal.mobile_no is derived from the primary row of the `contacts` child
	table on validate(), so reading the stored field is correct here and avoids
	re-walking the child table.
	"""
	return frappe.db.get_value("CRM Deal", deal, "mobile_no")


def build_completion_message(work_order: str, deal: str) -> str:
	organization = frappe.db.get_value("CRM Deal", deal, "organization") or "there"
	item = frappe.db.get_value("Work Order", work_order, "production_item")
	return (
		f"Hello {organization}! Your order is ready. "
		f"{item} (order {work_order}) has finished production. "
		"We will contact you shortly to arrange delivery."
	)


def log_to_conversation(phone: str, work_order: str):
	"""Record the outbound notification on the customer's conversation thread.

	Keeps the conversation a complete record of what the customer was told --
	without it the thread would show only inbound messages.
	"""
	from korkem_ai.korkem_ai.doctype.agent_conversation.agent_conversation import (
		AgentConversation,
	)

	conversation = AgentConversation.get_or_create_for_contact(phone)
	conversation.add_message("System", f"Notified customer: {work_order} finished production.")
