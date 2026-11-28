# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Several people on one stage (owner, 26.11.2026: «бывает большой объём,
тогда 2 или 3 вакуумщика делают вместе, и система делит на ровную часть …
на все этапы»): equal by default, by hand when said, the stage's m² once."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import (
	facade_prices,
	mdf_orders,
	mdf_volume,
	people_report,
	stage_crew,
	team,
	team_people,
)

COMPANY = "KORKEM"
MANAGER = "crew.manager@example.com"
BOSS = "crew.boss@example.com"
FLAT = "МДФ Тест Бригада 90°"
PVC = facade_prices.PVC


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc({"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
						"roles": [{"role": role}]}).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestStageCrew(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(MANAGER, "Sales User")
		_user(BOSS, "Manufacturing Manager")
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

	def _person(self, name: str) -> str:
		full = f"{name} {self.tag}"
		self._as(MANAGER, team.add_person, full, ["pvc.vacuum"])
		return frappe.db.get_value("Employee", {"employee_name": full, "company": COMPANY}, "name",
								   order_by="creation desc")

	def _order(self) -> str:
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
						head={"finish": PVC, "thickness_mm": 16},
						lines=[{"height_mm": 1000, "width_mm": 500, "qty": 4, "milling": FLAT}])  # 2 m²
		return self._as(MANAGER, mdf_orders.accept, card["name"])["name"]

	def _m2(self, employee: str) -> float:
		row = next(r for r in self._as(BOSS, people_report.overview, "day")["people"] if r["employee"] == employee)
		return row["m2"]

	def test_equal_shares_and_shares_by_hand(self):
		a, b, c = self._person("Ералы"), self._person("Тима"), self._person("Шамиль")
		self.assertEqual([s for _, s in stage_crew.parse([a, b], COMPANY)], [50, 50])
		three = [s for _, s in stage_crew.parse([a, b, c], COMPANY)]
		self.assertAlmostEqual(sum(three), 100, places=4)
		self.assertAlmostEqual(three[0], 33.3333, places=4)
		by_hand = stage_crew.parse([{"employee": a, "share": 60}, {"employee": b, "share": 40}], COMPANY)
		self.assertEqual([s for _, s in by_hand], [60, 40])
		for wrong in ([{"employee": a, "share": 60}, {"employee": b, "share": 50}],  # 110 %
					  [{"employee": a, "share": 100}, {"employee": b, "share": 0}],  # nobody's 0 %
					  [a, a]):  # twice
			with self.assertRaises(frappe.ValidationError):
				stage_crew.parse(wrong, COMPANY)

	def test_a_stage_given_to_two_is_done_by_both_half_each(self):
		a, b = self._person("Ералы"), self._person("Тима")
		order = self._order()
		card = self._as(MANAGER, mdf_orders.assign, order, "vacuum", crew=[a, b])
		vacuum = next(s for s in card["stages"] if s["stage"] == "vacuum")
		self.assertEqual([p["employee"] for p in vacuum["given_crew"]], [a, b])
		self.assertEqual(vacuum["given_to"], a)
		# In work for each of them.
		self.assertEqual(team.in_work(COMPANY).get(b), 1)
		self.assertEqual([w["order"] for w in self._as(MANAGER, team_people.open_work, b)], [order])
		# Ticked with no name: the crew it was given to did it.
		card = self._as(MANAGER, mdf_orders.set_stage, order, "vacuum", True)
		vacuum = next(s for s in card["stages"] if s["stage"] == "vacuum")
		self.assertEqual([(p["employee"], p["share"]) for p in vacuum["crew"]], [(a, 50), (b, 50)])
		self.assertEqual((self._m2(a), self._m2(b)), (1.0, 1.0))
		# The stage itself is 2 m² once, not twice.
		day = mdf_volume._ticked(COMPANY, frappe.utils.getdate(nowdate()), frappe.utils.getdate(nowdate()))
		self.assertEqual(len([t for t in day if t[0] == order and t[1] == "vacuum"]), 1)
		# Unticked: nobody did it any more.
		self._as(MANAGER, mdf_orders.set_stage, order, "vacuum", False)
		self.assertEqual(stage_crew.get(order, "vacuum", "by"), [])

	def test_shares_by_hand_count_each_his_part(self):
		a, b = self._person("Ералы"), self._person("Тима")
		order = self._order()
		self._as(MANAGER, mdf_orders.set_stage, order, "cut", True,
				 crew=[{"employee": a, "share": 60}, {"employee": b, "share": 40}])
		self.assertEqual((self._m2(a), self._m2(b)), (1.2, 0.8))

	def test_one_of_a_crew_hands_his_place_over(self):
		a, b, c = self._person("Ералы"), self._person("Тима"), self._person("Шамиль")
		order = self._order()
		self._as(MANAGER, mdf_orders.assign, order, "vacuum",
				 crew=[{"employee": a, "share": 60}, {"employee": b, "share": 40}])
		# Тима's place — and his 40 % — goes to Шамиль; Ералы keeps his.
		self._as(MANAGER, team_people.hand_over, b, c)
		self.assertEqual(stage_crew.get(order, "vacuum", "to"), [(a, 60), (c, 40)])
		# Шамиль leaves with nobody named: Ералы has the stage alone.
		self._as(MANAGER, team_people.hand_over, c)
		self.assertEqual(stage_crew.get(order, "vacuum", "to"), [])
		self.assertEqual(frappe.db.get_value("Sales Order", order, mdf_orders.STAGE_TO["vacuum"]), a)

	def test_a_tick_with_nobody_known_is_named_later_and_keeps_its_date(self):
		# Owner, 28.11.2026: a tick asks nothing; who did it is said afterwards.
		a, b = self._person("Ералы"), self._person("Тима")
		order = self._order()
		# Two on the vacuum post and given to nobody: the tick names nobody.
		self._as(MANAGER, mdf_orders.set_stage, order, "vacuum", True)
		self.assertFalse(frappe.db.get_value("Sales Order", order, mdf_orders.STAGE_BY["vacuum"]))
		self.assertIn(order, mdf_orders.without_doer(COMPANY))
		row = next(r for r in self._as(MANAGER, mdf_orders.listing, search=order, no_doer=1)["orders"]
				   if r["name"] == order)
		vacuum = next(s for s in row["stages"] if s["stage"] == "vacuum")
		self.assertEqual((vacuum["done"], vacuum["by"]), (True, False))
		# Named three days later: the date stays the tick's, his m² count.
		ticked_on = add_days(nowdate(), -3)
		frappe.db.set_value("Sales Order", order, mdf_orders.STAGES["vacuum"], ticked_on)
		card = self._as(MANAGER, mdf_orders.set_doer, order, "vacuum", a)
		vacuum = next(s for s in card["stages"] if s["stage"] == "vacuum")
		self.assertEqual((vacuum["worker"], vacuum["done_on"]), (a, str(ticked_on)))
		self.assertNotIn(order, mdf_orders.without_doer(COMPANY))
		# A crew instead: each his share, the date still the same.
		card = self._as(MANAGER, mdf_orders.set_doer, order, "vacuum", crew=[a, b])
		vacuum = next(s for s in card["stages"] if s["stage"] == "vacuum")
		self.assertEqual([(p["employee"], p["share"]) for p in vacuum["crew"]], [(a, 50), (b, 50)])
		self.assertEqual(vacuum["done_on"], str(ticked_on))
		# Nobody again: back on the list.
		self._as(MANAGER, mdf_orders.set_doer, order, "vacuum")
		self.assertIn(order, mdf_orders.without_doer(COMPANY))

	def test_who_did_a_stage_not_ticked_cannot_be_said(self):
		a = self._person("Ералы")
		order = self._order()
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.set_doer, order, "vacuum", a)
