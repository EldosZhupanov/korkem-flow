# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Раскрой на форматно-раскроечной пиле (owner, 28.11.2026).

The layout is a saw's: strips along the sheet's height, crosscut, parted;
every edge trimmed, the kerf between parts, a banded side cut short by its
band. Fewer sheets first, then fewer fence settings, then the larger offcut.
A job keeps its parts and its saw, a change is a new version, a sheet sawn
cannot be changed by changing the job, and each sheet says who sawed it and
puts its offcuts on the shelf. The last sheet ticks «Раскрой» on the order."""

from __future__ import annotations

import itertools
import json
import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing import testing
from korkem_manufacturing.services import (
	facade_prices,
	material_stock,
	mdf_customers,
	mdf_orders,
	offcuts,
	saw_cutting,
	saw_engine,
)

COMPANY = "KORKEM"
MANAGER = "saw.manager@example.com"
CUTTER = "saw.cutter@example.com"
#: A thickness no other test keeps.
THICKNESS = "21"
MAKER = "Пила-Тест МДФ"
FLAT = "МДФ Тест Пила"
SHEET = {"sheet_h": 2800, "sheet_w": 2070, "kerf": 4, "trim": 10, "min_offcut": (300, 300)}
PARTS = [
	{"n": 1, "height": 716, "width": 596, "qty": 3},
	{"n": 2, "height": 996, "width": 446, "qty": 2},
	{"n": 3, "height": 446, "width": 396, "qty": 5},
	{"n": 4, "height": 596, "width": 296, "qty": 4},
]


def _user(email: str, *roles: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": r} for r in roles]}
		).insert(ignore_permissions=True)
	else:
		frappe.get_doc("User", email).add_roles(*roles)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


def _overlaps(parts: list[dict]) -> list:
	return [
		(a["n"], a["k"], b["n"], b["k"]) for a, b in itertools.combinations(parts, 2)
		if a["x"] < b["x"] + b["width"] and b["x"] < a["x"] + a["width"]
		and a["y"] < b["y"] + b["height"] and b["y"] < a["y"] + a["height"]
	]


class TestSawEngine(IntegrationTestCase):
	"""The layout alone — no database."""

	def best(self, rows, **kw):
		kw = SHEET | kw
		plans = saw_engine.plan(rows, **kw)
		return saw_engine.as_dict(plans[0], **{k: v for k, v in kw.items() if k != "edge_deduct"})

	def test_the_sample_order_fits_one_sheet_inside_the_trim_without_overlap(self):
		laid = self.best(PARTS)
		self.assertEqual(len(laid["sheets"]), 1)
		parts = laid["sheets"][0]["parts"]
		self.assertEqual(len(parts), 14)
		self.assertEqual(_overlaps(parts), [])
		for p in parts:
			self.assertGreaterEqual(p["x"], 0)
			self.assertLessEqual(p["x"] + p["width"], 2070 - 20 + 0.01)
			self.assertLessEqual(p["y"] + p["height"], 2800 - 20 + 0.01)

	def test_parts_side_by_side_keep_the_kerf_between_them(self):
		laid = self.best([{"n": 1, "height": 500, "width": 300, "qty": 6}])
		parts = sorted(laid["sheets"][0]["parts"], key=lambda p: (p["x"], p["y"]))
		for a, b in zip(parts, parts[1:]):
			if a["x"] == b["x"]:
				self.assertGreaterEqual(b["y"] - (a["y"] + a["height"]), 4 - 0.01)

	def test_strips_of_one_width_are_cut_on_one_fence_setting(self):
		laid = self.best([{"n": 1, "height": 600, "width": 400, "qty": 8, "rotate": False}])
		cuts = laid["sheets"][0]["cuts"]
		self.assertEqual([c["kind"] for c in cuts[:2]], ["trim", "trim"])
		strips = [c for c in cuts if c["kind"] == "strip"]
		self.assertTrue(strips and all(c["set"] == 400 and c["along"] for c in strips))
		# The rip fence once at 400, the crosscut stop once at 600.
		self.assertEqual(laid["fences"], 2)

	def test_a_banded_side_is_cut_short_by_its_band(self):
		pieces = saw_engine.pieces([{"n": 1, "height": 766, "width": 446, "qty": 1, "edges": [0, 2, 0.4, 0.4]}])
		self.assertAlmostEqual(pieces[0].height, 764)
		self.assertAlmostEqual(pieces[0].width, 445.2)
		raw = saw_engine.pieces([{"n": 1, "height": 766, "width": 446, "qty": 1, "edges": [0, 2, 0, 0]}],
								edge_deduct=False)
		self.assertEqual(raw[0].height, 766)

	def test_a_part_larger_than_the_sheet_is_reported_never_squeezed(self):
		laid = self.best([{"n": 1, "height": 3000, "width": 500, "qty": 1},
						  {"n": 2, "height": 500, "width": 500, "qty": 1}])
		self.assertEqual(laid["too_big"], [1])
		self.assertEqual(len(laid["sheets"][0]["parts"]), 1)

	def test_a_part_not_to_be_turned_lies_as_entered(self):
		laid = self.best([{"n": 1, "height": 300, "width": 1800, "qty": 2, "rotate": False}])
		self.assertTrue(all(not p["rotated"] and p["height"] == 300 for p in laid["sheets"][0]["parts"]))

	def test_what_is_left_is_an_offcut_only_from_the_size_set(self):
		laid = self.best([{"n": 1, "height": 2780, "width": 1700, "qty": 1, "rotate": False}])
		sheet = laid["sheets"][0]
		self.assertEqual([(round(r["width"]), round(r["height"])) for r in sheet["offcuts"]], [(346, 2780)])
		small = self.best([{"n": 1, "height": 2780, "width": 1800, "qty": 1, "rotate": False}],
						  min_offcut=(300, 300))
		self.assertEqual(small["sheets"][0]["offcuts"], [])
		self.assertEqual(len(small["sheets"][0]["waste"]), 1)

	def test_more_parts_go_on_more_sheets_and_the_choices_are_distinct(self):
		plans = saw_engine.plan([{"n": 1, "height": 720, "width": 560, "qty": 40},
								 {"n": 2, "height": 400, "width": 300, "qty": 25}], **SHEET)
		self.assertEqual(len(plans[0].sheets), 4)
		picked = saw_engine.choices(plans)
		self.assertEqual(picked[0][0], "best")
		self.assertEqual(len({id(p) for _, p in picked}), len(picked))

	def test_a_trim_larger_than_the_sheet_is_refused(self):
		with self.assertRaises(ValueError):
			saw_engine.plan(PARTS, **(SHEET | {"trim": 1100}))


class TestSawImport(IntegrationTestCase):
	def test_a_text_paste_in_any_usual_shape(self):
		read = saw_cutting.rows_from_cells([[line] for line in (
			"716 596 2 Боковина", "766x446x3", "1200×700*1", "716;596;2;Боковина", "600 x", "abc",
			"766 446 3 Полка 0-2-0,4-0,4",
		)])
		self.assertEqual([(r["height"], r["width"], r["qty"]) for r in read["rows"]],
						 [(716, 596, 2), (766, 446, 3), (1200, 700, 1), (716, 596, 2), (766, 446, 3)])
		self.assertEqual(read["rows"][0]["name"], "Боковина")
		self.assertEqual(read["rows"][-1]["edges"], [0, 2, 0.4, 0.4])
		self.assertEqual([(e["line"], e["reason"]) for e in read["errors"]], [(5, "no_width"), (6, "no_size")])

	def test_a_sheet_with_headings_in_its_own_order(self):
		read = saw_cutting.rows_from_cells([
			["Наименование", "Длина", "Ширина", "Кол-во", "Верх", "Низ"],
			["Дно", 500, 300, 2, 2, 0],
			[None] * 6,
			["Крышка", "700,5", 350, "1", 0, 0.4],
			["Полка", 400, 9000, 1, 0, 0],
		])
		self.assertEqual([(r["name"], r["height"], r["width"], r["qty"], r["edges"]) for r in read["rows"]],
						 [("Дно", 500, 300, 2, [2, 0, 0, 0]), ("Крышка", 700.5, 350, 1, [0, 0.4, 0, 0])])
		self.assertEqual(read["errors"][0]["reason"], "size")

	def test_a_csv_file(self):
		import base64

		frappe.set_user("Administrator")
		content = base64.b64encode("Высота;Ширина;Кол-во;Название\n716;596;2;Боковина\n".encode()).decode()
		read = saw_cutting.parse_parts(content=content, filename="parts.csv")
		self.assertEqual(read["rows"][0]["name"], "Боковина")


class TestSawCuttingJob(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		# Sales User makes the order's customer; Sales Manager makes the job.
		_user(MANAGER, "Sales User", "Sales Manager")
		_user(CUTTER, "Manufacturing User")
		for kind, value in (("Толщина МДФ", THICKNESS), ("Производитель", MAKER)):
			material_stock.add_option(kind, value)
		cls.board = material_stock.define_material(material_stock.MDF, "лист", thickness=THICKNESS,
												   manufacturer=MAKER)["item"]

	def setUp(self):
		frappe.set_user("Administrator")

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _order(self) -> str:
		facade_prices.set_price(FLAT, facade_prices.PVC, 10_000)
		tail = uuid.uuid4().int % 10_000_000
		customer = self._as(MANAGER, mdf_customers.add, f"Пила Тестов {tail}", f"8 706 {tail:07d}")["name"]
		card = self._as(
			MANAGER, mdf_orders.save_draft, customer=customer, delivery_date=add_days(nowdate(), 3),
			head={"finish": facade_prices.PVC, "thickness_mm": int(THICKNESS)},
			lines=[{"height_mm": 716, "width_mm": 596, "qty": 2, "milling": FLAT}],
		)
		return self._as(MANAGER, mdf_orders.accept, card["name"])["name"]

	def test_settings_default_and_are_kept_as_saved(self):
		settings = self._as(MANAGER, saw_cutting.saw_settings)
		self.assertEqual((settings["kerf_mm"], settings["trim_mm"], settings["fence_side"]), (4.0, 10.0, "left"))
		saved = self._as(MANAGER, saw_cutting.save_saw_settings, kerf_mm=3.2, trim_mm=0, fence_side="right",
						 sheets=[{"thickness_mm": int(THICKNESS), "height_mm": 2750, "width_mm": 1830}])
		self.assertEqual((saved["kerf_mm"], saved["trim_mm"], saved["fence_side"]), (3.2, 0.0, "right"))
		self.assertEqual(saw_cutting.sheet_for(saved, int(THICKNESS)), {"height_mm": 2750, "width_mm": 1830})
		self.assertEqual(saw_cutting.sheet_for(saved, 99), saved["default_sheet"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, saw_cutting.save_saw_settings, kerf_mm=40)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, saw_cutting.save_saw_settings, kerf_mm=3)

	def test_a_job_from_parts_to_sheets_sawn_with_its_history(self):
		order = self._order()
		parts = [{"height": 716, "width": 596, "qty": 2, "name": "Боковина", "edges": [2, 2, 2, 2]},
				 {"height": 2700, "width": 1800, "qty": 1, "rotate": False}]
		made = self._as(MANAGER, saw_cutting.save_job, material_item=self.board, parts=parts, orders=[order])
		self.assertEqual((made["status"], made["version"]), ("Draft", 1))
		self.assertEqual(made["sheets_total"], 2)
		self.assertIn(saw_cutting.order_number(order), made["title"])
		self.assertEqual(made["parts"][0]["n"], 1)
		self.assertEqual(made["edges"]["2"], round((716 + 596) * 2 * 2 / 1000, 2))

		# Not checked — the floor does not saw it yet; the floor does not make jobs.
		with self.assertRaises(frappe.ValidationError):
			self._as(CUTTER, saw_cutting.sheet_done, made["name"], 1)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, saw_cutting.save_job, material_item=self.board, parts=parts)

		changed = self._as(MANAGER, saw_cutting.save_job, name=made["name"], material_item=self.board,
						   parts=parts + [{"height": 300, "width": 300, "qty": 1}], orders=[order])
		self.assertEqual(changed["version"], 2)
		checked = self._as(MANAGER, saw_cutting.check_job, made["name"])
		self.assertEqual(checked["status"], "Checked")

		first = self._as(CUTTER, saw_cutting.sheet_done, made["name"], 1, defects="деталь 2: скол")
		self.assertEqual(first["status"], "Cutting")
		self.assertEqual(first["sheets"][0]["defects"], "деталь 2: скол")
		shelved = [o["name"] for s in first["sheets"] for o in s["offcuts"]]
		for name in shelved:
			self.assertEqual(frappe.db.get_value(offcuts.DOCTYPE, name, "material_item"), self.board)

		# The board is cut: the job is not changed by changing it.
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, saw_cutting.save_job, name=made["name"], material_item=self.board, parts=parts)

		undone = self._as(MANAGER, saw_cutting.sheet_done, made["name"], 1, done=False)
		self.assertEqual(undone["status"], "Checked")
		for name in shelved:
			self.assertEqual(frappe.db.get_value(offcuts.DOCTYPE, name, "status"), "Scrapped")

		for sheet in range(1, undone["sheets_total"] + 1):
			last = self._as(CUTTER, saw_cutting.sheet_done, made["name"], sheet)
		self.assertEqual(last["status"], "Done")
		self.assertTrue(frappe.db.get_value("Sales Order", order, mdf_orders.STAGES["cut"]))
		actions = [h["action"] for h in last["history"]]
		for action in ("job_saved", "job_checked", "sheet_done", "sheet_undone"):
			self.assertIn(action, actions)

		scanned = self._as(CUTTER, saw_cutting.scan, f"SAW:{made['name']}:1")
		self.assertEqual((scanned["job"]["name"], scanned["sheet_no"]), (made["name"], 1))

	def test_a_part_larger_than_the_sheet_is_not_saved(self):
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, saw_cutting.save_job, material_item=self.board,
					 parts=[{"height": 4000, "width": 4000, "qty": 1}])

	def test_the_journal_puts_the_nearest_due_first_and_offers_to_saw_together(self):
		order = self._order()
		small = [{"height": 900, "width": 900, "qty": 2}]
		a = self._as(MANAGER, saw_cutting.save_job, material_item=self.board, parts=small, orders=[order])
		b = self._as(MANAGER, saw_cutting.save_job, material_item=self.board, parts=small,
					 due_date=add_days(nowdate(), 1))
		journal = self._as(CUTTER, saw_cutting.listing, search=a["name"])
		self.assertEqual([j["name"] for j in journal["jobs"]], [a["name"]])
		journal = self._as(MANAGER, saw_cutting.listing, material=self.board)
		names = [j["name"] for j in journal["jobs"]]
		self.assertLess(names.index(b["name"]), names.index(a["name"]))
		offer = [t for t in journal["together"] if set(t["jobs"]) >= {a["name"], b["name"]}]
		self.assertTrue(offer and offer[0]["together"] < offer[0]["apart"])
		merged = self._as(MANAGER, saw_cutting.merge_jobs, [a["name"], b["name"]])
		self.assertEqual(len(merged["parts"]), 2)
		self.assertEqual(frappe.db.get_value(saw_cutting.JOB, a["name"], "status"), "Cancelled")

	def test_cancelling_wants_a_reason(self):
		made = self._as(MANAGER, saw_cutting.save_job, material_item=self.board,
						parts=[{"height": 500, "width": 500, "qty": 1}])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, saw_cutting.cancel_job, made["name"], "")
		cancelled = self._as(MANAGER, saw_cutting.cancel_job, made["name"], "клиент передумал")
		self.assertEqual((cancelled["status"], cancelled["cancel_reason"]), ("Cancelled", "клиент передумал"))

	def test_another_company_sees_no_job(self):
		made = self._as(MANAGER, saw_cutting.save_job, material_item=self.board,
						parts=[{"height": 500, "width": 500, "qty": 1}])
		other = testing.second_company()
		frappe.db.set_value(saw_cutting.JOB, made["name"], "company", other)
		with self.assertRaises(frappe.DoesNotExistError):
			self._as(MANAGER, saw_cutting.job, made["name"])
		self.assertNotIn(made["name"], [j["name"] for j in self._as(MANAGER, saw_cutting.listing)["jobs"]])
		self.assertTrue(json.loads(frappe.db.get_value(saw_cutting.JOB, made["name"], "plan_json"))["plan"])
