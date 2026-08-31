# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The AI Orchestrator's router.

Per ADR-0003 this holds routing logic only -- classify the message, dispatch to
the skill that owns that intent, record what happened on the conversation. It
contains no business rules and writes no business data; skills produce Pending
Actions and the domain layer executes them on approval (ADR-0015).

Per ADR-0016 the agent skills are logical roles in this one process, not
separate services.
"""

import frappe

from korkem_ai.korkem_ai.agents import sales_agent
from korkem_ai.korkem_ai.orchestrator import intent as intent_module

# intent -> handler. Sprint 1 implements the sales path end to end; the other
# intents are recognised (so they aren't misrouted into it) and answered with a
# holding reply until their own skills land.
SKILL_ROUTES = {
	"new_order_inquiry": sales_agent.handle_inquiry,
}

FALLBACK_REPLIES = {
	"order_status": "Thanks! Let me check on your order and get back to you shortly.",
	"general_question": "Thanks for your message! Someone from our team will reply shortly.",
	"other": "Thanks for reaching out to KORKEM! How can we help you today?",
}


def handle_message(conversation_name: str, message_text: str) -> dict:
	"""Route one inbound customer message. Returns a summary of what was done."""
	classified = intent_module.classify(message_text)
	intent = classified["intent"]

	conversation = frappe.get_doc("Agent Conversation", conversation_name)
	conversation.add_message("System", f"Classified intent: {intent}")

	handler = SKILL_ROUTES.get(intent)
	if not handler:
		reply = FALLBACK_REPLIES.get(intent, FALLBACK_REPLIES["other"])
		conversation.add_message("Agent", reply)
		return {"intent": intent, "handled": False, "reply": reply}

	action = handler(conversation_name, classified)
	conversation.add_message(
		"Agent",
		"Thanks! I've prepared a quote for our team to review — we'll confirm shortly.",
	)
	return {"intent": intent, "handled": True, "pending_action": action.name}


def handle_message_async(conversation_name: str, message_text: str):
	"""Queue routing as a background job.

	Per ADR-0009 an LLM call is a third-party call with unbounded latency and must
	never block a request handler -- the WhatsApp webhook returns immediately and
	the orchestrator runs here.
	"""
	frappe.enqueue(
		"korkem_ai.korkem_ai.orchestrator.router.handle_message",
		queue="long",
		conversation_name=conversation_name,
		message_text=message_text,
	)
