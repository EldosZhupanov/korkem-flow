# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Замер — звено между «клиент чего-то хочет» и «мы знаем цену»."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import enquiry as enquiry_service
from korkem_manufacturing.services import measurement as service


class TestRecordingAMeasurement(IntegrationTestCase):
	def setUp(self):
		capture = capture_service.record(
			text="Кухня, замерить",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
			assign_to="Administrator",
		)["capture"]
		converted = enquiry_service.convert(capture=capture)
		self.enquiry = converted["enquiry"]
		self.capture = capture

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_the_measurement_lands_on_the_enquiry(self):
		service.record(enquiry=self.enquiry, dimensions="3200x600, высота 2100")

		said = frappe.get_all(
			"Comment",
			filters={"reference_doctype": "Opportunity", "reference_name": self.enquiry},
			pluck="content",
		)
		self.assertTrue(any("3200x600" in c for c in said))

	def test_recording_a_measurement_closes_the_measurers_task(self):
		"""Человек делает это одним движением — система тоже."""
		result = service.record(enquiry=self.enquiry, dimensions="3200x600")

		self.assertIsNotNone(result["task_closed"])
		self.assertEqual(
			frappe.db.get_value("CRM Task", result["task_closed"], "status"), "Done"
		)

	def test_an_address_becomes_an_address_not_a_note(self):
		"""Доставка и монтаж будут искать его там, а не в ленте комментариев."""
		result = service.record(
			enquiry=self.enquiry,
			dimensions="3200x600",
			address_line="Абая 12, кв 5",
			city="Астана",
		)

		self.assertIsNotNone(result["address"])
		address = frappe.get_doc("Address", result["address"])
		self.assertEqual(address.address_line1, "Абая 12, кв 5")
		self.assertEqual(address.city, "Астана")

	def test_notes_alone_are_a_valid_measurement(self):
		"""«Стены кривые, нужен доборный элемент» — это результат замера."""
		result = service.record(
			enquiry=self.enquiry, notes="Стены кривые, нужен доборный элемент"
		)
		self.assertIsNotNone(result["task_closed"])

	def test_an_empty_measurement_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.record(enquiry=self.enquiry, dimensions="   ", notes="")

	def test_an_enquiry_with_no_task_still_takes_a_measurement(self):
		"""Задачу могли и не создавать — замер от этого не перестаёт быть замером."""
		capture = capture_service.record(
			text="Сам поеду мерить",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["capture"]
		enquiry = enquiry_service.convert(capture=capture)["enquiry"]

		result = service.record(enquiry=enquiry, dimensions="1800x600")

		self.assertIsNone(result["task_closed"])


class TestScope(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		import inspect

		self.assertNotIn("company", inspect.signature(service.record).parameters)

	def test_an_enquiry_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.PermissionError):
			service.record(enquiry="does-not-exist", dimensions="1x1")
