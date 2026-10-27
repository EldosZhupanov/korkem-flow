# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""A facade position carries what the floor reads: thickness, decors, edge, colour group."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import (
	facade_jobs,
	facade_order,
	facade_prices,
	facade_quote,
	facade_spec,
	material_stock,
)

COMPANY = "KORKEM"
PVC = facade_prices.PVC
SELLER = "spec.seller@example.com"
CUTTER = "spec.cutter@example.com"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


def _line(**spec) -> dict:
	return {"width_mm": 500, "height_mm": 400, "qty": 1, "milling": "Квадро", "finish": PVC, **spec}


class TestFacadeSpec(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(SELLER, "Sales User")
		_user(CUTTER, "Manufacturing User")
		facade_prices.seed_company(COMPANY)

	def setUp(self):
		frappe.set_user("Administrator")
		for kind, value in (
			(facade_spec.DECOR, "Графит"),
			(facade_spec.DECOR, "Белый матовый"),
			(facade_spec.EDGE, "R3"),
		):
			material_stock.add_option(kind, value)
		self.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _order(self, *lines) -> str:
		return facade_order.create_order(
			customer=self.customer, delivery_date=add_days(nowdate(), 10), lines=list(lines)
		)["sales_order"]

	# --- the quote --------------------------------------------------------------

	def test_the_spec_rides_along_and_the_group_defaults_to_the_face_decor(self):
		line = facade_quote.quote(
			[_line(thickness_mm=19, decor_top="Графит", decor_bottom="Белый матовый", edge_profile="R3")]
		)["lines"][0]
		self.assertEqual(
			(line["thickness_mm"], line["decor_top"], line["decor_bottom"], line["edge_profile"]),
			(19, "Графит", "Белый матовый", "R3"),
		)
		self.assertEqual(line["color_group"], "Графит")

	def test_the_spec_does_not_change_the_price(self):
		plain = facade_quote.quote([_line()])["total"]
		specified = facade_quote.quote([_line(decor_top="Графит", edge_profile="R3")])["total"]
		self.assertEqual(plain, specified)

	def test_a_decor_nobody_listed_is_refused_not_stored_as_typed(self):
		with self.assertRaises(frappe.ValidationError):
			facade_quote.quote([_line(decor_top="Графитт")])

	def test_an_impossible_thickness_is_refused(self):
		for thickness in (0, 200, "толстый"):
			with self.subTest(thickness=thickness), self.assertRaises(frappe.ValidationError):
				facade_quote.quote([_line(thickness_mm=thickness)])

	# --- the order and the floor -------------------------------------------------

	def test_the_order_keeps_the_spec_and_the_floor_reads_it(self):
		order = self._order(_line(thickness_mm=19, decor_top="Графит", edge_profile="R3"))
		job = next(j for j in facade_jobs.jobs(limit=200)["jobs"] if j["sales_order"] == order)
		self.assertEqual(
			(job["thickness_mm"], job["decor_top"], job["edge_profile"], job["color_group"]),
			(19, "Графит", "R3", "Графит"),
		)

	def test_any_positions_can_be_grouped_by_hand(self):
		order = self._order(_line(), _line(), _line())
		lines = frappe.get_all(
			"Sales Order Item",
			filters={"parent": order, "korkem_width_mm": [">", 0]},
			pluck="name",
			order_by="idx",
		)
		picked = [lines[0], lines[2]]
		result = self._as(SELLER, facade_spec.set_color_group, picked, "Кашемир")
		self.assertEqual(result["changed"], 2)
		rows = frappe.get_all(
			"Sales Order Item", filters={"parent": order}, fields=["name", "korkem_color_group"]
		)
		groups = {row.name: row.korkem_color_group for row in rows}
		self.assertEqual([groups[name] for name in lines], ["Кашемир", None, "Кашемир"])
		audited = {"action": "manufacturing.color_group", "entity_id": order}
		self.assertTrue(frappe.db.exists("Domain Audit Event", audited))

	def test_the_floor_does_not_regroup(self):
		order = self._order(_line())
		line = frappe.db.get_value("Sales Order Item", {"parent": order, "korkem_width_mm": [">", 0]}, "name")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, facade_spec.set_color_group, [line], "Кашемир")

	# --- the lists ------------------------------------------------------------------

	def test_a_decor_an_order_uses_is_switched_off_not_deleted(self):
		material_stock.add_option(facade_spec.DECOR, "Кашемир")
		self._order(_line(decor_top="Кашемир"))
		option = frappe.db.get_value(
			"Material Option", {"company": COMPANY, "kind": facade_spec.DECOR, "value": "Кашемир"}, "name"
		)
		self.assertEqual(material_stock.remove_option(option)["outcome"], "disabled")
