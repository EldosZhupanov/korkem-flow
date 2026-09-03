# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Счёт по заказу — документ, который клиент подписывает."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import acceptance as acceptance_service
from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import enquiry as enquiry_service
from korkem_manufacturing.services import invoicing as service
from korkem_manufacturing.services import proposal as proposal_service


class TestDraftingAnInvoice(IntegrationTestCase):
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
			enquiry=enquiry, items=[{"item_code": found[0], "qty": 2, "rate": 110000}]
		)["quotation"]
		self.order = acceptance_service.accept(
			quotation=quotation,
			deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 18),
		)["sales_order"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_a_draft_order_cannot_be_invoiced(self):
		"""Счёт по черновику — счёт за то, о чём не договорились окончательно."""
		with self.assertRaises(frappe.ValidationError) as refusal:
			service.draft(sales_order=self.order)
		self.assertIn("проведён", str(refusal.exception))

	def test_nothing_delivered_means_no_invoice(self):
		"""Счёт за непривезённую мебель ссорит с довольным клиентом."""
		doc = frappe.get_doc("Sales Order", self.order)
		doc.submit()

		with self.assertRaises(frappe.ValidationError) as refusal:
			service.draft(sales_order=self.order)
		self.assertIn("отгружено", str(refusal.exception))

	def test_an_invoice_is_built_once_something_was_delivered(self):
		doc = frappe.get_doc("Sales Order", self.order)
		doc.submit()

		with patch.object(service, "_delivered", return_value=2):
			result = service.draft(sales_order=self.order)

		invoice = frappe.get_doc("Sales Invoice", result["invoice"])
		self.assertEqual(invoice.docstatus, 0)
		self.assertEqual(invoice.items[0].sales_order, self.order)

	def test_drafting_twice_returns_the_same_invoice(self):
		doc = frappe.get_doc("Sales Order", self.order)
		doc.submit()

		with patch.object(service, "_delivered", return_value=2):
			first = service.draft(sales_order=self.order)
			second = service.draft(sales_order=self.order)

		self.assertEqual(second["status"], "already_drafted")
		self.assertEqual(second["invoice"], first["invoice"])


class TestScope(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		import inspect

		self.assertNotIn("company", inspect.signature(service.draft).parameters)

	def test_an_order_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.PermissionError):
			service.draft(sales_order="does-not-exist")
