# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""One company's answers must never contain another company's documents.

This bench carries twenty-three companies, twenty-two of them ERPNext's own
fixtures, and the assistant's answers used to be clean by accident: the other
companies' orders happened to be drafts, so a `docstatus = 1` filter hid them.
Submitting one would have started reporting another company's late orders to a
KORKEM planner, with nothing in the code to stop it.

Role permissions do not cover this. `Sales User` grants read on *Sales Order* —
the doctype, not one company's rows. So these tests submit a real document for
another company and assert it never appears.
"""

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing import seed_demo

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401
from korkem_ai.korkem_ai.tools.scope import current_company

PLANNER = "korkem.planner@example.com"
OTHER_COMPANY = "_Test Company"


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


class TestAnotherCompanysWorkIsInvisible(IntegrationTestCase):
	"""Creates a real submitted order for `_Test Company` and looks for it."""

	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		seed_demo.seed_users()
		cls.intruder = cls._foreign_order()
		frappe.db.commit()

	@classmethod
	def tearDownClass(cls):
		frappe.set_user("Administrator")
		if cls.intruder and frappe.db.exists("Sales Order", cls.intruder):
			doc = frappe.get_doc("Sales Order", cls.intruder)
			if doc.docstatus == 1:
				doc.cancel()
			frappe.delete_doc("Sales Order", cls.intruder, force=1, ignore_permissions=True)
		frappe.db.commit()
		super().tearDownClass()

	@classmethod
	def _foreign_order(cls):
		"""A submitted, open order belonging to somebody else.

		Submitted on purpose: a draft would be filtered out by `docstatus` and
		the test would pass without the scope doing any work at all.
		"""
		item = frappe.db.get_value(
			"Item", {"is_stock_item": 1, "item_code": ["like", "_Test Item%"]}, "name"
		)
		customer = frappe.db.get_value("Customer", {"name": ["like", "_Test Customer%"]}, "name")
		warehouse = frappe.db.get_value(
			"Warehouse", {"company": OTHER_COMPANY, "is_group": 0}, "name"
		)
		if not (item and customer and warehouse):
			return None

		order = frappe.get_doc(
			{
				"doctype": "Sales Order",
				"company": OTHER_COMPANY,
				"customer": customer,
				# Back-dated wholly: ERPNext refuses a delivery date before the
				# order date, and an order that is late was placed a while ago.
				"transaction_date": add_days(nowdate(), -12),
				"delivery_date": add_days(nowdate(), -5),  # overdue, so it is loud
				"currency": frappe.db.get_value("Company", OTHER_COMPANY, "default_currency"),
				"conversion_rate": 1,
				"items": [
					{
						"item_code": item,
						"qty": 5,
						"rate": 100,
						"warehouse": warehouse,
						"delivery_date": add_days(nowdate(), -5),
					}
				],
			}
		)
		order.insert(ignore_permissions=True)
		order.submit()
		return order.name

	def setUp(self):
		if not self.intruder:
			self.skipTest("no usable _Test Company fixture on this bench")
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
		self.assertEqual(frappe.db.count("Material Request", {"company": OTHER_COMPANY}), 0)
