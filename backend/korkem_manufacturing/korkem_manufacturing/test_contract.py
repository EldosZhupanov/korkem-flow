# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Договор — половина этапа от нас не зависит, но документ нужен уже сегодня."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import contract as service


class TestContract(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.order = _an_order()

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_a_contract_is_drafted_against_the_order(self):
		result = service.draft(sales_order=self.order)

		self.assertEqual(result["status"], "drafted")
		linked = frappe.db.get_value(
			"Contract", result["contract"], ["document_type", "document_name"]
		)
		self.assertEqual(linked, ("Sales Order", self.order))

	def test_the_default_text_lists_what_was_agreed(self):
		"""Пустое поле нечего править. Здесь то, что система знает точно."""
		result = service.draft(sales_order=self.order)
		terms = frappe.db.get_value("Contract", result["contract"], "contract_terms")

		self.assertIn(self.order, terms)
		self.assertIn("Срок поставки", terms)
		self.assertIn("Позиции:", terms)

	def test_one_order_has_one_contract(self):
		"""Второй договор с другим текстом — спор о том, на что согласились."""
		first = service.draft(sales_order=self.order)
		second = service.draft(sales_order=self.order)

		self.assertEqual(first["contract"], second["contract"])
		self.assertEqual(second["status"], "already_drafted")

	def test_a_signature_records_who_and_when(self):
		"""Не галочка: сегодня отметку ставит человек, завтра TrustMe."""
		contract = service.draft(sales_order=self.order)["contract"]
		signed = service.sign(contract=contract, signee="Данияр Ахметов")

		self.assertEqual(signed["status"], "signed")
		row = frappe.db.get_value(
			"Contract", contract, ["is_signed", "signee", "signed_on"], as_dict=True
		)
		self.assertTrue(row["is_signed"])
		self.assertEqual(row["signee"], "Данияр Ахметов")
		self.assertTrue(row["signed_on"])

	def test_a_signature_without_a_name_is_refused(self):
		contract = service.draft(sales_order=self.order)["contract"]
		with self.assertRaises(frappe.ValidationError):
			service.sign(contract=contract, signee="   ")

	def test_signing_twice_does_not_rewrite_the_first_signature(self):
		contract = service.draft(sales_order=self.order)["contract"]
		service.sign(contract=contract, signee="Данияр Ахметов")
		again = service.sign(contract=contract, signee="Кто-то другой")

		self.assertEqual(again["status"], "already_signed")
		self.assertEqual(
			frappe.db.get_value("Contract", contract, "signee"), "Данияр Ахметов"
		)

	def test_an_unsigned_contract_is_a_draft(self):
		"""Проведён — значит действует. Черновик — это текст без согласия."""
		contract = service.draft(sales_order=self.order)["contract"]
		self.assertEqual(frappe.db.get_value("Contract", contract, "docstatus"), 0)

		service.sign(contract=contract, signee="Данияр Ахметов")
		self.assertEqual(frappe.db.get_value("Contract", contract, "docstatus"), 1)

	def test_status_says_what_is_going_on(self):
		before = service.status(sales_order=self.order)
		self.assertIsNone(before["contract"])
		self.assertFalse(before["signed"])

		contract = service.draft(sales_order=self.order)["contract"]
		service.sign(contract=contract, signee="Данияр Ахметов")

		after = service.status(sales_order=self.order)
		self.assertTrue(after["signed"])
		self.assertEqual(after["signee"], "Данияр Ахметов")

	def test_an_order_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.PermissionError):
			service.draft(sales_order="SAL-ORD-НЕТ-ТАКОГО")

	def test_an_employee_cannot_draft_or_sign(self):
		"""Договор — обязательство компании. Его подписывает владелец."""
		from korkem_manufacturing.services import invitations

		email = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		invitations.invite_employee(email=email, position="shop_floor")
		self.addCleanup(frappe.set_user, "Administrator")

		frappe.set_user(email)
		with self.assertRaises(frappe.PermissionError):
			service.draft(sales_order=self.order)


def _an_order() -> str:
	from korkem_manufacturing.services import acceptance, capture, catalogue, enquiry, proposal

	name = f"Кухня {frappe.generate_hash(length=6)}"
	catalogue.create(name=name, unit="Nos", price=650000)

	said = capture.record(
		text="Кухня",
		understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		assign_to="Administrator",
	)["capture"]
	asked = enquiry.convert(capture=said)["enquiry"]
	quotation = proposal.draft(enquiry=asked, items=[{"item_code": name, "qty": 1}])[
		"quotation"
	]
	frappe.db.set_value("Quotation", quotation, "docstatus", 1)

	return acceptance.accept(
		quotation=quotation,
		deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 21),
	)["sales_order"]
