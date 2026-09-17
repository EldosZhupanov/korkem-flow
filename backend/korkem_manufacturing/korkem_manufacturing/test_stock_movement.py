# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Unit and integration tests for Double-entry Material Movement Ledger."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import setup
from korkem_manufacturing.services import stock_movement
from korkem_manufacturing.services.scope import current_company


class TestStockMovement(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		setup.provision()

	def setUp(self):
		frappe.set_user("Administrator")
		self.company = current_company()
		frappe.defaults.set_user_default("Company", self.company)
		self.item_code = "TEST-LDSP-16-WHT"
		self.location_a = "Stores - KRK"
		self.location_b = "WIP:SO-100"

	def tearDown(self):
		frappe.defaults.set_user_default("Company", self.company)
		frappe.db.rollback()

	def test_double_entry_balance_reconstruction(self):
		"""Баланс на локации точно равен сумме приходов минус сумме расходов."""
		item = f"TEST-RECON-{frappe.generate_hash(length=6)}"
		loc = f"Loc-{frappe.generate_hash(length=4)}"

		# Начальный баланс: 0
		self.assertEqual(stock_movement.get_balance(self.company, loc, item), 0.0)

		# 1. Приход: +10
		stock_movement.record_movement(
			company=self.company,
			from_location="Supplier",
			to_location=loc,
			item_code=item,
			qty=10.0,
			reason="Initial Balance",
		)
		self.assertEqual(stock_movement.get_balance(self.company, loc, item), 10.0)

		# 2. Приход: +5
		stock_movement.record_movement(
			company=self.company,
			from_location="Supplier",
			to_location=loc,
			item_code=item,
			qty=5.0,
			reason="Purchase Receipt",
		)
		self.assertEqual(stock_movement.get_balance(self.company, loc, item), 15.0)

		# 3. Расход в цех: -4
		stock_movement.record_movement(
			company=self.company,
			from_location=loc,
			to_location="WIP-Cell-1",
			item_code=item,
			qty=4.0,
			reason="Issue to Production",
		)
		self.assertEqual(stock_movement.get_balance(self.company, loc, item), 11.0)
		self.assertEqual(stock_movement.get_balance(self.company, "WIP-Cell-1", item), 4.0)

	def test_non_positive_qty_rejected(self):
		"""Количество перемещения должно быть строго > 0."""
		with self.assertRaises(frappe.ValidationError):
			stock_movement.record_movement(
				company=self.company,
				from_location=self.location_a,
				to_location=self.location_b,
				item_code=self.item_code,
				qty=0.0,
				reason="Zero Qty Test",
			)

		with self.assertRaises(frappe.ValidationError):
			stock_movement.record_movement(
				company=self.company,
				from_location=self.location_a,
				to_location=self.location_b,
				item_code=self.item_code,
				qty=-5.0,
				reason="Negative Qty Test",
			)

	def test_append_only_modification_blocked(self):
		"""Изменение существующей записи складского перемещения запрещено."""
		doc = stock_movement.record_movement(
			company=self.company,
			from_location=self.location_a,
			to_location=self.location_b,
			item_code=self.item_code,
			qty=2.0,
			reason="Initial",
		)
		doc.qty = 10.0
		with self.assertRaises(frappe.PermissionError):
			doc.save()

	def test_physical_deletion_blocked(self):
		"""Физическое удаление записи перемещения запрещено."""
		doc = stock_movement.record_movement(
			company=self.company,
			from_location=self.location_a,
			to_location=self.location_b,
			item_code=self.item_code,
			qty=2.0,
			reason="Initial",
		)
		with self.assertRaises(frappe.PermissionError):
			doc.delete()

	def test_compensation_reversal_restores_balance(self):
		"""Сторнирующая проводка (Compensation) зеркально восстанавливает баланс."""
		item = f"TEST-COMP-{frappe.generate_hash(length=6)}"
		loc = f"LocComp-{frappe.generate_hash(length=4)}"

		# Движение: +8 на склад loc
		orig = stock_movement.record_movement(
			company=self.company,
			from_location="Supplier",
			to_location=loc,
			item_code=item,
			qty=8.0,
			reason="Delivery",
		)
		self.assertEqual(stock_movement.get_balance(self.company, loc, item), 8.0)

		# Сторнируем движение
		comp = stock_movement.compensate_movement(orig.name, reason="Ошибочная поставка")
		self.assertEqual(comp.is_compensation, 1)
		self.assertEqual(comp.compensated_movement, orig.name)
		self.assertEqual(comp.from_location, loc)
		self.assertEqual(comp.to_location, "Supplier")
		self.assertEqual(comp.qty, 8.0)

		# Баланс вернулся в 0.0
		self.assertEqual(stock_movement.get_balance(self.company, loc, item), 0.0)
