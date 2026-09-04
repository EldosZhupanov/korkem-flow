# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""End-to-end test of the Sprint 1 vertical slice.

Customer sends WhatsApp message -> AI classifies intent -> Customer created ->
CRM Deal created -> Quote approved -> Production Order created -> Task assigned
-> Worker completes task -> Customer notified.

Only two things are stubbed, both genuine third-party network calls: the LLM
provider and the outbound WhatsApp send. Every other step -- classification
routing, both approval gates, Work Order submission, the completion hooks --
runs for real against the database.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import notifications
from korkem_ai.korkem_ai.orchestrator import inbound

CUSTOMER_PHONE = "77010001122"
CUSTOMER_MESSAGE = "Здравствуйте! Нужны кухонные фасады, 8 штук. Сколько будет стоить?"

# What the LLM is expected to extract from that message.
CLASSIFIED = {
	"intent": "new_order_inquiry",
	"customer_name": "Aigerim Nurlanovna",
	"product_description": "kitchen facades",
	"quantity": 8,
}


class TestSprint1EndToEnd(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		from korkem_manufacturing import setup

		setup.provision()

	def tearDown(self):
		frappe.db.rollback()

	def test_whatsapp_message_becomes_a_manufactured_order(self):
		from korkem_manufacturing import shop_floor
		from korkem_ai.korkem_ai.integrations.whatsapp import _dispatch_inbound_message

		with patch.object(notifications.whatsapp, "queue_send_message") as outbound:
			# 1. The customer's WhatsApp message arrives.
			with patch(
				"korkem_ai.korkem_ai.orchestrator.inbound.intent_module.classify",
				return_value=CLASSIFIED,
			):
				_dispatch_inbound_message(
					{
						"from": CUSTOMER_PHONE,
						"message_id": "wamid.e2e",
						"timestamp": "1780000000",
						"text": CUSTOMER_MESSAGE,
					}
				)

				conversation = frappe.get_all(
					"Agent Conversation",
					filters={"contact_phone": CUSTOMER_PHONE, "channel": "WhatsApp"},
					pluck="name",
				)
				self.assertEqual(len(conversation), 1, "Inbound message must open one conversation")

				# 2. The orchestrator classifies and routes it. Called directly rather
				# than through the queue so the test asserts on the outcome, not on
				# worker timing -- handle_message_async only wraps this in enqueue().
				routed = inbound.handle_message(conversation[0], CUSTOMER_MESSAGE)

			self.assertEqual(routed["intent"], "new_order_inquiry")
			self.assertTrue(routed["handled"])

			# 3. Gate one: nothing exists in the CRM until a human approves.
			quote_proposal = frappe.get_doc("Pending Action", routed["pending_action"])
			self.assertEqual(quote_proposal.status, "Pending")
			self.assertFalse(frappe.db.exists("CRM Organization", "Aigerim Nurlanovna"))

			quote_result = quote_proposal.approve()

			deal = quote_result["deal"]
			self.assertTrue(frappe.db.exists("CRM Organization", "Aigerim Nurlanovna"))
			self.assertEqual(
				frappe.db.get_value("CRM Deal", deal, "mobile_no"),
				CUSTOMER_PHONE,
				"The deal must carry the phone the customer wrote from",
			)

			# 4. Gate two: approving the quote proposes production, but builds nothing.
			production_proposal = frappe.get_doc(
				"Pending Action", quote_result["production_proposal"]
			)
			self.assertEqual(production_proposal.status, "Pending")
			self.assertFalse(frappe.db.exists("Work Order", {"originating_deal": deal}))

			production_result = production_proposal.approve()
			work_order = frappe.get_doc("Work Order", production_result["work_order"])

			# 5. A real, submitted Work Order carrying the customer's quantity.
			self.assertEqual(work_order.docstatus, 1)
			self.assertEqual(work_order.qty, 8)
			self.assertEqual(work_order.originating_deal, deal)
			self.assertEqual(
				{row.item_code for row in work_order.required_items},
				{"MDF Panel", "PVC Film"},
				"The BOM must drive real material requirements",
			)

			# 6. The worker finishes the job.
			outbound.assert_not_called()  # nothing sent before the work is done
			shop_floor.complete_task(production_result["task"])

		# 7. The customer is told, on the number they wrote from.
		outbound.assert_called_once()
		to = outbound.call_args.kwargs.get("to") or outbound.call_args.args[0]
		body = outbound.call_args.kwargs.get("body") or outbound.call_args.args[1]
		self.assertEqual(to, CUSTOMER_PHONE)
		self.assertIn(work_order.name, body)
		self.assertIn("Kitchen Facade", body)

		# 8. The conversation is a complete record of the exchange.
		messages = frappe.get_all(
			"Agent Conversation Message",
			filters={"conversation": conversation[0]},
			fields=["sender", "content"],
			order_by="creation asc",
		)
		transcript = " | ".join(f"{m.sender}: {m.content}" for m in messages)
		self.assertIn(CUSTOMER_MESSAGE, transcript)
		self.assertIn("new_order_inquiry", transcript)
		self.assertIn("Quote created", transcript)
		self.assertIn("finished production", transcript)
