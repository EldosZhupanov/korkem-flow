# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Черновик КП — первый шаг цепочки, на котором появляются деньги."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.api import proposal as api
from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import enquiry as enquiry_service
from korkem_manufacturing.services import proposal as service


class TestDraftingAProposal(IntegrationTestCase):
	def setUp(self):
		name = f"Клиент {frappe.generate_hash(length=6)}"
		capture = capture_service.record(
			text="Кухня три двести на шестьсот, белый глянец",
			understood={"customer_hint": name, "product_hint": "Кухня"},
		)["capture"]
		self.enquiry = enquiry_service.convert(capture=capture)["enquiry"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def _item(self):
		found = frappe.get_all("Item", filters={"is_sales_item": 1}, pluck="name", limit=1)
		if not found:
			self.skipTest("на этом стенде нет ни одной продаваемой позиции")
		return found[0]

	def test_a_draft_carries_the_customer_and_the_enquiry(self):
		result = service.draft(
			enquiry=self.enquiry, items=[{"item_code": self._item(), "qty": 1}]
		)

		quotation = frappe.get_doc("Quotation", result["quotation"])
		self.assertEqual(quotation.opportunity, self.enquiry)
		self.assertEqual(quotation.docstatus, 0)
		self.assertTrue(quotation.party_name)
		self.assertTrue(quotation.company)

	def test_a_draft_with_no_items_is_refused_because_ERPNext_is_right(self):
		"""Предложение без строк — не предложение.

		Я собирался разрешить пустой черновик и ошибся: ERPNext отказался его
		вставлять. Роль «обращение принято, цена не известна» уже играет
		заявка, и второй документ с тем же смыслом только запутает.
		"""
		with self.assertRaises(frappe.ValidationError):
			service.draft(enquiry=self.enquiry)

	def test_the_customers_own_words_travel_onto_the_quotation(self):
		"""Тот, кто ставит цену, должен видеть, что именно просили."""
		result = service.draft(
			enquiry=self.enquiry, items=[{"item_code": self._item(), "qty": 1}]
		)

		said = frappe.get_all(
			"Comment",
			filters={"reference_doctype": "Quotation", "reference_name": result["quotation"]},
			pluck="content",
		)
		self.assertTrue(any("белый глянец" in c for c in said))

	def test_drafting_twice_returns_the_same_draft(self):
		"""Два предложения по одному обращению — два разных ответа клиенту."""
		rows = [{"item_code": self._item(), "qty": 1}]
		first = service.draft(enquiry=self.enquiry, items=rows)
		second = service.draft(enquiry=self.enquiry, items=rows)

		self.assertEqual(second["status"], "already_drafted")
		self.assertEqual(second["quotation"], first["quotation"])

	def test_items_are_taken_when_they_are_already_known(self):
		result = service.draft(
			enquiry=self.enquiry,
			items=[{"item_code": self._item(), "qty": 2, "rate": 150000}],
		)
		self.assertEqual(result["items"], 1)

	def test_a_broken_item_list_is_refused_rather_than_silently_emptied(self):
		"""Испорченный список — это не «нет позиций», это непонятый запрос."""
		with self.assertRaises(frappe.ValidationError):
			api.draft(enquiry=self.enquiry, items="{не json")

	def test_validity_has_an_end(self):
		result = service.draft(
			enquiry=self.enquiry, items=[{"item_code": self._item(), "qty": 1}], valid_days=7
		)
		self.assertEqual(
			frappe.utils.getdate(result["valid_till"]),
			frappe.utils.getdate(frappe.utils.add_days(frappe.utils.nowdate(), 7)),
		)


class TestScope(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		import inspect

		self.assertNotIn("company", inspect.signature(service.draft).parameters)
		self.assertNotIn("company", inspect.signature(api.draft).parameters)

	def test_an_enquiry_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.PermissionError):
			service.draft(enquiry="does-not-exist")
