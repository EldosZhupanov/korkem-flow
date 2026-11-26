# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Цех» (owner, 26.11.2026): the month's plan against what is made, each
stage in the order an order goes, the late orders — and a tick with no name
counted for the one person on the post."""

from __future__ import annotations

import uuid
from unittest import mock

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, getdate, nowdate

from korkem_manufacturing.services import facade_prices, mdf_orders, shop_board, team

COMPANY = "KORKEM"
MANAGER = "board.manager@example.com"
FLAT = "МДФ Тест Цех 90°"
PVC = facade_prices.PVC


class TestShopBoard(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		if not frappe.db.exists("User", MANAGER):
			frappe.get_doc({"doctype": "User", "email": MANAGER, "first_name": "Board", "send_welcome_email": 0,
							"roles": [{"role": "Sales User"}]}).insert(ignore_permissions=True)
		frappe.defaults.set_user_default("Company", COMPANY, user=MANAGER)
		cls.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		assert cls.customer, "the seeded site has customers; no silent skip"

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price(FLAT, PVC, 10_000)
		self.tag = uuid.uuid4().hex[:6]

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _order(self) -> str:
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
						head={"finish": PVC, "thickness_mm": 16},
						lines=[{"height_mm": 1000, "width_mm": 500, "qty": 4, "milling": FLAT}])  # 2 m²
		return self._as(MANAGER, mdf_orders.accept, card["name"])["name"]

	def test_the_working_days_leave_sunday_out(self):
		self.assertEqual(shop_board.workdays(getdate("2026-11-01"), getdate("2026-11-30")), 25)
		self.assertFalse(shop_board.workday(getdate("2026-11-29")))  # a Sunday

	def test_sanding_is_a_department_after_cnc_and_keeps_its_posts(self):
		# Owner, 26.11.2026: «где у нас тут шлифовка?» — after ЧПУ, as the order goes.
		order = [d["key"] for d in team.structure()["departments"]]
		self.assertEqual(order[order.index("cnc") + 1], "sand")
		sand = next(d for d in team.structure()["departments"] if d["key"] == "sand")
		self.assertEqual([p["key"] for p in sand["posts"]], ["pvc.sander", "paint.sander"])
		self.assertEqual(team.department_of("pvc.sander"), "sand")
		self.assertEqual(team.department_of("pvc.vacuum"), "pvc")
		# The keys people already hold are the same: nobody loses a post.
		self.assertEqual(team.parse("pvc.sander\npaint.sander"), ["pvc.sander", "paint.sander"])
		self.assertEqual(mdf_orders.STAGE_NAMES["mill"], "ЧПУ")

	def test_the_board_counts_today_by_stage_and_by_person(self):
		self._as(MANAGER, team.add_person, f"Ерлан Цехов {self.tag}", ["cut.cutter"])
		cutter = frappe.db.get_value("Employee", {"employee_name": f"Ерлан Цехов {self.tag}"}, "name")
		order = self._order()
		self._as(MANAGER, mdf_orders.set_stage, order, "cut", True, cutter)
		b = self._as(MANAGER, shop_board.board)
		self.assertEqual([s["stage"] for s in b["stages"]], list(shop_board.FLOW))
		cut = b["stages"][0]
		self.assertGreaterEqual(cut["today_m2"], 2.0)
		person = next(p for post in cut["posts"] for p in post["people"] if p["employee"] == cutter)
		self.assertEqual(person["today_m2"], 2.0)
		# The order moved on to milling: it waits there now.
		mill = b["stages"][1]
		self.assertGreaterEqual(mill["waiting_m2"], 2.0)
		self.assertGreater(b["month"]["taken_m2"], 0)
		self.assertIn(b["month"]["plan_from"], ("target", "due"))
		self.assertEqual([d["department"] for d in b["side"]], ["film_sales", "warehouse"])
		# The shop's own goal is its plan once set — not «Итоги»'s sales goal.
		self._as(MANAGER, shop_board.set_target, 500)
		self.assertEqual(self._as(MANAGER, shop_board.board)["month"]["plan_m2"], 500)
		self._as(MANAGER, shop_board.set_target, None)

	def test_a_tick_with_no_name_is_the_one_person_s_on_the_post(self):
		order = self._order()
		# Given to nobody (accepting may have given it to a lone vacuum operator).
		frappe.db.set_value("Sales Order", order, mdf_orders.STAGE_TO["vacuum"], None)
		self._as(MANAGER, team.add_person, f"Тима Вакуумов {self.tag}", ["pvc.vacuum"])
		only = frappe.db.get_value("Employee", {"employee_name": f"Тима Вакуумов {self.tag}"}, "name")
		one = [{"employee": only, "name": "Тима", "posts": ["pvc.vacuum"]}]
		with mock.patch.object(team, "holders", return_value=one):
			self._as(MANAGER, mdf_orders.set_stage, order, "vacuum", True)
		self.assertEqual(frappe.db.get_value("Sales Order", order, mdf_orders.STAGE_BY["vacuum"]), only)
		# Two on the post: not a guess — nobody.
		self._as(MANAGER, mdf_orders.set_stage, order, "vacuum", False)
		two = [*one, {"employee": "HR-EMP-X", "name": "Ералы", "posts": ["pvc.vacuum"]}]
		with mock.patch.object(team, "holders", return_value=two):
			self._as(MANAGER, mdf_orders.set_stage, order, "vacuum", True)
		self.assertIsNone(frappe.db.get_value("Sales Order", order, mdf_orders.STAGE_BY["vacuum"]))

	def test_the_floor_does_not_see_the_board(self):
		with self.assertRaises(frappe.PermissionError):
			self._as("Guest", shop_board.board)
