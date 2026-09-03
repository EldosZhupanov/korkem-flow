# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Склады — имя склада печатается в каждом складском документе."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import warehouses as service
from korkem_manufacturing.services.scope import current_company


class TestWarehouses(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")

	def _name(self) -> str:
		return f"Склад {frappe.generate_hash(length=6)}"

	def test_the_four_erpnext_makes_are_already_there(self):
		"""Заводить их заново не надо — надо их видеть."""
		listed = {row["name"] for row in service.listing()}
		self.assertIn("Finished Goods", listed)
		self.assertIn("Stores", listed)

	def test_the_shipping_warehouse_is_marked(self):
		"""С него уходит готовая мебель, и владелец должен знать, с какого."""
		marked = [row for row in service.listing() if row["is_shipping_default"]]
		self.assertEqual(len(marked), 1)

	def test_a_warehouse_can_be_added(self):
		name = self._name()
		created = service.create(name=name)

		self.assertEqual(created["name"], name)
		self.assertFalse(created["disabled"])
		self.assertIn(name, {row["name"] for row in service.listing()})

	def test_a_warehouse_without_a_name_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.create(name="   ")

	def test_two_warehouses_with_one_name_are_refused(self):
		name = self._name()
		service.create(name=name)
		with self.assertRaises(frappe.ValidationError):
			service.create(name=name)

	def test_a_warehouse_can_become_the_shipping_default(self):
		"""Ради этого свой склад и заводят: иначе он стоит пустым."""
		created = service.create(name=self._name())
		made = service.set_shipping_default(warehouse=created["warehouse"])

		self.assertTrue(made["is_shipping_default"])
		self.assertEqual(
			frappe.db.get_value("Company", current_company(), "default_fg_warehouse"),
			created["warehouse"],
		)

	def test_only_one_warehouse_is_the_shipping_default(self):
		first = service.create(name=self._name())
		second = service.create(name=self._name())
		service.set_shipping_default(warehouse=first["warehouse"])
		service.set_shipping_default(warehouse=second["warehouse"])

		marked = [row for row in service.listing() if row["is_shipping_default"]]
		self.assertEqual([row["warehouse"] for row in marked], [second["warehouse"]])

	def test_a_disabled_warehouse_cannot_become_the_shipping_default(self):
		created = service.create(name=self._name())
		service.set_disabled(warehouse=created["warehouse"], disabled=True)
		with self.assertRaises(frappe.ValidationError):
			service.set_shipping_default(warehouse=created["warehouse"])

	def test_erpnext_refuses_to_rename_a_warehouse_and_we_do_not_force_it(self):
		"""Проверено, а не предположено: у `Warehouse` нет `allow_rename`.

		В документах печатается сам идентификатор склада, а дерево держится на
		нём же. Обойти флаг можно за строку — и это ровно тот случай, про
		который сказано «не двигать остатки руками».
		"""
		created = service.create(name=self._name())
		with self.assertRaises(frappe.ValidationError):
			frappe.rename_doc("Warehouse", created["warehouse"], "Другое имя - ED")

	def test_an_unused_place_is_disabled_not_deleted(self):
		"""Склад с проводками нельзя убрать, не оторвав историю остатков."""
		created = service.create(name=self._name())
		off = service.set_disabled(warehouse=created["warehouse"], disabled=True)

		self.assertTrue(off["disabled"])
		self.assertTrue(frappe.db.exists("Warehouse", created["warehouse"]))

	def test_a_disabled_place_can_come_back(self):
		created = service.create(name=self._name())
		service.set_disabled(warehouse=created["warehouse"], disabled=True)
		back = service.set_disabled(warehouse=created["warehouse"], disabled=False)
		self.assertFalse(back["disabled"])

	def test_the_shipping_warehouse_cannot_be_disabled(self):
		"""Иначе заказы будет некуда отгружать, и выяснится это при отгрузке."""
		shipping = frappe.db.get_value("Company", current_company(), "default_fg_warehouse")
		with self.assertRaises(frappe.ValidationError):
			service.set_disabled(warehouse=shipping, disabled=True)

	def test_a_warehouse_from_another_company_is_refused(self):
		"""Чужой склад — это отказ в доступе, а не ошибка ввода."""
		with self.assertRaises(frappe.PermissionError):
			service.set_shipping_default(warehouse="Склада-Нет - XX")

	def test_an_employee_cannot_add_or_rename_warehouses(self):
		from korkem_manufacturing.services import invitations

		email = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		invitations.invite_employee(email=email, position="shop_floor")

		frappe.set_user(email)
		with self.assertRaises(frappe.PermissionError):
			service.create(name=self._name())
