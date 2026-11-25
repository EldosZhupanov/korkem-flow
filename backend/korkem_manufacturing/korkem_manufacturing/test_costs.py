# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Where the shop's money goes (owner, 25.11.2026): the cost items he keeps,
the month's bills, the consumables on the shelf, and the month's picture."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_months, get_first_day, nowdate

from korkem_manufacturing.services import (
	consumables,
	cost_bills,
	cost_items,
	facade_prices,
	money_flow,
	morning_brief,
	urgent_expenses,
)

COMPANY = "KORKEM"
OWNER = "costs.owner@example.com"
CUTTER = "costs.cutter@example.com"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestCosts(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(OWNER, "Accounts Manager")
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		self.tag = uuid.uuid4().hex[:6]

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _item(self, title: str, group=cost_items.UTILITIES, mode="bill", **kw) -> dict:
		return self._as(OWNER, cost_items.add, f"{title} {self.tag}", group, mode, **kw)

	def test_the_list_starts_with_the_usual_items_and_is_the_owners(self):
		got = self._as(OWNER, cost_items.listing)
		titles = {i["title"] for i in got["items"]}
		self.assertIn("Электричество", titles)
		self.assertIn("Стрейч-плёнка", titles)
		self.assertEqual(got["groups"][0], cost_items.RAW)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, cost_items.listing)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, cost_items.add, "Свет 2", cost_items.UTILITIES)

	def test_items_are_added_renamed_archived_and_merged_with_their_history(self):
		tape = self._item("Скотч малярный", cost_items.CONSUMABLES, "other")
		twin = self._item("Малярный скотч", cost_items.CONSUMABLES, "other")
		with self.assertRaises(frappe.ValidationError):  # the same name twice
			self._item("Скотч малярный", cost_items.CONSUMABLES, "other")
		with self.assertRaises(frappe.ValidationError):
			self._as(OWNER, cost_items.add, "Х", cost_items.CONSUMABLES)
		with self.assertRaises(frappe.ValidationError):
			self._as(OWNER, cost_items.add, f"Что-то {self.tag}", "Нет такой группы")
		renamed = self._as(OWNER, cost_items.edit, tape["name"], title=f"Скотч бумажный {self.tag}",
						   area="Упаковка", monthly_limit=20_000)
		self.assertEqual((renamed["area"], renamed["monthly_limit"]), ("Упаковка", 20_000))
		# Money spent on it, then the two merged: the money follows.
		spent = self._as(CUTTER, urgent_expenses.file, 3_000, "Скотч в магазине", "Материалы", None, tape["name"])
		self._as(OWNER, urgent_expenses.decide, spent["expense"], 1)
		self._as(OWNER, cost_items.merge, tape["name"], twin["name"])
		self.assertEqual(frappe.db.get_value("Urgent Expense", spent["expense"], "cost_item"), twin["name"])
		names = {i["name"] for i in self._as(OWNER, cost_items.listing)["items"]}
		self.assertNotIn(tape["name"], names)
		self.assertIn(twin["name"], names)
		# Archived, not deleted; money is no longer put on it.
		self._as(OWNER, cost_items.archive, twin["name"])
		with self.assertRaises(frappe.ValidationError):
			self._as(CUTTER, urgent_expenses.file, 1_000, "Ещё скотч", "Материалы", None, twin["name"])
		with self.assertRaises(frappe.ValidationError):
			frappe.delete_doc("Cost Item", twin["name"], ignore_permissions=True)
		back = self._as(OWNER, cost_items.listing, None, 1)
		self.assertTrue(next(i for i in back["items"] if i["name"] == twin["name"])["archived"])

	def test_a_months_bill_with_the_meter_and_last_months_beside_it(self):
		power = self._item("Свет цеха", unit="кВт·ч")
		this = str(get_first_day(nowdate()))
		last = str(add_months(get_first_day(nowdate()), -1))
		self._as(OWNER, cost_bills.put, power["name"], last, 150_000, 1_000, 3_000)
		got = self._as(OWNER, cost_bills.put, power["name"], this, 185_000, 3_000, 6_700, "ноябрь")
		row = next(b for b in got["bills"] if b["item"] == power["name"])
		self.assertEqual((row["amount"], row["last_amount"], row["used"], row["meter_start"]),
						 (185_000, 150_000, 3_700, 3_000))
		# Changed, not doubled.
		got = self._as(OWNER, cost_bills.put, power["name"], this, 190_000)
		self.assertEqual(next(b for b in got["bills"] if b["item"] == power["name"])["amount"], 190_000)
		with self.assertRaises(frappe.ValidationError):
			self._as(OWNER, cost_bills.put, power["name"], str(add_months(this, 1)), 1)
		with self.assertRaises(frappe.ValidationError):
			self._as(OWNER, cost_bills.put, power["name"], this, 1, 500, 100)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, cost_bills.month)

	def test_consumables_are_bought_taken_and_said_when_low(self):
		stretch = self._item("Стрейч", cost_items.CONSUMABLES, "stock", unit="рулон")
		self.assertTrue(stretch["item"])
		self._as(OWNER, consumables.receive, stretch["name"], 3, 4_000)
		self._as(OWNER, consumables.set_minimum, stretch["name"], 3)
		after = self._as(CUTTER, consumables.take, stretch["name"], 1)
		row = next(x for x in after["items"] if x["item"] == stretch["name"])
		self.assertEqual((row["on_hand"], row["low"], row["taken_30d"]), (2, True, 1))
		self.assertIsNone(row["price"])  # the floor does not see what it costs
		owner_row = next(x for x in self._as(OWNER, consumables.listing)["items"] if x["item"] == stretch["name"])
		self.assertEqual(owner_row["price"], 4_000)
		with self.assertRaises(frappe.ValidationError):
			self._as(CUTTER, consumables.take, stretch["name"], 5)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, consumables.receive, stretch["name"], 1, 100)
		self.assertIn(stretch["title"], [x["title"] for x in consumables.low(COMPANY)])
		# Not in the list: added from the floor, marked new.
		sponge = self._as(CUTTER, cost_items.quick_add, f"Губка {self.tag}")
		self.assertTrue(sponge["new"])
		self.assertEqual(self._as(CUTTER, cost_items.quick_add, f"губка {self.tag}")["name"], sponge["name"])

	def test_the_months_picture_with_its_limits(self):
		power = self._item("Электроэнергия", monthly_limit=100_000, behaviour="fixed")
		stretch = self._item("Стрейч-плёнка", cost_items.CONSUMABLES, "stock", unit="рулон")
		self._as(OWNER, cost_bills.put, power["name"], nowdate(), 140_000)
		self._as(OWNER, consumables.receive, stretch["name"], 2, 5_000)
		self._as(CUTTER, consumables.take, stretch["name"], 1)
		got = self._as(OWNER, money_flow.month)
		rows = {r["key"]: r for r in got["items"]}
		self.assertEqual(rows[power["name"]]["amount"], 140_000)
		self.assertEqual(rows[stretch["name"]]["amount"], 5_000)
		self.assertIn(cost_items.UTILITIES, {g["group"] for g in got["groups"]})
		self.assertGreaterEqual(got["fixed"], 140_000)
		over = [a for a in got["alerts"] if a["kind"] == "limit" and a["title"] == power["title"]]
		self.assertEqual(over[0]["over"], 40)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, money_flow.month)
		# The morning brief says it to the owner.
		brief = morning_brief.collect(COMPANY, staff=False)
		self.assertIn(power["title"], [c["title"] for c in brief["costs"]])
		text = morning_brief.text(brief, COMPANY)
		self.assertIn("выше лимита", text)

	def test_a_merged_items_money_is_counted_on_its_target(self):
		a = self._item("Вода", behaviour="fixed")
		b = self._item("Водоснабжение", behaviour="fixed")
		self._as(OWNER, cost_bills.put, a["name"], nowdate(), 7_000)
		self._as(OWNER, cost_bills.put, b["name"], nowdate(), 3_000)
		self._as(OWNER, cost_items.merge, a["name"], b["name"])
		rows = {r["key"]: r for r in self._as(OWNER, money_flow.month)["items"]}
		self.assertEqual(rows[b["name"]]["amount"], 10_000)
		self.assertNotIn(a["name"], rows)
