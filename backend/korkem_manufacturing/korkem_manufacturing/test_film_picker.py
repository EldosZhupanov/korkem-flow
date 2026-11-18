# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The order's film window (owner, 18.11.2026): every film there is — the
books' and the makers' catalogues' — and the customer's of late on top. A
catalogue decor picked by an order's manager is taken in as a film."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import facade_prices, film_catalog, film_decors, film_picker, mdf_orders

COMPANY = "KORKEM"
MANAGER = "picker.manager@example.com"
CUTTER = "picker.cutter@example.com"
MAKER = "Пикер Тест"
FLAT = "МДФ Тест Пикер 90°"
PVC = facade_prices.PVC


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestFilmPicker(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(MANAGER, "Sales User")  # takes orders; not a stock editor
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		frappe.set_user("Administrator")
		self.name = f"Верде {uuid.uuid4().hex[:6]}"
		self.decor = frappe.get_doc({"doctype": film_decors.DOCTYPE, "company": COMPANY, "maker": MAKER,
									 "decor_name": self.name, "code": "PV-1"}).insert(ignore_permissions=True).name

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def test_a_catalogue_decor_is_offered_then_taken_in_by_an_orders_manager(self):
		label = film_catalog.label(MAKER, self.name)
		offered = {d["decor"]: d for d in self._as(MANAGER, film_picker.extras)["decors"]}
		self.assertEqual(offered[self.decor]["label"], label)

		took = self._as(MANAGER, film_picker.take, self.decor)
		self.assertEqual(took["label"], label)
		self.assertEqual(frappe.db.get_value("Item", took["item"], "korkem_color"), self.name)
		self.assertNotIn(self.decor, {d["decor"] for d in self._as(MANAGER, film_picker.extras)["decors"]})
		self.assertEqual(self._as(MANAGER, film_picker.take, self.decor)["item"], took["item"])  # once
		self.assertIn(label, film_catalog.labels(COMPANY))

	def test_a_shop_hand_sees_the_window_but_takes_nothing_in(self):
		self._as(CUTTER, film_picker.extras)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, film_picker.take, self.decor)

	def test_the_customers_films_of_late_come_first(self):
		label = self._as(MANAGER, film_picker.take, self.decor)["label"]
		facade_prices.set_price(FLAT, PVC, 10_000)
		customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		card = self._as(
			MANAGER, mdf_orders.save_draft, customer=customer, delivery_date=add_days(nowdate(), 7),
			head={"finish": PVC, "thickness_mm": 16, "decor_top": label},
			lines=[{"height_mm": 700, "width_mm": 400, "qty": 1, "milling": FLAT}],
		)
		self.assertEqual(self._as(MANAGER, film_picker.extras, customer)["recent"][0], label)
		self.assertEqual(self._as(MANAGER, film_picker.extras)["recent"], [])
		frappe.delete_doc("Sales Order", card["name"], force=True)
