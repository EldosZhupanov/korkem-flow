# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Unit and integration tests for Stock Reservation Service."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing import setup
from korkem_manufacturing.services import offcuts, stock_reservation
from korkem_manufacturing.services.scope import current_company


class TestStockReservation(IntegrationTestCase):
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
		self.order_doc = self._create_test_order()
		self.sales_order = self.order_doc.name

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

	def _create_test_order(self):
		doc = frappe.get_doc(
			{
				"doctype": "Sales Order",
				"company": self.company,
				"customer": "Павлодар Уют",
				"transaction_date": nowdate(),
				"delivery_date": add_days(nowdate(), 7),
				"korkem_state": "Draft",
				"items": [
					{
						"item_code": self.item_code,
						"qty": 2,
						"rate": 10000,
						"delivery_date": add_days(nowdate(), 7),
						"warehouse": self.warehouse,
					}
				],
			}
		)
		doc.insert(ignore_permissions=True)
		return doc

	def test_reserve_full_sheet(self):
		"""Резервирование целых листов материала под заказ."""
		res = stock_reservation.reserve_stock(
			company=self.company,
			sales_order=self.sales_order,
			item_code=self.item_code,
			qty=2.0,
			warehouse=self.warehouse,
			reservation_type="Full Sheet",
		)
		self.assertEqual(res.status, "Active")
		self.assertEqual(res.sales_order, self.sales_order)
		self.assertEqual(res.qty, 2.0)

	def test_reserve_offcut(self):
		"""Резервирование делового остатка под заказ связывает остаток и переводит его в Reserved."""
		offcut = offcuts.create_offcut(
			company=self.company,
			material_item=self.item_code,
			length_mm=1000,
			width_mm=500,
			warehouse=self.warehouse,
		)
		res = stock_reservation.reserve_stock(
			company=self.company,
			sales_order=self.sales_order,
			item_code=self.item_code,
			qty=1.0,
			warehouse=self.warehouse,
			offcut=offcut.name,
		)
		self.assertEqual(res.reservation_type, "Offcut")
		self.assertEqual(res.offcut, offcut.name)

		# Статус остатка обновился
		offcut_doc = frappe.get_doc("Stock Offcut", offcut.name)
		self.assertEqual(offcut_doc.status, "Reserved")
		self.assertEqual(offcut_doc.reserved_for_order, self.sales_order)

		# Повторная попытка забронировать тот же остаток под другой заказ блокируется
		other_order = self._create_test_order().name
		with self.assertRaises(frappe.ValidationError):
			stock_reservation.reserve_stock(
				company=self.company,
				sales_order=other_order,
				item_code=self.item_code,
				qty=1.0,
				warehouse=self.warehouse,
				offcut=offcut.name,
			)

	def test_idempotency_key_prevents_duplicate_reservation(self):
		"""Идемпотентный вызов с тем же ключом не создает дубликат брони."""
		key = f"idem-res-{frappe.generate_hash(length=8)}"
		res1 = stock_reservation.reserve_stock(
			company=self.company,
			sales_order=self.sales_order,
			item_code=self.item_code,
			qty=1.0,
			warehouse=self.warehouse,
			idempotency_key=key,
		)
		res2 = stock_reservation.reserve_stock(
			company=self.company,
			sales_order=self.sales_order,
			item_code=self.item_code,
			qty=1.0,
			warehouse=self.warehouse,
			idempotency_key=key,
		)
		self.assertEqual(res1.name, res2.name)

	def test_release_reservations_for_order(self):
		"""Освобождение всех резервов заказа освобождает и привязанные деловые остатки."""
		offcut = offcuts.create_offcut(
			company=self.company,
			material_item=self.item_code,
			length_mm=1000,
			width_mm=500,
			warehouse=self.warehouse,
		)
		stock_reservation.reserve_stock(
			company=self.company,
			sales_order=self.sales_order,
			item_code=self.item_code,
			qty=1.0,
			warehouse=self.warehouse,
			offcut=offcut.name,
		)
		stock_reservation.reserve_stock(
			company=self.company,
			sales_order=self.sales_order,
			item_code=self.item_code,
			qty=3.0,
			warehouse=self.warehouse,
			reservation_type="Full Sheet",
		)

		released = stock_reservation.release_reservations_for_order(self.sales_order)
		self.assertEqual(len(released), 2)

		# Остаток вернулся в Available
		offcut_doc = frappe.get_doc("Stock Offcut", offcut.name)
		self.assertEqual(offcut_doc.status, "Available")
		self.assertIsNone(offcut_doc.reserved_for_order)

	def test_consume_reservations_for_order(self):
		"""Списание резервов заказа переводит их и деловые остатки в статус Consumed."""
		offcut = offcuts.create_offcut(
			company=self.company,
			material_item=self.item_code,
			length_mm=1000,
			width_mm=500,
			warehouse=self.warehouse,
		)
		stock_reservation.reserve_stock(
			company=self.company,
			sales_order=self.sales_order,
			item_code=self.item_code,
			qty=1.0,
			warehouse=self.warehouse,
			offcut=offcut.name,
		)

		consumed = stock_reservation.consume_reservations_for_order(self.sales_order)
		self.assertEqual(len(consumed), 1)

		offcut_doc = frappe.get_doc("Stock Offcut", offcut.name)
		self.assertEqual(offcut_doc.status, "Consumed")
