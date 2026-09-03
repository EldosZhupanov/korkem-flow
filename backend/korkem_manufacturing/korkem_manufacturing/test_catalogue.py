# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Номенклатура и цены — то, из чего собирается предложение."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import catalogue as service


class TestCatalogue(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")

	def _name(self) -> str:
		return f"Шкаф {frappe.generate_hash(length=6)}"

	def test_units_are_the_seven_that_matter_not_all_two_hundred(self):
		"""«Acre» рядом со «шт» приглашает к ошибке, которую заметят при отгрузке."""
		listed = service.units()

		self.assertLessEqual(len(listed), len(service.UNITS))
		self.assertEqual(listed[0]["unit"], "Nos")
		self.assertEqual(listed[0]["label"], "шт")
		self.assertNotIn("Acre", {row["unit"] for row in listed})

	def test_an_item_can_be_created_without_a_price(self):
		"""Цену мебели на заказ называют после замера, а не при заведении."""
		name = self._name()
		created = service.create(name=name, unit="Nos")

		self.assertEqual(created["name"], name)
		self.assertEqual(created["unit"], "Nos")
		self.assertIsNone(created["price"])

	def test_an_item_without_a_unit_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.create(name=self._name(), unit="")

	def test_a_unit_outside_the_offered_list_is_refused(self):
		"""Единицу выбирают из того, что показали, а не присылают любую."""
		with self.assertRaises(frappe.ValidationError):
			service.create(name=self._name(), unit="Acre")

	def test_an_item_without_a_name_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.create(name="   ", unit="Nos")

	def test_the_same_item_is_not_created_twice(self):
		name = self._name()
		service.create(name=name, unit="Nos")
		with self.assertRaises(frappe.ValidationError):
			service.create(name=name, unit="Nos")

	def test_the_price_lands_where_the_quotation_reads_it(self):
		"""Цена не в том прайс-листе выглядит как «не сохранилась»."""
		name = self._name()
		service.create(name=name, unit="Nos")
		service.set_price(code=name, price=450000)

		price_list = frappe.db.get_single_value("Selling Settings", "selling_price_list")
		stored = frappe.get_all(
			"Item Price",
			filters={"item_code": name, "price_list": price_list},
			pluck="price_list_rate",
		)
		self.assertEqual(stored, [450000])

	def test_naming_the_price_twice_does_not_leave_two_prices(self):
		name = self._name()
		service.create(name=name, unit="Nos", price=100000)
		updated = service.set_price(code=name, price=120000)

		self.assertEqual(updated["price"], 120000)
		rows = frappe.get_all(
			"Item Price",
			filters={
				"item_code": name,
				"price_list": frappe.db.get_single_value(
					"Selling Settings", "selling_price_list"
				),
			},
			pluck="name",
		)
		self.assertEqual(len(rows), 1)

	def test_a_negative_price_is_refused(self):
		name = self._name()
		service.create(name=name, unit="Nos")
		with self.assertRaises(frappe.ValidationError):
			service.set_price(code=name, price=-1)

	def test_a_price_for_an_item_that_does_not_exist_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.set_price(code="ПОЗИЦИИ-НЕТ", price=100)

	def test_search_finds_by_name(self):
		name = self._name()
		service.create(name=name, unit="Nos")

		found = [row["name"] for row in service.items(query=name.split()[1])]
		self.assertIn(name, found)

	def test_search_that_matches_nothing_returns_nothing(self):
		self.assertEqual(service.items(query="этого-точно-нет-" + frappe.generate_hash()), [])

	def test_an_employee_cannot_create_items_or_name_prices(self):
		"""Цена уходит в предложение клиенту. Её называет владелец."""
		from korkem_manufacturing.services import invitations

		email = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		invitations.invite_employee(email=email, position="shop_floor")

		frappe.set_user(email)
		with self.assertRaises(frappe.PermissionError):
			service.create(name=self._name(), unit="Nos")

	def test_the_named_price_actually_reaches_a_quotation(self):
		"""Смысл всей номенклатуры — в этом, а не в списке позиций.

		Цена, записанная не в тот прайс-лист, живёт в базе и не появляется в
		предложении: ERPNext берёт список из настроек продаж и не находит в нём
		ничего. Выглядит это как «цена не сохранилась», и проверить это можно
		только пройдя до самого КП.
		"""
		from korkem_manufacturing.services import capture as capture_service
		from korkem_manufacturing.services import enquiry as enquiry_service
		from korkem_manufacturing.services import proposal as proposal_service

		name = self._name()
		service.create(name=name, unit="Nos", price=780000)

		capture = capture_service.record(
			text="Кухня",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
			assign_to="Administrator",
		)["capture"]
		enquiry = enquiry_service.convert(capture=capture)["enquiry"]

		drafted = proposal_service.draft(
			enquiry=enquiry, items=[{"item_code": name, "qty": 1}]
		)
		quotation = frappe.get_doc("Quotation", drafted["quotation"])

		self.assertEqual(quotation.items[0].item_code, name)
		self.assertEqual(frappe.utils.flt(quotation.items[0].rate), 780000)
		self.assertEqual(frappe.utils.flt(quotation.grand_total), 780000)
