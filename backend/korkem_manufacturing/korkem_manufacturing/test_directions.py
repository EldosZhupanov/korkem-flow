# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Every order says which line it is; urgent orders lead; customers carry a tier."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.api import queries
from korkem_manufacturing.patches.v0_0 import add_order_direction_fields
from korkem_manufacturing.services import directions, facade_jobs, facade_order, facade_prices

COMPANY = "KORKEM"
PVC = facade_prices.PVC
SELLER = "directions.seller@example.com"
HEAD = "directions.head@example.com"
CUTTER = "directions.cutter@example.com"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestDirections(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(SELLER, "Sales User")
		_user(HEAD, "Sales Manager")
		_user(CUTTER, "Manufacturing User")
		facade_prices.seed_company(COMPANY)

	def setUp(self):
		frappe.set_user("Administrator")
		self.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _facade_order(self, urgent=False, days=10) -> str:
		return facade_order.create_order(
			customer=self.customer,
			delivery_date=add_days(nowdate(), days),
			lines=[{"width_mm": 500, "height_mm": 400, "qty": 1, "milling": "Квадро", "finish": PVC}],
			urgent=urgent,
		)["sales_order"]

	# --- direction ------------------------------------------------------------

	def test_a_facade_quote_makes_a_facade_order(self):
		order = self._facade_order()
		self.assertEqual(directions.direction_of(order), directions.FACADES)

	def test_an_order_says_furniture_unless_it_was_made_as_facades(self):
		furniture = frappe.db.get_value(
			"Sales Order", {"docstatus": 1, "korkem_direction": directions.FURNITURE}, "name"
		)
		self.assertTrue(furniture, "seeded furniture orders exist")
		self.assertEqual(directions.direction_of(furniture), directions.FURNITURE)

	def test_existing_orders_are_classified_by_what_they_contain(self):
		order = self._facade_order()
		frappe.db.set_value("Sales Order", order, "korkem_direction", "")
		add_order_direction_fields.execute()
		self.assertEqual(directions.direction_of(order), directions.FACADES)

	def test_the_order_list_splits_by_direction(self):
		order = self._facade_order()
		facades = queries.sales_orders(direction=directions.FACADES, limit=100)["orders"]
		self.assertIn(order, [row["name"] for row in facades])
		self.assertTrue(all(row["korkem_direction"] == directions.FACADES for row in facades))
		furniture = queries.sales_orders(direction=directions.FURNITURE, limit=100)["orders"]
		self.assertNotIn(order, [row["name"] for row in furniture])

	def test_an_unknown_direction_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			queries.sales_orders(direction="Двери")

	# --- urgency --------------------------------------------------------------

	def test_an_order_can_be_urgent_from_the_start(self):
		order = self._facade_order(urgent=True)
		self.assertEqual(frappe.db.get_value("Sales Order", order, "korkem_urgent"), 1)

	def test_the_seller_marks_urgent_and_it_is_audited(self):
		order = self._facade_order()
		result = self._as(SELLER, directions.set_urgent, order, "1")
		self.assertEqual((result["urgent"], result["changed"]), (True, True))
		self.assertTrue(
			frappe.db.exists("Domain Audit Event", {"action": "sales.order_urgency", "entity_id": order})
		)

	def test_the_floor_cannot_mark_urgent(self):
		order = self._facade_order()
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, directions.set_urgent, order, 1)

	def test_urgent_facades_head_the_shop_queue(self):
		calm = self._facade_order(days=2)
		urgent = self._facade_order(urgent=True, days=20)
		queue = [job["sales_order"] for job in facade_jobs.jobs(limit=200)["jobs"]]
		self.assertLess(queue.index(urgent), queue.index(calm))

	def test_urgent_first_reorders_the_order_list(self):
		self._facade_order()
		urgent = self._facade_order(urgent=True)
		rows = queries.sales_orders(urgent_first=1, limit=5)["orders"]
		self.assertEqual(rows[0]["name"], urgent)

	# --- customer tier --------------------------------------------------------

	def test_the_head_of_sales_sets_a_tier_and_the_list_shows_it(self):
		self._as(HEAD, directions.set_tier, self.customer, directions.VIP)
		order = self._facade_order()
		row = next(r for r in queries.sales_orders(limit=100)["orders"] if r["name"] == order)
		self.assertEqual(row["customer_tier"], directions.VIP)

	def test_a_seller_cannot_set_a_tier(self):
		with self.assertRaises(frappe.PermissionError):
			self._as(SELLER, directions.set_tier, self.customer, directions.VIP)

	def test_an_unknown_tier_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			self._as(HEAD, directions.set_tier, self.customer, "Золотой")
