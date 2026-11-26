# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""A position with no price yet is 0 ₸ — never a price ERPNext finds on its
own (owner, 26.11.2026: «ERPNext посчитал заказ на 53 670 ₸, а расчёт — на
11 550 ₸ … заказ не сохранён»)."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import facade_order, facade_prices, mdf_orders

COMPANY = "KORKEM"
MANAGER = "unpriced.manager@example.com"


class TestUnpricedLine(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		if not frappe.db.exists("User", MANAGER):
			frappe.get_doc({"doctype": "User", "email": MANAGER, "first_name": "Unpriced", "send_welcome_email": 0,
							"roles": [{"role": "Sales User"}]}).insert(ignore_permissions=True)
		frappe.defaults.set_user_default("Company", COMPANY, user=MANAGER)
		cls.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		assert cls.customer, "the seeded site has customers; no silent skip"

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_a_line_with_no_price_stays_at_zero_beside_an_item_price(self):
		facade_order._ensure_items()
		price_list = frappe.db.get_single_value("Selling Settings", "selling_price_list") or "Standard Selling"
		# What ERPNext leaves behind after an earlier order (Stock Settings:
		# «auto insert price list rate if missing»).
		existing = frappe.db.get_value("Item Price", {"item_code": facade_order.FACADE_ITEM, "price_list": price_list})
		price = None if existing else frappe.get_doc(
			{"doctype": "Item Price", "item_code": facade_order.FACADE_ITEM, "price_list": price_list,
			 "price_list_rate": 7_020}).insert(ignore_permissions=True)
		try:
			frappe.set_user(MANAGER)
			card = mdf_orders.save_draft(customer=self.customer, delivery_date=add_days(nowdate(), 7),
										 head={"thickness_mm": 16},
										 lines=[{"height_mm": 1000, "width_mm": 500, "qty": 4}])  # no milling, no price
			self.assertEqual(card["total"], 0)
		finally:
			frappe.set_user("Administrator")
			if price:
				price.delete(ignore_permissions=True)
