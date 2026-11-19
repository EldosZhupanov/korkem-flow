# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""A film an order lacks: where to get it (owner, 19.11.2026: «в Алмате
дёшево, логистика 5 дней, в Астане чуть дороже, но 2 дня»).

The same maker from two cities: Almaty cheaper with the bringing counted and
slower, Astana dearer and quicker. In time for both, the cheaper is advised;
for an urgent order, the quicker. «Есть — заказать» lands on «К заказу» for
that source and that order, the price said onto the film's card; a look-alike
the customer agreed to replaces the film at the same price."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, nowdate

from korkem_manufacturing.services import (
	facade_prices,
	film_catalog,
	film_dept,
	film_orders,
	film_sources,
	film_sourcing,
	material_stock,
	mdf_orders,
)

COMPANY = "KORKEM"
MAKER = "Сорс Тест"
CUTTER = "sourcing.cutter@example.com"
FLAT = "МДФ Тест Тегіс 90°"
PVC = facade_prices.PVC


class TestFilmSourcing(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		if not frappe.db.exists("User", CUTTER):
			frappe.get_doc({"doctype": "User", "email": CUTTER, "first_name": "sourcing", "send_welcome_email": 0,
							"roles": [{"role": "Manufacturing User"}]}).insert(ignore_permissions=True)
		frappe.defaults.set_user_default("Company", COMPANY, user=CUTTER)
		material_stock.add_option("Производитель", MAKER)
		cls.astana = film_sources.add("Сорс Астана", city="Астана", lead="2 дня", makers=[MAKER])["supplier"]
		cls.almaty = film_sources.add("Сорс Алматы", city="Алматы", lead="5 дней", makers=[MAKER])["supplier"]

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price(FLAT, PVC, 10_000)
		self.colour = f"Деним {uuid.uuid4().hex[:6]}"
		self.item = film_catalog.add(MAKER, self.colour)["item"]
		self.label = film_catalog.label(MAKER, self.colour)
		# One metre from each: the last price and what the bringing cost.
		film_dept.receive(self.item, 1, 1300, self.almaty, delivery={"transport": "Такси", "from_city": "Алматы",
																		  "amount": 120})
		film_dept.receive(self.item, 1, 1450, self.astana)
		customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		card = mdf_orders.save_draft(
			customer=customer, delivery_date=add_days(nowdate(), 10),
			head={"finish": PVC, "thickness_mm": 16, "decor_top": self.label},
			lines=[{"height_mm": 2000, "width_mm": 600, "qty": 6, "milling": FLAT}],
		)
		self.order = mdf_orders.accept(card["name"])["name"]

	def _film(self, answer: dict) -> dict:
		return next(f for f in answer["films"] if f["item"] == self.item)

	def test_the_cheaper_in_time_is_advised_the_quicker_when_urgent(self):
		answer = film_sourcing.where(self.order)
		film = self._film(answer)
		by = {s["name"]: s for s in film["sources"]}
		self.assertEqual((by["Сорс Алматы"]["landed_m"], by["Сорс Алматы"]["days"]), (1420, 5))
		self.assertEqual((by["Сорс Астана"]["landed_m"], by["Сорс Астана"]["days"]), (1450, 2))
		self.assertTrue(by["Сорс Алматы"]["in_time"] and by["Сорс Астана"]["in_time"])
		self.assertTrue(by["Сорс Алматы"]["advised"])
		self.assertEqual(film["sources"][0]["name"], "Сорс Алматы")  # the advised one first

		frappe.db.set_value("Sales Order", self.order, "korkem_tags", "urgent")
		by = {s["name"]: s for s in self._film(film_sourcing.where(self.order))["sources"]}
		self.assertTrue(by["Сорс Астана"]["advised"])

	def test_a_source_that_cannot_come_in_time_is_not_advised(self):
		frappe.db.set_value("Sales Order", self.order, "delivery_date", add_days(nowdate(), 5))
		by = {s["name"]: s for s in self._film(film_sourcing.where(self.order))["sources"]}
		self.assertFalse(by["Сорс Алматы"]["in_time"])  # 5 days; wanted in the shop in 3
		self.assertTrue(by["Сорс Астана"]["advised"])

	def test_ordering_puts_it_on_the_list_for_the_order_and_the_price_on_the_card(self):
		answer = film_sourcing.order(self.order, self.item, self.astana, 4, price_m=1500,
									 comes_on=add_days(nowdate(), 2), said_by="Айгерим")
		ordered = self._film(answer)["ordered"]
		self.assertEqual((ordered[0]["metres"], ordered[0]["supplier"]), (4, "Сорс Астана"))
		self.assertIn("Айгерим", ordered[0]["note"])
		line = frappe.get_doc(film_orders._DOC, ordered[0]["line"])
		self.assertEqual((line.sales_order, line.supplier, line.status), (self.order, self.astana, film_orders.SENT))
		self.assertEqual(flt(frappe.db.get_value("Item", self.item, film_catalog.CARD["price_m"])), 1500)

		self.assertTrue(self._film(film_sourcing.nowhere(self.order, self.item))["nowhere"])

	def test_a_look_alike_the_customer_agreed_to_replaces_the_film_at_the_same_price(self):
		colour = f"Деним 2 {uuid.uuid4().hex[:6]}"
		film_catalog.add(MAKER, colour)
		new = film_catalog.label(MAKER, colour)
		before = flt(frappe.db.get_value("Sales Order", self.order, "grand_total"))
		film_sourcing.replace(self.order, self.label, new, "клиент согласен по WhatsApp")
		card = mdf_orders.card(self.order)
		self.assertEqual(card["head"]["decor_top"], new)
		self.assertEqual({line["film"] for line in card["lines"]}, {new})
		self.assertEqual(flt(frappe.db.get_value("Sales Order", self.order, "grand_total")), before)
		self.assertIn("клиент согласен", str(frappe.db.get_value(
			"Domain Audit Event", {"entity_id": self.order, "action": "mdf.order_changed"}, "diff_json",
			order_by="creation desc")))

	def test_the_shop_floor_does_not_order_film(self):
		frappe.set_user(CUTTER)
		try:
			with self.assertRaises(frappe.PermissionError):
				film_sourcing.where(self.order)
		finally:
			frappe.set_user("Administrator")
