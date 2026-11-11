# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Where film is bought: one maker, several sources, each with its own card."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import film_catalog, material_stock, mdf_dictionaries
from korkem_manufacturing.services import film_sources as service

COMPANY = "KORKEM"
MANAGER = "source.manager@example.com"
CUTTER = "source.cutter@example.com"
MAKER, OTHER = "Источник-Тест", "Источник-Другой"
ASTANA, ALMATY = "Источник-Тест · Астана", "Источник-Тест · Алматы"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestFilmSources(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(MANAGER, "Sales Manager")
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		frappe.set_user("Administrator")
		for maker in (MAKER, OTHER):
			material_stock.add_option("Производитель", maker)

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def test_one_maker_is_bought_in_two_cities_each_with_its_own_phone(self):
		astana = self._as(
			MANAGER, service.add, ASTANA, city="Астана", contact="Айгуль", phone="+7 701 000 00 01",
			makers=[MAKER],
		)
		almaty = self._as(
			MANAGER, service.add, ALMATY, city="Алматы", phone="+7 702 000 00 02", lead="5 дней",
			makers=[MAKER, OTHER],
		)
		self.assertEqual((astana["city"], astana["contact"], astana["phone"]), ("Астана", "Айгуль", "+7 701 000 00 01"))
		self.assertEqual((almaty["lead"], almaty["makers"]), ("5 дней", [MAKER, OTHER]))
		card = self._as(MANAGER, service.maker, MAKER)
		self.assertEqual({s["supplier"] for s in card["sources"]}, {astana["supplier"], almaty["supplier"]})
		other = self._as(MANAGER, service.maker, OTHER)
		self.assertEqual([s["supplier"] for s in other["sources"]], [almaty["supplier"]])
		# A receipt offers the maker's own sources.
		by_maker = self._as(MANAGER, film_catalog.catalog)["sources_by_maker"]
		self.assertEqual(set(by_maker[MAKER]), {astana["supplier"], almaty["supplier"]})

	def test_a_card_keeps_what_is_left_out_and_clears_what_is_empty(self):
		made = self._as(MANAGER, service.add, ASTANA, city="Астана", phone="111", note="звонить до 18")
		card = self._as(MANAGER, service.set_card, made["supplier"], phone="222", note="")
		self.assertEqual((card["city"], card["phone"], card["note"]), ("Астана", "222", None))
		card = self._as(MANAGER, service.set_card, made["supplier"], name="Источник-Тест · Нур-Султан")
		self.assertEqual(card["name"], "Источник-Тест · Нур-Султан")
		self._as(MANAGER, service.set_card, made["supplier"], name=ASTANA)

	def test_a_source_names_only_known_makers_and_the_floor_cannot_write(self):
		made = self._as(MANAGER, service.add, ASTANA)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.set_card, made["supplier"], makers=["Никто-Не-Делает"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.set_card, made["supplier"], phone="1")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.add, "Чужой источник")
		# The floor still reads who to ring.
		self.assertIn(made["supplier"], {s["supplier"] for s in self._as(CUTTER, service.sources)["sources"]})

	def test_a_maker_has_a_site_and_a_note_and_keeps_its_sources_when_renamed(self):
		made = self._as(MANAGER, service.add, ASTANA, makers=[MAKER])
		card = self._as(MANAGER, service.set_maker, MAKER, site="adilet.net", note="завод в Ульяновске")
		self.assertEqual((card["site"], card["note"]), ("adilet.net", "завод в Ульяновске"))
		option = frappe.db.get_value(
			"Material Option", {"company": COMPANY, "kind": "Производитель", "value": MAKER}, "name"
		)
		renamed = "Источник-Тест-2"
		self._as("Administrator", mdf_dictionaries.rename, "maker", option, renamed)
		try:
			self.assertEqual(self._as(MANAGER, service.source, made["supplier"])["makers"], [renamed])
		finally:
			self._as("Administrator", mdf_dictionaries.rename, "maker", option, MAKER)

	def test_a_removed_source_leaves_the_list(self):
		made = self._as(MANAGER, service.add, ASTANA, makers=[MAKER])
		left = self._as(MANAGER, service.remove, made["supplier"])
		self.assertNotIn(made["supplier"], {s["supplier"] for s in left["sources"]})
		self.assertNotIn(
			made["supplier"], {s["supplier"] for s in self._as(MANAGER, service.maker, MAKER)["sources"]}
		)
		# Added again by the same name, it is the same source, switched back on.
		again = self._as(MANAGER, service.add, ASTANA)
		self.assertEqual(again["supplier"], made["supplier"])
