# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The customer's card made useful (owner, 21.11.2026: «как бы ты настроил»):
his orders by where they are in the shop, one payment for all he owes,
the reminder of all of it, and his history on one line with notes."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_manufacturing.services import customer_card, facade_prices, mdf_customers, mdf_orders

COMPANY = "KORKEM"
MANAGER = "card.manager@example.com"
CUTTER = "card.cutter@example.com"
FLAT = "МДФ Тест Карточка 90°"
PVC = facade_prices.PVC


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestCustomerCard(IntegrationTestCase):
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
		self.customer = self._as(MANAGER, mdf_customers.add, f"Карточка Тест {tail}", f"8 705 {tail:07d}")["name"]
		self.orders = [self._order() for _ in range(2)]

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _order(self) -> str:
		card = self._as(
			MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
			head={"finish": PVC, "thickness_mm": 16},
			lines=[{"height_mm": 1000, "width_mm": 500, "qty": 2, "milling": FLAT}],  # 1 m²
		)
		return self._as(MANAGER, mdf_orders.accept, card["name"])["name"]

	def test_each_order_says_where_it_is_its_area_and_how_long_it_owes(self):
		first = self.orders[0]
		stages = mdf_orders.stages_for(PVC)
		self._as(MANAGER, mdf_orders.set_stage, first, stages[0])
		card = self._as(MANAGER, customer_card.card, self.customer)
		row = next(o for o in card["orders"] if o["name"] == first)
		self.assertEqual([s["key"] for s in row["stages"]], [s for s in stages if s in mdf_orders.STAGES])
		self.assertTrue(row["stages"][0]["done"])
		self.assertFalse(row["stages"][-1]["done"])
		self.assertEqual(row["area"], 1.0)
		self.assertEqual(row["debt_days"], 0)
		self.assertIn("limit", card)
		self.assertIsInstance(card["terms"], dict)

	def test_one_payment_closes_the_oldest_orders_first(self):
		old, new = self.orders
		made = self._as(MANAGER, customer_card.pay, self.customer, 15_000, "Перевод")
		self.assertEqual([(s["order"], s["amount"]) for s in made["split"]], [(old, 10_000), (new, 5_000)])
		self.assertEqual(flt(frappe.db.get_value("Sales Order", old, "advance_paid")), 10_000)
		self.assertEqual(flt(frappe.db.get_value("Sales Order", new, "advance_paid")), 5_000)
		self.assertEqual(made["card"]["figures"]["debt"], 5_000)
		# More than he owes is refused — an overpayment goes on its order.
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, customer_card.pay, self.customer, 6_000, "Перевод")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, customer_card.pay, self.customer, 1_000, "Перевод")
		# The history says it once, not once per order.
		history = self._as(MANAGER, customer_card.history, self.customer)
		split = [e for e in history if "разнесена" in e["text"]]
		self.assertEqual(len(split), 1)
		self.assertEqual(split[0]["kind"], "money")
		self.assertFalse(any(e["text"].startswith("Оплата (общая") for e in history))

	def test_the_reminder_names_every_order_owing_and_the_sum(self):
		said = self._as(MANAGER, customer_card.debt_text, self.customer)
		self.assertEqual(said["debt"], 20_000)
		self.assertEqual(set(said["orders"]), set(self.orders))
		self.assertIn("20 000 ₸", said["text"])
		self._as(MANAGER, customer_card.reminded, self.customer)
		for order in self.orders:
			self.assertEqual(getdate(frappe.db.get_value("Sales Order", order, "korkem_reminded_on")),
							 getdate(nowdate()))
		history = self._as(MANAGER, customer_card.history, self.customer)
		self.assertEqual(history[0]["kind"], "message")

	def test_his_history_holds_his_orders_and_the_notes_on_him(self):
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, customer_card.add_note, self.customer, "  ")
		history = self._as(MANAGER, customer_card.add_note, self.customer, "Звонить после 14:00")
		self.assertEqual((history[0]["text"], history[0]["kind"]), ("Звонить после 14:00", "note"))
		accepted = [e for e in history if e["kind"] == "order" and "принят" in e["text"]]
		self.assertEqual({e["order"] for e in accepted}, set(self.orders))
		# A shop hand who may see the card for its film sees no facade orders
		# in the history either.
		theirs = self._safe(CUTTER, customer_card.history, self.customer)
		self.assertFalse([e for e in theirs or [] if e["kind"] == "order"])

	def _safe(self, user, fn, *args):
		try:
			return self._as(user, fn, *args)
		except frappe.PermissionError:
			return None

	def test_the_reconciliation_has_the_balance_before_the_sales_and_payments_after(self):
		old, new = self.orders
		made = self._as(MANAGER, customer_card.pay, self.customer, 12_000, "Перевод")
		print("DBG split", made["split"], "payments", made["card"]["payments"])
		print("DBG PER", frappe.db.sql("""select per.parent, per.reference_name, per.allocated_amount, pe.company, pe.docstatus, pe.posting_date from `tabPayment Entry Reference` per join `tabPayment Entry` pe on pe.name = per.parent where per.reference_name in %s""", (tuple(self.orders),), as_dict=True))
		print("DBG company", frappe.db.get_value("Sales Order", old, ["company", "customer"]), self.customer)
		act = self._as(MANAGER, customer_card.reconciliation, self.customer)
		self.assertEqual((act["opening"], act["debit"], act["credit"], act["closing"]), (0, 20_000, 12_000, 8_000))
		self.assertEqual([r["order"] for r in act["rows"] if r["debit"]], [old, new])
		self.assertEqual(sum(r["credit"] for r in act["rows"]), 12_000)
		# A period after it all: what was owed comes as the opening balance.
		later = add_days(nowdate(), 1)
		act = self._as(MANAGER, customer_card.reconciliation, self.customer, later, later)
		self.assertEqual((act["opening"], act["rows"], act["closing"]), (8_000, [], 8_000))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, customer_card.reconciliation, self.customer, later, nowdate())
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, customer_card.reconciliation, self.customer)
