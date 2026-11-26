# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Когда будет готово» from the shop's load (owner, 25.11.2026)."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, getdate, nowdate

from korkem_manufacturing.services import facade_prices, mdf_customers, mdf_orders, ready_estimate

COMPANY = "KORKEM"
MANAGER = "ready.manager@example.com"
CUTTER = "ready.cutter@example.com"
FLAT = "МДФ Тест Срок 90°"
PVC = facade_prices.PVC


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestReadyEstimate(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(MANAGER, "Sales User")
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price(FLAT, PVC, 10_000)
		tail = uuid.uuid4().int % 10_000_000
		self.customer = self._as(MANAGER, mdf_customers.add, f"Срок Тест {tail}", f"8 707 {tail:07d}")["name"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _order(self, qty: int) -> str:
		card = self._as(
			MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
			head={"finish": PVC, "thickness_mm": 16},
			lines=[{"height_mm": 1000, "width_mm": 500, "qty": qty, "milling": FLAT}],  # 0.5 m² a piece
		)
		return self._as(MANAGER, mdf_orders.accept, card["name"])["name"]

	def test_the_date_grows_with_the_queue_at_the_shops_pace(self):
		# Four weeks at about 4 m² a day through the press: 96 m² made ready.
		for back in range(1, 5):
			done = self._order(48)  # 24 m²
			frappe.db.set_value("Sales Order", done, "korkem_ready_on", add_days(nowdate(), -back * 5))
		first = self._as(MANAGER, ready_estimate.estimate, {"pvc": 1})
		pvc = next(x for x in first["lanes"] if x["lane"] == "pvc")
		self.assertTrue(pvc["known"])
		self.assertGreater(pvc["pace_m2"], 0)
		# 200 m² more taken in: the same order is ready later.
		self._order(400)
		later = self._as(MANAGER, ready_estimate.estimate, {"pvc": 1})
		self.assertGreater(later["days"], first["days"])
		self.assertGreater(getdate(later["ready_on"]), getdate(first["ready_on"]))
		self.assertGreaterEqual(later["days"], ready_estimate.LEAST_DAYS["pvc"])
		# An order is not ahead of itself.
		own = self._order(2)
		self.assertLessEqual(self._as(MANAGER, ready_estimate.estimate, {"pvc": 1}, own)["days"], later["days"])

	def test_empty_and_unknown_and_not_for_the_shop(self):
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, ready_estimate.estimate, {})
		got = self._as(MANAGER, ready_estimate.estimate, '{"raw": 2}')
		self.assertGreaterEqual(got["days"], ready_estimate.LEAST_DAYS["raw"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, ready_estimate.estimate, {"pvc": 1})

	def test_sundays_are_not_working_days(self):
		saturday = getdate("2026-11-28")
		self.assertEqual(str(ready_estimate.working_days_from(saturday, 1)), "2026-11-30")
		self.assertEqual(str(ready_estimate.working_days_from(saturday, 0)), "2026-11-28")
		self.assertEqual(str(ready_estimate.working_days_from(getdate("2026-11-29"), 0)), "2026-11-30")
		self.assertEqual(str(ready_estimate.working_days_from(getdate("2026-11-23"), 6)), "2026-11-30")

	def test_the_due_window_gives_the_earliest_a_safe_day_and_the_days_load(self):
		# «Срок» (owner, 27.11.2026): never earlier than the estimate, a day of
		# reserve after it, each day's m² already due.
		taken = self._order(10)  # 5 m², due in a week
		got = self._as(MANAGER, ready_estimate.due_options, {"pvc": 1})
		estimate = self._as(MANAGER, ready_estimate.estimate, {"pvc": 1})
		self.assertEqual(got["earliest"], estimate["ready_on"])
		self.assertEqual(got["safe"], str(ready_estimate.working_days_from(got["earliest"], 1)))
		due = str(getdate(frappe.db.get_value("Sales Order", taken, "delivery_date")))
		day = next(d for d in got["days"] if d["date"] == due)
		self.assertGreaterEqual(day["m2"], 5)
		self.assertGreaterEqual(day["orders"], 1)
		# A film nobody keeps: said so, and no date made up for it.
		odd = self._as(MANAGER, ready_estimate.due_options, {"pvc": 1}, films=["Нет такой плёнки"])
		self.assertEqual(odd["films"], [{"decor": "Нет такой плёнки", "free_m": None, "short": False,
										 "comes_on": None, "supplier": None}])
		# Each film by its own m², as the form sends it.
		by_film = self._as(MANAGER, ready_estimate.due_options, {"pvc": 1},
						   films={"Нет такой плёнки": 0.5})
		self.assertEqual(by_film["films"][0]["decor"], "Нет такой плёнки")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, ready_estimate.due_options, {"pvc": 1})
