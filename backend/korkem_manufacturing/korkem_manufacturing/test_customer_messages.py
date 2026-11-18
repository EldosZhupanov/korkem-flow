# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Кому написать», the customer's card and «Итоги дня» (owner, 18.11.2026).

An order ready and not told is on the list, with the words ready to send;
once the manager has sent them it is not asked again. A debt is reminded of
some days after the order left, and not every day. The owner's evening
summary is said once a day, at his hour."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import (
	customer_card,
	customer_messages,
	daily_summary,
	facade_prices,
	mdf_customers,
	mdf_orders,
)

COMPANY = "KORKEM"
MANAGER = "messages.manager@example.com"
CUTTER = "messages.cutter@example.com"
FLAT = "МДФ Тест Сообщения 90°"
PVC = facade_prices.PVC


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestCustomerMessages(IntegrationTestCase):
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
		self.name = f"Сообщение Тест {tail}"
		self.customer = self._as(MANAGER, mdf_customers.add, self.name, f"8 702 {tail:07d}")["name"]
		card = self._as(
			MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
			head={"finish": PVC, "thickness_mm": 16},
			lines=[{"height_mm": 1000, "width_mm": 500, "qty": 2, "milling": FLAT}],
		)
		self.order = self._as(MANAGER, mdf_orders.accept, card["name"])["name"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _ready(self):
		for stage in mdf_orders.stages_for(PVC):
			self._as(MANAGER, mdf_orders.set_stage, self.order, stage)

	def test_a_ready_order_is_on_the_list_with_its_words_until_told(self):
		self.assertNotIn(self.order, [r["order"] for r in self._as(MANAGER, customer_messages.todo)["ready"]])
		self._ready()
		ready = {r["order"]: r for r in self._as(MANAGER, customer_messages.todo)["ready"]}
		row = ready[self.order]
		self.assertIn("готов", row["text"])
		self.assertIn(self.name, row["text"])
		self.assertIn("10 000 ₸", row["text"])  # nothing paid: the debt is said
		self._as(MANAGER, customer_messages.mark, customer_messages.READY, self.order)
		self.assertNotIn(self.order, [r["order"] for r in self._as(MANAGER, customer_messages.todo)["ready"]])
		self.assertEqual(str(frappe.db.get_value("Sales Order", self.order, "korkem_told_on")), nowdate())

	def test_a_debt_is_reminded_after_a_few_days_and_not_every_day(self):
		self._ready()
		mdf_orders.hand_over(self.order, comment="Доплатит на неделе")
		debts = lambda: [r["order"] for r in self._as(MANAGER, customer_messages.todo)["debts"]]  # noqa: E731
		self.assertNotIn(self.order, debts())  # left today: too soon
		frappe.db.set_value("Sales Order", self.order, "korkem_handed_over_on",
							add_days(nowdate(), -customer_messages.AFTER_DAYS))
		self.assertIn(self.order, debts())
		self._as(MANAGER, customer_messages.mark, customer_messages.DEBT, self.order)
		self.assertNotIn(self.order, debts())
		self.assertEqual(frappe.db.get_value("Sales Order", self.order, "korkem_reminders"), 1)
		frappe.db.set_value("Sales Order", self.order, "korkem_reminded_on",
							add_days(nowdate(), -customer_messages.REPEAT_DAYS))
		self.assertIn(self.order, debts())

	def test_the_owner_writes_his_own_words_and_they_must_name_the_customer(self):
		self._as(MANAGER, customer_messages.set_template, customer_messages.READY, "Привет, {имя}! № {номер} ждёт.")
		self.addCleanup(lambda: self._as(MANAGER, customer_messages.set_template, customer_messages.READY, ""))
		self._ready()
		text = self._as(MANAGER, customer_messages.text_for, self.order)["text"]
		self.assertTrue(text.startswith(f"Привет, {self.name}!"))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, customer_messages.set_template, customer_messages.READY, "Заказ готов")

	def test_the_customers_card_counts_his_orders_and_what_he_owes(self):
		card = self._as(MANAGER, customer_card.card, self.customer)
		self.assertEqual((card["figures"]["orders"], card["figures"]["debt"]), (1, 10_000))
		self.assertEqual(card["orders"][0]["name"], self.order)
		self.assertEqual(card["phone"][:5], "+7702")

	def test_a_shop_hand_has_no_list_and_no_facade_orders_on_a_card(self):
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, customer_messages.todo)
		card = self._as(CUTTER, customer_card.card, self.customer)
		self.assertNotIn("orders", card)

	def test_the_evening_summary_is_said_once_a_day_at_the_owners_hour(self):
		self._as(MANAGER, daily_summary.set_settings, enabled=1, hour=0)
		self.addCleanup(lambda: frappe.db.set_default(f"korkem_daily_summary:{COMPANY}", None))
		self.addCleanup(lambda: frappe.db.set_default(f"korkem_daily_summary_sent:{COMPANY}", None))
		frappe.db.set_default(f"korkem_daily_summary_sent:{COMPANY}", None)
		preview = self._as(MANAGER, daily_summary.preview)
		self.assertIn("Итоги дня", preview["text"])
		self.assertGreaterEqual(preview["accepted"], 1)
		self.assertIn(COMPANY, daily_summary.run())
		self.assertNotIn(COMPANY, daily_summary.run())
