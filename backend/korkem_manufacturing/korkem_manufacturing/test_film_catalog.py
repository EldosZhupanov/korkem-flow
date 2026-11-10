# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The PVC film catalogue: each film is its maker's own, with a card in metres."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import film_catalog as service
from korkem_manufacturing.services import material_stock, price_visibility

COMPANY = "KORKEM"
MANAGER = "film.manager@example.com"
CUTTER = "film.cutter@example.com"
SUPPLIER = "Film Test Supplier"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestFilmCatalog(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(MANAGER, "Sales Manager")
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		frappe.set_user("Administrator")
		price_visibility.set_floor_sees_prices(False)
		for kind, value in (
			("Производитель", "KIRA"),
			("Производитель", "JS Group"),
			("Цвет плёнки", "Белый Матовый"),
			("Цвет плёнки", "Лён Без Плёнки"),
			("Ширина плёнки", "1400"),
			("Толщина плёнки", "0,30"),
			("Тип плёнки", "Матовая"),
		):
			material_stock.add_option(kind, value)
		material_stock.add_supplier(SUPPLIER)
		self.supplier = frappe.db.get_value("Supplier", {"supplier_name": SUPPLIER}, "name")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _film(self, maker: str) -> str:
		return self._as(
			MANAGER, material_stock.define_material, material_stock.FILM, "м",
			color="Белый Матовый", width="1400", film_thickness="0,30", manufacturer=maker,
		)["item"]

	def test_the_same_colour_of_two_makers_is_two_films(self):
		kira, js = self._film("KIRA"), self._film("JS Group")
		self.assertNotEqual(kira, js)
		films = {f["item"]: f for f in self._as(MANAGER, service.catalog)["films"]}
		self.assertEqual((films[kira]["maker"], films[js]["maker"]), ("KIRA", "JS Group"))
		self.assertEqual(films[kira]["colour"], films[js]["colour"])

	def test_a_card_is_written_and_read_back_in_metres(self):
		item = self._film("KIRA")
		card = self._as(
			MANAGER, service.set_card, item, code="KR-101", type="Матовая", hex="f4f3ee", ral="9003",
			supplier=self.supplier, price_m="3200", url="kira-film.ru/kr-101",
		)
		self.assertEqual(
			(card["code"], card["type"], card["hex"], card["ral"], card["supplier"], card["price_m"], card["url"]),
			("KR-101", "Матовая", "#F4F3EE", "9003", self.supplier, 3200, "https://kira-film.ru/kr-101"),
		)
		# A field left out stays; an empty one is cleared.
		card = self._as(MANAGER, service.set_card, item, ral="")
		self.assertEqual((card["code"], card["ral"]), ("KR-101", None))

	def test_a_card_refuses_what_is_not_in_the_lists_or_not_a_colour(self):
		item = self._film("KIRA")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.set_card, item, type="Неизвестный")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.set_card, item, hex="белый")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.set_card, item, price_m="-5")

	def test_the_shop_floor_reads_the_catalogue_without_prices_and_cannot_write(self):
		item = self._film("KIRA")
		self._as(MANAGER, service.set_card, item, price_m=3200)
		row = next(f for f in self._as(CUTTER, service.catalog)["films"] if f["item"] == item)
		self.assertIsNone(row["price_m"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.set_card, item, code="X")

	def test_a_colour_no_film_carries_is_unassigned(self):
		self._film("KIRA")
		catalog = self._as(MANAGER, service.catalog)
		self.assertIn("Лён Без Плёнки", catalog["unassigned"])
		self.assertNotIn("Белый Матовый", catalog["unassigned"])
		self.assertIn("Матовая", catalog["types"])
		self.assertIn("KIRA", catalog["makers"])
