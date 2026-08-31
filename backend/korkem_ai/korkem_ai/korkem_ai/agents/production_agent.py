# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Production Agent skill.

Second gate of the Sprint 1 slice: once a quote (CRM Deal) exists, starting
manufacturing is a separate, costly decision -- it commits materials and shop
floor time. Per ADR-0015 the agent proposes; a manager approves.

Unlike the sales proposal, this one has a real target entity: the CRM Deal.
Invariant 9's re-validation at approval time is therefore meaningful here -- a
deal deleted between proposal and approval blocks production.
"""

import frappe

SKILL_NAME = "production_agent"

# ADR-0007: the Command lives in the manufacturing domain app, not here. The
# agent only decides *whether to propose*; korkem_manufacturing owns *how to build*.
PRODUCTION_COMMAND = "korkem_manufacturing.production.create_production_order_for_deal"


def propose_production_order(
	deal: str,
	qty: float = 1,
	assigned_to: str | None = None,
	conversation: str | None = None,
):
	"""Propose starting production for an approved quote.

	Returns the Pending Action. Nothing is manufactured until a human approves.
	"""
	deal_doc = frappe.get_doc("CRM Deal", deal)
	organization = deal_doc.organization or deal

	action = frappe.get_doc(
		{
			"doctype": "Pending Action",
			"conversation": conversation,
			"agent_skill": SKILL_NAME,
			"entity_type": "CRM Deal",
			"entity_name": deal,
			"action_class": PRODUCTION_COMMAND,
			"action_data": {"deal": deal, "qty": qty, "assigned_to": assigned_to},
			"display_data": {
				"summary": f"Start production for {organization}",
				"changes": [
					{"field": "Deal", "new": deal},
					{"field": "Customer", "new": organization},
					{"field": "Quantity", "new": qty},
					{"field": "Assign to", "new": assigned_to or "unassigned"},
				],
			},
		}
	)
	action.insert(ignore_permissions=True)
	return action
