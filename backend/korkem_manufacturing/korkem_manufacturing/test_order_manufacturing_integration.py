# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Integration test for Manufacturing Domain Flow: Order State Machine, BOM & Stock Reservation."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing import setup
from korkem_manufacturing.services import offcuts, order_state, outbox, stock_reservation
from korkem_manufacturing.services.scope import current_company


class TestOrderManufacturingIntegration(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		setup.provision()

	def setUp(self):
		frappe.set_user("Administrator")
		self.company = current_company()
		frappe.defaults.set_user_default("Company", self.company)
		self.warehouse = frappe.db.get_value("Warehouse", {"company": self.company}, "name") or "Stores - KRK"
		self.raw_item = self._get_or_create_item("TEST-RAW-BOARD-16", "ЛДСП 16 Сырье")
		self.fg_item = self._get_or_create_item("TEST-FG-WARDROBE", "Шкаф распашной 2-дв")

	def tearDown(self):
		frappe.defaults.set_user_default("Company", self.company)
		frappe.db.rollback()

	def _get_or_create_item(self, code: str, name: str) -> str:
		if not frappe.db.exists("Item", code):
			item = frappe.get_doc(
				{
					"doctype": "Item",
					"item_code": code,
					"item_name": name,
					"item_group": "Raw Material" if "RAW" in code else "Products",
					"stock_uom": "Nos",
					"is_stock_item": 1,
				}
			)
			item.insert(ignore_permissions=True)
		return code

	def _create_test_order(self, item_code: str, qty: float = 1.0):
		doc = frappe.get_doc(
			{
				"doctype": "Sales Order",
				"company": self.company,
				"customer": "Павлодар Уют",
				"transaction_date": nowdate(),
				"delivery_date": add_days(nowdate(), 7),
				"korkem_state": "Ready for Production",
				"items": [
					{
						"item_code": item_code,
						"qty": qty,
						"rate": 50000,
						"delivery_date": add_days(nowdate(), 7),
						"warehouse": self.warehouse,
					}
				],
			}
		)
		doc.insert(ignore_permissions=True)
		return doc

	def _create_test_bom(self, finished_item: str, raw_item: str, qty_needed: float = 2.0):
		bom = frappe.get_doc(
			{
				"doctype": "BOM",
				"item": finished_item,
				"quantity": 1,
				"currency": "KZT",
				"company": self.company,
				"is_active": 1,
				"is_default": 1,
				"items": [
					{
						"item_code": raw_item,
						"qty": qty_needed,
						"rate": 8000,
					}
				],
			}
		)
		bom.insert(ignore_permissions=True)
		bom.submit()
		return bom

	def test_in_production_blocked_without_bom(self):
		"""Перевод в In Production блокируется, если у изделий заказа нет BOM."""
		# Изделие без BOM
		no_bom_item = self._get_or_create_item("TEST-NOBOM-TABLE", "Стол без спецификации")
		order = self._create_test_order(no_bom_item)

		with self.assertRaises(frappe.ValidationError) as ctx:
			order_state.transition(
				sales_order=order.name,
				target_state="In Production",
			)
		self.assertIn("спецификация материалов (BOM)", str(ctx.exception))

	def test_in_production_blocked_on_material_shortage(self):
		"""Перевод в In Production блокируется при дефиците резервов и эмитирует событие material.shortage_detected."""
		bom = self._create_test_bom(self.fg_item, self.raw_item, qty_needed=3.0)
		order = self._create_test_order(self.fg_item, qty=1.0)

		# Пытаемся запустить заказ в производство без резервирования
		with self.assertRaises(frappe.ValidationError) as ctx:
			order_state.transition(
				sales_order=order.name,
				target_state="In Production",
			)
		self.assertIn("дефицит зарезервированных материалов", str(ctx.exception))

		# Проверяем, что событие дефицита записано в Outbox
		events = frappe.get_all(
			"Domain Outbox Event",
			filters={
				"event_name": "material.shortage_detected",
				"aggregate_id": order.name,
			},
		)
		self.assertGreater(len(events), 0)

	def test_in_production_succeeds_when_materials_reserved(self):
		"""Перевод в In Production успешен, когда все материалы по BOM зарезервированы."""
		bom = self._create_test_bom(self.fg_item, self.raw_item, qty_needed=2.0)
		order = self._create_test_order(self.fg_item, qty=1.0)

		# Резервируем требуемые 2 листа
		stock_reservation.reserve_stock(
			company=self.company,
			sales_order=order.name,
			item_code=self.raw_item,
			qty=2.0,
			warehouse=self.warehouse,
			reservation_type="Full Sheet",
		)

		# Теперь переход в In Production должен пройти успешно
		result = order_state.transition(
			sales_order=order.name,
			target_state="In Production",
		)
		self.assertEqual(result["new_state"], "In Production")

		# Проверяем, что резерв перешел в статус Consumed
		res = frappe.db.get_value(
			"Stock Reservation",
			{"sales_order": order.name, "item_code": self.raw_item},
			"status",
		)
		self.assertEqual(res, "Consumed")

	def test_order_cancellation_releases_all_reservations(self):
		"""При отмене заказа все активные брони материалов и остатков автоматически освобождаются."""
		order = self._create_test_order(self.fg_item, qty=1.0)

		# Создаем остаток и бронируем его
		offcut = offcuts.create_offcut(
			company=self.company,
			material_item=self.raw_item,
			length_mm=1200,
			width_mm=600,
			warehouse=self.warehouse,
		)
		stock_reservation.reserve_stock(
			company=self.company,
			sales_order=order.name,
			item_code=self.raw_item,
			qty=1.0,
			warehouse=self.warehouse,
			offcut=offcut.name,
		)

		# Отменяем заказ
		order_state.transition(
			sales_order=order.name,
			target_state="Cancelled",
			reason="Клиент передумал",
		)

		# Резерв стал Released
		res_status = frappe.db.get_value("Stock Reservation", {"sales_order": order.name}, "status")
		self.assertEqual(res_status, "Released")

		# Деловой остаток снова Available
		offcut_status = frappe.db.get_value("Stock Offcut", offcut.name, "status")
		self.assertEqual(offcut_status, "Available")
