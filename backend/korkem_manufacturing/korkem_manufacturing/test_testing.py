# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The cleanup tests lean on must itself work: a committed order really goes."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing import testing
from korkem_manufacturing.services import facade_order, facade_prices

COMPANY = "KORKEM"
PVC = facade_prices.PVC


class TestLeftoversAreRemoved(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)

	def _committed_order(self) -> tuple[str, str]:
		customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		order = facade_order.create_order(
			customer=customer,
			delivery_date=add_days(nowdate(), 10),
			lines=[{"width_mm": 500, "height_mm": 400, "qty": 1, "milling": "Квадро", "finish": PVC}],
		)["sales_order"]
		# What the tests this exists for do by accident: commit past the rollback.
		frappe.db.commit()
		return order, customer

	def test_a_committed_submitted_order_is_cancelled_and_removed(self):
		order, _ = self._committed_order()
		self.assertEqual(frappe.db.get_value("Sales Order", order, "docstatus"), 1)

		self.assertEqual(testing.remove_order(order), [])
		self.assertFalse(frappe.db.exists("Sales Order", order))

	def test_a_customer_something_else_still_uses_is_kept(self):
		order, customer = self._committed_order()
		keeper, _ = self._committed_order()

		self.assertEqual(testing.remove_order(order, also=[("Customer", customer)]), [])
		self.assertTrue(frappe.db.exists("Customer", customer))

		# And the second order goes too: a cleanup test must not be a leftover.
		self.assertEqual(testing.remove_order(keeper), [])
		self.assertFalse(frappe.db.exists("Sales Order", keeper))

	def test_an_order_that_is_already_gone_is_nothing_to_do(self):
		self.assertEqual(testing.remove_order("SAL-ORD-НЕТ-ТАКОГО"), [])
