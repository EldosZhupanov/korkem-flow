# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Sales Agent skill.

Handles `new_order_inquiry` -- a customer asking to buy furniture. Per ADR-0015
the agent never writes: it produces a Pending Action describing what it wants to
create, and a human approves before anything reaches the CRM.

Note on the proposal's target entity: Pending Action requires an entity_type /
entity_name pair, but a "create a new Customer and Deal" proposal has no target
record yet -- the records are what approval creates. The proposal is therefore
anchored to the Agent Conversation it arose from, which is both semantically
right (this is the conversation's proposal) and satisfies invariant 9: approval
re-validates that the originating conversation still exists.
"""

import frappe

SKILL_NAME = "sales_agent"

# The stage a freshly-quoted deal sits in. Real seeded CRM Deal Status value --
# verified against the site, not assumed.
QUOTED_STATUS = "Proposal/Quotation"


def handle_inquiry(conversation_name: str, intent_data: dict):
	"""Propose creating a Customer + Deal from a classified order inquiry.

	Returns the created Pending Action. Nothing is written to the CRM here.
	"""
	conversation = frappe.get_doc("Agent Conversation", conversation_name)

	organization_name = _derive_organization_name(intent_data, conversation)
	product = intent_data.get("product_description") or "Unspecified furniture"
	quantity = intent_data.get("quantity")

	action = frappe.get_doc(
		{
			"doctype": "Pending Action",
			"conversation": conversation.name,
			"agent_skill": SKILL_NAME,
			"entity_type": "Agent Conversation",
			"entity_name": conversation.name,
			"action_class": "korkem_ai.korkem_ai.agents.sales_agent.create_customer_and_deal",
			"action_data": {
				"organization_name": organization_name,
				"product_description": product,
				"quantity": quantity,
				"contact_phone": conversation.contact_phone,
				"conversation": conversation.name,
			},
			"display_data": {
				"summary": f"Create a quote for {organization_name}",
				"changes": [
					{"field": "Customer", "new": organization_name},
					{"field": "Product", "new": product},
					{"field": "Quantity", "new": quantity or "not specified"},
					{"field": "Deal status", "new": QUOTED_STATUS},
				],
			},
		}
	)
	action.insert(ignore_permissions=True)
	return action


def _derive_organization_name(intent_data: dict, conversation) -> str:
	"""Name the customer record.

	Prefer what the customer actually told us. Fall back to their phone number so
	the record is still identifiable -- never invent a name.
	"""
	stated = (intent_data.get("customer_name") or "").strip()
	if stated:
		return stated
	if conversation.contact_phone:
		return f"WhatsApp {conversation.contact_phone}"
	return f"Unknown customer ({conversation.name})"


def create_customer_and_deal(
	organization_name: str,
	product_description: str,
	quantity=None,
	contact_phone: str | None = None,
	conversation: str | None = None,
):
	"""Execute the approved proposal: find-or-create the Customer, then the Deal.

	This is the Command the Pending Action dispatches to on approval. It is real
	business logic and therefore lives in the domain layer (ADR-0007), not in the
	orchestrator.
	"""
	organization = find_or_create_organization(organization_name)
	deal = create_deal(
		organization=organization,
		product_description=product_description,
		quantity=quantity,
		contact_phone=contact_phone,
	)

	if conversation:
		frappe.get_doc("Agent Conversation", conversation).add_message(
			"System",
			f"Quote created: deal {deal} for {organization}.",
		)

	# The quote is approved; producing it is the next decision. It gets its own
	# approval gate rather than being chained automatically, because committing
	# materials and shop-floor time is a materially bigger commitment than
	# recording a quote (ADR-0015).
	from korkem_ai.korkem_ai.agents import production_agent

	proposal = production_agent.propose_production_order(
		deal=deal, qty=quantity or 1, conversation=conversation
	)

	return {"organization": organization, "deal": deal, "production_proposal": proposal.name}


def find_or_create_organization(organization_name: str) -> str:
	"""Return the CRM Organization name, creating it only if it doesn't exist.

	CRM Organization is autonamed from `organization_name`, so the name *is* the
	identity -- an exact-match lookup is the correct dedupe check here.
	"""
	if frappe.db.exists("CRM Organization", organization_name):
		return organization_name

	organization = frappe.get_doc(
		{"doctype": "CRM Organization", "organization_name": organization_name}
	)
	organization.insert(ignore_permissions=True)
	return organization.name


def create_deal(
	organization: str,
	product_description: str,
	quantity=None,
	contact_phone: str | None = None,
) -> str:
	"""Create the CRM Deal that represents the quote.

	`mobile_no` on CRM Deal is derived, not stored: CRM Deal.validate() runs
	set_primary_email_mobile_no(), which reads the phone off the primary row in
	the `contacts` child table and blanks the field when there is none. So the
	phone must be attached as a real Contact -- writing deal.mobile_no directly
	is silently discarded on save.
	"""
	next_step = product_description
	if quantity:
		next_step = f"{product_description} (qty {quantity})"

	deal = frappe.get_doc(
		{
			"doctype": "CRM Deal",
			"organization": organization,
			"status": QUOTED_STATUS,
			"next_step": next_step,
		}
	)

	if contact_phone:
		# Reuse CRM's own contact helper (it dedupes on existing phone/email)
		# rather than hand-rolling a parallel Contact-creation path.
		from crm.fcrm.doctype.crm_deal.crm_deal import create_contact

		contact = create_contact(
			{"first_name": organization, "organization": organization, "mobile_no": contact_phone}
		)
		deal.append("contacts", {"contact": contact, "is_primary": 1})

	deal.insert(ignore_permissions=True)
	return deal.name
