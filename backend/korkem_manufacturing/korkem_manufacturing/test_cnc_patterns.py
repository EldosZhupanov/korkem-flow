"""«Узоры ЧПУ» — the geometry, the G-code, and the sandbox around them.

The owner (18.11.2026): load it and test it, but it must not interfere with
the application's work. So the tests check the switch as hard as the cuts.
"""

from __future__ import annotations

import json
import math
import re

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import cnc_geometry as geo
from korkem_manufacturing.services import cnc_patterns, facade_prices, mdf_orders
from korkem_manufacturing.services.cnc_geometry import PatternError, Tool

COMPANY = "KORKEM"
MANAGER = "cnc.manager@example.com"
STRANGER = "cnc.stranger@example.com"
PVC = facade_prices.PVC
PATTERN = "ЧПУ Тест Классика"
FLAT = "ЧПУ Тест Тегіс"
V90 = Tool("V90", "v", 12, 90, 3000, 1000, 18000, 3)
R3 = Tool("R3", "ball", 6, 0, 2500, 800, 18000, 2)
TOOLS = {"V90": V90, "R3": R3}
CLASSIC = {"elements": [{"kind": "frame", "tool": "V90", "depth": 4, "offset": 60, "corner": "cove", "radius": 15}]}


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


def _moves(text: str) -> list[str]:
	return [line for line in text.splitlines() if line and not line.startswith("(")]


class TestCncGeometry(IntegrationTestCase):
	"""Numbers in, cuts and G-code out — no database involved."""

	def test_a_classic_frame_cuts_its_cove_corners_clockwise_in_two_passes(self):
		paths, warnings = geo.build(CLASSIC, 500, 718, TOOLS)
		self.assertEqual((len(paths), warnings), (1, []))
		text = geo.gcode(paths, TOOLS, {}, "test")[0]["text"]
		moves = _moves(text)
		self.assertEqual(moves[:3], ["G21 G90 G17", "G0 Z20", "M3 S18000"])
		self.assertEqual(moves[-3:], ["M5", "G0 X0 Y0", "M30"])
		# 4 mm with a 3 mm pass is two passes of 2 mm, each round the frame.
		self.assertEqual([m for m in moves if m.startswith("G1 Z")], ["G1 Z-2 F1000", "G1 Z-4 F1000"])
		# A cove corner turns about the frame's own corner, clockwise.
		self.assertIn("G2 X440 Y75 I15 J0", moves)
		self.assertEqual(sum(m.startswith("G2 ") for m in moves), 8)
		# Every cut stays inside the facade.
		for x, y in paths[0].points():
			self.assertTrue(60 <= x <= 440 and 60 <= y <= 658)

	def test_a_round_corner_turns_the_other_way(self):
		paths, _ = geo.build({"elements": [{**CLASSIC["elements"][0], "corner": "round", "radius": 10}]}, 500, 500,
							 TOOLS)
		moves = _moves(geo.gcode(paths, TOOLS, {}, "t")[0]["text"])
		self.assertEqual(sum(m.startswith("G3 ") for m in moves), 8)
		self.assertFalse(any(m.startswith("G2 ") for m in moves))

	def test_without_arcs_the_corners_are_short_lines(self):
		paths, _ = geo.build(CLASSIC, 500, 718, TOOLS)
		moves = _moves(geo.gcode(paths, TOOLS, {"arcs": False}, "t")[0]["text"])
		self.assertFalse(any(re.match(r"G[23] ", m) for m in moves))
		self.assertGreater(len(moves), 40)

	def test_grooves_run_through_the_edges_and_alternate(self):
		paths, _ = geo.build({"elements": [{"kind": "grooves", "tool": "R3", "depth": 3, "direction": "vertical",
											"step": 30, "side": 0, "ends": 0}]}, 498, 550, TOOLS)
		self.assertEqual(len(paths), 17)
		# Centred: the first and the last groove equally far from the edges.
		self.assertAlmostEqual(paths[0].start[0], 498 - paths[-1].start[0])
		# Through: they start and end beyond the board, past the cutter.
		self.assertLess(paths[0].start[1], -3)
		self.assertGreater(paths[0].moves[-1][2], 553)
		self.assertGreater(paths[1].start[1], paths[1].moves[-1][2])

	def test_an_arch_rises_to_the_frame_top_in_the_middle(self):
		paths, _ = geo.build({"elements": [{"kind": "arch", "tool": "V90", "depth": 3, "offset": 60,
											"rise": 80}]}, 500, 900, TOOLS)
		top = max(y for _, y in paths[0].points())
		self.assertAlmostEqual(top, 840, delta=0.5)

	def test_swapping_the_axes_mirrors_the_arcs(self):
		paths, _ = geo.build(CLASSIC, 500, 718, TOOLS)
		moves = _moves(geo.gcode(paths, TOOLS, {"swap_xy": True}, "t")[0]["text"])
		self.assertIn("G0 X60 Y75", moves)
		self.assertIn("G3 X75 Y440 I0 J15", moves)

	def test_two_cutters_are_two_programs(self):
		modern = {"elements": [{"kind": "frame", "tool": "V90", "depth": 3, "offset": 50},
							   {"kind": "grooves", "tool": "R3", "depth": 2, "direction": "horizontal", "step": 40,
								"side": 80, "ends": 80}]}
		files = geo.gcode(*[geo.build(modern, 500, 700, TOOLS)[0]], TOOLS, {"line_numbers": True}, "t")
		self.assertEqual([f["tool"] for f in files], ["V90", "R3"])
		for f in files:
			self.assertTrue(_moves(f["text"])[0].startswith("N10 "))
			self.assertGreater(f["stats"]["minutes"], 0)

	def test_a_pocket_is_cleared_ring_by_ring_from_the_middle_out(self):
		"""«Выборка филёнки» (owner, 20.11.2026 — from ArtCAM's 2D-выборка)."""
		f6 = Tool("F6", "flat", 6, 0, 2500, 800, 18000, 3)
		tools = {**TOOLS, "F6": f6}
		paths, _ = geo.build({"elements": [{"kind": "pocket", "tool": "F6", "depth": 3, "offset": 80}]}, 400, 600,
							 tools)
		# The outermost ring runs the cutter's radius inside the pocket's edge.
		outer = paths[-1]
		self.assertEqual(outer.start, (83, 83))
		xs = [x for p in paths for x, _ in p.points()]
		self.assertEqual((min(xs), max(xs)), (83, 317))
		# Rings 2.4 mm apart (40 % of 6): nothing between them is left uncut.
		self.assertAlmostEqual(paths[-2].start[0] - outer.start[0], 2.4)
		inner = paths[0]
		self.assertLess(inner.start[0], 200)
		self.assertGreater(200 - inner.start[0], 0)
		self.assertLessEqual(200 - inner.start[0], 2.4 + 3)
		files = geo.gcode(paths, tools, {}, "t")
		self.assertEqual([f["tool"] for f in files], ["F6"])
		# A V-cutter cannot clear a floor; a pocket too big for the board says so.
		for element, words in (
			({"kind": "pocket", "tool": "V90", "depth": 3, "offset": 80}, "V-образной"),
			({"kind": "pocket", "tool": "F6", "depth": 3, "offset": 199}, "не помещается"),
		):
			with self.assertRaises(PatternError) as e:
				geo.build({"elements": [element]}, 400, 600, tools)
			self.assertIn(words, str(e.exception))

	def test_what_does_not_fit_is_said_in_words(self):
		for pattern, w, h, words in (
			({"elements": [{**CLASSIC["elements"][0], "offset": 260}]}, 500, 500, "не помещается"),
			({"elements": [{**CLASSIC["elements"][0], "offset": 3}]}, 500, 500, "за край"),
			({"elements": [{**CLASSIC["elements"][0], "radius": 300}]}, 500, 500, "Радиус"),
			({"elements": [{**CLASSIC["elements"][0], "tool": "нет"}]}, 500, 500, "Нет фрезы"),
			({"elements": []}, 500, 500, "ни одного"),
			(CLASSIC, 30, 500, "от 50"),
		):
			with self.assertRaises(PatternError) as e:
				geo.build(pattern, w, h, TOOLS)
			self.assertIn(words, str(e.exception))

	def test_the_program_is_plain_ascii_even_with_a_kazakh_title(self):
		paths, _ = geo.build(CLASSIC, 500, 718, TOOLS)
		text = geo.gcode(paths, TOOLS, {}, "Қорқем · Классика (тест) 718×500")[0]["text"]
		self.assertTrue(text.isascii())
		self.assertTrue(text.startswith("(Qorqem"))
		self.assertEqual(text.count("("), text.count(")"))
		self.assertNotIn("(", geo.gcode(paths, TOOLS, {"comments": False}, "x")[0]["text"])

	def test_the_minutes_add_up_from_the_feeds(self):
		paths, _ = geo.build(CLASSIC, 500, 718, TOOLS)
		stats = geo.gcode(paths, TOOLS, {}, "t")[0]["stats"]
		length = paths[0].length()
		self.assertEqual(stats["passes"], 2)
		self.assertAlmostEqual(stats["cut_m"], 2 * length / 1000, places=2)
		self.assertGreater(stats["minutes"], 2 * length / 3000)
		self.assertLess(stats["minutes"], 2 * length / 3000 + 1)

	def test_a_v_cutter_cut_width_follows_the_depth(self):
		self.assertAlmostEqual(V90.width_at(3), 6)
		self.assertAlmostEqual(V90.width_at(10), 12)
		self.assertAlmostEqual(R3.width_at(3), 6)
		self.assertAlmostEqual(R3.width_at(1), 2 * math.sqrt(9 - 4))


class TestCncPatternsSandbox(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(MANAGER, "Sales User")
		_user(STRANGER, "Sales User")
		cls.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		cls.key = f"{cnc_patterns._KEY}:{COMPANY}"
		cls.before = frappe.db.get_default(cls.key)

	@classmethod
	def tearDownClass(cls):
		frappe.set_user("Administrator")
		frappe.db.set_default(cls.key, cls.before or "")
		super().tearDownClass()

	def setUp(self):
		frappe.set_user("Administrator")
		frappe.db.set_default(self.key, "")
		facade_prices.set_price(PATTERN, PVC, 19_500)
		facade_prices.set_price(FLAT, PVC, 17_000)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _order(self):
		return self._as(
			MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
			head={"finish": PVC, "thickness_mm": 16},
			lines=[{"height_mm": 718, "width_mm": 500, "qty": 4, "milling": PATTERN},
				   {"height_mm": 150, "width_mm": 400, "qty": 1, "milling": PATTERN},
				   {"height_mm": 600, "width_mm": 400, "qty": 2, "milling": FLAT}],
		)

	def test_off_by_default_and_invisible(self):
		status = cnc_patterns.status()
		self.assertEqual((status["enabled"], status["visible"], status["can_manage"]), (False, False, True))
		self.assertNotIn("patterns", status)
		with self.assertRaises(frappe.PermissionError):
			cnc_patterns.preview("Классика", 500, 700)
		order = self._order()
		self.assertFalse(mdf_orders.card(order["name"])["cnc"])

	def test_only_the_owner_turns_it_on_and_says_who_sees_it(self):
		with self.assertRaises(frappe.PermissionError):
			self._as(MANAGER, cnc_patterns.set_enabled, True)
		status = cnc_patterns.set_enabled(True)
		# The first time on, the examples arrive.
		self.assertIn("Классика", {p["name"] for p in status["patterns"]})
		self.assertTrue(all(p["example"] for p in status["patterns"]))
		self.assertFalse(self._as(MANAGER, cnc_patterns.visible))
		cnc_patterns.set_enabled(True, [MANAGER])
		self.assertTrue(self._as(MANAGER, cnc_patterns.visible))
		self.assertFalse(self._as(STRANGER, cnc_patterns.visible))
		# Seeing is not managing.
		with self.assertRaises(frappe.PermissionError):
			self._as(MANAGER, cnc_patterns.save_tool, "Моя", "flat", 6)
		with self.assertRaises(frappe.ValidationError):
			cnc_patterns.set_enabled(True, ["nobody@example.com"])
		# Off again: the library stays, the module is gone.
		status = cnc_patterns.set_enabled(False)
		self.assertEqual((status["enabled"], status["visible"]), (False, False))
		self.assertIn("Классика", cnc_patterns._settings(COMPANY)["patterns"])

	def test_the_library_keeps_its_cutters_and_patterns_whole(self):
		cnc_patterns.set_enabled(True)
		cnc_patterns.save_tool("V-60° 10 мм", "v", 10, angle=60, feed=2800)
		with self.assertRaises(frappe.ValidationError):
			cnc_patterns.save_tool("Кривая", "v", 10, angle=200)
		cnc_patterns.save_pattern("Моя рамка", [{"kind": "frame", "tool": "V-60° 10 мм", "depth": 3, "offset": 55,
												 "corner": "round", "radius": 12}], milling=PATTERN, min_w=200,
								  min_h=200, fallback="Квадро")
		# A cutter in use is not taken away; a renamed one follows its patterns.
		with self.assertRaises(frappe.ValidationError):
			cnc_patterns.delete_tool("V-60° 10 мм")
		cnc_patterns.save_tool("V-60°", "v", 10, angle=60, old_name="V-60° 10 мм")
		saved = cnc_patterns._settings(COMPANY)["patterns"]["Моя рамка"]
		self.assertEqual(saved["elements"][0]["tool"], "V-60°")
		# One milling, one pattern.
		with self.assertRaises(frappe.ValidationError):
			cnc_patterns.save_pattern("Вторая", [{"kind": "frame", "tool": "V-60°", "depth": 3, "offset": 50}],
									  milling=PATTERN)
		for bad in ([], [{"kind": "круг", "tool": "V-60°", "depth": 3}],
					[{"kind": "frame", "tool": "V-60°", "depth": 99, "offset": 50}]):
			with self.assertRaises(frappe.ValidationError):
				cnc_patterns.save_pattern("Плохой", bad)
		machine = cnc_patterns.set_machine(ext="tap", arcs=0, safe_z=25)["machine"]
		self.assertEqual((machine["ext"], machine["arcs"], machine["safe_z"]), ("tap", False, 25))
		with self.assertRaises(frappe.ValidationError):
			cnc_patterns.set_machine(clear_z=30)

	def test_an_edited_pattern_previews_before_it_is_saved(self):
		cnc_patterns.set_enabled(True)
		draft = json.dumps({"name": "Черновик", "elements": [
			{"kind": "frame", "tool": "V-90° 12 мм", "depth": 4, "offset": 60, "corner": "cove", "radius": 15}]})
		got = cnc_patterns.preview(draft, 500, 718)
		self.assertEqual((got["pattern"], got["error"] if "error" in got else None), ("Черновик", None))
		self.assertEqual(len(got["paths"]), 1)
		self.assertIn("M30", got["files"][0]["text"])
		self.assertGreater(got["minutes"], 0)
		small = cnc_patterns.preview("Модерн", 250, 600)
		# Smaller than «Модерн» allows: its fallback, said so.
		self.assertEqual(small["pattern"], "Квадро")
		self.assertIn("меньше", small["warnings"][0])
		tiny = cnc_patterns.preview("Классика", 150, 400)
		self.assertIn("не помещается", tiny["error"])

	def test_an_order_gets_its_programs_and_is_not_touched(self):
		cnc_patterns.set_enabled(True, [MANAGER])
		cnc_patterns.save_pattern("Классика", [{"kind": "frame", "tool": "V-90° 12 мм", "depth": 4, "offset": 60,
												"corner": "cove", "radius": 15}], milling=PATTERN, min_w=250,
								  min_h=250, old_name="Классика")
		order = self._order()["name"]
		modified = frappe.db.get_value("Sales Order", order, "modified")
		self.assertTrue(self._as(MANAGER, mdf_orders.card, order)["cnc"])
		self.assertFalse(self._as(STRANGER, cnc_patterns.visible))
		plan = self._as(MANAGER, cnc_patterns.for_order, order)
		first, small, flat = plan["lines"]
		self.assertEqual((first["pattern"], first["error"]), ("Классика", None))
		self.assertGreater(first["minutes"], 0)
		self.assertIn("не помещается", small["error"])
		self.assertEqual((flat["pattern"], flat["error"]), (None, None))
		self.assertAlmostEqual(plan["minutes"], first["minutes"] * 4, places=1)
		files = self._as(MANAGER, cnc_patterns.order_files, order)["files"]
		self.assertEqual(len(files), 1)
		self.assertEqual(files[0]["qty"], 4)
		self.assertTrue(files[0]["name"].startswith(order) and files[0]["name"].endswith("-01-718x500-Классика.nc"))
		self.assertTrue(files[0]["text"].isascii())
		# Read only: the order is as it was.
		self.assertEqual(frappe.db.get_value("Sales Order", order, "modified"), modified)
		with self.assertRaises(frappe.PermissionError):
			self._as(STRANGER, cnc_patterns.order_files, order)
		cnc_patterns.set_enabled(False)
		self.assertFalse(mdf_orders.card(order)["cnc"])
		with self.assertRaises(frappe.PermissionError):
			cnc_patterns.order_files(order)
