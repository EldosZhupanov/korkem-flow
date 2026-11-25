# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Рейтинг клиентов» (owner, 25.11.2026): who brings the most money, who
pays fast, who drags it out."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import (
	customer_card,
	customer_rating,
	facade_prices,
	mdf_customers,
	mdf_orders,
)

COMPANY = "KORKEM"
MANAGER = "rating.manager@example.com"
CUTTER = "rating.cutter@example.com"
FLAT = "МДФ Тест Рейтинг 90°"
PVC = facade_prices.PVC


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestCustomerRating(IntegrationTestCase):
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

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _customer(self) -> str:
		tail = uuid.uuid4().int % 10_000_000
		return self._as(MANAGER, mdf_customers.add, f"Рейтинг Тест {tail}", f"8 706 {tail:07d}")["name"]

	def _order(self, customer: str, sheets: int = 1) -> str:
		card = self._as(
			MANAGER, mdf_orders.save_draft, customer=customer, delivery_date=add_days(nowdate(), 7),
			head={"finish": PVC, "thickness_mm": 16},
			lines=[{"height_mm": 1000, "width_mm": 500, "qty": 2 * sheets, "milling": FLAT}],
		)
		return self._as(MANAGER, mdf_orders.accept, card["name"])["name"]

	def test_the_one_who_brings_more_is_first_and_one_long_owing_drags_it_out(self):
		big, small = self._customer(), self._customer()
		self._order(big, sheets=3)  # 30 000
		owing = self._order(small)  # 10 000, taken 40 days ago and not paid
		frappe.db.set_value("Sales Order", owing, "korkem_handed_over_on", add_days(nowdate(), -40))
		self._as(MANAGER, customer_card.pay, big, 30_000, "Перевод")
		got = self._as(MANAGER, customer_rating.rating, "all")
		rows = {r["customer"]: r for r in got["customers"]}
		names = [r["customer"] for r in got["customers"]]
		self.assertLess(names.index(big), names.index(small))
		self.assertEqual((rows[big]["total"], rows[big]["debt"]), (30_000, 0))
		self.assertEqual(rows[small]["debt"], 10_000)
		self.assertEqual(rows[small]["oldest_debt_days"], 40)
		self.assertEqual(rows[small]["mark"], "slow")
		self.assertIn(rows[big]["class"], ("A", "B", "C"))
		self.assertGreater(rows[big]["share"], rows[small]["share"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, customer_rating.rating)

	def test_the_marks(self):
		self.assertEqual(customer_rating.mark(None, None), None)
		self.assertEqual(customer_rating.mark(1.5, None), "fast")
		self.assertEqual(customer_rating.mark(1.5, 10), "usual")  # fast, but owes past a week
		self.assertEqual(customer_rating.mark(6, 0), "usual")
		self.assertEqual(customer_rating.mark(20, 0), "slow")
		self.assertEqual(customer_rating.mark(None, 45), "slow")
		self.assertEqual(customer_rating.pay_days(None, "2026-11-20"), 0)
		self.assertEqual(customer_rating.pay_days("2026-11-10", "2026-11-20"), 10)
		self.assertEqual(customer_rating.pay_days("2026-11-10", "2026-11-05"), 0)
