# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""A facade quote becomes a real Sales Order — with exactly the quoted money."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, nowdate

from korkem_manufacturing.services import facade_order, facade_prices, facade_quote

COMPANY = "KORKEM"
SELLER = "order.seller@example.com"
HEAD_OF_SALES = "order.head@example.com"
CUTTER = "order.cutter@example.com"
PVC = facade_prices.PVC


def _line(**overrides) -> dict:
	return {"width_mm": 500, "height_mm": 400, "qty": 2, "milling": "Квадро", "finish": PVC, **overrides}


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestFacadeOrder(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(SELLER, "Sales User")
		_user(HEAD_OF_SALES, "Sales Manager")
		_user(CUTTER, "Manufacturing User")
		cls.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		assert cls.customer, "the seeded site has customers; no silent skip"

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price("Квадро", PVC, 21_000)
		frappe.db.delete("Facade Pricing Settings", {"company": COMPANY})
		facade_quote.save_settings(
			double_sided_factor=1.8,
			demolition_unit=facade_quote.PER_ORDER,
			demolition_rate=5_000,
			prepayment_percent=50,
		)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _order(self, user: str = SELLER, **kwargs) -> dict:
		frappe.set_user(user)
		try:
			return facade_order.create_order(
				customer=kwargs.pop("customer", self.customer),
				delivery_date=kwargs.pop("delivery_date", add_days(nowdate(), 14)),
				lines=kwargs.pop("lines", [_line()]),
				**kwargs,
			)
		finally:
			frappe.set_user("Administrator")

	def test_the_head_of_sales_writes_an_order_too(self):
		"""A Sales Manager alone once failed on the customer's receivable account."""
		result = self._order(HEAD_OF_SALES)
		self.assertEqual(frappe.db.get_value("Sales Order", result["sales_order"], "docstatus"), 1)

	def test_the_head_of_sales_writes_for_a_customer_with_an_address(self):
		"""ERPNext renders the billing address onto the order and checks the
		reader may see it. CI found it on 29.10.2026, where the first customer
		happened to have one: «Sales Manager» alone was refused."""
		name = "Фасад Тест Адрес"
		if not frappe.db.exists("Customer", name):
			frappe.get_doc(
				{"doctype": "Customer", "customer_name": name, "customer_type": "Individual"}
			).insert(ignore_permissions=True)
		if not frappe.db.exists("Dynamic Link", {"link_doctype": "Customer", "link_name": name, "parenttype": "Address"}):
			frappe.get_doc(
				{
					"doctype": "Address",
					"address_title": name,
					"address_type": "Billing",
					"address_line1": "ул. Абая, 1",
					"city": "Астана",
					"country": frappe.db.get_value("Company", COMPANY, "country") or "Kazakhstan",
					"is_primary_address": 1,
					"links": [{"link_doctype": "Customer", "link_name": name}],
				}
			).insert(ignore_permissions=True)
		result = self._order(HEAD_OF_SALES, customer=name)
		self.assertEqual(frappe.db.get_value("Sales Order", result["sales_order"], "docstatus"), 1)

	def test_the_order_carries_exactly_the_quoted_total(self):
		result = self._order(lines=[_line(), _line(double_sided=1, qty=1)], demolition=1)
		order = frappe.get_doc("Sales Order", result["sales_order"])

		self.assertEqual(order.docstatus, 1)
		# 8 400 + 7 560 + 5 000 demolition
		self.assertEqual(result["total"], 20_960)
		self.assertEqual(flt(order.grand_total), 20_960)
		self.assertEqual(flt(order.korkem_prepayment_agreed), 10_480)

	def test_the_line_is_pieces_times_a_whole_tenge_price(self):
		result = self._order()
		row = frappe.get_doc("Sales Order", result["sales_order"]).items[0]
		self.assertEqual((flt(row.qty), flt(row.rate), flt(row.amount)), (2, 4_200, 8_400))

	def test_the_shop_floor_reads_the_size_from_fields(self):
		result = self._order(lines=[_line(double_sided=1)])
		row = frappe.get_doc("Sales Order", result["sales_order"]).items[0]
		self.assertEqual((row.korkem_width_mm, row.korkem_height_mm), (500, 400))
		self.assertEqual((row.korkem_milling, row.korkem_finish), ("Квадро", PVC))
		self.assertEqual(row.korkem_double_sided, 1)
		self.assertAlmostEqual(flt(row.korkem_area_m2), 0.4)

	def test_the_manager_can_set_a_different_prepayment(self):
		result = self._order(prepayment_amount=3_000)
		self.assertEqual(result["prepayment"], 3_000)
		self.assertEqual(flt(frappe.db.get_value("Sales Order", result["sales_order"], "korkem_prepayment_agreed")), 3_000)

	def test_prices_are_recomputed_on_the_server_not_taken_from_the_client(self):
		"""A total from the screen is never trusted: today's price list decides."""
		facade_prices.set_price("Квадро", PVC, 25_000)
		result = self._order(lines=[_line(amount=1, price_per_piece=1)])
		self.assertEqual(result["total"], 10_000)  # 0.4 m² × 25 000

	def test_a_rule_nobody_set_creates_no_order(self):
		before = frappe.db.count("Sales Order")
		with self.assertRaises(frappe.ValidationError):
			self._order(lines=[_line(customer_material=1)])
		self.assertEqual(frappe.db.count("Sales Order"), before)

	def test_a_past_delivery_date_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			self._order(delivery_date=add_days(nowdate(), -1))

	def test_an_unknown_customer_is_refused(self):
		with self.assertRaises(frappe.DoesNotExistError):
			self._order(customer="Нет такого клиента 404")

	def test_the_shop_floor_cannot_create_one(self):
		with self.assertRaises(frappe.PermissionError):
			self._order(user=CUTTER)

	def test_the_picker_offers_the_customer_the_order_accepts(self):
		frappe.set_user(SELLER)
		try:
			wanted = frappe.db.get_value("Customer", self.customer, "customer_name")
			names = [row["name"] for row in facade_order.customers(search=wanted, limit=50)]
		finally:
			frappe.set_user("Administrator")
		self.assertIn(self.customer, names)

	def test_the_shop_floor_gets_no_customer_list(self):
		frappe.set_user(CUTTER)
		try:
			with self.assertRaises(frappe.PermissionError):
				facade_order.customers()
		finally:
			frappe.set_user("Administrator")

	def test_the_order_is_audited(self):
		result = self._order()
		self.assertTrue(
			frappe.db.exists(
				"Domain Audit Event",
				{"action": "sales.facade_order_created", "entity_id": result["sales_order"]},
			)
		)

	def test_the_same_button_press_twice_makes_one_order(self):
		from korkem_manufacturing.api import facade_prices as api

		frappe.set_user(SELLER)
		try:
			arguments = {
				"customer": self.customer,
				"delivery_date": add_days(nowdate(), 14),
				"lines": frappe.as_json([_line()]),
				"idempotency_key": "facade-order-" + frappe.generate_hash(length=10),
			}
			first = api.create_order(**arguments)
			second = api.create_order(**arguments)
		finally:
			frappe.set_user("Administrator")
		self.assertEqual(first["sales_order"], second["sales_order"])
