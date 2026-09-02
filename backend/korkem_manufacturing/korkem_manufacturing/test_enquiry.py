# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""From a sentence to a customer and an enquiry — step one of the chain.

The tests that matter here are the ones about *not* guessing. Creating a
customer is cheap to undo; picking the wrong one is not, because everything
downstream — the address, the price list, the delivery — follows the choice
silently.
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.api import enquiry as api
from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import enquiry as service


class TestConvertingACapture(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")

	def _capture(self, text="Айгуль, кухня", **hints):
		return capture_service.record(text=text, understood=hints or None)["capture"]

	def test_a_named_stranger_becomes_a_customer_and_an_enquiry(self):
		name = f"Айгуль {frappe.generate_hash(length=6)}"
		capture = self._capture(customer_hint=name, product_hint="Кухня")

		result = service.convert(capture=capture)

		self.assertTrue(result["customer_created"])
		self.assertEqual(
			frappe.db.get_value("Customer", result["customer"], "customer_name"), name
		)
		enquiry = frappe.get_doc("Opportunity", result["enquiry"])
		self.assertEqual(enquiry.party_name, result["customer"])
		# Company-scoped by construction: this is why the enquiry is an
		# Opportunity and not a CRM Lead, which carries no company at all.
		self.assertTrue(enquiry.company)

	def test_the_spoken_words_stay_on_the_enquiry(self):
		"""Whoever picks this up later needs what the customer actually said."""
		said = "Айгуль, кухня три двести, белый глянец"
		capture = self._capture(text=said, customer_hint=f"Клиент {frappe.generate_hash(length=6)}")

		result = service.convert(capture=capture)

		comments = frappe.get_all(
			"Comment",
			filters={"reference_doctype": "Opportunity", "reference_name": result["enquiry"]},
			pluck="content",
		)
		self.assertTrue(any(said in c for c in comments))

	def test_an_existing_customer_is_reused_rather_than_duplicated(self):
		name = f"Мебель {frappe.generate_hash(length=6)}"
		existing = frappe.get_doc(
			{"doctype": "Customer", "customer_name": name, "customer_type": "Company"}
		).insert()

		result = service.convert(capture=self._capture(customer_hint=name))

		self.assertFalse(result["customer_created"])
		self.assertEqual(result["customer"], existing.name)

	def test_converting_twice_does_not_create_a_second_of_anything(self):
		"""Dusty hands double-tap. That must cost nothing."""
		capture = self._capture(customer_hint=f"Серик {frappe.generate_hash(length=6)}")

		first = service.convert(capture=capture)
		second = service.convert(capture=capture)

		self.assertEqual(second["status"], "already_converted")
		self.assertEqual(second["enquiry"], first["enquiry"])

	def test_a_measurer_can_be_given_the_job_in_the_same_breath(self):
		when = frappe.utils.add_days(frappe.utils.nowdate(), 2)
		capture = self._capture(customer_hint=f"Асем {frappe.generate_hash(length=6)}")

		result = service.convert(
			capture=capture, assign_measurer="Administrator", measure_on=when
		)

		self.assertIsNotNone(result["task"])
		task = frappe.get_doc("CRM Task", result["task"])
		self.assertEqual(task.assigned_to, "Administrator")
		self.assertEqual(frappe.utils.getdate(task.due_date), frappe.utils.getdate(when))


class TestNotGuessingTheCustomer(IntegrationTestCase):
	"""The wrong customer is a kitchen delivered to somebody else."""

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_two_possible_customers_stop_the_conversion(self):
		stem = f"Айгуль{frappe.generate_hash(length=5)}"
		for suffix in ("Абая", "Сатпаева"):
			frappe.get_doc(
				{
					"doctype": "Customer",
					"customer_name": f"{stem} {suffix}",
					"customer_type": "Individual",
				}
			).insert()

		capture = capture_service.record(
			text="Позвонила Айгуль", understood={"customer_hint": stem}
		)["capture"]

		with self.assertRaises(service.AmbiguousCustomer):
			service.convert(capture=capture)

	def test_the_endpoint_hands_back_the_choice_instead_of_an_error(self):
		"""A person deciding which Айгуль this is needs names, not a red box."""
		stem = f"Марат{frappe.generate_hash(length=5)}"
		for suffix in ("Первый", "Второй"):
			frappe.get_doc(
				{
					"doctype": "Customer",
					"customer_name": f"{stem} {suffix}",
					"customer_type": "Individual",
				}
			).insert()

		capture = capture_service.record(
			text="Марат звонил", understood={"customer_hint": stem}
		)["capture"]

		result = api.convert(capture=capture)

		self.assertEqual(result["status"], "ambiguous_customer")
		self.assertEqual(len(result["candidates"]), 2)
		self.assertEqual(frappe.local.response.get("http_status_code"), 409)

	def test_an_explicit_choice_ends_the_ambiguity(self):
		stem = f"Дана{frappe.generate_hash(length=5)}"
		chosen = frappe.get_doc(
			{
				"doctype": "Customer",
				"customer_name": f"{stem} Одна",
				"customer_type": "Individual",
			}
		).insert()
		frappe.get_doc(
			{
				"doctype": "Customer",
				"customer_name": f"{stem} Другая",
				"customer_type": "Individual",
			}
		).insert()

		capture = capture_service.record(
			text="Дана", understood={"customer_hint": stem}
		)["capture"]

		result = service.convert(capture=capture, customer=chosen.name)

		self.assertEqual(result["customer"], chosen.name)
		self.assertFalse(result["customer_created"])

	def test_a_capture_naming_nobody_is_refused_rather_than_invented(self):
		capture = capture_service.record(text="Надо не забыть про фасады")["capture"]

		with self.assertRaises(frappe.ValidationError):
			service.convert(capture=capture)


class TestScope(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		import inspect

		self.assertNotIn("company", inspect.signature(service.convert).parameters)
		self.assertNotIn("company", inspect.signature(api.convert).parameters)

	def test_a_capture_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.PermissionError):
			service.convert(capture="does-not-exist")
