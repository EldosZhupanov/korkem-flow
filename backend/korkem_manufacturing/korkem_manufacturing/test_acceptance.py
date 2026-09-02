# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Согласие клиента — звено между передней половиной цепочки и производством."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import acceptance as service
from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import enquiry as enquiry_service
from korkem_manufacturing.services import proposal as proposal_service


class TestAcceptingAProposal(IntegrationTestCase):
	def setUp(self):
		found = frappe.get_all("Item", filters={"is_sales_item": 1}, pluck="name", limit=1)
		if not found:
			self.skipTest("на этом стенде нет ни одной продаваемой позиции")
		capture = capture_service.record(
			text="Кухня, договорились",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["capture"]
		enquiry = enquiry_service.convert(capture=capture)["enquiry"]
		self.when = frappe.utils.add_days(frappe.utils.nowdate(), 21)
		self.quotation = proposal_service.draft(
			enquiry=enquiry, items=[{"item_code": found[0], "qty": 2, "rate": 150000}]
		)["quotation"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_accepting_submits_the_quotation_and_builds_an_order(self):
		result = service.accept(quotation=self.quotation, deliver_on=self.when)

		self.assertEqual(result["status"], "accepted")
		self.assertEqual(frappe.db.get_value("Quotation", self.quotation, "docstatus"), 1)
		order = frappe.get_doc("Sales Order", result["sales_order"])
		self.assertEqual(order.docstatus, 0)
		self.assertEqual(len(order.items), 1)

	def test_the_order_keeps_the_price_that_was_agreed(self):
		"""Цена в заказе — та, на которую согласился клиент, а не пересчитанная."""
		result = service.accept(quotation=self.quotation, deliver_on=self.when)

		order = frappe.get_doc("Sales Order", result["sales_order"])
		self.assertEqual(frappe.utils.flt(order.items[0].rate), 150000)

	def test_the_order_is_a_draft_because_prepayment_comes_first(self):
		"""Проведённый заказ резервирует материал; в цепочке до него — предоплата."""
		result = service.accept(quotation=self.quotation, deliver_on=self.when)
		self.assertFalse(result["submitted"])
		self.assertEqual(
			frappe.db.get_value("Sales Order", result["sales_order"], "docstatus"), 0
		)

	def test_accepting_twice_returns_the_same_order(self):
		"""Клиент соглашается один раз, а кнопку нажимают сколько угодно."""
		first = service.accept(quotation=self.quotation, deliver_on=self.when)
		second = service.accept(quotation=self.quotation, deliver_on=self.when)

		self.assertEqual(second["status"], "already_accepted")
		self.assertEqual(second["sales_order"], first["sales_order"])

	def test_an_order_without_a_promised_date_is_refused(self):
		"""«Когда готово?» — вопрос, ради которого построен весь продукт."""
		with self.assertRaises(frappe.ValidationError):
			service.accept(quotation=self.quotation, deliver_on="")

	def test_the_promised_date_reaches_the_order(self):
		result = service.accept(quotation=self.quotation, deliver_on=self.when)
		order = frappe.get_doc("Sales Order", result["sales_order"])
		self.assertEqual(
			frappe.utils.getdate(order.delivery_date), frappe.utils.getdate(self.when)
		)

	def test_a_cancelled_quotation_cannot_become_an_order(self):
		doc = frappe.get_doc("Quotation", self.quotation)
		doc.submit()
		doc.cancel()

		with self.assertRaises(frappe.ValidationError):
			service.accept(quotation=self.quotation, deliver_on=self.when)


class TestScope(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		import inspect

		self.assertNotIn("company", inspect.signature(service.accept).parameters)

	def test_a_quotation_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.PermissionError):
			service.accept(
				quotation="does-not-exist",
				deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 7),
			)
