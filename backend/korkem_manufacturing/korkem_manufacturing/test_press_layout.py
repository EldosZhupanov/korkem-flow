# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Film by the press load: facades laid on the membrane-vacuum press, the
shortest section that holds them, textured film never turned."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing import testing
from korkem_manufacturing.services import facade_materials, facade_order, facade_prices, film_orders, material_stock
from korkem_manufacturing.services import press_layout
from korkem_manufacturing.services.press_layout import (
	DEFAULT_PRESS,
	Part,
	best_plan,
	check_layout,
	parts_key,
	plan,
)

COMPANY = "KORKEM"
MANAGER = "pl.manager@example.com"
CUTTER = "pl.cutter@example.com"
SELLER = "pl.seller@example.com"
THICKNESS, MAKER, PLAIN, TEXTURED = "16", "PL-Test", "PL Авори", "PL Какао нубук"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


def _press(**over) -> dict:
	return {**DEFAULT_PRESS, **over}


#: Order №1110 of the pilot shop, as laid out by hand in cutting2: the plain
#: decor took the whole table (3.1 m), the textured one the 2.1 m section.
AVORI = [Part(1, 598, 298)] * 7 + [Part(2, 718, 298)] * 2
CACAO = [Part(3, 598, 148)] * 2 + [Part(4, 598, 283)] * 4


class TestThePacking(IntegrationTestCase):
	def test_the_pilot_order_takes_what_the_shop_ordered(self):
		loads, too_big = plan(AVORI, _press(), rotate=True)
		self.assertEqual(([load.film_m for load in loads], too_big), ([3.1], []))
		loads, _ = plan(CACAO, _press(), rotate=False)
		self.assertEqual([load.film_m for load in loads], [2.1])

	def test_a_textured_film_is_never_turned(self):
		loads, _ = plan(CACAO + AVORI, _press(), rotate=False)
		self.assertFalse(any(p.rotated for load in loads for p in load.placed))

	def test_the_smart_layout_tries_orders_and_keeps_the_shortest(self):
		# Order 00016's positions 4–6 (owner, 12.11.2026): the plain layout
		# takes four loads, the last one 2.1 m; the squares 498×498 go into the
		# empty corners of the first two, and the fourth needs only 1.1 m.
		parts = [Part(4, 2000, 498)] * 5 + [Part(5, 498, 498)] * 5 + [Part(6, 800, 498)] * 5
		plain = [load.film_m for load in plan(parts, _press(), rotate=True)[0]]
		smart = [load.film_m for load in best_plan(parts, _press(), rotate=True)[0]]
		self.assertEqual((round(sum(plain), 2), round(sum(smart), 2)), (11.4, 10.4))
		# The same parts, the same layout — the map does not change on its own.
		again = best_plan(parts, _press(), rotate=True)[0]
		self.assertEqual([[vars(p) for p in load.placed] for load in again],
						 [[vars(p) for p in load.placed] for load in best_plan(parts, _press(), rotate=True)[0]])
		# Never worse than the plain one; the pilot order stays what the shop ordered.
		self.assertEqual([load.film_m for load in best_plan(AVORI, _press(), rotate=True)[0]], [3.1])
		self.assertEqual([load.film_m for load in best_plan(CACAO, _press(), rotate=False)[0]], [2.1])
		self.assertFalse(any(p.rotated for load in best_plan(CACAO + AVORI, _press(), rotate=False)[0]
							 for p in load.placed))

	def test_a_layout_made_by_hand_is_checked_before_it_is_kept(self):
		press = _press()
		parts = [Part(1, 500, 718)] * 2 + [Part(3, 498, 550)]
		gap = press["press_gap_mm"]

		def lay(*placed, length=0):
			return check_layout(parts, [{"length_mm": length, "placed": [
				{"pos": pos, "x": x, "y": y, "rotated": turned} for pos, x, y, turned in placed]}], press, rotate=True)

		# Three in a row, the third turned: the shortest section that holds them.
		row = lay((1, 0, 0, False), (1, 500 + gap, 0, False), (3, 2 * (500 + gap), 0, True))
		self.assertEqual([(load.film_m, len(load.placed)) for load in row], [(2.1, 3)])
		self.assertEqual((row[0].placed[2].width, row[0].placed[2].height), (550, 498))
		# A longer section named by hand is kept.
		self.assertEqual(lay((1, 0, 0, False), (1, 560, 0, False), (3, 1120, 0, True), length=2750)[0].film_m, 3.1)
		for bad in (
			[(1, 0, 0, False), (1, 500 + gap - 1, 0, False), (3, 1200, 0, False)],  # nearer than the gap
			[(1, 0, 0, False), (1, 560, 600, False), (3, 1200, 0, False)],  # off the table's side
			[(1, 0, 0, False), (1, 560, 0, False)],  # one not laid out
			[(1, 0, 0, False), (1, 560, 0, False), (3, 1120, 0, False), (3, 1700, 0, False)],  # one too many
			[(1, 0, 0, False), (1, 560, 0, False), (3, 2500, 0, False)],  # past the table's end
		):
			with self.assertRaises(frappe.ValidationError):
				lay(*bad)
		# A textured film is never turned.
		with self.assertRaises(frappe.ValidationError):
			check_layout(parts, [{"placed": [{"pos": 1, "x": 0, "y": 0, "rotated": True}]}], press, rotate=False)
		self.assertEqual(parts_key(parts), parts_key(list(reversed(parts))))
		self.assertNotEqual(parts_key(parts), parts_key(parts[:2]))

	def test_every_part_is_placed_once_inside_the_working_area_with_its_gap(self):
		press = _press()
		parts = [Part(i % 4 + 1, 500 + 37 * (i % 5), 300 + 41 * (i % 3)) for i in range(30)]
		self._check(press, *plan(parts, press, rotate=True))
		self._check(press, *best_plan(parts, press, rotate=True))

	def _check(self, press, loads, too_big):
		self.assertEqual(sum(len(load.placed) for load in loads), 30)
		self.assertEqual(too_big, [])
		margin, gap = press["press_margin_mm"], press["press_gap_mm"]
		for load in loads:
			for p in load.placed:
				self.assertGreaterEqual(min(p.x, p.y), margin)
				self.assertLessEqual(p.x + p.width, load.length_mm - margin)
				self.assertLessEqual(p.y + p.height, press["press_width_mm"] - margin)
			for i, a in enumerate(load.placed):
				for b in load.placed[i + 1:]:
					apart = (
						a.x + a.width + gap <= b.x or b.x + b.width + gap <= a.x
						or a.y + a.height + gap <= b.y or b.y + b.height + gap <= a.y
					)
					self.assertTrue(apart, f"{a} and {b} closer than {gap} mm")

	def test_more_than_a_table_goes_on_another_load(self):
		loads, _ = plan([Part(1, 500, 400)] * 30, _press(), rotate=True)
		self.assertGreater(len(loads), 1)
		self.assertEqual(loads[0].film_m, 3.1)

	def test_the_gap_is_the_shop_s_own(self):
		parts = [Part(1, 560, 1100)] * 3
		self.assertEqual([load.film_m for load in plan(parts, _press(press_gap_mm=60), True)[0]], [3.1])
		self.assertEqual([load.film_m for load in plan(parts, _press(press_gap_mm=0), True)[0]], [2.1])

	def test_a_facade_bigger_than_the_table_is_said_not_squeezed(self):
		loads, too_big = plan([Part(5, 3000, 500)], _press(), rotate=True)
		self.assertEqual((loads, [p.pos for p in too_big]), ([], [5]))


class TestAnOrderOnThePress(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(MANAGER, "Sales Manager")
		_user(CUTTER, "Manufacturing User")
		_user(SELLER, "Sales User")
		facade_prices.seed_company(COMPANY)
		for kind, value in (
			("Толщина МДФ", THICKNESS), ("Производитель", MAKER), ("Цвет плёнки", PLAIN), ("Цвет плёнки", TEXTURED),
			("Ширина плёнки", "1400"), ("Толщина плёнки", "0,35"),
		):
			material_stock.add_option(kind, value)
		cls.plain = material_stock.define_material(
			material_stock.FILM, "м", color=PLAIN, width="1400", film_thickness="0,35", manufacturer=MAKER
		)["item"]
		cls.textured = material_stock.define_material(
			material_stock.FILM, "м", color=TEXTURED, width="1400", film_thickness="0,35", manufacturer=MAKER
		)["item"]
		material_stock.set_film_textured(cls.textured, 1)
		frappe.db.commit()

	def setUp(self):
		frappe.set_user("Administrator")
		press_layout.save_press_settings(**{k: v for k, v in DEFAULT_PRESS.items()})
		self.orders: list[str] = []

	def tearDown(self):
		frappe.set_user("Administrator")
		press_layout.save_press_settings(**{k: v for k, v in DEFAULT_PRESS.items()})
		for order in self.orders:
			testing.remove_order(order)

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _order(self) -> str:
		def line(width, height, qty, decor):
			return {"width_mm": width, "height_mm": height, "qty": qty, "milling": "Квадро",
					"finish": facade_prices.PVC, "thickness_mm": int(THICKNESS), "decor_top": decor}

		order = self._as(
			SELLER, facade_order.create_order,
			customer=frappe.db.get_value("Customer", {"disabled": 0}, "name"),
			delivery_date=add_days(nowdate(), 10),
			lines=[line(598, 298, 7, PLAIN), line(718, 298, 2, PLAIN), line(598, 148, 2, TEXTURED), line(598, 283, 4, TEXTURED)],
		)["sales_order"]
		self.orders.append(order)
		return order

	def test_the_order_s_films_are_laid_out_and_the_metres_set(self):
		order = self._order()
		films = {f["decor"]: f for f in self._as(CUTTER, press_layout.order_layout, order)["films"]}
		self.assertEqual((films[PLAIN]["film_m"], films[PLAIN]["textured"]), (3.1, False))
		self.assertEqual((films[TEXTURED]["film_m"], films[TEXTURED]["textured"]), (2.1, True))
		self.assertIn(order, films[TEXTURED]["title"])
		self.assertIn(TEXTURED, films[TEXTURED]["title"])
		placed = [p["pos"] for load in films[TEXTURED]["loads"] for p in load["placed"]]
		self.assertEqual(sorted(placed), [3, 3, 4, 4, 4, 4])
		# The warehouse's need follows the press, not the square metre.
		need = {m["item"]: m for m in facade_materials.need(order)["materials"]}
		self.assertEqual((need[self.plain]["needed"], need[self.textured]["needed"]), (3.1, 2.1))

	def test_a_roll_bought_for_an_order_goes_into_its_production(self):
		order = self._order()
		material_stock.add_supplier("PL Test Supplier")
		supplier = frappe.db.get_value("Supplier", {"supplier_name": "PL Test Supplier"}, "name")
		before = {m["item"]: m for m in facade_materials.need(order)["materials"]}[self.plain]
		if before["short"]:
			# The order lacks its film: offered when a roll of it comes in.
			wants = self._as(MANAGER, film_orders.for_production, self.plain)
			self.assertIn(order, [w["order"] for w in wants])
		# 10 m: 3.1 into the order's production, the rest to the shelf.
		got = self._as(MANAGER, film_orders.receive_many, supplier, [
			{"item": self.plain, "metres": 10, "price_m": 2000, "update_price": False,
			 "production": [{"order": order, "metres": 3.1}]},
		])
		line = frappe.db.get_value("Film Order Line", {"receipt": got["receipts"][0]},
								   ["sales_order", "metres", "status"], as_dict=True)
		self.assertEqual((line.sales_order, line.metres, line.status), (order, 3.1, "Received"))
		after = {m["item"]: m for m in facade_materials.need(order)["materials"]}[self.plain]
		self.assertEqual(after["short"], 0)
		# Only an MDF order of ours takes film into production.
		with self.assertRaises(frappe.DoesNotExistError):
			self._as(MANAGER, film_orders.receive_many, supplier, [
				{"item": self.plain, "metres": 1, "price_m": 2000, "production": [{"order": "SO-NONE", "metres": 1}]},
			])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, film_orders.for_production, self.plain)

	def test_metres_set_by_hand_need_a_reason_and_win(self):
		order = self._order()
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, press_layout.set_film_metres, order, PLAIN, 2.1, "")
		result = self._as(MANAGER, press_layout.set_film_metres, order, PLAIN, 2.1, "Уложили плотнее вручную")
		plain = next(f for f in result["films"] if f["decor"] == PLAIN)
		self.assertEqual((plain["film_m"], plain["layout_m"], plain["corrected"]), (2.1, 3.1, True))
		need = {m["item"]: m for m in facade_materials.need(order)["materials"]}
		self.assertEqual(need[self.plain]["needed"], 2.1)
		cleared = self._as(MANAGER, press_layout.set_film_metres, order, PLAIN, None)
		self.assertEqual(next(f for f in cleared["films"] if f["decor"] == PLAIN)["film_m"], 3.1)

	def test_the_floor_sees_the_map_but_does_not_change_the_metres_or_the_press(self):
		order = self._order()
		self.assertTrue(self._as(CUTTER, press_layout.order_layout, order)["films"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, press_layout.set_film_metres, order, PLAIN, 2.1, "так")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, press_layout.save_press_settings, press_gap_mm=10)

	def test_a_hand_made_layout_is_the_order_s_and_the_manager_checks_it(self):
		order = self._order()
		own = next(f for f in self._as(MANAGER, press_layout.order_layout, order)["films"] if f["decor"] == PLAIN)
		self.assertFalse(own["manual"])
		# The press's own layout, on the whole table by the manager's hand.
		loads = [{"length_mm": 2750, "placed": load["placed"]} for load in own["loads"]]
		kept = self._as(MANAGER, press_layout.save_layout, order, PLAIN, loads)
		film = next(f for f in kept["films"] if f["decor"] == PLAIN)
		self.assertTrue(film["manual"])
		self.assertEqual(film["film_m"], round(3.1 * len(own["loads"]), 2))
		self.assertEqual([len(load["placed"]) for load in film["loads"]], [len(load["placed"]) for load in own["loads"]])
		# Checked: who and when.
		self.assertIsNone(kept["approved"])
		checked = self._as(MANAGER, press_layout.approve, order)
		self.assertEqual(checked["approved"]["by"], frappe.utils.get_fullname(MANAGER))
		# The film still lacking is on «К заказу» for the customer — once.
		note = f"заказ {order}"
		for row in checked["short"]:
			self.assertEqual(frappe.db.count("Film Order Line", {"item": row["item"], "note": note}), 1)
		self.assertIsNone(self._as(MANAGER, press_layout.approve, order, approved=False)["approved"])
		again = self._as(MANAGER, press_layout.approve, order)
		for row in again["short"]:
			self.assertEqual(frappe.db.count("Film Order Line", {"item": row["item"], "note": note}), 1)
		self._as(MANAGER, press_layout.approve, order, approved=False)
		# Back to the press's own.
		back = self._as(MANAGER, press_layout.save_layout, order, PLAIN, None)
		self.assertFalse(next(f for f in back["films"] if f["decor"] == PLAIN)["manual"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, press_layout.save_layout, order, PLAIN, loads)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, press_layout.approve, order)

	def test_the_press_settings_are_checked_and_kept(self):
		saved = self._as(MANAGER, press_layout.save_press_settings, press_gap_mm=40)
		self.assertEqual(saved["press_gap_mm"], 40)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, press_layout.save_press_settings, press_sections=[{"film_m": 3.5, "length_mm": 4000}])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, press_layout.save_press_settings, press_sections="ерунда")

	def test_only_film_can_be_textured(self):
		mdf_kind = frappe.get_all("Item", filters={"korkem_material_kind": material_stock.MDF}, pluck="name", limit=1)
		if mdf_kind:
			with self.assertRaises(frappe.ValidationError):
				material_stock.set_film_textured(mdf_kind[0], 1)
