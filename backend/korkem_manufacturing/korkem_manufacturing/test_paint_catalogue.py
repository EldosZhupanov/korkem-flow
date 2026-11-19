# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Каталог красок and «Замена цвета» (owner, 19.11.2026)."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import (
	facade_prices,
	mdf_orders,
	mdf_paint,
	mdf_paints,
	paint_catalogue,
	paint_swap,
)

COMPANY = "KORKEM"
MANAGER = "paint.manager@example.com"
SALES = "paint.sales@example.com"
CUTTER = "paint.cutter@example.com"
FLAT = "МДФ Тест Тегіс 90°"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestPaintCatalogue(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		mdf_paints.seed_company(COMPANY)
		_user(MANAGER, "Sales Manager")
		_user(SALES, "Sales User")
		_user(CUTTER, "Manufacturing User")
		cls.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		assert cls.customer, "the seeded site has customers; no silent skip"

	def setUp(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _colour(self, cat: dict, code: str) -> dict:
		return next(c for c in cat["colours"] if c["code"] == code)

	def test_ral_classic_is_whole_with_its_shades_families_top_and_trends(self):
		cat = self._as(MANAGER, paint_catalogue.catalogue)
		classic = [c for c in cat["colours"] if c["system"] == mdf_paints.RAL_CLASSIC]
		self.assertGreaterEqual(len(classic), 216)
		white = self._colour(cat, "RAL 9010")
		self.assertEqual((white["name"], white["hex"], white["family"]),
						 ("Чисто-белый", "#F1ECE1", "Белые и чёрные"))
		self.assertTrue(white["top"])
		self.assertTrue(self._colour(cat, "RAL 6021")["trend"])
		self.assertFalse(self._colour(cat, "RAL 3020")["top"])
		# The seeded colours are on the «Краска» list already.
		self.assertTrue(white["on_list"])
		systems = [s["name"] for s in cat["systems"]]
		self.assertIn(mdf_paints.RAL_CLASSIC, systems)
		# The floor reads it; it cannot change it.
		self.assertTrue(self._as(CUTTER, paint_catalogue.catalogue)["colours"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, paint_catalogue.set_colour, white["key"], starred=1)

	def test_a_ral_design_colour_reads_its_shade_off_its_code(self):
		self.assertEqual(paint_catalogue.design_hex("RAL 000 90 00"), "#E2E2E2")
		self.assertIsNone(paint_catalogue.design_hex("RAL 9010"))
		taken = self._as(MANAGER, paint_catalogue.add_colour, "Тест-серый", mdf_paints.RAL_DESIGN, code="RAL 000 90 00")
		cat = self._as(MANAGER, paint_catalogue.catalogue)
		mine = next(c for c in cat["colours"] if c["key"] == taken["key"])
		self.assertEqual((mine["system"], mine["hex"], mine["on_list"]), (mdf_paints.RAL_DESIGN, "#E2E2E2", True))

	def test_a_colour_of_our_own_is_added_starred_renamed_and_hidden(self):
		name = f"Тест-шалфей {frappe.generate_hash(length=4)}"
		taken = self._as(MANAGER, paint_catalogue.add_colour, name, mdf_paints.SAMPLE, hexcode="8a9977")
		mine = self._as(MANAGER, paint_catalogue.set_colour, taken["key"], starred=1, title="Шалфей клиента")
		self.assertEqual((mine["hex"], mine["starred"], mine["name"]), ("#8A9977", True, "Шалфей клиента"))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, paint_catalogue.set_colour, taken["key"], hexcode="зелёный")
		self._as(MANAGER, paint_catalogue.set_colour, taken["key"], hidden=1)
		near = self._as(MANAGER, paint_catalogue.similar, hexcode="#8A9977")
		self.assertNotIn(taken["key"], [c["key"] for c in near["similar"]])
		# A catalogue colour into work: onto the list, once.
		first = self._as(MANAGER, paint_catalogue.take, "RAL 6021 Бледно-зелёный")
		again = self._as(MANAGER, paint_catalogue.take, "RAL 6021")
		self.assertEqual(first["value"], again["value"])

	def test_similar_puts_the_nearest_first_and_says_how_near(self):
		near = self._as(MANAGER, paint_catalogue.similar, colour="RAL 7016")
		self.assertEqual(near["hex"], "#383E42")
		keys = [c["key"] for c in near["similar"]]
		self.assertNotIn(paint_catalogue.key("RAL 7016"), keys)
		self.assertEqual(keys[0], paint_catalogue.key("RAL 7026"))
		deltas = [c["delta"] for c in near["similar"]]
		self.assertEqual(deltas, sorted(deltas))
		self.assertEqual(paint_catalogue.look(1.0), "same")
		self.assertEqual(paint_catalogue.look(4.0), "close")
		self.assertEqual(paint_catalogue.look(9.0), "other")

	def _painted_order(self, colour: str) -> str:
		facade_prices.set_price(FLAT, facade_prices.PVC, 17_000)
		lines = [{"height_mm": 1577, "width_mm": 517, "qty": 2, "milling": FLAT, "coating": "paint", "film": colour,
				  "rate": 24_000}]
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
						head={"thickness_mm": 16}, lines=lines)
		self._as(MANAGER, mdf_orders.accept, card["name"])
		self.addCleanup(self._drop, card["name"])
		return card["name"]

	def _drop(self, name: str) -> None:
		frappe.set_user("Administrator")
		doc = frappe.get_doc("Sales Order", name)
		if doc.docstatus == 1:
			doc.cancel()

	def test_a_colour_no_supplier_has_is_replaced_only_once_the_customer_agrees(self):
		colour = "RAL 6021 Бледно-зелёный"
		paint_catalogue.listed(colour)
		name = self._painted_order(colour)
		offer = self._as(MANAGER, paint_swap.options, name, "RAL 6021")
		self.assertEqual(offer["hex"], "#8A9977")
		self.assertTrue(offer["similar"])
		asked = self._as(MANAGER, paint_swap.propose, name, colour, "replace", to="RAL 6011 Резедово-зелёный")
		self.assertIn("RAL 6011", asked["message"])
		self.assertIn("Вы согласны?", asked["message"])
		self.assertEqual(asked["swaps"][0]["status"], paint_swap.ASKED)
		# Until he agrees, no painting.
		for stage in mdf_orders.stages_of(frappe.get_doc("Sales Order", name)):
			if stage == mdf_paint.PAINT:
				break
			self._as(MANAGER, mdf_orders.set_stage, name, stage)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_paint.start_drying, name)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.set_stage, name, mdf_paint.PAINT)
		# He agrees on the phone: the order is painted in the new colour, the
		# old one kept beside it.
		done = self._as(MANAGER, paint_swap.agree, name, colour, via="phone", who="Ерлан")
		row = done["swaps"][0]
		self.assertEqual((row["status"], row["agreed_via"], row["agreed_by"]), (paint_swap.AGREED, "phone", "Ерлан"))
		self.assertEqual(row["from"], colour)
		card = self._as(MANAGER, mdf_orders.card, name)
		self.assertEqual(card["paint_swaps"][0]["to"], row["to"])
		tops = frappe.get_all("Sales Order Item", filters={"parent": name}, pluck="korkem_decor_top")
		self.assertTrue(all(paint_catalogue.key(t) == paint_catalogue.key("RAL 6011") for t in tops))
		self._as(MANAGER, mdf_paint.start_drying, name)
		with self.assertRaises(frappe.ValidationError):  # agreed — cannot be taken back here
			self._as(MANAGER, paint_swap.cancel, name, colour)

	def test_waiting_or_tinting_is_asked_too_and_a_wrong_colour_is_refused(self):
		colour = "RAL 7016 Антрацитово-серый"
		paint_catalogue.listed(colour)
		name = self._painted_order(colour)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, paint_swap.propose, name, "RAL 3020", "tint")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, paint_swap.propose, name, colour, "replace")
		asked = self._as(MANAGER, paint_swap.propose, name, colour, "wait", wait_until=add_days(nowdate(), 8))
		self.assertIn("дождаться", asked["message"])
		self.assertTrue(paint_swap.pending(frappe.get_doc("Sales Order", name)))
		# Changed to tinting — one record a colour.
		asked = self._as(MANAGER, paint_swap.propose, name, colour, "tint")
		self.assertEqual([r["how"] for r in asked["swaps"]], ["tint"])
		self.assertIn("заколеровать", asked["message"])
		left = self._as(MANAGER, paint_swap.cancel, name, colour)
		self.assertEqual(left["swaps"], [])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, paint_swap.propose, name, colour, "tint")
