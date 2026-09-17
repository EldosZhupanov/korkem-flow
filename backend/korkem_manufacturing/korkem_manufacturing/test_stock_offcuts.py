# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Unit and integration tests for Stock Offcut Domain Service and Invariants."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing import setup
from korkem_manufacturing.services import offcuts
from korkem_manufacturing.services.scope import current_company


class TestStockOffcuts(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		setup.provision()

	def setUp(self):
		frappe.set_user("Administrator")
		self.company = current_company()
		frappe.defaults.set_user_default("Company", self.company)
		self.warehouse = frappe.db.get_value("Warehouse", {"company": self.company}, "name") or "Stores - KRK"
		self.item_code = self._get_or_create_test_item()
		self.sales_order = self._create_test_order(self.company).name

	def tearDown(self):
		frappe.defaults.set_user_default("Company", self.company)
		frappe.db.rollback()

	def _get_or_create_test_item(self) -> str:
		code = "TEST-LDSP-16-WHT"
		if not frappe.db.exists("Item", code):
			item = frappe.get_doc(
				{
					"doctype": "Item",
					"item_code": code,
					"item_name": "ЛДСП 16мм Белый Шагрень",
					"item_group": "Raw Material",
					"stock_uom": "Nos",
					"is_stock_item": 1,
				}
			)
			item.insert(ignore_permissions=True)
		return code

	def _create_test_order(self, company: str):
		wh = frappe.db.get_value("Warehouse", {"company": company}, "name") or self.warehouse
		doc = frappe.get_doc(
			{
				"doctype": "Sales Order",
				"company": company,
				"customer": "Павлодар Уют",
				"transaction_date": nowdate(),
				"delivery_date": add_days(nowdate(), 7),
				"korkem_state": "Draft",
				"items": [
					{
						"item_code": self.item_code,
						"qty": 1,
						"rate": 10000,
						"delivery_date": add_days(nowdate(), 7),
						"warehouse": wh,
					}
				],
			}
		)
		doc.insert(ignore_permissions=True)
		return doc

	def test_create_offcut_generates_area_qr_and_barcode(self):
		"""Проверка автоматического расчета площади в м2 и генерации кодов."""
		doc = offcuts.create_offcut(
			company=self.company,
			material_item=self.item_code,
			length_mm=1200,
			width_mm=600,
			warehouse=self.warehouse,
			decor="W1000",
			thickness_mm=16,
		)
		self.assertEqual(doc.status, "Available")
		self.assertEqual(doc.area_m2, 0.72)  # 1200 * 600 / 1e6
		self.assertTrue(doc.qr_code.startswith("OFFCUT:"))
		self.assertTrue(doc.barcode.startswith("OFC-"))

	def test_min_size_threshold_rejected(self):
		"""Остатки меньше 100х100 мм или 0.04 м2 считаются отходом и блокируются."""
		with self.assertRaises(frappe.ValidationError):
			offcuts.create_offcut(
				company=self.company,
				material_item=self.item_code,
				length_mm=80,  # < 100mm
				width_mm=600,
				warehouse=self.warehouse,
			)

		with self.assertRaises(frappe.ValidationError):
			offcuts.create_offcut(
				company=self.company,
				material_item=self.item_code,
				length_mm=150,
				width_mm=150,  # 0.0225 m2 < 0.04 m2
				warehouse=self.warehouse,
			)

	def test_find_usable_offcuts_with_rotation(self):
		"""Поиск остатков поддерживает поворот на 90 градусов (Best-fit)."""
		# Создаем остаток 800 (L) x 400 (W)
		doc = offcuts.create_offcut(
			company=self.company,
			material_item=self.item_code,
			length_mm=800,
			width_mm=400,
			warehouse=self.warehouse,
		)

		# Запрашиваем деталь 350 (L) x 750 (W) -> без поворота не влезет, с поворотом (800x400 >= 750x350) влезет
		direct_match = offcuts.find_usable_offcuts(
			company=self.company,
			material_item=self.item_code,
			min_length=350,
			min_width=750,
			allow_rotation=False,
		)
		matched_names = [m["name"] for m in direct_match]
		self.assertNotIn(doc.name, matched_names)

		# С разрешением поворота
		rotated_match = offcuts.find_usable_offcuts(
			company=self.company,
			material_item=self.item_code,
			min_length=350,
			min_width=750,
			allow_rotation=True,
		)
		rot_names = [m["name"] for m in rotated_match]
		self.assertIn(doc.name, rot_names)

	def test_reserve_release_consume_lifecycle(self):
		"""Полный жизненный цикл остатка: Available -> Reserved -> Available -> Reserved -> Consumed."""
		doc = offcuts.create_offcut(
			company=self.company,
			material_item=self.item_code,
			length_mm=1000,
			width_mm=500,
			warehouse=self.warehouse,
		)

		# Бронируем
		offcuts.reserve_offcut(doc.name, sales_order=self.sales_order)
		d1 = frappe.get_doc("Stock Offcut", doc.name)
		self.assertEqual(d1.status, "Reserved")
		self.assertEqual(d1.reserved_for_order, self.sales_order)

		# Освобождаем
		offcuts.release_offcut(doc.name, sales_order=self.sales_order)
		d2 = frappe.get_doc("Stock Offcut", doc.name)
		self.assertEqual(d2.status, "Available")
		self.assertIsNone(d2.reserved_for_order)

		# Снова бронируем и списываем в производство
		offcuts.reserve_offcut(doc.name, sales_order=self.sales_order)
		offcuts.consume_offcut(doc.name, sales_order=self.sales_order)
		d3 = frappe.get_doc("Stock Offcut", doc.name)
		self.assertEqual(d3.status, "Consumed")

		# Нельзя списать повторно!
		with self.assertRaises(frappe.ValidationError):
			offcuts.consume_offcut(doc.name, sales_order=self.sales_order)

	def test_scrap_offcut(self):
		"""Списание поврежденного остатка в утиль."""
		doc = offcuts.create_offcut(
			company=self.company,
			material_item=self.item_code,
			length_mm=900,
			width_mm=450,
			warehouse=self.warehouse,
		)
		offcuts.scrap_offcut(doc.name, reason="Скол угла при транспортировке")
		d = frappe.get_doc("Stock Offcut", doc.name)
		self.assertEqual(d.status, "Scrapped")
		self.assertIn("Скол угла", d.notes)

		# Нельзя забронировать списанный
		with self.assertRaises(frappe.ValidationError):
			offcuts.reserve_offcut(doc.name, sales_order=self.sales_order)

	def test_soft_delete_blocked(self):
		"""Физическое удаление Stock Offcut запрещено."""
		doc = offcuts.create_offcut(
			company=self.company,
			material_item=self.item_code,
			length_mm=1000,
			width_mm=500,
			warehouse=self.warehouse,
		)
		with self.assertRaises(frappe.PermissionError):
			doc.delete()

	def test_cross_tenant_isolation(self):
		"""Компания Б не может видеть или бронировать остатки Компании А."""
		other_company = "Мебель Тест Цех"
		if not frappe.db.exists("Company", other_company):
			return

		doc = offcuts.create_offcut(
			company=self.company,
			material_item=self.item_code,
			length_mm=1000,
			width_mm=500,
			warehouse=self.warehouse,
		)

		order_b = self._create_test_order(other_company)

		frappe.defaults.set_user_default("Company", other_company)
		try:
			with self.assertRaises(frappe.PermissionError):
				offcuts.reserve_offcut(doc.name, sales_order=order_b.name)
		finally:
			frappe.defaults.set_user_default("Company", self.company)
