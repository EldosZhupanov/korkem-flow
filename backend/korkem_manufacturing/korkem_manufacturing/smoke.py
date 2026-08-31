# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Live smoke test of the Sprint 1 slice.

Runs the whole flow against a real site rather than the test database, because
integration tests roll back and can hide problems that only appear on a live
site (a webhook returning the wrong content type, a hook not registered because
the app was installed after the process booted).

Run with:
    bench --site <site> execute korkem_manufacturing.smoke.run

Creates real records and prints their names. Safe to re-run: each run uses a
distinct phone number so it never collides with a previous run's data.
"""

import frappe

from korkem_manufacturing import production, setup, shop_floor


def run():
	"""Execute the full slice live and return what was created."""
	setup.provision()

	phone = _unique_phone()
	report = {"phone": phone}

	conversation = _inbound_message(phone)
	report["conversation"] = conversation.name

	quote_action = _propose_quote(conversation)
	report["quote_proposal"] = quote_action.name
	_assert(quote_action.status == "Pending", "quote proposal should await approval")

	quote_result = quote_action.approve()
	report["organization"] = quote_result["organization"]
	report["deal"] = quote_result["deal"]

	production_action = frappe.get_doc("Pending Action", quote_result["production_proposal"])
	report["production_proposal"] = production_action.name
	_assert(
		not frappe.db.exists("Work Order", {"originating_deal": quote_result["deal"]}),
		"nothing may be manufactured before the production gate is approved",
	)

	production_result = production_action.approve()
	report["work_order"] = production_result["work_order"]
	report["task"] = production_result["task"]

	work_order = frappe.get_doc("Work Order", production_result["work_order"])
	_assert(work_order.docstatus == 1, "work order must be submitted")
	_assert(work_order.originating_deal == quote_result["deal"], "work order must link to the deal")

	shop_floor.complete_task(production_result["task"])
	_assert(
		frappe.db.get_value("CRM Task", production_result["task"], "status") == "Done",
		"task must be complete",
	)

	report["transcript"] = _transcript(conversation.name)
	frappe.db.commit()
	return report


def _unique_phone() -> str:
	"""A phone number no previous smoke run used, so runs never collide."""
	existing = frappe.db.count("Agent Conversation", {"channel": "WhatsApp"})
	return f"7709{existing:07d}"


def _inbound_message(phone: str):
	from korkem_ai.korkem_ai.doctype.agent_conversation.agent_conversation import (
		AgentConversation,
	)

	conversation = AgentConversation.get_or_create_for_contact(phone, channel="WhatsApp")
	conversation.add_message("User", "Need 4 kitchen facades, what is the price?")
	return conversation


def _propose_quote(conversation):
	"""Skip the LLM: this site has no provider credentials.

	The classifier is exercised by its own tests against a real model; what this
	smoke run verifies is everything downstream of classification, on a live site.
	"""
	from korkem_ai.korkem_ai.agents import sales_agent

	return sales_agent.handle_inquiry(
		conversation.name,
		{
			"intent": "new_order_inquiry",
			"customer_name": f"Smoke Customer {conversation.name}",
			"product_description": "kitchen facades",
			"quantity": 4,
		},
	)


def _transcript(conversation: str) -> list[str]:
	return [
		f"{m.sender}: {m.content}"
		for m in frappe.get_all(
			"Agent Conversation Message",
			filters={"conversation": conversation},
			fields=["sender", "content"],
			order_by="creation asc",
		)
	]


def _assert(condition: bool, message: str):
	if not condition:
		frappe.throw(f"SMOKE TEST FAILED: {message}")
