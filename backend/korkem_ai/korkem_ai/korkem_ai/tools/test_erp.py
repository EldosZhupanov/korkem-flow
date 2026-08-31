# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""The production tools, against the seeded KORKEM dataset.

These read a dataset `korkem_manufacturing.seed_demo` creates: one cabinet, one
BOM, real stock, a submitted order and a half-finished work order. If it is
absent the tests skip rather than fail — an empty bench is a missing fixture,
not a broken tool.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import catalog, erp, registry  # noqa: F401
from korkem_ai.korkem_ai.tools.control import production_control

PRODUCT = "Шкаф Астана"
BOARD = "ДСП 16мм"


def _order():
	rows = frappe.get_all(
		"Sales Order", filters={"customer": "Мебель Астана", "docstatus": 1}, pluck="name"
	)
	return rows[0] if rows else None


class _SeededTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.order = _order()
		if not self.order:
			self.skipTest("seed_demo has not been run on this site")


class TestBillsAreExplodedNotWalked(_SeededTestCase):
	def test_materials_come_back_for_the_quantity_asked_for(self):
		"""4.2 sheets per cabinet, ten cabinets, 42 sheets. The scaling is the
		part worth checking — a BOM written per-batch would otherwise be read
		as per-unit."""
		result = erp.get_bom_materials(PRODUCT, 10)

		board = next(m for m in result["materials"] if m["item_code"] == BOARD)
		self.assertEqual(board["required_qty"], 42.0)
		self.assertEqual(board["uom"], "Лист")

	def test_a_different_quantity_scales(self):
		self.assertEqual(
			erp.get_bom_materials(PRODUCT, 1)["materials"][0]["required_qty"] * 10,
			erp.get_bom_materials(PRODUCT, 10)["materials"][0]["required_qty"],
		)

	def test_an_item_with_no_bom_says_so_rather_than_failing(self):
		"""A model asking about a bought-in part should be told there is no
		bill, not handed an exception to interpret."""
		result = erp.get_bom_materials(BOARD, 5)

		self.assertIsNone(result["bom"])
		self.assertEqual(result["materials"], [])


class TestReadinessComparesAgainstRealStock(_SeededTestCase):
	def test_a_shortage_is_reported_with_the_amount_missing(self):
		result = production_control(sales_order=self.order)["orders"][0]

		self.assertFalse(result["can_start"])
		short = {m["item_code"]: m for m in result["blocking_materials"]}
		self.assertIn(BOARD, short)
		self.assertEqual(short[BOARD]["physical_shortage_qty"], 4.0)

	def test_sufficient_materials_are_not_reported_as_blocking(self):
		result = production_control(sales_order=self.order)["orders"][0]
		blocking = {m["item_code"] for m in result["blocking_materials"]}

		self.assertNotIn("Петля", blocking)
		self.assertNotIn("Кромка 2мм", blocking)

	def test_work_orders_already_running_are_included(self):
		"""'Can we start' has a different answer when it already started."""
		order = production_control(sales_order=self.order)["orders"][0]

		self.assertTrue(order["work_orders"])
		running = order["work_orders"][0]
		self.assertEqual(running["remaining_qty"], running["qty"] - running["produced_qty"])

	def test_an_unknown_order_is_a_sentence_not_a_traceback(self):
		outcome = registry.execute(
			"manufacturing.production_control", {"sales_order": "SAL-ORD-9999-99999"}
		)

		self.assertFalse(outcome["ok"])
		self.assertIn("not found", outcome["error"]["message"])


class TestStockDistinguishesHeldFromFree(_SeededTestCase):
	def test_reserved_stock_is_reported_separately_from_on_hand(self):
		"""Stock committed to another work order is not available for this one,
		and `actual_qty` alone would say it is."""
		rows = erp.get_stock([BOARD])["stock"]

		self.assertTrue(rows)
		row = rows[0]
		self.assertIn("reserved_qty", row)
		self.assertIn("projected_qty", row)
		self.assertNotEqual(row["projected_qty"], row["actual_qty"])


class TestEveryProductionToolIsReadOnly(IntegrationTestCase):
	def test_none_of_them_can_change_anything(self):
		"""Production writes are a separate decision with a separate blast
		radius; they belong behind confirmation, not beside a search."""
		for name in (
			"sales.search_sales_orders",
			"sales.get_sales_order",
			"manufacturing.get_bom_materials",
			"manufacturing.search_work_orders",
			"inventory.get_stock",
			"manufacturing.production_control",
		):
			with self.subTest(tool=name):
				spec = registry.get(name)
				self.assertIs(spec.risk, registry.Risk.READ)
				self.assertFalse(spec.requires_confirmation)
