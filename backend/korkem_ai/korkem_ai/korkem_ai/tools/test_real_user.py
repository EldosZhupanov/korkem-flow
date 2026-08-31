# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""The assistant as somebody other than Administrator.

Every earlier phase ran as Administrator, which cannot fail a permission check
and therefore proves nothing about them. These tests run the real workflow as
two ordinary System Users built from stock ERPNext roles, and the interesting
assertion is the negative one: the viewer can see the same production floor and
cannot buy anything on it.

The rule under test is absolute and worth stating in one line:

    AI permissions ⊆ the logged-in user's ERPNext permissions

Nothing in the tool layer may widen that, which is why the tools run in-process
under the caller's own session rather than a service account.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import seed_demo

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401

PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"
BOARD = "ДСП 16мм"
WRITE = "inventory.create_material_request"


def _order():
	rows = frappe.get_all(
		"Sales Order", filters={"customer": "Мебель Астана", "docstatus": 1}, pluck="name"
	)
	return rows[0] if rows else None


class _RealUserTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.order = _order()
		if not self.order:
			self.skipTest("seed_demo has not been run on this site")
		seed_demo.seed_users()
		self._clean()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		self._clean()

	def _clean(self):
		frappe.set_user("Administrator")
		for name in frappe.get_all("Material Request", pluck="name"):
			doc = frappe.get_doc("Material Request", name)
			if doc.docstatus == 1:
				doc.cancel()
			frappe.delete_doc("Material Request", name, force=1, ignore_permissions=True)
		frappe.db.delete("Pending Action", {"tool": WRITE})
		frappe.db.commit()

	def requests(self):
		frappe.set_user("Administrator")
		return frappe.db.count("Material Request")

	def as_user(self, user, tool, args):
		frappe.set_user(user)
		try:
			return registry.execute(tool, args)
		finally:
			frappe.set_user("Administrator")


class TestNeitherUserIsAnAdministrator(_RealUserTestCase):
	def test_the_demo_users_hold_no_administrative_role(self):
		"""If either of these picked up System Manager, every other test in
		this file would pass while proving nothing."""
		for user in (PLANNER, VIEWER):
			with self.subTest(user=user):
				roles = set(frappe.get_roles(user))

				self.assertNotIn("System Manager", roles)
				self.assertNotIn("Administrator", roles)

	def test_the_roles_are_erpnext_s_own(self):
		"""Least privilege assembled from stock roles, not from a custom role
		invented to make the workflow pass."""
		self.assertEqual(
			set(frappe.get_roles(PLANNER)) & {"Manufacturing User", "Stock User"},
			{"Manufacturing User", "Stock User"},
		)


class TestThePlannerCanDoTheWholeJob(_RealUserTestCase):
	def test_every_step_of_the_workflow_succeeds(self):
		for tool, args in (
			("sales.search_sales_orders", {"customer": "Мебель Астана"}),
			("sales.get_sales_order", {"name": self.order}),
			("manufacturing.production_control", {"sales_order": self.order}),
			("inventory.material_shortage", {"sales_order": self.order}),
			("manufacturing.production_control", {}),
		):
			with self.subTest(tool=tool):
				result = self.as_user(PLANNER, tool, args)

				self.assertTrue(result["ok"], result.get("error"))

	def test_the_request_is_created_and_owned_by_the_planner(self):
		result = self.as_user(
			PLANNER, WRITE, {"sales_order": self.order, "items": [{"item_code": BOARD, "qty": 4}]}
		)

		self.assertTrue(result["ok"], result.get("error"))
		frappe.set_user("Administrator")
		created = frappe.get_doc("Material Request", result["data"]["material_request"])
		self.assertEqual(
			created.owner, PLANNER, "the document must carry the real user, not a service account"
		)


class TestTheViewerCanLookButNotBuy(_RealUserTestCase):
	def test_reading_production_is_allowed(self):
		result = self.as_user(VIEWER, "manufacturing.production_control", {})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertGreater(result["data"]["summary"]["active_orders"], 0)

	def test_creating_a_request_is_refused_and_writes_nothing(self):
		result = self.as_user(
			VIEWER, WRITE, {"sales_order": self.order, "items": [{"item_code": BOARD, "qty": 4}]}
		)

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "permission_denied")
		self.assertEqual(self.requests(), 0)

	def test_the_write_tool_is_not_even_offered(self):
		"""Refusing at execution is the guarantee; not offering it is the
		courtesy. A model handed a tool it can never use will keep retrying."""
		frappe.set_user(VIEWER)
		try:
			offered = {spec.name for spec in registry.available_to()}
		finally:
			frappe.set_user("Administrator")

		self.assertNotIn(WRITE, offered)
		self.assertIn("manufacturing.production_control", offered)

	def test_no_wording_of_the_request_changes_the_answer(self):
		"""The permission check does not read the conversation, so nothing said
		in it can move the boundary. Asserted because it is the claim a user
		will most want evidence for."""
		insistent = {
			"sales_order": self.order,
			"items": [{"item_code": BOARD, "qty": 4}],
			"purpose": "Purchase",
		}
		result = self.as_user(VIEWER, WRITE, insistent)

		self.assertFalse(result["ok"])
		self.assertEqual(self.requests(), 0)


class TestCreateWithoutSubmitLeavesNothingBehind(_RealUserTestCase):
	def test_a_user_who_cannot_submit_is_refused_before_anything_is_inserted(self):
		"""ERPNext lets an administrator grant create without submit. Finding
		that out after `insert()` leaves a draft nobody asked for and nobody
		will action — invisible to purchasing, indistinguishable from one a
		person started and abandoned."""
		real = frappe.has_permission

		def without_submit(doctype, ptype="read", *args, **kwargs):
			if doctype == "Material Request" and ptype == "submit":
				return False
			return real(doctype, ptype, *args, **kwargs)

		frappe.set_user(PLANNER)
		try:
			with patch("korkem_ai.korkem_ai.tools.procurement.frappe.has_permission", without_submit):
				result = registry.execute(
					WRITE, {"sales_order": self.order, "items": [{"item_code": BOARD, "qty": 4}]}
				)
		finally:
			frappe.set_user("Administrator")

		self.assertFalse(result["ok"])
		self.assertIn("not submit", result["error"]["message"])
		self.assertEqual(self.requests(), 0, "a draft was left behind")


class TestProductionControlReportsTheRealFloor(_RealUserTestCase):
	def setUp(self):
		super().setUp()
		self.floor = self.as_user(PLANNER, "manufacturing.production_control", {})["data"]

	def test_the_counts_match_the_orders_listed(self):
		"""The summary is what the model reads aloud, so it must not be able to
		disagree with the detail underneath it."""
		summary, orders = self.floor["summary"], self.floor["orders"]

		self.assertEqual(summary["active_orders"], len(orders))
		self.assertEqual(summary["overdue_orders"], len([o for o in orders if o["overdue"]]))
		self.assertEqual(
			summary["orders_with_material_shortage"],
			len([o for o in orders if o["material_status"] == "shortage"]),
		)

	def test_an_overdue_order_is_past_its_delivery_date_and_undelivered(self):
		"""A late order that shipped is history, not a problem."""
		for order in self.floor["orders"]:
			if order["overdue"]:
				self.assertLess(order["days_to_delivery"], 0)
				self.assertLess(order["delivered_percent"], 100)

	def test_the_blocked_order_reports_the_same_shortage_the_write_would_order(self):
		"""One number, one meaning. Two paths to a shortage is how an overview
		and an action come to disagree in front of a customer."""
		blocked = next(o for o in self.floor["orders"] if o["material_status"] == "shortage")
		direct = self.as_user(
			PLANNER, "inventory.material_shortage", {"sales_order": blocked["sales_order"]}
		)["data"]

		self.assertEqual(
			{s["item_code"]: s["shortage_qty"] for s in blocked["shortages"]},
			{s["item_code"]: s["shortage_qty"] for s in direct["shortages"]},
		)

	def test_an_order_nobody_started_and_that_lacks_nothing_is_ready(self):
		ready = [o for o in self.floor["orders"] if o["ready_to_start"]]

		self.assertTrue(ready, "the fixture no longer has an unstarted order")
		for order in ready:
			self.assertFalse(order["started"])
			self.assertEqual(order["shortages"], [])

	def test_the_most_pressing_orders_come_first(self):
		"""«Какой заказ самый проблемный» must not depend on the model
		re-sorting a list correctly."""
		attention = self.floor["attention"]

		self.assertTrue(attention)
		overdue = [o["sales_order"] for o in self.floor["orders"] if o["overdue"]]
		self.assertEqual(attention[0], overdue[0])

	def test_it_is_a_read_and_needs_no_confirmation(self):
		spec = registry.get("manufacturing.production_control")

		self.assertIs(spec.risk, registry.Risk.READ)
		self.assertFalse(spec.requires_confirmation)
