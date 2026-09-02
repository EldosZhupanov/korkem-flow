# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Монтаж — последнее, что видит клиент, и первое, о чём он рассказывает."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import acceptance as acceptance_service
from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import enquiry as enquiry_service
from korkem_manufacturing.services import installation as service
from korkem_manufacturing.services import proposal as proposal_service


class TestSchedulingAnInstallation(IntegrationTestCase):
	def setUp(self):
		found = frappe.get_all("Item", filters={"is_sales_item": 1}, pluck="name", limit=1)
		if not found:
			self.skipTest("на этом стенде нет ни одной продаваемой позиции")
		capture = capture_service.record(
			text="Кухня",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["capture"]
		enquiry = enquiry_service.convert(capture=capture)["enquiry"]
		quotation = proposal_service.draft(
			enquiry=enquiry, items=[{"item_code": found[0], "qty": 3, "rate": 120000}]
		)["quotation"]
		self.order = acceptance_service.accept(
			quotation=quotation,
			deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 20),
		)["sales_order"]
		self.when = frappe.utils.add_days(frappe.utils.nowdate(), 22)

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_nothing_delivered_means_nobody_drives_out(self):
		"""Бригада без мебели теряет день, а клиент — доверие."""
		with self.assertRaises(frappe.ValidationError) as refusal:
			service.schedule(
				sales_order=self.order, installer="Administrator", install_on=self.when
			)
		self.assertIn("отгружено", str(refusal.exception))

	def test_once_something_is_delivered_the_brigade_can_be_sent(self):
		with patch.object(service, "_delivered_quantity", return_value=3):
			result = service.schedule(
				sales_order=self.order, installer="Administrator", install_on=self.when
			)

		self.assertEqual(result["status"], "scheduled")
		task = frappe.get_doc("CRM Task", result["task"])
		self.assertEqual(task.assigned_to, "Administrator")
		self.assertEqual(
			frappe.utils.getdate(task.due_date), frappe.utils.getdate(self.when)
		)

	def test_a_date_is_required_because_the_customer_waits_at_home(self):
		with patch.object(service, "_delivered_quantity", return_value=3):
			with self.assertRaises(frappe.ValidationError):
				service.schedule(
					sales_order=self.order, installer="Administrator", install_on=""
				)

	def test_scheduling_twice_does_not_send_two_brigades(self):
		with patch.object(service, "_delivered_quantity", return_value=3):
			first = service.schedule(
				sales_order=self.order, installer="Administrator", install_on=self.when
			)
			second = service.schedule(
				sales_order=self.order, installer="Administrator", install_on=self.when
			)

		self.assertEqual(second["status"], "already_scheduled")
		self.assertEqual(second["task"], first["task"])


class TestCompletingAnInstallation(IntegrationTestCase):
	def setUp(self):
		found = frappe.get_all("Item", filters={"is_sales_item": 1}, pluck="name", limit=1)
		if not found:
			self.skipTest("на этом стенде нет ни одной продаваемой позиции")
		capture = capture_service.record(
			text="Шкаф",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["capture"]
		enquiry = enquiry_service.convert(capture=capture)["enquiry"]
		quotation = proposal_service.draft(
			enquiry=enquiry, items=[{"item_code": found[0], "qty": 1, "rate": 80000}]
		)["quotation"]
		self.order = acceptance_service.accept(
			quotation=quotation,
			deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 10),
		)["sales_order"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_closing_an_installation_that_was_never_scheduled_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.complete(sales_order=self.order)

	def test_the_brigades_words_stay_on_the_order(self):
		"""Через год, на гарантийном случае, они стоят дороже факта «закрыто»."""
		with patch.object(service, "_delivered_quantity", return_value=1):
			service.schedule(
				sales_order=self.order,
				installer="Administrator",
				install_on=frappe.utils.add_days(frappe.utils.nowdate(), 12),
			)

		service.complete(
			sales_order=self.order, notes="Стена кривая, ставили с доборным элементом"
		)

		said = frappe.get_all(
			"Comment",
			filters={"reference_doctype": "Sales Order", "reference_name": self.order},
			pluck="content",
		)
		self.assertTrue(any("доборным" in c for c in said))


class TestScope(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		import inspect

		self.assertNotIn("company", inspect.signature(service.schedule).parameters)

	def test_an_order_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.PermissionError):
			service.complete(sales_order="does-not-exist")
