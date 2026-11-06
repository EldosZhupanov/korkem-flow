# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The MDF order card, on the owner's own order forms.

№1129 (27.10.2026, Арман Қалдыбаев): four lines, two millings, 3,04 m² and
58 680 ₸. №36 (06.12.2025, Тұрсын Қасенов): twelve lines, 21 pieces, 9,60 m².
Both were priced by hand in OnayBaza; the arithmetic here has to land on the
same figures, line by line.
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, nowdate

from korkem_manufacturing.services import facade_prices, mdf_orders

COMPANY = "KORKEM"
MANAGER = "mdf.manager@example.com"
CUTTER = "mdf.cutter@example.com"
PVC = facade_prices.PVC
FLAT, PATTERN = "МДФ Тест Тегіс 90°", "МДФ Тест Суреттегі үлгі"

ORDER_1129 = [
	{"height_mm": 130, "width_mm": 1040, "qty": 1, "milling": FLAT},
	{"height_mm": 1577, "width_mm": 517, "qty": 2, "milling": PATTERN},
	{"height_mm": 1130, "width_mm": 517, "qty": 2, "milling": PATTERN},
	{"height_mm": 95, "width_mm": 1040, "qty": 1, "milling": FLAT},
]
ORDER_36 = [
	(348, 997, 2), (348, 947, 1), (2027, 497, 4), (2027, 472, 2), (2480, 60, 1), (2480, 120, 1),
	(1550, 60, 2), (348, 597, 2), (100, 597, 2), (2050, 497, 1), (148, 597, 1), (730, 240, 2),
]


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestMdfOrders(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(MANAGER, "Sales User")
		_user(CUTTER, "Manufacturing User")
		cls.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		from korkem_manufacturing.services import material_stock

		material_stock.add_option("Цвет плёнки", "МДФ Тест Венге")
		cls.decor = "МДФ Тест Венге"
		assert cls.customer, "the seeded site has customers; no silent skip"

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price(FLAT, PVC, 17_000)
		facade_prices.set_price(PATTERN, PVC, 19_500)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _draft(self, lines=None, **head):
		return self._as(
			MANAGER,
			mdf_orders.save_draft,
			customer=self.customer,
			delivery_date=add_days(nowdate(), 7),
			head={"finish": PVC, "thickness_mm": 16, **head},
			lines=lines or ORDER_1129,
		)

	# --- the arithmetic, on the owner's forms ---

	def test_order_1129_lands_on_58_680(self):
		result = self._as(MANAGER, mdf_orders.price, ORDER_1129, finish=PVC)
		self.assertEqual([line["area_m2"] for line in result["lines"]], [0.14, 1.63, 1.17, 0.10])
		self.assertEqual([line["amount"] for line in result["lines"]], [2380, 31785, 22815, 1700])
		self.assertEqual((result["pieces"], result["area_m2"], result["total"]), (6, 3.04, 58680))

	def test_order_36_has_no_minimum_area(self):
		lines = [{"height_mm": h, "width_mm": w, "qty": q, "milling": FLAT} for h, w, q in ORDER_36]
		result = self._as(MANAGER, mdf_orders.price, lines, finish=PVC)
		self.assertEqual(result["lines"][10]["area_m2"], 0.09)  # 148 × 597 stays 0,09
		self.assertEqual((result["pieces"], result["area_m2"]), (21, 9.60))

	def test_a_price_nobody_set_counts_at_zero_and_says_so(self):
		lines = [*ORDER_1129, {"height_mm": 500, "width_mm": 400, "qty": 1, "milling": "Нет такой"}]
		result = self._as(MANAGER, mdf_orders.price, lines, finish=PVC)
		self.assertEqual(result["no_price_lines"], [5])
		self.assertEqual(result["total"], 58680)

	def test_a_price_typed_on_the_line_wins(self):
		lines = [{**ORDER_1129[0], "rate": 15_000}]
		line = self._as(MANAGER, mdf_orders.price, lines, finish=PVC)["lines"][0]
		self.assertEqual((line["rate_m2"], line["amount"], line["manual_rate"]), (15000, 2100, True))

	# --- the card ---

	def test_draft_accept_and_the_total_erpnext_keeps(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self.assertEqual((card["status"], card["total"], card["area_m2"]), ("draft", 58680, 3.04))
		card = self._as(MANAGER, mdf_orders.accept, card["name"])
		self.assertEqual((card["status"], card["total"], card["debt"]), ("accepted", 58680, 58680))

	def test_three_pieces_of_an_amount_three_does_not_divide(self):
		"""10 000 ₸ over 3 pieces is 3 333,33… a piece; the order keeps 10 000."""
		lines = [{"height_mm": 1000, "width_mm": 500, "qty": 3, "milling": FLAT, "rate": 6_666.67}]
		card = self._draft(lines)
		self.addCleanup(self._drop, card["name"])
		self.assertEqual(card["total"], 10000)

	def test_a_draft_changes_an_accepted_order_does_not(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer,
						delivery_date=add_days(nowdate(), 9), head={"finish": PVC},
						lines=ORDER_1129[:2], order=card["name"])
		self.assertEqual(card["total"], 2380 + 31785)
		self._as(MANAGER, mdf_orders.accept, card["name"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.save_draft, customer=self.customer,
					 delivery_date=add_days(nowdate(), 9), head={"finish": PVC},
					 lines=ORDER_1129, order=card["name"])

	def test_film_is_ready_after_the_vacuum_and_never_painted(self):
		self.assertEqual(mdf_orders.stages_for(PVC), ["cut", "mill", "sand", "vacuum"])
		self.assertIn("paint", mdf_orders.stages_for("Эмаль"))
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		for stage in ("cut", "mill", "sand"):
			card = self._as(MANAGER, mdf_orders.set_stage, card["name"], stage)
		self.assertEqual(card["status"], "in_shop")
		card = self._as(MANAGER, mdf_orders.set_stage, card["name"], "vacuum")
		self.assertEqual((card["status"], card["ready_on"]), ("ready", nowdate()))
		card = self._as(MANAGER, mdf_orders.set_stage, card["name"], "vacuum", 0)
		self.assertEqual((card["status"], card["ready_on"]), ("in_shop", None))

	def test_not_handed_over_with_a_debt_unless_an_administrator_says_why(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		for stage in mdf_orders.stages_for(PVC):
			self._as(MANAGER, mdf_orders.set_stage, card["name"], stage)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.hand_over, card["name"])
		with self.assertRaises(frappe.ValidationError):
			mdf_orders.hand_over(card["name"])  # an administrator, but no comment
		card = mdf_orders.hand_over(card["name"], comment="Доплатит в пятницу")
		self.assertEqual(card["status"], "handed_over")

	def test_on_hold_needs_nothing_more_than_a_reason(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		card = self._as(MANAGER, mdf_orders.hold, card["name"], "Клиент меняет цвет")
		self.assertEqual((card["status"], card["hold_reason"]), ("on_hold", "Клиент меняет цвет"))
		card = self._as(MANAGER, mdf_orders.hold, card["name"])
		self.assertEqual(card["status"], "accepted")

	def test_only_a_draft_is_deleted(self):
		card = self._draft()
		self._as(MANAGER, mdf_orders.delete_draft, card["name"])
		self.assertFalse(frappe.db.exists("Sales Order", card["name"]))
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.delete_draft, card["name"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.cancel, card["name"], "  ")

	def test_the_list_finds_by_customer_and_status(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		name = frappe.db.get_value("Customer", self.customer, "customer_name")
		found = self._as(MANAGER, mdf_orders.listing, search=name[:5], status="draft")["orders"]
		self.assertIn(card["name"], [row["name"] for row in found])
		row = next(row for row in found if row["name"] == card["name"])
		self.assertEqual((row["area_m2"], row["total"], row["status"]), (3.04, 58680, "draft"))

	def test_the_floor_does_not_open_the_card(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, mdf_orders.card, card["name"])

	def test_a_new_customer_on_the_card_and_the_same_phone_twice(self):
		first = self._as(MANAGER, mdf_orders.new_customer, "Тест Қалдыбаев", "8 (777) 990-11-22")
		self.assertFalse(first["existing"])
		again = self._as(MANAGER, mdf_orders.new_customer, "Другое имя", "+7 777 990 11 22")
		self.assertEqual((again["name"], again["existing"]), (first["name"], True))
		from korkem_manufacturing.services import facade_order

		found = self._as(MANAGER, facade_order.customers, search="990-11")
		self.assertIn(first["name"], [row["name"] for row in found])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.new_customer, "Тест", "123")

	def test_a_new_order_starts_from_the_last_head(self):
		card = self._draft(edge_profile=None, patina="Золото")
		self.addCleanup(self._drop, card["name"])
		head = self._as(MANAGER, mdf_orders.last_head)
		self.assertEqual((head["finish"], head["patina"], head["thickness_mm"]), (PVC, "Золото", 16))

	def test_the_film_an_accepted_order_still_needs_is_on_the_list(self):
		from korkem_manufacturing.services import film_shortage

		card = self._draft(decor_top=self.decor)
		self.addCleanup(self._drop, card["name"])
		before = {r["order"] for r in self._as(MANAGER, film_shortage.shortage)["orders"]}
		self.assertNotIn(card["name"], before)  # a draft holds nothing and needs nothing yet
		self._as(MANAGER, mdf_orders.accept, card["name"])
		report = self._as(MANAGER, film_shortage.shortage)
		mine = [r for r in report["orders"] if r["order"] == card["name"]]
		self.assertEqual([r["decor"] for r in mine], [self.decor])
		self.assertGreater(mine[0]["needed"], 0)
		film = next(f for f in report["by_film"] if f["decor"] == self.decor)
		self.assertGreaterEqual(film["to_buy"], 0)
		self.assertLessEqual(film["to_buy"], film["needed"])
		for stage in ("cut", "mill", "sand", "vacuum"):
			self._as(MANAGER, mdf_orders.set_stage, card["name"], stage)
		after = {r["order"] for r in self._as(MANAGER, film_shortage.shortage)["orders"]}
		self.assertNotIn(card["name"], after)  # pressed: the film is on the facades

	def test_debts_by_order_and_by_customer(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		before = self._as(MANAGER, mdf_orders.debts)
		self.assertNotIn(card["name"], [o["name"] for o in before["orders"]])  # a draft owes nothing
		self._as(MANAGER, mdf_orders.accept, card["name"])
		report = self._as(MANAGER, mdf_orders.debts)
		mine = next(o for o in report["orders"] if o["name"] == card["name"])
		self.assertEqual(mine["debt"], 58680)
		customer = next(c for c in report["customers"] if c["customer"] == self.customer)
		self.assertGreaterEqual(customer["debt"], 58680)
		self.assertAlmostEqual(report["total"], sum(o["debt"] for o in report["orders"]), places=2)
		later = self._as(MANAGER, mdf_orders.debts, since=add_days(nowdate(), 1))
		self.assertNotIn(card["name"], [o["name"] for o in later["orders"]])

	def test_two_orders_of_one_film_cut_as_one_list(self):
		first = self._draft(decor_top=self.decor)
		second = self._draft([{"height_mm": 1040, "width_mm": 130, "qty": 3, "milling": FLAT}], decor_top=self.decor)
		for card in (first, second):
			self.addCleanup(self._drop, card["name"])
			self._as(MANAGER, mdf_orders.accept, card["name"])
		batch = self._as(MANAGER, mdf_orders.batch, decor=self.decor, milling=FLAT)
		self.assertEqual({o["name"] for o in batch["orders"]}, {first["name"], second["name"]})
		# 130 × 1040 from №1 and 1040 × 130 turned from №2 are one part: 1 + 3 pieces.
		row = next(r for r in batch["parts"] if (r["long_mm"], r["short_mm"]) == (1040, 130))
		self.assertEqual((row["qty"], set(row["orders"])), (4, {first["name"], second["name"]}))
		self.assertEqual([r["milling"] for r in batch["parts"]], [FLAT] * len(batch["parts"]))
		longest = [r["long_mm"] for r in batch["parts"]]
		self.assertEqual(longest, sorted(longest, reverse=True))

	def test_an_accepted_order_changes_with_a_reason_and_keeps_its_history(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.change_order, card["name"], lines=ORDER_1129[:2], reason=" ")
		changed = self._as(MANAGER, mdf_orders.change_order, card["name"],
						   lines=[*ORDER_1129[:2], {"height_mm": 500, "width_mm": 400, "qty": 2, "milling": FLAT}],
						   reason="Клиент убрал две полоски, добавил две двери")
		# 2 380 + 31 785 + 0,40 м² × 17 000 = 6 800
		self.assertEqual(changed["total"], 2380 + 31785 + 6800)
		self.assertEqual([line["area_m2"] for line in changed["lines"]], [0.14, 1.63, 0.40])
		self.assertEqual(changed["lines"][2]["milling"], FLAT)
		self.assertEqual(changed["status"], "accepted")
		self.assertTrue(any("Клиент убрал" in h["text"] for h in changed["history"]))

	def test_a_handed_over_order_is_not_changed(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		for stage in mdf_orders.stages_for(PVC):
			self._as(MANAGER, mdf_orders.set_stage, card["name"], stage)
		mdf_orders.hand_over(card["name"], comment="Тест")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.change_order, card["name"], lines=ORDER_1129, reason="Поздно")

	def test_the_plan_puts_an_order_at_its_first_unticked_stage(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])

		def where():
			plan = self._as(MANAGER, mdf_orders.plan)
			return next((q["stage"] for q in plan["stages"] for o in q["orders"] if o["name"] == card["name"]),
						None), plan

		stage, plan = where()
		self.assertEqual(stage, "cut")
		cut = next(q for q in plan["stages"] if q["stage"] == "cut")
		self.assertGreaterEqual(cut["area_m2"], 3.04)
		self.assertTrue(any(d["date"] == nowdate() for d in plan["intake"]))
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "cut")
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "mill")
		self.assertEqual(where()[0], "sand")
		self._as(MANAGER, mdf_orders.hold, card["name"], "Ждём плёнку")
		self.assertIsNone(where()[0])  # on hold waits nowhere

	def test_the_cash_book_shows_a_payment_by_its_method_and_an_approved_expense(self):
		from korkem_manufacturing.api import mdf_orders as api
		from korkem_manufacturing.services import mdf_cash, urgent_expenses

		before = self._as(MANAGER, mdf_cash.cash)
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		self._as(MANAGER, api.add_payment, card["name"], 20_000, "Kaspi")
		self.addCleanup(self._cancel_payments, card["name"])
		expense = frappe.get_doc(
			{"doctype": urgent_expenses.DOCTYPE, "company": COMPANY, "requested_by": CUTTER, "amount": 3_500,
			 "purpose": "Пилки для форматки", "category": "Инструмент", "status": urgent_expenses.APPROVED,
			 "decided_by": "Administrator", "decided_at": frappe.utils.now_datetime()}
		).insert(ignore_permissions=True)
		# An expense is never deleted (urgent_expense.on_trash); the class rolls back.

		cash = self._as(MANAGER, mdf_cash.cash)
		self.assertEqual(cash["since"], nowdate())
		self.assertIn(card["name"], [p["order"] for p in cash["payments"] if p["method"] == "Kaspi"])
		self.assertEqual(cash["total_in"] - before["total_in"], 20_000)  # the part paid, not the order's total
		self.assertEqual([p["amount"] for p in self._as(MANAGER, mdf_orders.card, card["name"])["payments"]], [20_000])
		self.assertEqual(cash["total_out"] - before["total_out"], 3_500)
		self.assertEqual(cash["net"], cash["total_in"] - cash["total_out"])
		today = cash["days"][0]
		self.assertEqual((today["date"], today["net"]), (nowdate(), today["in"] - today["out"]))
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, mdf_cash.cash)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_cash.cash, since=nowdate(), until=add_days(nowdate(), -1))

	def test_the_order_report_counts_accepted_orders_and_cancelled_ones_apart(self):
		from korkem_manufacturing.services import mdf_report

		before = self._as(MANAGER, mdf_report.report, since=nowdate(), until=nowdate())
		kept, dropped, draft = self._draft(decor_top=self.decor), self._draft(), self._draft()
		for card in (kept, dropped, draft):
			self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, kept["name"])
		self._as(MANAGER, mdf_orders.accept, dropped["name"])
		self._as(MANAGER, mdf_orders.cancel, dropped["name"], "Клиент передумал")

		report = self._as(MANAGER, mdf_report.report, since=nowdate(), until=nowdate())
		self.assertEqual(report["orders"] - before["orders"], 1)  # the draft is not an order yet
		self.assertEqual(report["cancelled"] - before["cancelled"], 1)
		self.assertAlmostEqual(report["area_m2"] - before["area_m2"], 3.04, places=2)
		self.assertEqual(report["total"] - before["total"], 58_680)
		venge = next(d for d in report["by_decor"] if d["decor"] == self.decor)
		self.assertGreaterEqual(venge["orders"], 1)
		self.assertIn("accepted", [s["status"] for s in report["by_status"]])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, mdf_report.report)

	def test_a_stage_ticked_with_a_worker_counts_to_their_work_volume(self):
		from korkem_manufacturing.services import mdf_volume

		worker = self._worker()
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		before = self._as(MANAGER, mdf_volume.volume, since=nowdate(), until=nowdate())
		card = self._as(MANAGER, mdf_orders.set_stage, card["name"], "cut", worker=worker)
		self.assertEqual(card["stages"][0]["worker"], worker)
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "mill")  # nobody named

		after = self._as(MANAGER, mdf_volume.volume, since=nowdate(), until=nowdate())

		def area(report, who):
			return next((w["area_m2"] for w in report["workers"] if w["worker"] == who), 0)

		self.assertAlmostEqual(area(after, worker) - area(before, worker), 3.04, places=2)
		self.assertAlmostEqual(after["unassigned_m2"] - before["unassigned_m2"], 3.04, places=2)
		self.assertIn(worker, [w["employee"] for w in self._as(MANAGER, mdf_volume.workers)])

		card = self._as(MANAGER, mdf_orders.set_stage, card["name"], "cut", done=False)
		self.assertIsNone(card["stages"][0]["worker"])  # unticking forgets who
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.set_stage, card["name"], "cut", worker="EMP-NOBODY")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, mdf_volume.volume)

	def _worker(self) -> str:
		existing = frappe.db.get_value("Employee", {"company": COMPANY, "status": "Active"}, "name")
		if existing:
			return existing
		return frappe.get_doc(
			{"doctype": "Employee", "first_name": "Цех", "last_name": "Тест", "company": COMPANY, "status": "Active",
			 "gender": self._gender(), "date_of_birth": "1990-01-01",
			 "date_of_joining": "2024-01-01"}
		).insert(ignore_permissions=True).name

	def _gender(self) -> str:
		if not frappe.db.exists("Gender", "Male"):
			frappe.get_doc({"doctype": "Gender", "gender": "Male"}).insert(ignore_permissions=True)
		return "Male"

	def _cancel_payments(self, order: str) -> None:
		frappe.set_user("Administrator")
		for parent in frappe.get_all("Payment Entry Reference", filters={"reference_name": order, "docstatus": 1},
									 pluck="parent"):
			frappe.get_doc("Payment Entry", parent).cancel()

	def _drop(self, name: str) -> None:
		frappe.set_user("Administrator")
		if not frappe.db.exists("Sales Order", name):
			return
		doc = frappe.get_doc("Sales Order", name)
		if doc.docstatus == 1:
			doc.cancel()  # releases what the order held (facade_materials.on_order_cancelled)
		# Nothing committed and nothing hard-deleted: the class rolls back, and
		# a deleted order would hand its name back to the naming series for the
		# next test to inherit (CI, 05.11.2026).
