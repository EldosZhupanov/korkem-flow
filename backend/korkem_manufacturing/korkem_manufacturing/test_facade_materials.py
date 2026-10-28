# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""A facade order's material: counted from m², held on order, written off in ERPNext."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, nowdate

from korkem_manufacturing import testing
from korkem_manufacturing.services import (
	facade_jobs,
	facade_materials,
	facade_order,
	facade_prices,
	facade_quote,
	material_stock,
)

COMPANY = "KORKEM"
MANAGER = "fm.manager@example.com"
CUTTER = "fm.cutter@example.com"
#: Orders are written by sales, as on the quote screen.
SELLER = "fm.seller@example.com"
SUPPLIER = "FM Test Supplier"
#: Values nobody else's test uses, so the materials picked are this test's own.
THICKNESS, MAKER, DECOR, OTHER_DECOR = "18", "FM-Test", "FM Дуб", "FM Ясень"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


def _line(**over) -> dict:
	line = {
		"width_mm": 500, "height_mm": 400, "qty": 10, "milling": "Квадро", "finish": facade_prices.PVC,
		"thickness_mm": int(THICKNESS), "decor_top": DECOR,
	}
	line.update(over)
	return line


class TestFacadeMaterials(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(MANAGER, "Sales Manager")
		_user(CUTTER, "Manufacturing User")
		_user(SELLER, "Sales User")
		facade_prices.seed_company(COMPANY)
		for kind, value in (
			("Толщина МДФ", THICKNESS),
			("Производитель", MAKER),
			("Цвет плёнки", DECOR),
			("Цвет плёнки", OTHER_DECOR),
			("Ширина плёнки", "1400"),
			("Толщина плёнки", "0,30"),
		):
			material_stock.add_option(kind, value)
		material_stock.add_supplier(SUPPLIER)
		cls.supplier = frappe.db.get_value("Supplier", {"supplier_name": SUPPLIER}, "name")
		cls.mdf = material_stock.define_material(
			material_stock.MDF, "лист", thickness=THICKNESS, manufacturer=MAKER
		)["item"]
		cls.film = material_stock.define_material(
			material_stock.FILM, "м", color=DECOR, width="1400", film_thickness="0,30", manufacturer=MAKER
		)["item"]
		frappe.db.commit()

	def setUp(self):
		frappe.set_user("Administrator")
		self.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		self.orders: list[str] = []
		# The standard norms, whatever a previous test saved.
		facade_materials.save_norms(**facade_materials.DEFAULTS)
		# And the standard press: film is counted by its loads (press_layout).
		from korkem_manufacturing.services import press_layout

		press_layout.save_press_settings(**press_layout.DEFAULT_PRESS)

	def tearDown(self):
		frappe.set_user("Administrator")
		for order in self.orders:
			testing.remove_order(order)

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _stock(self, mdf: int = 0, film: float = 0) -> None:
		for item, qty, price in ((self.mdf, mdf, 21_000), (self.film, film, 900)):
			if qty:
				material_stock.receive(item, qty, price, self.supplier)

	def _order(self, *lines) -> dict:
		result = self._as(
			SELLER,
			facade_order.create_order,
			customer=self.customer,
			delivery_date=add_days(nowdate(), 10),
			lines=list(lines) or [_line()],
		)
		self.orders.append(result["sales_order"])
		frappe.db.commit()
		return result

	def _offering(self, **rules):
		"""Switch on a quote rule for one test and put the old value back after."""
		before = facade_quote.settings()
		facade_quote.save_settings(**rules)
		self.addCleanup(lambda: facade_quote.save_settings(**{k: before[k] for k in rules}))

	def _row(self, order: str, item: str) -> dict:
		return next(m for m in facade_materials.need(order)["materials"] if m["item"] == item)

	def _on_hand(self, item: str) -> float:
		return flt(sum(frappe.get_all("Bin", filters={"item_code": item}, pluck="actual_qty")))

	# --- need -----------------------------------------------------------------------

	def test_square_metres_become_whole_sheets_and_running_metres(self):
		order = self._order()["sales_order"]  # ten 500×400 facades: 2 m²
		mdf = self._row(order, self.mdf)
		film = self._row(order, self.film)
		# 2 m² × 1.15 = 2.3 m² of a 2800×2070 sheet (5.796 m²): one sheet, not 0.4.
		# ERPNext names units without regard to case: an existing «Лист» answers.
		self.assertEqual((mdf["area_m2"], mdf["needed"], mdf["unit"].lower()), (2.3, 1.0, "лист"))
		# Film goes by the press load (press_layout): ten 500×400 facades with
		# 60 mm gaps need the whole table, so 3.1 m — not 2.2 m² ÷ 1.4 m.
		self.assertEqual((film["area_m2"], film["needed"]), (2.2, 3.1))

	def test_a_double_sided_facade_is_wrapped_twice(self):
		self._offering(double_sided_factor=1.8)
		order = self._order(_line(double_sided=1, decor_bottom=OTHER_DECOR))["sales_order"]
		materials = {m["key"]: m for m in facade_materials.need(order)["materials"]}
		self.assertEqual(materials[DECOR]["area_m2"], 2.2)
		self.assertEqual(materials[OTHER_DECOR]["area_m2"], 2.2)
		# No film of that colour on the books: said, not guessed.
		self.assertIsNone(materials[OTHER_DECOR]["item"])
		self.assertIn(OTHER_DECOR, materials[OTHER_DECOR]["note"])

	def test_enamel_needs_no_film_and_customer_material_needs_nothing(self):
		self._offering(customer_material_offered=1)
		order = self._order(
			_line(finish=facade_prices.ENAMEL, decor_top=None),
			_line(customer_material=1),
		)["sales_order"]
		kinds = [m["kind"] for m in facade_materials.need(order)["materials"]]
		self.assertEqual(kinds, [material_stock.MDF])

	def test_a_line_without_thickness_or_decor_is_named(self):
		order = self._order(_line(thickness_mm=None, decor_top=None))["sales_order"]
		result = facade_materials.need(order)
		self.assertFalse(result["fully_held"])
		self.assertEqual(len(result["unresolved"]), 2)

	def test_the_factory_s_own_norms_change_the_count(self):
		self._as(MANAGER, facade_materials.save_norms, sheet_length_mm=1000, sheet_width_mm=1000, mdf_waste_percent=0)
		order = self._order()["sales_order"]
		self.assertEqual(self._row(order, self.mdf)["needed"], 2.0)

	def test_the_floor_does_not_set_norms(self):
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, facade_materials.save_norms, mdf_waste_percent=0)

	# --- hold -----------------------------------------------------------------------

	def test_an_order_holds_its_material_and_the_shelf_keeps_it(self):
		self._stock(mdf=3, film=10)
		on_hand = self._on_hand(self.mdf)
		result = self._order()
		self.assertTrue(result["materials_held"], result["materials_short"])
		mdf = self._row(result["sales_order"], self.mdf)
		self.assertEqual((mdf["held"], mdf["short"]), (1.0, 0))
		# Held is a promise: ERPNext still has the sheet.
		self.assertEqual(self._on_hand(self.mdf), on_hand)

	def test_a_second_order_cannot_hold_what_the_first_holds(self):
		# One square-metre sheet, no waste: five 500×400 facades take one sheet.
		facade_materials.save_norms(sheet_length_mm=1000, sheet_width_mm=1000, mdf_waste_percent=0)
		self._stock(mdf=1, film=10)
		free = sum(facade_materials._free_by_warehouse(self.mdf, COMPANY).values())
		first = self._order(_line(qty=5 * int(free)))  # exactly what is free
		self.assertEqual(self._row(first["sales_order"], self.mdf)["short"], 0)
		second = self._order(_line(qty=5))
		mdf = self._row(second["sales_order"], self.mdf)
		self.assertEqual((mdf["held"], mdf["short"]), (0.0, 1.0))
		self.assertFalse(second["materials_held"])

	def test_holding_again_is_harmless(self):
		self._stock(mdf=2, film=10)
		order = self._order()["sales_order"]
		again = facade_materials.reserve(order)
		self.assertEqual(again["reservations_created"], [])
		self.assertEqual(self._row(order, self.mdf)["held"], 1.0)

	def test_a_cancelled_order_lets_go(self):
		self._stock(mdf=2, film=10)
		order = self._order()["sales_order"]
		frappe.get_doc("Sales Order", order).cancel()
		self.assertFalse(frappe.db.exists("Stock Reservation", {"sales_order": order, "status": "Active"}))

	# --- write off -----------------------------------------------------------------

	def test_the_first_facade_into_work_writes_the_material_off_in_erpnext(self):
		self._stock(mdf=2, film=10)
		order = self._order(_line(), _line(qty=5))["sales_order"]
		on_hand = self._on_hand(self.mdf)
		lines = frappe.get_all(
			"Sales Order Item", filters={"parent": order, "korkem_width_mm": [">", 0]}, pluck="name", order_by="idx"
		)

		self._as(CUTTER, facade_jobs.set_status, lines[0], facade_jobs.IN_WORK)

		entry = frappe.get_doc("Stock Entry", {"korkem_sales_order": order})
		self.assertEqual((entry.docstatus, entry.purpose), (1, "Material Issue"))
		self.assertEqual(self._on_hand(self.mdf), on_hand - 1)
		mdf = self._row(order, self.mdf)
		self.assertEqual((mdf["held"], mdf["issued"], mdf["short"]), (0.0, 1.0, 0))
		self.assertTrue(frappe.db.exists("Domain Audit Event", {"action": "stock.facade_written_off", "entity_id": order}))

		# The second facade finds nothing left to write off.
		self._as(CUTTER, facade_jobs.set_status, lines[1], facade_jobs.IN_WORK)
		self.assertEqual(frappe.db.count("Stock Entry", {"korkem_sales_order": order}), 1)

	def test_nothing_held_nothing_written_off(self):
		order = self._order(_line(thickness_mm=None, decor_top=None))["sales_order"]
		line = frappe.db.get_value("Sales Order Item", {"parent": order, "korkem_width_mm": [">", 0]}, "name")
		self._as(CUTTER, facade_jobs.set_status, line, facade_jobs.IN_WORK)
		self.assertFalse(frappe.db.exists("Stock Entry", {"korkem_sales_order": order}))

	def test_the_warehouse_shows_what_is_promised_and_what_is_free(self):
		self._stock(mdf=2, film=10)
		before = material_stock.material(self.mdf)
		self._order()
		after = material_stock.material(self.mdf)
		self.assertEqual(after["on_hand"], before["on_hand"])
		self.assertEqual(after["reserved"], before["reserved"] + 1)
		self.assertEqual(after["free"], before["free"] - 1)
