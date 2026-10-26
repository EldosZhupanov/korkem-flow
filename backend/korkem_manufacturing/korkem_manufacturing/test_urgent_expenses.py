# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Urgent expenses: filed by anyone on staff, decided by somebody else."""

from __future__ import annotations

import io

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import urgent_expenses as service

COMPANY = "KORKEM"
DRIVER = "expense.driver@example.com"
CUTTER = "expense.cutter@example.com"
BOOKKEEPER = "expense.bookkeeper@example.com"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


def _photo() -> bytes:
	from PIL import Image

	buffer = io.BytesIO()
	Image.new("RGB", (4, 4), (10, 20, 30)).save(buffer, format="JPEG")
	return buffer.getvalue()


class TestUrgentExpenses(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(DRIVER, "Delivery User")
		_user(CUTTER, "Manufacturing User")
		_user(BOOKKEEPER, "Accounts Manager")

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _filed(self, user=DRIVER, amount=8_500, purpose="Бензин на доставку") -> str:
		return self._as(user, service.file, amount, purpose, "Транспорт")["expense"]

	def test_a_driver_files_one_for_himself(self):
		name = self._filed()
		doc = frappe.get_doc(service.DOCTYPE, name)
		self.assertEqual((doc.requested_by, doc.status, doc.amount), (DRIVER, service.PENDING, 8_500))

	def test_accounting_approves(self):
		name = self._filed()
		row = self._as(BOOKKEEPER, service.decide, name, 1)
		self.assertEqual((row["status"], row["decided_by"]), (service.APPROVED, BOOKKEEPER))

	def test_a_rejection_needs_a_reason(self):
		name = self._filed()
		with self.assertRaises(frappe.ValidationError):
			self._as(BOOKKEEPER, service.decide, name, 0)
		row = self._as(BOOKKEEPER, service.decide, name, 0, "Нет чека")
		self.assertEqual((row["status"], row["decision_note"]), (service.REJECTED, "Нет чека"))

	def test_nobody_decides_their_own(self):
		name = self._filed(user=BOOKKEEPER)
		with self.assertRaises(frappe.PermissionError):
			self._as(BOOKKEEPER, service.decide, name, 1)

	def test_a_worker_cannot_decide(self):
		name = self._filed()
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.decide, name, 1)

	def test_a_decision_is_final(self):
		name = self._filed()
		self._as(BOOKKEEPER, service.decide, name, 1)
		with self.assertRaises(frappe.ValidationError):
			self._as(BOOKKEEPER, service.decide, name, 0, "передумал")

	def test_each_sees_their_own_and_accounting_sees_all(self):
		mine = self._filed()
		other = self._filed(user=CUTTER, purpose="Пильный диск")
		driver_sees = {r["expense"] for r in self._as(DRIVER, service.listing)["expenses"]}
		self.assertIn(mine, driver_sees)
		self.assertNotIn(other, driver_sees)
		books = {r["expense"] for r in self._as(BOOKKEEPER, service.listing)["expenses"]}
		self.assertTrue({mine, other} <= books)

	def test_somebody_elses_expense_reads_as_missing(self):
		other = self._filed(user=CUTTER, purpose="Пильный диск")
		with self.assertRaises(frappe.DoesNotExistError):
			self._as(DRIVER, service.attach_receipt, other, "чек.jpg", _photo())

	def test_a_receipt_photo_is_private(self):
		name = self._filed()
		result = self._as(DRIVER, service.attach_receipt, name, "IMG_7.jpg", _photo())
		self.assertTrue(frappe.db.get_value("File", result["file"], "is_private"))

	def test_nonsense_is_refused(self):
		for amount, purpose in ((0, "Бензин"), (-5, "Бензин"), ("много", "Бензин"), (100, ""), (10_000_000, "Станок")):
			with self.assertRaises(frappe.ValidationError, msg=f"{amount} {purpose}"):
				self._as(DRIVER, service.file, amount, purpose, "Другое")

	def test_filing_and_deciding_are_audited(self):
		name = self._filed()
		self._as(BOOKKEEPER, service.decide, name, 1)
		actions = set(frappe.get_all("Domain Audit Event", filters={"entity_id": name}, pluck="action"))
		self.assertTrue({"expense.filed", "expense.approved"} <= actions)
