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

	def test_an_order_names_a_film_by_its_maker(self):
		from korkem_manufacturing.services import facade_materials, mdf_orders

		kira = self._film("KIRA")
		self._film("JS Group")
		row = next(f for f in self._as(MANAGER, service.catalog)["films"] if f["item"] == kira)
		self.assertEqual(row["label"], "KIRA · Белый Матовый")
		self.assertEqual(service.split("KIRA · Белый Матовый"), ("KIRA", "Белый Матовый"))
		self.assertIsNone(service.split("Белый Матовый"))
		# The order form takes the catalogue's name, and the plain colour as before.
		known = mdf_orders._colours("Цвет плёнки", COMPANY)
		self.assertTrue({"KIRA · Белый Матовый", "JS Group · Белый Матовый", "Белый Матовый"} <= known)
		self.assertNotIn("Nobody · Белый Матовый", known)
		# And the stock finds that maker's roll, not the other's.
		picked = facade_materials._pick_item(material_stock.FILM, "KIRA · Белый Матовый", COMPANY, {})
		self.assertEqual(picked.name, kira)

	def test_a_film_is_added_from_the_catalogue_itself(self):
		made = self._as(MANAGER, service.add, "KIRA", "Шалфей Новый")
		self.assertEqual((made["maker"], made["colour"], made["width_mm"]), ("KIRA", "Шалфей Новый", 1400))
		self.assertEqual(made["label"], "KIRA · Шалфей Новый")
		# The same film again is the same film, not a second one.
		self.assertEqual(self._as(MANAGER, service.add, "KIRA", "Шалфей Новый")["item"], made["item"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.add, "Никто", "Шалфей Новый")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.add, "KIRA", " ")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.add, "KIRA", "Чужая")

	def test_a_colour_no_film_carries_is_unassigned(self):
		self._film("KIRA")
		catalog = self._as(MANAGER, service.catalog)
		self.assertIn("Лён Без Плёнки", catalog["unassigned"])
		self.assertNotIn("Белый Матовый", catalog["unassigned"])
		self.assertIn("Матовая", catalog["types"])
		self.assertIn("KIRA", catalog["makers"])
		# The old colour is taken off by hand; a catalogue film's colour is not.
		left = self._as(MANAGER, service.drop_unassigned, "Лён Без Плёнки")
		self.assertNotIn("Лён Без Плёнки", left["unassigned"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.drop_unassigned, "Белый Матовый")

	def test_a_maker_keeps_its_own_collections(self):
		self._as(MANAGER, service.add_collection, "KIRA", "Древесные")
		catalog = self._as(MANAGER, service.add_collection, "JS Group", "Древесные")
		# The same name under two makers is two collections.
		self.assertIn("Древесные", catalog["collections"]["KIRA"])
		self.assertIn("Древесные", catalog["collections"]["JS Group"])
		made = self._as(MANAGER, service.add, "KIRA", "Дуб Коллекционный", collection="Древесные")
		self.assertEqual(made["collection"], "Древесные")
		# A film takes only a collection of its own maker.
		self._as(MANAGER, service.add_collection, "JS Group", "Только JS")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.set_card, made["item"], collection="Только JS")
		# Renamed, the collection keeps its films; the other maker's is untouched.
		catalog = self._as(MANAGER, service.rename_collection, "KIRA", "Древесные", "Wood")
		self.assertIn("Wood", catalog["collections"]["KIRA"])
		self.assertNotIn("Древесные", catalog["collections"]["KIRA"])
		self.assertIn("Древесные", catalog["collections"]["JS Group"])
		self.assertEqual(self._as(MANAGER, service.film, made["item"])["collection"], "Wood")
		# Removed, its films stay — without a collection.
		catalog = self._as(MANAGER, service.remove_collection, "KIRA", "Wood")
		self.assertNotIn("Wood", catalog["collections"].get("KIRA", []))
		self.assertIsNone(self._as(MANAGER, service.film, made["item"])["collection"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.add_collection, "KIRA", "Чужая")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.add_collection, "Никто", "Коллекция")

	def test_a_thickness_written_with_a_comma_is_read_as_it_is(self):
		made = self._as(MANAGER, service.add, "KIRA", "Тонкая Запятая")
		self.assertEqual((made["thickness_mm"], made["width_mm"]), (0.3, 1400))

	def test_a_name_is_renamed_to_itself_in_another_case(self):
		from korkem_manufacturing.services import mdf_dictionaries

		material_stock.add_option("Банк", "КАСПИЙТЕСТ")
		option = frappe.db.get_value(
			"Material Option", {"company": COMPANY, "kind": "Банк", "value": "КАСПИЙТЕСТ"}, "name"
		)
		mdf_dictionaries.rename("bank", option, "Каспийтест")
		self.assertEqual(frappe.db.get_value("Material Option", option, "value"), "Каспийтест")
		material_stock.add_option("Банк", "Другой Банк Тест")
		with self.assertRaises(frappe.ValidationError):
			mdf_dictionaries.rename("bank", option, "другой банк тест")

	def test_a_film_is_added_with_its_card_at_once(self):
		made = self._as(
			MANAGER, service.add, "KIRA", "Сразу С Карточкой", code="KR-7", type="Матовая",
			supplier=self.supplier, price_m="3200", retail_m="3900", wholesale_m="3400",
		)
		self.assertEqual(
			(made["code"], made["type"], made["supplier"], made["price_m"], made["retail_m"], made["wholesale_m"]),
			("KR-7", "Матовая", self.supplier, 3200, 3900, 3400),
		)

	def test_a_film_is_renamed_and_the_change_is_written_down(self):
		made = self._as(MANAGER, service.add, "KIRA", "Имя Старое", retail_m="3900")
		card = self._as(
			MANAGER, service.set_card, made["item"], colour="Имя Новое", thickness="0,35", retail_m="4100"
		)
		self.assertEqual(
			(card["colour"], card["label"], card["thickness_mm"], card["retail_m"]),
			("Имя Новое", "KIRA · Имя Новое", 0.35, 4100),
		)
		# An old order that names the film as it was still saves.
		self.assertIn("KIRA · Имя Старое", service.labels(COMPANY))
		# The old name does not come back as a colour without a maker.
		self.assertNotIn("Имя Старое", self._as(MANAGER, service.catalog)["unassigned"])
		log = self._as(MANAGER, service.changes, made["item"])
		named = {(c["what"], c["before"], c["after"]) for c in log}
		self.assertIn(("название", "Имя Старое", "Имя Новое"), named)
		self.assertIn(("розница", "3900", "4100"), named)
		self.assertTrue(all(c["who"] and c["when"] for c in log))
		# Saving the same again writes nothing down.
		count = len(log)
		self._as(MANAGER, service.set_card, made["item"], colour="Имя Новое", retail_m="4100")
		self.assertEqual(len(self._as(MANAGER, service.changes, made["item"])), count)
		# The shop floor reads the history without the money.
		floor = {c["what"] for c in self._as(CUTTER, service.changes, made["item"])}
		self.assertIn("название", floor)
		self.assertNotIn("розница", floor)
		# A name another film of the maker carries is refused.
		self._as(MANAGER, service.add, "KIRA", "Имя Занятое")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.set_card, made["item"], colour="Имя Занятое")
		self._as(MANAGER, service.set_card, made["item"], colour="Имя Старое", thickness="0,3", retail_m="3900")

	def test_an_unused_film_is_deleted_and_a_used_one_only_archived(self):
		from korkem_manufacturing.services import film_dept

		unused = self._as(MANAGER, service.add, "KIRA", "Заведена По Ошибке")
		left = self._as(MANAGER, service.delete, unused["item"])
		self.assertNotIn(unused["item"], {f["item"] for f in left["films"]})
		self.assertNotIn("Заведена По Ошибке", left["unassigned"])

		used = self._as(MANAGER, service.add, "KIRA", "С Историей")
		self._as(MANAGER, film_dept.receive, used["item"], 10, 3000, self.supplier)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.delete, used["item"])
		archived = self._as(MANAGER, service.archive, used["item"])
		self.assertEqual((archived["enabled"], archived["archived"]), (False, True))
		# Its metres are still on the department's stock, to be sold out.
		self.assertIn(used["item"], {f["item"] for f in self._as(MANAGER, film_dept.stock)["films"]})
		back = self._as(MANAGER, service.restore, used["item"])
		self.assertEqual((back["enabled"], back["archived"]), (True, False))
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.archive, used["item"])

