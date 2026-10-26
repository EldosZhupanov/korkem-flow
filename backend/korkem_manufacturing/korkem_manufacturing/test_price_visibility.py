# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Who sees money — and that the answer is the server's, not the screen's.

Two layers are tested, because a worker can reach an order through both:
KORKEM's own endpoints, and Frappe's generic REST (`frappe.client.get`, which
is what `/api/resource/Sales Order/<name>` runs).
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.api import queries
from korkem_manufacturing.services import order_state, price_visibility

CUTTER = "price.cutter@example.com"
SELLER = "price.seller@example.com"
BOOKKEEPER = "price.bookkeeper@example.com"
SALES_HEAD = "price.saleshead@example.com"
COMPANY = "KORKEM"
#: A total nobody could mistake for a default.
TOTAL = 123457.0


def _user(email: str, roles: tuple[str, ...]) -> str:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{
				"doctype": "User",
				"email": email,
				"first_name": email.split("@")[0],
				"send_welcome_email": 0,
			}
		).insert(ignore_permissions=True)
	user = frappe.get_doc("User", email)
	for role in roles:
		if role not in {row.role for row in user.roles}:
			user.append("roles", {"role": role})
	user.save(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)
	return email


class _PriceTestCase(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		# The site state a migrated pilot is in; idempotent, so harmless here.
		price_visibility.apply_field_levels()
		_user(CUTTER, ("Manufacturing User",))
		_user(SELLER, ("Sales User",))
		_user(BOOKKEEPER, ("Accounts User",))
		_user(SALES_HEAD, ("Sales Manager",))
		cls.order = cls._order()

	@classmethod
	def _order(cls) -> str:
		name = frappe.db.get_value("Sales Order", {"company": COMPANY, "docstatus": 1}, "name")
		assert name, "the seeded KORKEM site has submitted orders; no silent skip"
		doc = frappe.copy_doc(frappe.get_doc("Sales Order", name))
		doc.transaction_date = nowdate()
		doc.delivery_date = add_days(nowdate(), 7)
		doc.set("payment_schedule", [])
		for row in doc.items:
			row.qty = 1
			row.delivery_date = doc.delivery_date
			row.delivered_qty = 0
			row.billed_amt = 0
			# A copy is a new order, not a second order against the same
			# quotation line — ERPNext refuses that as over-allowance.
			row.prevdoc_docname = None
			row.quotation_item = None
		doc.insert(ignore_permissions=True)
		# Written straight to the row: what is under test is who may *read* a
		# total, and a copied order can come out of ERPNext's pricing at 0 —
		# where "hidden" and "really zero" would look the same.
		frappe.db.set_value("Sales Order", doc.name, {"grand_total": TOTAL, "advance_paid": 1000})
		for item in doc.items:
			frappe.db.set_value("Sales Order Item", item.name, {"rate": TOTAL, "amount": TOTAL})
		return doc.name

	def setUp(self):
		frappe.set_user("Administrator")
		self._switch(False)

	def tearDown(self):
		frappe.set_user("Administrator")
		self._switch(False)

	def _switch(self, enabled: bool):
		current = frappe.session.user
		frappe.set_user("Administrator")
		price_visibility.set_floor_sees_prices(enabled)
		frappe.set_user(current)

	def _listed(self, user: str) -> dict:
		frappe.set_user(user)
		rows = queries.sales_orders(search=self.order, limit=5)["orders"]
		frappe.set_user("Administrator")
		row = next((row for row in rows if row["name"] == self.order), None)
		self.assertIsNotNone(row, f"{user} must still see the order itself")
		return row

	def _rest(self, user: str) -> dict:
		frappe.set_user(user)
		try:
			return frappe.client.get("Sales Order", self.order)
		finally:
			frappe.set_user("Administrator")


class TestTheStandardRolesStillReadOrders(_PriceTestCase):
	"""Regression: grant_order_read once took Sales Order away from Sales and Accounts."""

	def test_a_seller_reads_sales_orders(self):
		self.assertTrue(frappe.has_permission("Sales Order", "read", user=SELLER))

	def test_a_bookkeeper_reads_sales_orders(self):
		self.assertTrue(frappe.has_permission("Sales Order", "read", user=BOOKKEEPER))

	def test_the_shop_floor_still_reads_the_order_it_works_on(self):
		self.assertTrue(frappe.has_permission("Sales Order", "read", user=CUTTER))

	def test_the_shop_floor_still_cannot_write_an_order(self):
		self.assertFalse(frappe.has_permission("Sales Order", "write", user=CUTTER))


class TestTheShopFloorDoesNotSeeMoneyByDefault(_PriceTestCase):
	def test_the_switch_starts_off(self):
		frappe.db.set_default(price_visibility._setting_key(COMPANY), None)
		self.assertFalse(price_visibility.floor_sees_prices(COMPANY))

	def test_the_money_fields_sit_behind_level_one(self):
		meta = frappe.get_meta("Sales Order")
		self.assertEqual(meta.get_field("grand_total").permlevel, 1)
		self.assertEqual(frappe.get_meta("Sales Order Item").get_field("rate").permlevel, 1)
		# And the fields a cutter needs did not move with them.
		self.assertEqual(meta.get_field("delivery_date").permlevel, 0)
		self.assertEqual(meta.get_field("korkem_state").permlevel, 0)

	def test_korkems_list_sends_a_cutter_no_total(self):
		row = self._listed(CUTTER)
		self.assertIsNone(row["grand_total"])
		self.assertIsNone(row["advance_paid"])
		# None — not 0: "hidden" must not read as "free".
		self.assertIn("grand_total", row)

	def test_frappes_own_rest_sends_a_cutter_no_total(self):
		"""What `/api/resource/Sales Order/<name>` returns — the app is not the only client."""
		doc = self._rest(CUTTER)
		# Frappe sends a hidden currency field as 0.0 rather than leaving it
		# out; what matters is that the real figure never leaves the server.
		self.assertFalse(doc.get("grand_total"))
		self.assertFalse(any(item.get("rate") for item in doc.get("items")))
		self.assertTrue(doc.get("items"), "the cutter still sees what is being made")

	def test_the_order_state_does_not_tell_a_cutter_what_was_paid(self):
		frappe.set_user(CUTTER)
		state = order_state.get_order_state(self.order)
		frappe.set_user("Administrator")
		self.assertIsNone(state["total_amount"])
		self.assertIsNone(state["advance_paid"])


class TestMoneyRolesAlwaysSeeIt(_PriceTestCase):
	def test_a_seller_sees_the_total(self):
		self.assertEqual(self._listed(SELLER)["grand_total"], TOTAL)

	def test_a_seller_sees_it_over_rest_too(self):
		self.assertEqual(self._rest(SELLER).get("grand_total"), TOTAL)

	def test_a_bookkeeper_sees_the_total(self):
		self.assertIsNotNone(self._listed(BOOKKEEPER)["grand_total"])


class TestTheAdministratorDecides(_PriceTestCase):
	def test_switching_it_on_shows_the_cutter_money_everywhere(self):
		self._switch(True)
		self.assertEqual(self._listed(CUTTER)["grand_total"], TOTAL)
		self.assertEqual(self._rest(CUTTER).get("grand_total"), TOTAL)

	def test_switching_it_off_again_takes_it_back_everywhere(self):
		self._switch(True)
		self._switch(False)
		self.assertIsNone(self._listed(CUTTER)["grand_total"])
		self.assertFalse(self._rest(CUTTER).get("grand_total"))

	def test_a_sales_manager_cannot_flip_it(self):
		"""Sales may set prices, not decide who on the floor reads them."""
		frappe.set_user(SALES_HEAD)
		with self.assertRaises(frappe.PermissionError):
			price_visibility.set_floor_sees_prices(True)
		frappe.set_user("Administrator")
		self.assertFalse(price_visibility.floor_sees_prices(COMPANY))

	def test_a_cutter_cannot_flip_it_for_themselves(self):
		frappe.set_user(CUTTER)
		with self.assertRaises(frappe.PermissionError):
			price_visibility.set_floor_sees_prices(True)

	def test_status_tells_each_caller_their_own_answer(self):
		frappe.set_user(CUTTER)
		self.assertEqual(
			price_visibility.status(),
			{"floor_sees_prices": False, "you_see_prices": False, "can_change": False},
		)
		frappe.set_user(SELLER)
		self.assertTrue(price_visibility.status()["you_see_prices"])

	def test_the_change_is_audited(self):
		self._switch(True)
		self.assertTrue(
			frappe.db.exists(
				"Domain Audit Event",
				{"action": "settings.floor_sees_prices", "entity_id": COMPANY},
			)
		)


class TestRedact(IntegrationTestCase):
	def test_hidden_money_is_none_even_where_the_key_was_dropped(self):
		self.assertEqual(
			price_visibility.redact([{"name": "SO-1"}], ("grand_total",), allowed=False),
			[{"name": "SO-1", "grand_total": None}],
		)

	def test_an_allowed_caller_gets_the_data_untouched(self):
		row = {"name": "SO-1", "grand_total": 5}
		self.assertIs(price_visibility.redact(row, ("grand_total",), allowed=True), row)
