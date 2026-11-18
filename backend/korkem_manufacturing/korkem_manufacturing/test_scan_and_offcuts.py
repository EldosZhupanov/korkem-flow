# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""An order's sticker scanned on the floor, and offcuts on the shelf (owner,
18.11.2026).

A scanned code — the QR, the name or just the number — opens the order with
its stages, and says which one is the scanner's; the manager may tick any.
An offcut put on the shelf is offered to an order whose part it holds, the
smallest that does, and once taken it is offered no more."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import (
	facade_prices,
	material_stock,
	mdf_customers,
	mdf_orders,
	my_work,
	offcut_stock,
	search_text,
)

COMPANY = "KORKEM"
MANAGER = "scan.manager@example.com"
CUTTER = "scan.cutter@example.com"
FLAT = "МДФ Тест Скан 90°"
PVC = facade_prices.PVC
#: A thickness no other test keeps offcuts of.
THICKNESS = "13"
MAKER = "Скан-Тест МДФ"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestScanAndOffcuts(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(MANAGER, "Sales User")
		_user(CUTTER, "Manufacturing User")
		for kind, value in (("Толщина МДФ", THICKNESS), ("Производитель", MAKER)):
			material_stock.add_option(kind, value)
		material_stock.define_material(material_stock.MDF, "лист", thickness=THICKNESS, manufacturer=MAKER)

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price(FLAT, PVC, 10_000)
		tail = uuid.uuid4().int % 10_000_000
		customer = self._as(MANAGER, mdf_customers.add, f"Скан Тест {tail}", f"8 705 {tail:07d}")["name"]
		card = self._as(
			MANAGER, mdf_orders.save_draft, customer=customer, delivery_date=add_days(nowdate(), 7),
			head={"finish": PVC, "thickness_mm": int(THICKNESS)},
			lines=[{"height_mm": 1000, "width_mm": 500, "qty": 2, "milling": FLAT}],
		)
		self.order = self._as(MANAGER, mdf_orders.accept, card["name"])["name"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	# --- the sticker ---

	def test_the_sticker_the_name_and_the_number_all_open_the_order(self):
		number = search_text.number_in(self.order)
		for code in (f"{my_work.QR_PREFIX}{self.order}", self.order, str(number), f"№ {number}"):
			self.assertEqual(self._as(MANAGER, my_work.scan, code)["order"], self.order, code)
		with self.assertRaises(frappe.DoesNotExistError):
			self._as(MANAGER, my_work.scan, "KORKEM:ORDER:SAL-ORD-NOPE-1")

	def test_the_manager_ticks_any_stage_from_a_scan(self):
		scan = self._as(MANAGER, my_work.scan, self.order)
		self.assertTrue(scan["manager"])
		first = scan["stages"][0]
		self.assertTrue(first["mine"])
		self.assertIsNone(first["done_on"])
		self.assertEqual(scan["stages"][1]["waiting_for"], [first["stage"]])
		scan = self._as(MANAGER, my_work.tick, self.order, first["stage"])
		self.assertEqual(scan["stages"][0]["done_on"], nowdate())
		scan = self._as(MANAGER, my_work.tick, self.order, first["stage"], 1)
		self.assertIsNone(scan["stages"][0]["done_on"])

	def test_a_scanner_not_linked_to_a_person_is_told_so(self):
		frappe.db.sql("update `tabEmployee` set user_id = null where user_id = %s", CUTTER)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, my_work.scan, self.order)

	# --- offcuts ---

	def test_an_offcut_on_the_shelf_is_offered_to_a_part_it_holds_and_once_taken_no_more(self):
		before = {c["offcut"] for c in self._as(CUTTER, offcut_stock.listing)["offcuts"]}
		big = self._as(CUTTER, offcut_stock.add, THICKNESS, 600, 1300, cell="A-3")["added"]
		small = self._as(CUTTER, offcut_stock.add, THICKNESS, 1015, 520, note="край")["added"]
		self._as(CUTTER, offcut_stock.add, THICKNESS, 900, 600)  # too short for 1000
		self.addCleanup(self._clear, before)
		shelf = {c["offcut"]: c for c in self._as(CUTTER, offcut_stock.listing)["offcuts"]}
		self.assertEqual((shelf[big]["length_mm"], shelf[big]["width_mm"]), (1300, 600))  # long side first
		self.assertIn(int(THICKNESS), self._as(CUTTER, offcut_stock.listing)["thicknesses"])

		self.assertEqual(self._as(MANAGER, mdf_orders.card, self.order)["offcut_parts"], 2)  # the card's hint
		parts = self._as(MANAGER, offcut_stock.suggest, self.order)["parts"]
		self.assertEqual([p["offcut"]["offcut"] for p in parts], [small, big])  # smallest that holds first
		left = self._as(MANAGER, offcut_stock.take, small, self.order)["parts"]
		self.assertEqual([p["offcut"]["offcut"] for p in left], [big])
		self.assertEqual(frappe.db.get_value("Stock Offcut", small, "status"), "Consumed")

	def test_a_crumb_or_an_unknown_thickness_is_not_shelved_and_a_stranger_sees_nothing(self):
		with self.assertRaises(frappe.ValidationError):
			self._as(CUTTER, offcut_stock.add, THICKNESS, 900, 50)
		with self.assertRaises(frappe.ValidationError):
			self._as(CUTTER, offcut_stock.add, "47", 900, 500)
		frappe.set_user("Guest")
		try:
			with self.assertRaises(frappe.PermissionError):
				offcut_stock.listing()
		finally:
			frappe.set_user("Administrator")

	def _clear(self, keep: set[str]) -> None:
		frappe.set_user("Administrator")
		for name in frappe.get_all("Stock Offcut", filters={"company": COMPANY, "status": "Available"}, pluck="name"):
			if name not in keep and frappe.db.get_value("Stock Offcut", name, "thickness_mm") == int(THICKNESS):
				frappe.db.set_value("Stock Offcut", name, "status", "Scrapped")
