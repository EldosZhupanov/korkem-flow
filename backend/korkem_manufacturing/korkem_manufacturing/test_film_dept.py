# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The film department: metres in, metres out — sold, to the shop, written off."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import film_catalog, film_dept as service
from korkem_manufacturing.services import material_stock, price_visibility

COMPANY = "KORKEM"
MANAGER = "filmdept.manager@example.com"
CUTTER = "filmdept.cutter@example.com"
SUPPLIER = "Film Dept Test Supplier"
BUYER = "Film Dept Test Buyer"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestFilmDept(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(MANAGER, "Sales Manager")
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		frappe.set_user("Administrator")
		price_visibility.set_floor_sees_prices(False)
		material_stock.add_option("Производитель", "KIRA")
		material_stock.add_supplier(SUPPLIER)
		self.supplier = frappe.db.get_value("Supplier", {"supplier_name": SUPPLIER}, "name")
		if not frappe.db.exists("Customer", {"customer_name": BUYER}):
			frappe.get_doc({"doctype": "Customer", "customer_name": BUYER, "customer_type": "Company"}).insert(
				ignore_permissions=True
			)
		self.buyer = frappe.db.get_value("Customer", {"customer_name": BUYER}, "name")
		frappe.db.set_value("Customer", self.buyer, {"korkem_film_tier": None, "korkem_film_discount": 0})
		# A film of its own for each test, so one test's metres are not another's.
		self.film = self._as(MANAGER, film_catalog.add, "KIRA", f"Тест {frappe.generate_hash(length=6)}")["item"]
		self._as(MANAGER, film_catalog.set_card, self.film, retail_m=3900, wholesale_m=3400)
		self._as(MANAGER, service.receive, self.film, 50, 3200, self.supplier)

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _free(self) -> float:
		row = next(f for f in self._as(MANAGER, service.stock)["films"] if f["item"] == self.film)
		return row["free"]

	def test_a_receipt_is_metres_on_the_shelf(self):
		self.assertEqual(self._free(), 50)
		first = self._as(MANAGER, service.history, self.film)[-1]
		self.assertEqual((first["kind"], first["metres"], first["price_m"]), ("receipt", 50, 3200))

	def test_a_sale_takes_metres_and_records_what_was_charged(self):
		sale = self._as(
			MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 12}], paid=20000, method="Наличные",
		)
		# Over the counter, no discount: 12 m × 3 900.
		self.assertEqual((sale["kind"], sale["amount"], sale["paid"], sale["debt"]), ("sale", 46800, 20000, 26800))
		self.assertEqual(sale["lines"][0]["price_m"], 3900)
		self.assertEqual(self._free(), 38)
		# A facade customer who buys film is a film customer from then on.
		row = next(c for c in self._as(MANAGER, service.customers) if c["customer"] == self.buyer)
		self.assertGreaterEqual(row["month_m"], 12)
		self.assertGreaterEqual(row["debt"], 26800)
		self.assertFalse(row["asleep"])
		# The debt is paid off, and no more than is owed.
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.pay, sale["entry"], 30000, "Наличные")
		paid = self._as(MANAGER, service.pay, sale["entry"], 26800, "Перевод", "Kaspi")
		self.assertEqual((paid["debt"], paid["method"], paid["bank"]), (0, "Перевод", "Kaspi"))

	def test_the_customers_card_sets_the_price(self):
		self.assertEqual(self._as(MANAGER, service.price_for, self.film, self.buyer)["price_m"], 3900)
		self._as(MANAGER, service.set_customer, self.buyer, tier="wholesale", discount=5)
		price = self._as(MANAGER, service.price_for, self.film, self.buyer)
		self.assertEqual((price["tier"], price["base_m"], price["price_m"]), ("wholesale", 3400, 3230))
		sale = self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 10}], paid=32300,
						method="Карта", bank="Halyk")
		self.assertEqual((sale["amount"], sale["debt"]), (32300, 0))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.set_customer, self.buyer, discount=80)

	def test_no_more_is_sold_than_lies_on_the_shelf(self):
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 51}])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 5}], paid=999999,
					 method="Наличные")
		self.assertEqual(self._free(), 50)

	def test_film_goes_to_the_shop_and_is_written_off_with_a_reason(self):
		shop = self._as(MANAGER, service.to_shop, self.film, 6, order="SAL-ORD-2026-00017")
		self.assertEqual((shop["kind"], shop["order"]), ("shop", "SAL-ORD-2026-00017"))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.write_off, self.film, 1, " ")
		off = self._as(MANAGER, service.write_off, self.film, 1.5, "Образец для клиента")
		self.assertEqual((off["kind"], off["reason"]), ("write_off", "Образец для клиента"))
		self.assertEqual(self._free(), 42.5)
		kinds = [h["kind"] for h in self._as(MANAGER, service.history, self.film)]
		self.assertEqual(kinds, ["write_off", "shop", "receipt"])

	def test_a_mistake_is_cancelled_the_same_day_and_an_old_one_only_by_the_owner(self):
		sale = self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 10}])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.cancel, sale["entry"], " ")
		self._as(MANAGER, service.cancel, sale["entry"], "Не тот клиент")
		self.assertEqual(self._free(), 50)
		old = self._as(MANAGER, service.to_shop, self.film, 4)
		frappe.db.set_value("Stock Entry", old["entry"], "creation", add_days(nowdate(), -1), update_modified=False)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.cancel, old["entry"], "Ошибка")
		service.cancel(old["entry"], "Ошибка")
		self.assertEqual(self._free(), 50)

	def test_the_shop_floor_sees_metres_not_money_and_sells_nothing(self):
		self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 2}])
		rows = self._as(CUTTER, service.history, self.film)
		self.assertTrue(all(r["price_m"] is None for r in rows))
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.sell, self.buyer, [{"item": self.film, "metres": 1}])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.write_off, self.film, 1, "Просто так")
