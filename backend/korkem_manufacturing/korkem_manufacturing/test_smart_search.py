# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The general search (owner, 18.11.2026, variant Б): one line finds the
customer, his orders, what he owes and what he paid — typed in the wrong
layout, in Latin letters, with a typo, as a phone or as an order's number —
and shows nobody what his own section would not."""

from __future__ import annotations

import io
import json
import uuid
import zipfile
from unittest import TestCase

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import (
	facade_prices,
	film_decors,
	mdf_customers,
	mdf_orders,
	search_text,
	smart_search,
)

COMPANY = "KORKEM"
MANAGER = "search.manager@example.com"
CUTTER = "search.cutter@example.com"
FLAT = "МДФ Тест Поиск 90°"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestSearchText(TestCase):
	"""How what was typed is read — no database."""

	def test_the_wrong_layout_and_latin_letters_are_read_too(self):
		self.assertIn("ерлан", search_text.variants("thkfy"))
		self.assertIn("ерлан", search_text.variants("Erlan"))
		self.assertIn("lw 611", search_text.variants("ДЦ 611"))

	def test_kazakh_letters_and_yo_are_their_russian_neighbours(self):
		self.assertEqual(search_text.fold("Айгүл Қасенова"), "аигул касенова")
		self.assertTrue(search_text.score(search_text.variants("Айгүл"), "Айгуль Сапарова"))
		self.assertTrue(search_text.score(search_text.variants("Семён"), "Семен"))

	def test_a_typo_is_forgiven_a_different_name_is_not(self):
		self.assertTrue(search_text.score(search_text.variants("сиена вердэ"), "сиена верде"))
		self.assertTrue(search_text.score(search_text.variants("абено"), "Ерлан Абенов"))
		self.assertFalse(search_text.score(search_text.variants("ерлан"), "Нурлан"))
		self.assertFalse(search_text.score(search_text.variants("ерлан абенов"), "Ерлан"))

	def test_a_code_matches_with_or_without_its_spaces(self):
		self.assertTrue(search_text.score(search_text.variants("lw6112"), "LW 611-2"))
		self.assertTrue(search_text.score(search_text.variants("ДЦ 611"), "LW 611-2"))

	def test_a_phone_and_a_number_are_told_apart(self):
		self.assertEqual(search_text.phone_of("8 701 555 12 34"), "7015551234")
		self.assertEqual(search_text.phone_of("+7 (701) 555-12-34"), "7015551234")
		self.assertIsNone(search_text.phone_of("245"))
		self.assertEqual(search_text.number_of("№ 245"), 245)
		self.assertIsNone(search_text.number_of("ерлан"))
		self.assertEqual(search_text.number_in("SAL-ORD-2026-00245"), 245)


class TestSmartSearch(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(MANAGER, "Sales User")
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price(FLAT, facade_prices.PVC, 17_000)
		tail = uuid.uuid4().int % 10_000_000
		# A surname of its own, not one letter off the last run's: those
		# stay in the database, and a typo one letter off matched five of
		# them before this one (CI, 26.11.2026).
		rnd = uuid.uuid4().int
		syllables = [
			"бвгдзклмнпрстфх"[(rnd >> (8 * i)) % 15] + "аеиоу"[(rnd >> (8 * i + 4)) % 5] for i in range(4)
		]
		self.surname = "Тест" + "".join(syllables) + "ов"
		self.phone = f"8 701 {tail:07d}"
		self.customer = self._as(MANAGER, mdf_customers.add, f"Ерлан {self.surname}", self.phone)["name"]
		card = self._as(
			MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
			head={"finish": facade_prices.PVC, "thickness_mm": 16},
			lines=[{"height_mm": 500, "width_mm": 400, "qty": 2, "milling": FLAT}],
		)
		self.order = self._as(MANAGER, mdf_orders.accept, card["name"])["name"]

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _find(self, query, user=MANAGER):
		return self._as(user, smart_search.find, query)

	def test_a_name_finds_the_customer_his_order_and_his_debt(self):
		got = self._find(f"ерлан {self.surname}")
		customer = got["parts"]["customers"][0]
		self.assertEqual((customer["customer"], customer["orders"]), (self.customer, 1))
		self.assertEqual(customer["debt"], 6800)
		self.assertEqual(got["parts"]["facade_orders"][0]["name"], self.order)
		self.assertEqual(got["parts"]["facade_orders"][0]["debt"], 6800)

	def test_the_wrong_layout_a_typo_and_latin_letters_find_him_too(self):
		english = f"ерлан {self.surname}".lower().translate(str.maketrans(
			"йцукенгшщзхъфывапролджэячсмитьбю", "qwertyuiop[]asdfghjkl;'zxcvbnm,."))
		typo = f"ерлан {self.surname[:-2]}э{self.surname[-1]}"
		for query in (english, typo):
			with self.subTest(query=query):
				names = [c["customer"] for c in self._find(query)["parts"]["customers"]]
				self.assertIn(self.customer, names)

	def test_a_phone_finds_the_customer_and_his_orders(self):
		got = self._find("+7" + self.phone[1:])
		self.assertEqual(got["kind"], "phone")
		self.assertEqual(got["parts"]["customers"][0]["customer"], self.customer)
		self.assertIn(self.order, [o["name"] for o in got["parts"]["facade_orders"]])

	def test_an_orders_number_finds_that_order_first(self):
		number = search_text.number_in(self.order)
		got = self._find(f"№{number}")
		self.assertEqual(got["kind"], "number")
		self.assertEqual(got["parts"]["facade_orders"][0]["name"], self.order)

	def test_a_shop_hand_sees_no_facade_customers_orders_or_money(self):
		# The film department's customers he may see (as in that department);
		# a facade customer, the orders and the payments — not.
		got = self._find(f"ерлан {self.surname}", user=CUTTER)
		self.assertFalse(got["allowed"]["facades"])
		self.assertNotIn(self.customer, [c["customer"] for c in got["parts"].get("customers", [])])
		for part in ("facade_orders", "cnc_orders", "payments"):
			self.assertNotIn(part, got["parts"])

	def test_a_makers_decor_is_found_by_its_code(self):
		maker = f"Декор Поиск {uuid.uuid4().hex[:4]}"
		buffer = io.BytesIO()
		with zipfile.ZipFile(buffer, "w") as z:
			z.writestr("manifest.json", json.dumps(
				[{"maker": maker, "collection": "Arctic", "name": "ZB 700-2", "code": "ZB 700-2"}]))
		film_decors.import_pack(buffer.getvalue(), source="test")
		got = self._find("zb7002")
		self.assertIn(maker, [d["maker"] for d in got["parts"]["decors"]])

	def test_too_little_typed_finds_nothing_and_says_what_may_be_seen(self):
		got = self._find("е")
		self.assertEqual(got["parts"], {})
		self.assertTrue(got["allowed"]["facades"])
