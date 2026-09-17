# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

import frappe
from frappe.tests import IntegrationTestCase
from korkem_manufacturing.services import registration


class TestRegistration(IntegrationTestCase):
	def setUp(self):
		self.test_email = "furniture.test.maker@example.com"
		self.test_company = "Мебель Тест Цех"
		self._cleanup()

	def tearDown(self):
		self._cleanup()

	def _cleanup(self):
		frappe.set_user("Administrator")
		if frappe.db.exists("User", self.test_email):
			frappe.delete_doc("User", self.test_email, force=1, ignore_permissions=True)
		for perm in frappe.get_all(
			"User Permission",
			filters={"user": self.test_email},
			pluck="name",
		):
			frappe.delete_doc("User Permission", perm, force=1, ignore_permissions=True)
		frappe.db.commit()

	def test_register_creates_company_and_owner(self):
		result = registration.register_company(
			company_name=self.test_company,
			owner_name="Тест Мебельщик",
			email=self.test_email,
			password="SecurePassword123!",
		)

		self.assertEqual(result["status"], "ok")
		self.assertEqual(result["email"], self.test_email)
		self.assertTrue(frappe.db.exists("User", self.test_email))
		self.assertTrue(frappe.db.exists("Company", self.test_company))

		# Check roles
		user = frappe.get_doc("User", self.test_email)
		roles = {r.role for r in user.roles}
		self.assertIn("System Manager", roles)
		self.assertIn("Manufacturing Manager", roles)

		# Check company permission
		perm = frappe.db.get_value(
			"User Permission",
			{"user": self.test_email, "allow": "Company", "for_value": self.test_company},
		)
		self.assertIsNotNone(perm)

	def test_duplicate_email_is_refused(self):
		registration.register_company(
			company_name=self.test_company,
			owner_name="Тест Мебельщик",
			email=self.test_email,
			password="SecurePassword123!",
		)
		with self.assertRaises(frappe.ValidationError):
			registration.register_company(
				company_name=self.test_company,
				owner_name="Второй Раз",
				email=self.test_email,
				password="SecurePassword123!",
			)
