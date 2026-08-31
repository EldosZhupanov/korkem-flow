# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""One company's answers must never contain another company's documents.

The assistant's answers were once clean by accident: the only other companies
on the bench were ERPNext's own fixtures, their orders were drafts, and a
`docstatus = 1` filter hid them. Submitting one would have started reporting
another company's late orders to a KORKEM planner, with nothing in the code to
stop it.

The fixture those tests leaned on is not present on a site built from an empty
volume, and they answered by turning themselves off — see
`foreign_fixture`, which builds the second company instead of hunting for one.

Role permissions do not cover this. `Sales User` grants read on *Sales Order* —
the doctype, not one company's rows. So these tests submit a real document for
another company and assert it never appears.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import seed_demo

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401
from korkem_ai.korkem_ai.tools import foreign_fixture
from korkem_ai.korkem_ai.tools.scope import current_company

PLANNER = "korkem.planner@example.com"


class TestTheCompanyIsTheServersAnswer(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		seed_demo.seed_users()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def test_the_session_resolves_to_one_company(self):
		frappe.set_user(PLANNER)
		try:
			self.assertEqual(current_company(), "KORKEM")
		finally:
			frappe.set_user("Administrator")

	def test_no_tool_lets_the_model_name_a_company(self):
		"""The whole control. A model that could pass `company` could read any
		company on the bench by naming it, and nothing downstream would narrow
		it again — the same reasoning that keeps a generic request tool out of
		the registry."""
		for spec in registry.all_specs():
			with self.subTest(tool=spec.name):
				self.assertNotIn("company", spec.input_schema.get("properties", {}))


class TestAnotherCompanysWorkIsInvisible(foreign_fixture.UsesForeignCompany, IntegrationTestCase):
	"""Creates a real submitted order for another company and looks for it."""

	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		seed_demo.seed_users()
		cls.intruder = cls._foreign_order()
		frappe.db.commit()

	@classmethod
	def _foreign_order(cls):
		"""A submitted, open order belonging to somebody else.

		Submitted on purpose: a draft would be filtered out by `docstatus` and
		the test would pass without the scope doing any work at all.
		"""
		return foreign_fixture.ensure()["sales_order"]

	def setUp(self):
		frappe.set_user("Administrator")

	def tearDown(self):
		frappe.set_user("Administrator")

	def as_planner(self, tool, args=None):
		frappe.set_user(PLANNER)
		try:
			return registry.execute(tool, args or {})
		finally:
			frappe.set_user("Administrator")

	def test_it_is_absent_from_the_order_search(self):
		result = self.as_planner("sales.search_sales_orders", {})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertNotIn(
			self.intruder, [row["name"] for row in result["data"]["sales_orders"]]
		)

	def test_it_is_absent_from_the_production_overview(self):
		"""It is overdue, so if scoping failed it would arrive at the top of
		somebody's morning as a crisis in a factory they have never heard of."""
		floor = self.as_planner("manufacturing.production_control", {})["data"]

		self.assertNotIn(self.intruder, [row["sales_order"] for row in floor["orders"]])
		self.assertNotIn(self.intruder, floor["attention"])

	def test_it_is_absent_from_the_factory_shortage(self):
		shortage = self.as_planner("inventory.factory_shortage", {})["data"]
		blocked = {
			order["sales_order"]
			for item in shortage["items"]
			for order in item["orders_blocked"]
		}

		self.assertNotIn(self.intruder, blocked)

	def test_fetching_it_by_name_is_refused(self):
		"""Refused as "not found" rather than "not yours": confirming the
		document exists is itself a disclosure."""
		result = self.as_planner("sales.get_sales_order", {"name": self.intruder})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"].lower())

	def test_its_shortage_cannot_be_computed(self):
		result = self.as_planner("inventory.material_shortage", {"sales_order": self.intruder})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"].lower())

	def test_nothing_can_be_bought_for_it(self):
		"""The write path matters most: a purchase request against another
		company's order would be a real document with real money on it."""
		result = self.as_planner(
			"inventory.create_material_request",
			{"sales_order": self.intruder, "items": [{"item_code": "ДСП 16мм", "qty": 1}]},
		)

		self.assertFalse(result["ok"])
		self.assertEqual(frappe.db.count("Material Request", {"company": foreign_fixture.COMPANY}), 0)
