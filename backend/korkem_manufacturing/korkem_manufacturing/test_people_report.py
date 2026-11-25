# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Сотрудники» (owner, 25.11.2026): who did what, earned what, for a day,
a week or a month; a worker sees his own card only."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, getdate, nowdate

from korkem_manufacturing.services import facade_prices, mdf_orders, people_report, team

COMPANY = "KORKEM"
MANAGER = "people.manager@example.com"
BOSS = "people.boss@example.com"
CUTTER = "people.cutter@example.com"
FLAT = "МДФ Тест Люди 90°"
PVC = facade_prices.PVC


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestPeopleReport(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(MANAGER, "Sales User")
		_user(BOSS, "Manufacturing Manager")
		_user(CUTTER, "Manufacturing User")
		cls.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		assert cls.customer, "the seeded site has customers; no silent skip"

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price(FLAT, PVC, 10_000)
		self.tag = uuid.uuid4().hex[:6]
		frappe.db.sql("update `tabEmployee` set user_id = null where user_id = %s", CUTTER)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _person(self, name: str, posts: list[str]) -> str:
		self._as(MANAGER, team.add_person, name, posts)
		return frappe.db.get_value("Employee", {"employee_name": name, "company": COMPANY}, "name",
								   order_by="creation desc")

	def _order(self) -> str:
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
						head={"finish": PVC, "thickness_mm": 16},
						lines=[{"height_mm": 1000, "width_mm": 500, "qty": 4, "milling": FLAT}])  # 2 m²
		return self._as(MANAGER, mdf_orders.accept, card["name"])["name"]

	def test_the_day_shows_who_cut_what_and_the_worker_his_own_card(self):
		cutter = self._person(f"Ерлан Раскроев {self.tag}", ["cut.cutter"])
		other = self._person(f"Асет Другой {self.tag}", ["cnc.operator"])
		order = self._order()
		self._as(MANAGER, mdf_orders.set_stage, order, "cut", True, cutter)
		self._as(MANAGER, mdf_orders.set_stage, order, "mill", True, other)
		day = self._as(BOSS, people_report.overview, "day")
		row = next(r for r in day["people"] if r["employee"] == cutter)
		self.assertEqual((row["stages_done"], row["m2"], row["orders"], row["days"]), (1, 2.0, 1, 1))
		self.assertEqual(row["stages"][0]["stage"], "cut")
		self.assertEqual(row["post_titles"], [team.POSTS["cut.cutter"]])
		self.assertIsNone(row["money"])  # no login: no piece pay booked to him
		week = self._as(BOSS, people_report.overview, "week")
		self.assertEqual((getdate(week["to_date"]) - getdate(week["from_date"])).days, 6)
		# The floor sees no one's figures but his own.
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, people_report.overview)
		self._as(MANAGER, team.link_user, cutter, CUTTER)
		mine = self._as(CUTTER, people_report.person, cutter, "month")
		self.assertTrue(mine["me"])
		self.assertEqual([w["order"] for w in mine["works"]], [order])
		self.assertEqual(sum(d["m2"] for d in mine["by_day"]), 2.0)
		self.assertIsNotNone(mine["money"])  # a login: his money, even if zero
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, people_report.person, other, "month")

	def test_the_periods(self):
		self.assertEqual(people_report.span("day", "2026-11-25"), (getdate("2026-11-25"), getdate("2026-11-25")))
		self.assertEqual(people_report.span("week", "2026-11-25"), (getdate("2026-11-23"), getdate("2026-11-29")))
		self.assertEqual(people_report.span("month", "2026-11-25"), (getdate("2026-11-01"), getdate("2026-11-30")))
