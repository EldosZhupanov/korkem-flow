"""The human-confirmation path must inherit the same retry protection as the loop."""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import registry


class TestConfirmedIdempotency(IntegrationTestCase):
	def setUp(self):
		self.tool = "test.confirmed." + frappe.generate_hash(length=8)
		self.subject = "confirmed-idempotency-" + frappe.generate_hash(length=12)

		def handler(description):
			doc = frappe.get_doc({"doctype": "ToDo", "description": description}).insert()
			return {"task": doc.name}

		registry.register(
			registry.ToolSpec(
				name=self.tool,
				description="test",
				input_schema={
					"type": "object",
					"properties": {"description": {"type": "string"}},
					"required": ["description"],
				},
				risk=registry.Risk.WRITE,
				handler=handler,
				doctypes=("ToDo",),
			)
		)

	def tearDown(self):
		registry._REGISTRY.pop(self.tool, None)
		frappe.db.rollback()
		super().tearDown()

	def proposal(self, turn):
		return frappe.get_doc(
			{
				"doctype": "Pending Action",
				"tool": self.tool,
				"turn_id": turn,
				"action_data": frappe.as_json({"description": self.subject}),
				"status": "Pending",
			}
		).insert(ignore_permissions=True)

	def test_two_proposals_of_the_same_turn_create_one_real_task(self):
		turn = frappe.generate_hash(length=12)
		first = self.proposal(turn).approve()
		second = self.proposal(turn).approve()
		self.assertTrue(first["ok"] and second["ok"])
		self.assertEqual(first["data"], second["data"])
		self.assertEqual(frappe.db.count("ToDo", {"description": self.subject}), 1)

	def test_distinct_turns_are_distinct_intents(self):
		self.proposal(frappe.generate_hash(length=12)).approve()
		self.proposal(frappe.generate_hash(length=12)).approve()
		self.assertEqual(frappe.db.count("ToDo", {"description": self.subject}), 2)
