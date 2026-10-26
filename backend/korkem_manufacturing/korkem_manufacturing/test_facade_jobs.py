# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The shop floor sees what facades to make — sizes, never prices."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import facade_jobs, facade_order, facade_prices, facade_quote

COMPANY = "KORKEM"
CUTTER = "jobs.cutter@example.com"
SELLER = "jobs.seller@example.com"
MONEY = {"rate", "amount", "price", "price_per_piece", "total", "grand_total", "rate_per_m2"}


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestFacadeJobs(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(CUTTER, "Manufacturing User")
		_user(SELLER, "Sales User")

	def setUp(self):
		frappe.set_user("Administrator")
		frappe.db.delete("Facade Pricing Settings", {"company": COMPANY})
		facade_quote.save_settings(double_sided_factor=1.8)
		customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		self.order = facade_order.create_order(
			customer=customer,
			delivery_date=add_days(nowdate(), 10),
			lines=[
				{"width_mm": 716, "height_mm": 396, "qty": 3, "milling": "Классика", "finish": facade_prices.ENAMEL},
				{"width_mm": 596, "height_mm": 2000, "qty": 1, "milling": "Тегіс", "finish": facade_prices.PVC, "double_sided": 1},
			],
		)["sales_order"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def _mine(self, user=CUTTER, **kwargs) -> list[dict]:
		frappe.set_user(user)
		try:
			rows = facade_jobs.jobs(limit=200, **kwargs)["jobs"]
		finally:
			frappe.set_user("Administrator")
		return [row for row in rows if row["sales_order"] == self.order]

	def test_the_cutter_sees_sizes_and_options(self):
		rows = self._mine()
		self.assertEqual(
			[(r["width_mm"], r["height_mm"], r["qty"], r["milling"]) for r in rows],
			[(716, 396, 3, "Классика"), (596, 2000, 1, "Тегіс")],
		)
		self.assertTrue(rows[1]["double_sided"])
		self.assertEqual({r["status"] for r in rows}, {facade_jobs.QUEUED})

	def test_the_list_carries_no_money_at_all(self):
		for row in self._mine():
			self.assertFalse(MONEY.intersection(row), row)

	def test_the_cutter_moves_a_facade_along(self):
		line = self._mine()[0]["line"]
		frappe.set_user(CUTTER)
		result = facade_jobs.set_status(line, facade_jobs.IN_WORK)
		frappe.set_user("Administrator")
		self.assertTrue(result["changed"])
		self.assertEqual(self._mine(status=facade_jobs.IN_WORK)[0]["line"], line)
		self.assertTrue(
			frappe.db.exists("Domain Audit Event", {"action": "manufacturing.facade_status", "entity_id": self.order})
		)

	def test_setting_the_same_status_twice_changes_nothing(self):
		line = self._mine()[0]["line"]
		frappe.set_user(CUTTER)
		facade_jobs.set_status(line, facade_jobs.DONE)
		again = facade_jobs.set_status(line, facade_jobs.DONE)
		self.assertFalse(again["changed"])

	def test_sales_cannot_report_production(self):
		line = self._mine()[0]["line"]
		frappe.set_user(SELLER)
		with self.assertRaises(frappe.PermissionError):
			facade_jobs.set_status(line, facade_jobs.DONE)

	def test_an_unknown_line_or_status_is_refused(self):
		frappe.set_user(CUTTER)
		with self.assertRaises(frappe.DoesNotExistError):
			facade_jobs.set_status("no-such-line", facade_jobs.DONE)
		line = self._mine()[0]["line"]
		frappe.set_user(CUTTER)
		with self.assertRaises(frappe.ValidationError):
			facade_jobs.set_status(line, "Потеряно")

	def test_an_ordinary_order_line_is_not_a_facade(self):
		ordinary = frappe.db.get_value(
			"Sales Order Item", {"parenttype": "Sales Order", "korkem_width_mm": ["<", 1]}, "name"
		)
		if ordinary:
			frappe.set_user(CUTTER)
			with self.assertRaises(frappe.DoesNotExistError):
				facade_jobs.set_status(ordinary, facade_jobs.DONE)
