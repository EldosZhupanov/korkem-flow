# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Обмен с 1С»: what was sold, paid and received, as files 1C loads — and a
switch that turns it off."""

from __future__ import annotations

import csv
import io
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import nowdate

from korkem_manufacturing.services import acceptance, capture, enquiry, invoicing, proposal
from korkem_manufacturing.services import accounting_export as service

COMPANY = "KORKEM"
ACCOUNTANT = "onec.accountant@example.com"
CHIEF_ACCOUNTANT = "onec.chief@example.com"
CUTTER = "onec.cutter@example.com"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)
	if not frappe.db.exists("User Permission", {"user": email, "allow": "Company", "for_value": COMPANY}):
		frappe.get_doc(
			{"doctype": "User Permission", "user": email, "allow": "Company", "for_value": COMPANY,
			 "apply_to_all_doctypes": 1}
		).insert(ignore_permissions=True)


def _rows(result: dict) -> list[list[str]]:
	text = result["csv"]
	assert text.startswith("﻿"), "Excel needs the BOM to read Cyrillic"
	return list(csv.reader(io.StringIO(text[1:]), delimiter=";"))


class TestOneCExport(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(ACCOUNTANT, "Accounts User")
		_user(CHIEF_ACCOUNTANT, "Accounts Manager")
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		frappe.set_user("Administrator")
		frappe.db.delete(service.SETTINGS, {"company": COMPANY})

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _today(self) -> dict:
		return {"from_date": nowdate(), "to_date": nowdate()}

	# --- the switch -----------------------------------------------------------

	def test_it_is_on_until_somebody_turns_it_off(self):
		self.assertTrue(self._as(ACCOUNTANT, service.settings)["enabled"])
		self._as(CHIEF_ACCOUNTANT, service.set_enabled, 0)
		self.assertFalse(self._as(ACCOUNTANT, service.settings)["enabled"])
		with self.assertRaises(frappe.ValidationError):
			self._as(ACCOUNTANT, service.export, service.SALES, **self._today())
		self._as(CHIEF_ACCOUNTANT, service.set_enabled, "1")
		self.assertEqual(self._as(ACCOUNTANT, service.export, service.PAYROLL, **self._today())["table"], "payroll")

	def test_only_the_administrator_and_the_chief_accountant_switch_it(self):
		with self.assertRaises(frappe.PermissionError):
			self._as(ACCOUNTANT, service.set_enabled, 0)

	def test_the_shop_floor_sees_none_of_it(self):
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.settings)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.export, service.SALES)

	# --- the files --------------------------------------------------------------

	def test_every_table_opens_with_its_header(self):
		for table in service.TABLES:
			result = self._as(ACCOUNTANT, service.export, table, **self._today())
			self.assertTrue(result["filename"].endswith(".csv"))
			self.assertGreaterEqual(len(_rows(result)), 1, table)

	def test_numbers_and_dates_are_written_as_1c_reads_them(self):
		self.assertEqual(service._num(1234.5), "1234,50")
		self.assertEqual(service._num(2, 3), "2,000")
		self.assertEqual(service._day("2026-10-28"), "28.10.2026")

	def test_an_unknown_table_or_a_long_period_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			self._as(ACCOUNTANT, service.export, "everything")
		with self.assertRaises(frappe.ValidationError):
			self._as(ACCOUNTANT, service.export, service.SALES, from_date="2026-01-01", to_date="2026-10-28")

	def test_a_submitted_invoice_is_in_the_sales_file_line_by_line(self):
		item = frappe.get_all("Item", filters={"is_sales_item": 1}, pluck="name", limit=1)
		if not item:
			self.skipTest("на этом стенде нет продаваемой позиции")
		found = capture.record(
			text="Кухня", understood={"customer_hint": f"Клиент 1С {frappe.generate_hash(length=6)}"}
		)["capture"]
		quotation = proposal.draft(
			enquiry=enquiry.convert(capture=found)["enquiry"], items=[{"item_code": item[0], "qty": 2, "rate": 110000}]
		)["quotation"]
		order = acceptance.accept(quotation=quotation, deliver_on=frappe.utils.add_days(nowdate(), 18))["sales_order"]
		frappe.get_doc("Sales Order", order).submit()
		with patch.object(invoicing, "_delivered", return_value=2):
			invoice = frappe.get_doc("Sales Invoice", invoicing.draft(sales_order=order)["invoice"])
		try:
			invoice.submit()
		except frappe.ValidationError as error:
			self.skipTest(f"счёт на этом стенде не проводится: {error}")

		rows = _rows(self._as(ACCOUNTANT, service.export, service.SALES, **self._today()))
		mine = [r for r in rows if r[1] == invoice.name]
		self.assertEqual(len(mine), len(invoice.items))
		self.assertEqual(mine[0][7], "2,000")  # quantity
		self.assertEqual(mine[0][10], order)
		parties = _rows(self._as(ACCOUNTANT, service.export, service.PARTIES, **self._today()))
		self.assertIn(invoice.customer, [r[3] for r in parties])
