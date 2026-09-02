# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Гарантия — последнее звено и первое, о чём вспоминают через год."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import acceptance as acceptance_service
from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import enquiry as enquiry_service
from korkem_manufacturing.services import proposal as proposal_service
from korkem_manufacturing.services import warranty as service


class TestWarrantyStatus(IntegrationTestCase):
	def setUp(self):
		found = frappe.get_all("Item", filters={"is_sales_item": 1}, pluck="name", limit=1)
		if not found:
			self.skipTest("на этом стенде нет ни одной продаваемой позиции")
		self.item = found[0]
		capture = capture_service.record(
			text="Кухня",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["capture"]
		enquiry = enquiry_service.convert(capture=capture)["enquiry"]
		quotation = proposal_service.draft(
			enquiry=enquiry, items=[{"item_code": self.item, "qty": 1, "rate": 100000}]
		)["quotation"]
		self.order = acceptance_service.accept(
			quotation=quotation,
			deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 15),
		)["sales_order"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_nothing_shipped_means_no_warranty_yet(self):
		"""Это состояние, а не ошибка: клиент ещё ничего не получил."""
		result = service.status(sales_order=self.order)

		self.assertIsNone(result["shipped_on"])
		self.assertTrue(all(row["until"] is None for row in result["items"]))

	def test_the_clock_starts_at_delivery_not_at_the_order(self):
		"""Недели ожидания — не гарантийный срок клиента."""
		shipped = frappe.utils.add_days(frappe.utils.nowdate(), -10)
		with (
			patch.object(service, "_shipped_on", return_value=shipped),
			patch.object(service.frappe.db, "get_value", return_value=365),
		):
			result = service.status(sales_order=self.order)

		self.assertEqual(str(result["shipped_on"]), str(shipped))
		self.assertEqual(
			frappe.utils.getdate(result["items"][0]["until"]),
			frappe.utils.getdate(frappe.utils.add_days(shipped, 365)),
		)
		self.assertTrue(result["items"][0]["active"])

	def test_an_item_with_no_warranty_period_has_no_end_date(self):
		with (
			patch.object(service, "_shipped_on", return_value=frappe.utils.nowdate()),
			patch.object(service.frappe.db, "get_value", return_value=0),
		):
			result = service.status(sales_order=self.order)
		self.assertIsNone(result["items"][0]["until"])


class TestClaims(IntegrationTestCase):
	def setUp(self):
		found = frappe.get_all("Item", filters={"is_sales_item": 1}, pluck="name", limit=1)
		if not found:
			self.skipTest("на этом стенде нет ни одной продаваемой позиции")
		self.item = found[0]
		capture = capture_service.record(
			text="Шкаф",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["capture"]
		enquiry = enquiry_service.convert(capture=capture)["enquiry"]
		quotation = proposal_service.draft(
			enquiry=enquiry, items=[{"item_code": self.item, "qty": 1, "rate": 70000}]
		)["quotation"]
		self.order = acceptance_service.accept(
			quotation=quotation,
			deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 15),
		)["sales_order"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def _status(self, until, active):
		return {
			"sales_order": self.order,
			"customer": "x",
			"shipped_on": "2026-01-01",
			"items": [
				{
					"item_code": self.item,
					"item_name": self.item,
					"days": 365,
					"until": until,
					"active": active,
				}
			],
		}

	def test_an_expired_warranty_is_refused_with_the_date(self):
		"""«Гарантия закончилась 14 июня» — ответ, с которым можно согласиться."""
		with patch.object(service, "status", return_value=self._status("2026-06-14", False)):
			with self.assertRaises(frappe.ValidationError) as refusal:
				service.claim(
					sales_order=self.order, item_code=self.item, complaint="Отвалилась петля"
				)
		self.assertIn("2026-06-14", str(refusal.exception))

	def test_a_live_warranty_accepts_the_claim(self):
		until = frappe.utils.add_days(frappe.utils.nowdate(), 90)
		with patch.object(service, "status", return_value=self._status(str(until), True)):
			result = service.claim(
				sales_order=self.order, item_code=self.item, complaint="Отвалилась петля"
			)

		self.assertEqual(result["status"], "accepted")
		claim = frappe.get_doc("Warranty Claim", result["claim"])
		self.assertIn("петля", claim.complaint)

	def test_a_claim_with_no_description_is_refused(self):
		"""Рекламация без описания — это звонок, а не рекламация."""
		with patch.object(service, "status", return_value=self._status("2027-01-01", True)):
			with self.assertRaises(frappe.ValidationError):
				service.claim(sales_order=self.order, item_code=self.item, complaint="  ")

	def test_a_claim_on_an_item_not_in_the_order_is_refused(self):
		with patch.object(service, "status", return_value=self._status("2027-01-01", True)):
			with self.assertRaises(frappe.ValidationError):
				service.claim(
					sales_order=self.order, item_code="НЕТ-ТАКОГО", complaint="Скрипит"
				)


class TestScope(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		import inspect

		self.assertNotIn("company", inspect.signature(service.status).parameters)

	def test_an_order_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.PermissionError):
			service.status(sales_order="does-not-exist")
