# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Реквизиты компании — то, что печатается в договоре и в накладной."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import company_details as service


class TestCompanyDetails(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")

	def test_reading_details_names_the_company(self):
		details = service.read()
		self.assertTrue(details["company"])
		self.assertTrue(details["name"])

	def test_the_bin_lands_where_erpnext_keeps_a_tax_number(self):
		"""Своё поле означало бы два места, где написан один номер."""
		service.save(bin="123456789012")

		company = service.read()["company"]
		self.assertEqual(frappe.db.get_value("Company", company, "tax_id"), "123456789012")
		self.assertEqual(service.read()["bin"], "123456789012")

	def test_a_bin_of_eleven_digits_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.save(bin="12345678901")

	def test_a_bin_with_a_letter_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.save(bin="12345678901A")

	def test_the_address_becomes_an_address_not_a_field(self):
		service.save(address="проспект Абая 15", city="Астана")

		details = service.read()
		self.assertEqual(details["address"], "проспект Абая 15")
		self.assertEqual(details["city"], "Астана")

	def test_saving_twice_does_not_leave_two_addresses(self):
		service.save(address="проспект Абая 15", city="Астана")
		service.save(address="улица Кенесары 40", city="Астана")

		details = service.read()
		self.assertEqual(details["address"], "улица Кенесары 40")

		company = details["company"]
		links = frappe.get_all(
			"Dynamic Link",
			filters={
				"link_doctype": "Company",
				"link_name": company,
				"parenttype": "Address",
			},
			parent_doctype="Address",
			pluck="parent",
		)
		self.assertEqual(len(set(links)), 1)

	def test_the_bank_account_keeps_iban_and_bik_where_erpnext_keeps_them(self):
		service.save(
			bank_name="Kaspi Bank",
			bank_account="KZ69 1234 5678 9012 345C",
			bik="CASPKZKA",
		)

		details = service.read()
		self.assertEqual(details["bank_name"], "Kaspi Bank")
		self.assertEqual(details["bank_account"], "KZ69123456789012345C")
		self.assertEqual(details["bik"], "CASPKZKA")

	def test_an_account_that_is_not_a_kazakh_iban_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.save(bank_name="Halyk Bank", bank_account="40817810099910004312")

	def test_a_kazakh_looking_iban_with_a_wrong_checksum_is_refused_too(self):
		"""Форму проверяем мы, контрольную сумму — ERPNext, и он тут авторитет."""
		with self.assertRaises(frappe.ValidationError):
			service.save(bank_name="Halyk Bank", bank_account="KZ00123456789012345C")

	def test_a_partial_form_saves(self):
		"""Сегодня адрес, завтра банк. Требовать всё сразу — не дать записать ничего."""
		service.save(phone="+7 775 267 33 39")

		details = service.read()
		self.assertEqual(details["phone"], "+7 775 267 33 39")

	def test_an_empty_field_does_not_erase_what_was_written(self):
		service.save(bin="123456789012", phone="+7 700 000 00 00")
		service.save(phone="+7 701 111 11 11")

		details = service.read()
		self.assertEqual(details["bin"], "123456789012")
		self.assertEqual(details["phone"], "+7 701 111 11 11")

	def test_an_employee_cannot_rewrite_the_company_details(self):
		"""Реквизиты уходят в договор. Их меняет владелец, а не замерщик."""
		from korkem_manufacturing.services import invitations

		email = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		invitations.invite_employee(email=email, position="shop_floor")

		frappe.set_user(email)
		with self.assertRaises(frappe.PermissionError):
			service.save(bin="999999999999")
