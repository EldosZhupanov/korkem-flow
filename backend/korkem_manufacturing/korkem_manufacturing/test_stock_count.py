# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The month-end count and what the month really used — the owner's own
example: bought 50 sheets, orders took 40, two are left on the shelf."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, get_last_day, nowdate

from korkem_manufacturing import setup
from korkem_manufacturing.services import material_stock, stock_count

COMPANY = setup.COMPANY
MANAGER = "count.manager@example.com"
CUTTER = "count.cutter@example.com"
MAKER = "SC-Kronospan"
#: A thickness no other test uses. Facade orders pick «an MDF of that
#: thickness», and an 18 mm sheet of this test's once took the place of
#: test_facade_materials' own on CI (30.10.2026).
THICKNESS = "19"
SUPPLIER = "SC Supplier Test"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestTheMonthEndCount(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(MANAGER, "Sales Manager")
		_user(CUTTER, "Manufacturing User")
		for kind, value in (("Толщина МДФ", THICKNESS), ("Производитель", MAKER)):
			material_stock.add_option(kind, value)
		material_stock.add_supplier(SUPPLIER)
		cls.supplier = frappe.db.get_value("Supplier", {"supplier_name": SUPPLIER}, "name")
		cls.mdf = material_stock.define_material(material_stock.MDF, "лист", thickness=THICKNESS, manufacturer=MAKER)["item"]
		cls.order = frappe.db.get_value("Sales Order", {"company": COMPANY, "docstatus": 1}, "name")
		assert cls.order, "the seeded site has submitted orders; no silent skip"
		frappe.db.commit()

	def setUp(self):
		frappe.set_user("Administrator")
		self.posted: list[tuple[str, str]] = []

	def tearDown(self):
		frappe.set_user("Administrator")
		for doctype, name in reversed(self.posted):
			doc = frappe.get_doc(doctype, name)
			if doc.docstatus == 1:
				doc.flags.ignore_permissions = True
				doc.cancel()
		frappe.db.commit()

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _bought(self, qty):
		receipt = material_stock.receive(self.mdf, qty, 21_000, self.supplier)["receipt"]
		self.posted.append(("Stock Entry", receipt))

	def _taken_by_orders(self, qty):
		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Issue",
				"purpose": "Material Issue",
				"company": COMPANY,
				"korkem_sales_order": self.order,
				"items": [
					{"item_code": self.mdf, "qty": qty,
					 "s_warehouse": material_stock._receiving_warehouse(COMPANY, None)}
				],
			}
		)
		entry.insert(ignore_permissions=True)
		entry.submit()
		self.posted.append(("Stock Entry", entry.name))

	def _count(self, qty, user=MANAGER):
		result = self._as(user, stock_count.record, {self.mdf: qty})
		if result["reconciliation"]:
			self.posted.append(("Stock Reconciliation", result["reconciliation"]))
		return result

	def _usage(self):
		return {r["item"]: r for r in self._as(MANAGER, stock_count.month_usage)["materials"]}

	def test_the_owner_s_month(self):
		start = self._usage().get(self.mdf, {}).get("end", 0)
		self._bought(50)
		self._taken_by_orders(40)

		result = self._count(start + 2)
		row = result["rows"][0]
		self.assertEqual((row["books"], row["counted"], row["difference"]), (start + 10, start + 2, -8))

		month = self._usage()[self.mdf]
		self.assertEqual((month["bought"], month["end"], month["by_orders"]), (50, start + 2, 40))
		self.assertEqual(month["used"], 48)
		self.assertEqual(month["unaccounted"], 8)
		self.assertEqual(material_stock.material(self.mdf)["on_hand"], start + 2)

	def test_a_count_that_agrees_posts_nothing(self):
		self._bought(5)
		on_hand = material_stock.material(self.mdf)["on_hand"]
		result = self._count(on_hand)
		self.assertIsNone(result["reconciliation"])
		self.assertEqual(result["rows"][0]["difference"], 0)

	def test_what_cannot_be_true_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			self._count(2.5)  # sheets are whole
		with self.assertRaises(frappe.ValidationError):
			self._count(-1)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, stock_count.record, {self.mdf: 3}, counted_on=add_days(nowdate(), 1))

	def test_the_shop_floor_cannot_count(self):
		with self.assertRaises(frappe.PermissionError):
			self._count(3, user=CUTTER)

	def test_the_reminder_comes_on_the_last_days_and_not_after_a_count(self):
		from korkem_manufacturing import domain_events

		emitted = []
		with patch.object(domain_events, "emit", side_effect=lambda event, **kw: emitted.append((event, kw))):
			with patch.object(stock_count, "nowdate", return_value=str(add_days(get_last_day(nowdate()), -5))):
				self.assertEqual(stock_count.remind(), 0)
			with patch.object(stock_count, "nowdate", return_value=str(get_last_day(nowdate()))):
				counted_already = bool(stock_count.counts())
				stock_count.remind()
		mine = [kw for event, kw in emitted if event == stock_count.COUNT_DUE and kw["company"] == COMPANY]
		self.assertEqual(len(mine), 0 if counted_already else 1)
