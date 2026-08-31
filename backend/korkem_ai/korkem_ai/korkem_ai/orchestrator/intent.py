# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Intent classification -- the Orchestrator's routing decision.

Per ADR-0003 the Orchestrator only routes; it holds no business rules. This
module turns a customer's free-text message into a structured intent plus any
entities worth extracting, and nothing else. What to *do* with that intent is
the agent skill's job (see korkem_ai/agents/).
"""

from korkem_ai.korkem_ai.orchestrator import llm

# Sprint 1 covers exactly one flow end to end: a customer asking for furniture.
# Other intents are recognised so the router can decline them cleanly rather
# than misrouting -- they get their own skills in later sprints.
INTENTS = (
	"new_order_inquiry",
	"order_status",
	"general_question",
	"other",
)

INTENT_SCHEMA = {
	"type": "object",
	"properties": {
		"intent": {
			"type": "string",
			"enum": list(INTENTS),
			"description": "The customer's primary intent.",
		},
		"customer_name": {
			"type": ["string", "null"],
			"description": "The customer's name if they stated it, otherwise null.",
		},
		"product_description": {
			"type": ["string", "null"],
			"description": "What furniture the customer wants, in their own words, otherwise null.",
		},
		"quantity": {
			"type": ["integer", "null"],
			"description": "How many units they asked for, if stated, otherwise null.",
		},
	},
	"required": ["intent", "customer_name", "product_description", "quantity"],
	"additionalProperties": False,
}

SYSTEM_PROMPT = """You classify incoming customer messages for KORKEM, a furniture and door facade manufacturer in Kazakhstan.

Classify the message into exactly one intent:
- new_order_inquiry: the customer wants to buy, order, or get a quote for furniture
- order_status: the customer is asking about an order they already placed
- general_question: a question about the business (hours, location, materials) with no order intent
- other: anything else, including greetings with no request

Also extract any details the customer stated explicitly. Do not infer or invent
details they did not state -- use null when something was not mentioned.

Messages may be in Russian, Kazakh, or English. Classify by meaning, not language."""


def classify(message: str) -> dict:
	"""Classify a customer message. Returns the validated intent dict."""
	provider = llm.get_provider()
	result = provider.complete_json(
		system=SYSTEM_PROMPT,
		user_message=message,
		schema=INTENT_SCHEMA,
	)
	return normalize(result)


def normalize(result: dict) -> dict:
	"""Defensively normalize a provider result.

	Schema-constrained output makes malformed results unlikely, but a local model
	can still return an out-of-enum intent -- fall back to "other" rather than
	letting an unknown value reach the router.
	"""
	intent = result.get("intent")
	return {
		"intent": intent if intent in INTENTS else "other",
		"customer_name": result.get("customer_name") or None,
		"product_description": result.get("product_description") or None,
		"quantity": result.get("quantity") or None,
	}
