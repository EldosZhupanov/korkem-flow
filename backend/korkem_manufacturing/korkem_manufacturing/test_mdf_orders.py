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

	def test_film_is_ready_when_готово_is_ticked_after_the_vacuum_and_never_painted(self):
		# The owner's stages (09.11.2026): «готово» last, checked and packed.
		self.assertEqual(mdf_orders.stages_for(PVC), ["cut", "mill", "sand", "vacuum", "ready"])
		self.assertEqual(mdf_orders.stages_for("Эмаль"), ["cut", "mill", "sand", "paint", "ready"])
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		with self.assertRaises(frappe.ValidationError):  # a film facade is not painted
			self._as(MANAGER, mdf_orders.set_stage, card["name"], "paint")
		for stage in ("cut", "mill", "sand"):
			card = self._as(MANAGER, mdf_orders.set_stage, card["name"], stage)
		with self.assertRaises(frappe.ValidationError):  # «готово» only after every stage
			self._as(MANAGER, mdf_orders.set_stage, card["name"], "ready")
		card = self._as(MANAGER, mdf_orders.set_stage, card["name"], "vacuum")
		self.assertEqual((card["status"], card["ready_on"]), ("in_shop", None))  # pressed, not yet checked
		card = self._as(MANAGER, mdf_orders.set_stage, card["name"], "ready")
		self.assertEqual((card["status"], card["ready_on"]), ("ready", nowdate()))
		card = self._as(MANAGER, mdf_orders.set_stage, card["name"], "ready", 0)
		self.assertEqual((card["status"], card["ready_on"]), ("in_shop", None))

	def test_a_rework_adds_a_stage_its_finish_has_not(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		for stage in mdf_orders.stages_for(PVC):
			card = self._as(MANAGER, mdf_orders.set_stage, card["name"], stage)
		self.assertEqual(card["status"], "ready")
		# Repainted after a master's mistake: paint goes before the vacuum, and
		# the order is not ready until it is done.
		card = self._as(MANAGER, mdf_orders.extra_stage, card["name"], "paint")
		self.assertEqual([s["stage"] for s in card["stages"]], ["cut", "mill", "sand", "paint", "vacuum", "ready"])
		self.assertTrue(next(s for s in card["stages"] if s["stage"] == "paint")["extra"])
		self.assertIsNone(card["ready_on"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.extra_stage, card["name"], "cut")
		card = self._as(MANAGER, mdf_orders.set_stage, card["name"], "paint")
		with self.assertRaises(frappe.ValidationError):  # ticked: it stays
			self._as(MANAGER, mdf_orders.extra_stage, card["name"], "paint", 0)
		card = self._as(MANAGER, mdf_orders.set_stage, card["name"], "paint", 0)
		card = self._as(MANAGER, mdf_orders.extra_stage, card["name"], "paint", 0)
		self.assertNotIn("paint", [s["stage"] for s in card["stages"]])

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
		from korkem_manufacturing.services import material_stock

		# Once the patina list has values, an order's patina must be one of them.
		self._as(MANAGER, material_stock.put_option, "Патина", "Золото")
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
		# An older app's «Kaspi» is a Kaspi transfer (09.11.2026: method and bank).
		mine = next(p for p in cash["payments"] if p["order"] == card["name"])
		self.assertEqual((mine["method"], mine["bank"]), ("Перевод", "Kaspi"))
		transfer = next(m for m in cash["by_method"] if m["method"] == "Перевод")
		self.assertIn("Kaspi", [b["bank"] for b in transfer["banks"]])
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

	def test_the_summary_compares_says_who_ordered_and_who_fell_asleep(self):
		from korkem_manufacturing.services import mdf_summary

		before = self._as(MANAGER, mdf_summary.summary, since=nowdate(), until=nowdate())
		card = self._draft(decor_top=self.decor)
		self.addCleanup(self._drop, card["name"])
		# The card says how much film the order takes, as the press lays it out.
		press = card["press"][self.decor]
		self.assertGreater(press["film_m"], 0)
		self.assertEqual(round(sum(press["loads"]), 2), press["layout_m"])
		self.assertLessEqual(press["layout_m"], press["plain_m"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		after = self._as(MANAGER, mdf_summary.summary, since=nowdate(), until=nowdate())
		self.assertEqual(after["orders"] - before["orders"], 1)
		self.assertAlmostEqual(after["area_m2"] - before["area_m2"], 3.04, places=2)
		self.assertEqual(after["total"] - before["total"], 58_680)
		# Against yesterday, the period of the same length before.
		self.assertEqual(after["before"]["since"], str(add_days(nowdate(), -1)))
		self.assertAlmostEqual(after["plan"]["done_m2"] - before["plan"]["done_m2"], 3.04, places=2)
		self.assertIn(self.customer, [c["customer"] for c in after["top_customers"]])
		manager = next(m for m in after["managers"] if m["user"] == MANAGER)
		self.assertGreaterEqual(manager["orders"], 1)
		self.assertGreaterEqual(after["shop"]["in_work_orders"], 1)
		venge = next(f for f in after["films"] if f["decor"] == self.decor)
		self.assertGreaterEqual(venge["area_m2"], 3.04)
		# The dashboard: the order waits at its first stage, and today's bar
		# carries it.
		cut = lambda s: next(x for x in s["stages"] if x["stage"] == "cut")  # noqa: E731
		self.assertEqual(cut(after)["orders"] - cut(before)["orders"], 1)
		self.assertEqual([d["date"] for d in after["days"]], [nowdate()])
		self.assertAlmostEqual(after["days"][0]["area_m2"] - before["days"][0]["area_m2"], 3.04, places=2)
		self.assertIsInstance(after["at_risk"], int)
		year = self._as(MANAGER, mdf_summary.summary, since=add_days(nowdate(), -300), until=nowdate())
		self.assertLessEqual(len(year["days"]), 12)
		# The month's goal: set once, the progress follows.
		self._as(MANAGER, mdf_summary.set_target, 1000)
		plan = self._as(MANAGER, mdf_summary.summary, since=nowdate(), until=nowdate())["plan"]
		self.assertEqual(plan["target_m2"], 1000)
		self.assertAlmostEqual(plan["progress"], round(plan["done_m2"] / 1000, 3), places=3)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, mdf_summary.summary)

	def test_a_customer_is_asleep_by_his_own_rhythm(self):
		from korkem_manufacturing.services import mdf_summary

		def order(customer: str, days_ago: int) -> None:
			card = self._as(MANAGER, mdf_orders.save_draft, customer=customer,
							delivery_date=add_days(nowdate(), 7), head={"finish": PVC, "thickness_mm": 16},
							lines=ORDER_1129)
			self.addCleanup(self._drop, card["name"])
			self._as(MANAGER, mdf_orders.accept, card["name"])
			frappe.db.set_value("Sales Order", card["name"], "transaction_date", add_days(nowdate(), -days_ago))

		tag = frappe.generate_hash(length=6)
		often = self._as(MANAGER, mdf_orders.new_customer, f"Ритм {tag}")["name"]
		once = self._as(MANAGER, mdf_orders.new_customer, f"Один {tag}")["name"]
		# Every ten days, and not for fifty: gone. One order a month ago: not yet.
		order(often, 60)
		order(often, 50)
		order(once, 30)
		asleep = {c["customer"]: c for c in self._as(MANAGER, mdf_summary.summary)["asleep"]}
		self.assertEqual((asleep[often]["rhythm_days"], asleep[often]["idle_days"], asleep[often]["gone"]),
						 (10, 50, True))
		self.assertNotIn(once, asleep)

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
		# The shop's dashboard: today's bar carries both stages; the queue
		# has the order waiting at sanding next; the period before is a number.
		self.assertEqual([d["date"] for d in after["days"]], [nowdate()])
		self.assertAlmostEqual(after["days"][0]["area_m2"] - before["days"][0]["area_m2"], 6.08, places=2)
		self.assertIsInstance(after["previous_m2"], float)
		waiting = {q["stage"]: q["orders"] for q in after["queue"]}
		before_waiting = {q["stage"]: q["orders"] for q in before["queue"]}
		self.assertEqual(sum(waiting.values()), sum(before_waiting.values()))

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

	# --- the order form's dictionaries (OnayBaza's blue button) ---

	def test_a_dictionary_value_is_added_renamed_with_its_price_and_deleted(self):
		from korkem_manufacturing.services import mdf_dictionaries as dicts

		lists = self._as(MANAGER, dicts.dictionaries)
		self.assertEqual(set(lists), {"material", "thickness", "finish", "decor", "patina", "milling", "edge", "bank", "paint", "maker", "film_type", "film_thickness", "film_width", "transport", "city"})
		self.assertNotIn(PVC, [v["value"] for v in lists["finish"]])  # nothing is filled in for the owner

		lists = self._as(MANAGER, dicts.add, "patina", "  Алтын/Золотой ")
		self.assertIn("Алтын/Золотой", [v["value"] for v in lists["patina"]])
		self.assertEqual(len(self._as(MANAGER, dicts.add, "patina", "Алтын/Золотой")["patina"]),
						 len(lists["patina"]))  # the same value twice is one value

		lists = self._as(MANAGER, dicts.add, "milling", "МДФ Тест Квадро 10")
		self._as(MANAGER, facade_prices.set_price, "МДФ Тест Квадро 10", PVC, 21_000)
		option = next(v["id"] for v in lists["milling"] if v["value"] == "МДФ Тест Квадро 10")
		lists = self._as(MANAGER, dicts.rename, "milling", option, "МДФ Тест Квадро 12")
		self.assertIn("МДФ Тест Квадро 12", [v["value"] for v in lists["milling"]])
		self.assertEqual(facade_prices.price_for("МДФ Тест Квадро 12", PVC, COMPANY), 21_000)  # the price follows
		self.assertIsNone(facade_prices.price_for("МДФ Тест Квадро 10", PVC, COMPANY))

		result = self._as(MANAGER, dicts.remove, "milling", option)
		self.assertEqual(result["outcome"], "deleted")
		self.assertNotIn("МДФ Тест Квадро 12", [v["value"] for v in result["milling"]])
		self.assertIsNone(facade_prices.price_for("МДФ Тест Квадро 12", PVC, COMPANY))  # its price is switched off

		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, dicts.add, "patina", "   ")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, dicts.add, "nonsense", "x")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, dicts.dictionaries)

	def test_a_value_an_order_uses_is_switched_off_not_deleted_and_names_stay_unique(self):
		from korkem_manufacturing.services import mdf_dictionaries as dicts

		lists = self._as(MANAGER, dicts.add, "edge", "МДФ Тест R3")
		lists = self._as(MANAGER, dicts.add, "edge", "МДФ Тест R4")
		r3, r4 = (next(v["id"] for v in lists["edge"] if v["value"] == name) for name in ("МДФ Тест R3", "МДФ Тест R4"))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, dicts.rename, "edge", r4, "МДФ Тест R3")
		card = self._draft(edge_profile="МДФ Тест R3")
		self.addCleanup(self._drop, card["name"])

		result = self._as(MANAGER, dicts.remove, "edge", r3)
		self.assertEqual(result["outcome"], "disabled")
		self.assertNotIn("МДФ Тест R3", [v["value"] for v in result["edge"]])
		self.assertEqual(frappe.db.get_value("Sales Order", card["name"], "korkem_edge_profile"), "МДФ Тест R3")
		with self.assertRaises(frappe.DoesNotExistError):
			self._as(MANAGER, dicts.rename, "patina", r4, "x")  # an id from another list

	def test_a_new_finish_can_be_priced_and_a_film_is_known_by_its_name(self):
		from korkem_manufacturing.services import mdf_dictionaries as dicts

		self._as(MANAGER, dicts.add, "finish", "МДФ Тест Переделка")
		self._as(MANAGER, facade_prices.set_price, FLAT, "МДФ Тест Переделка", 8_000)
		self.assertEqual(facade_prices.price_for(FLAT, "МДФ Тест Переделка", COMPANY), 8_000)
		self.assertTrue(facade_prices.is_film("Пленка ПВХ"))
		self.assertTrue(facade_prices.is_film(PVC))
		self.assertFalse(facade_prices.is_film("Бояу/Краска"))
		self.assertEqual(mdf_orders.stages_for("Пленка ПВХ"), ["cut", "mill", "sand", "vacuum", "ready"])

	def _gender(self) -> str:
		if not frappe.db.exists("Gender", "Male"):
			frappe.get_doc({"doctype": "Gender", "gender": "Male"}).insert(ignore_permissions=True)
		return "Male"

	def test_the_customer_list_adds_edits_and_deletes_a_customer(self):
		from korkem_manufacturing.services import mdf_customers

		import random

		phone = "8 701 " + "".join(random.choices("0123456789", k=7))
		added = self._as(MANAGER, mdf_customers.add, "МДФ Тест Куат", phone, "ИП Куат")
		self.addCleanup(lambda: frappe.db.exists("Customer", added["name"]) and frappe.delete_doc(
			"Customer", added["name"], force=True, ignore_permissions=True))
		self.assertEqual(added["organization"], "ИП Куат")
		listed = {c["name"]: c for c in self._as(MANAGER, mdf_customers.customers)}
		self.assertEqual(listed[added["name"]]["phone"], phone)

		with self.assertRaises(frappe.ValidationError):  # the same phone is the same person
			self._as(MANAGER, mdf_customers.add, "МДФ Тест Куат второй", phone)
		changed = self._as(MANAGER, mdf_customers.update, added["name"], "МДФ Тест Куат С.", phone, "Куад")
		self.assertEqual((changed["customer_name"], changed["organization"]), ("МДФ Тест Куат С.", "Куад"))

		self.assertEqual(self._as(MANAGER, mdf_customers.remove, added["name"])["outcome"], "deleted")
		self.assertFalse(frappe.db.exists("Customer", added["name"]))
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, mdf_customers.customers)

	def test_a_customer_with_an_order_is_disabled_not_deleted(self):
		from korkem_manufacturing.services import mdf_customers

		made = self._as(MANAGER, mdf_customers.add, "МДФ Тест С заказом")
		card = self._as(MANAGER, mdf_orders.save_draft, customer=made["name"], delivery_date=add_days(nowdate(), 7),
						head={"finish": PVC, "thickness_mm": 16}, lines=ORDER_1129)
		self.addCleanup(self._drop, card["name"])
		self.assertEqual(self._as(MANAGER, mdf_customers.remove, made["name"])["outcome"], "disabled")
		self.assertTrue(frappe.db.get_value("Customer", made["name"], "disabled"))
		self.assertNotIn(made["name"], [c["name"] for c in self._as(MANAGER, mdf_customers.customers)])

	def test_an_order_of_several_films_keeps_each_positions_film_back_and_material(self):
		from korkem_manufacturing.services import mdf_dictionaries

		for kind, value in (("decor", "МДФ Тест Палома"), ("material", "16 мм МДФ"), ("material", "3 мм ХДФ")):
			self._as(MANAGER, mdf_dictionaries.add, kind, value)
		paloma = "МДФ Тест Палома"
		lines = [
			{"height_mm": 718, "width_mm": 500, "qty": 2, "milling": FLAT, "film": self.decor, "material": "16 мм МДФ",
			 "rate": 17_000},
			{"height_mm": 2000, "width_mm": 500, "qty": 2, "milling": FLAT, "film": self.decor, "material": "16 мм МДФ",
			 "film_back": self.decor, "rate": 19_500},
			{"height_mm": 300, "width_mm": 400, "qty": 2, "milling": PATTERN, "film": paloma, "material": "3 мм ХДФ",
			 "film_back": paloma, "rate": 21_000},
			# No price typed: the film's price in the group's header.
			{"height_mm": 500, "width_mm": 498, "qty": 5, "milling": PATTERN, "film": paloma},
		]
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
						head={"finish": PVC, "material": "16 мм МДФ",
							  "film_rates": {self.decor: 17_000, paloma: 18_000}},
						lines=lines)
		self.addCleanup(self._drop, card["name"])

		self.assertEqual(card["head"]["material"], "16 мм МДФ")
		self.assertEqual(card["head"]["thickness_mm"], 16)  # from the material's name
		self.assertEqual(card["head"]["film_rates"], {self.decor: 17_000, paloma: 18_000})
		got = [(l["film"], l["film_back"], l["material"], l["thickness_mm"], l["amount"]) for l in card["lines"]]
		self.assertEqual(got, [
			(self.decor, None, "16 мм МДФ", 16, 12_240),
			(self.decor, self.decor, "16 мм МДФ", 16, 39_000),
			(paloma, paloma, "3 мм ХДФ", 3, 5_040),
			(paloma, None, "16 мм МДФ", 16, 22_500),  # 1.25 m² × the group's 18 000; the head's material
		])
		self.assertFalse(card["lines"][3]["manual_rate"])
		self.assertEqual(card["total"], 78_780)

		with self.assertRaises(frappe.ValidationError):  # a film nobody put on the list
			self._as(MANAGER, mdf_orders.price, [{**lines[0], "film": "Нет такой плёнки"}], finish=PVC)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.price, [{**lines[0], "material": "99 мм Картон"}], finish=PVC)

	def test_a_position_keeps_its_own_radius_and_patina(self):
		from korkem_manufacturing.services import material_stock

		for kind, value in (("Профиль кромки", "R3"), ("Профиль кромки", "R0"), ("Патина", "МДФ Тест Золото")):
			material_stock.put_option(kind, value)
		lines = [{**ORDER_1129[0], "edge": "R0", "patina": "МДФ Тест Золото"}, {**ORDER_1129[1], "edge": "R3"}]
		card = self._draft(lines=lines, edge_profile="R3")
		self.addCleanup(self._drop, card["name"])
		got = [(l["edge"], l["patina"]) for l in card["lines"]]
		self.assertEqual(got, [("R0", "МДФ Тест Золото"), ("R3", None)])
		with self.assertRaises(frappe.ValidationError):  # a radius nobody put on the list
			self._as(MANAGER, mdf_orders.price, [{**ORDER_1129[0], "edge": "R99"}], finish=PVC)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.price, [{**ORDER_1129[0], "patina": "Нет такой"}], finish=PVC)

	def test_tags_of_an_order_and_of_its_customer(self):
		from korkem_manufacturing.services import mdf_customers

		made = self._as(MANAGER, mdf_customers.add, "МДФ Тест Вип", None, None, ["prepay_only", "vip"])
		self.addCleanup(lambda: frappe.delete_doc("Customer", made["name"], force=True, ignore_permissions=True))
		self.assertEqual(made["tags"], ["vip", "prepay_only"])  # kept in a fixed order
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_customers.update, made["name"], "МДФ Тест Вип", None, None, ["king"])
		calm = self._as(MANAGER, mdf_orders.save_draft, customer=made["name"], delivery_date=add_days(nowdate(), 7),
						head={"finish": PVC, "thickness_mm": 16}, lines=ORDER_1129)
		self.addCleanup(self._drop, calm["name"])
		urgent = self._as(MANAGER, mdf_orders.save_draft, customer=made["name"],
						  delivery_date=add_days(nowdate(), 7),
						  head={"finish": PVC, "thickness_mm": 16, "tags": ["urgent"]}, lines=ORDER_1129)
		self.addCleanup(self._drop, urgent["name"])
		self.assertEqual(urgent["tags"], ["urgent"])
		self.assertEqual(urgent["head"]["tags"], ["urgent"])
		self.assertNotIn("tags", self._as(MANAGER, mdf_orders.last_head))
		self.assertEqual(urgent["customer_tags"], ["vip", "prepay_only"])
		with self.assertRaises(frappe.ValidationError):
			self._draft(tags=["vip"])  # a customer's tag is not an order's

		self._as(MANAGER, mdf_orders.accept, calm["name"])
		self._as(MANAGER, mdf_orders.accept, urgent["name"])
		listed = self._as(MANAGER, mdf_orders.listing, search="МДФ Тест Вип")["orders"]
		self.assertEqual([o["name"] for o in listed][:1], [urgent["name"]])  # urgent first
		self.assertEqual(
			[o["name"] for o in self._as(MANAGER, mdf_orders.listing, tag="urgent", search="МДФ Тест Вип")["orders"]],
			[urgent["name"]])
		self.assertEqual(
			{o["name"] for o in self._as(MANAGER, mdf_orders.listing, tag="vip")["orders"]} >= {calm["name"],
																					 urgent["name"]}, True)
		cut = next(q for q in self._as(MANAGER, mdf_orders.plan)["stages"] if q["stage"] == "cut")
		mine = [o for o in cut["orders"] if o["name"] in (calm["name"], urgent["name"])]
		self.assertEqual(mine[0]["name"], urgent["name"])
		self.assertGreaterEqual(mine[0]["days_left"], 7)  # a weekend date moves to a working day
		self.assertFalse(mine[0]["at_risk"])

	def test_a_rework_or_a_warranty_job_owes_nothing(self):
		card = self._draft(tags=["rework"])
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		self.assertEqual(self._as(MANAGER, mdf_orders.card, card["name"])["debt"], 0)
		self.assertNotIn(card["name"], [o["name"] for o in self._as(MANAGER, mdf_orders.debts)["orders"]])

	def test_an_order_misses_its_date_when_its_stages_outrun_its_days(self):
		self.assertFalse(mdf_orders._at_risk(2, 0))  # due today, two stages: still makes it
		self.assertTrue(mdf_orders._at_risk(3, 0))
		self.assertTrue(mdf_orders._at_risk(5, 1))
		self.assertFalse(mdf_orders._at_risk(4, 1))
		self.assertFalse(mdf_orders._at_risk(9, -1))  # overdue is late, not at risk

	def test_a_payment_names_its_method_and_the_bank_of_a_transfer(self):
		from korkem_manufacturing.api import mdf_orders as api
		from korkem_manufacturing.services import mdf_dictionaries

		self._as(MANAGER, mdf_dictionaries.add, "bank", "МДФ Тест Халык")
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		self.addCleanup(self._cancel_payments, card["name"])
		self._as(MANAGER, api.add_payment, card["name"], 5_000, "Карта", bank="МДФ Тест Халык")
		card = self._as(MANAGER, api.add_payment, card["name"], 1_000, "Наличные", bank="МДФ Тест Халык")
		# Two payments of one day, in no particular order; cash has no bank.
		self.assertEqual({(p["method"], p["bank"]) for p in card["payments"]},
						 {("Карта", "МДФ Тест Халык"), ("Наличные", None)})
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, api.add_payment, card["name"], 1_000, "Перевод", bank="Нет такого банка")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, api.add_payment, card["name"], 1_000, "Бартер")

	def test_thickness_and_material_apart_and_the_standard_edges_stay(self):
		from korkem_manufacturing.services import mdf_dictionaries

		self._as(MANAGER, mdf_dictionaries.add, "material", "МДФ")
		lines = [{**ORDER_1129[0], "material": "МДФ", "thickness_mm": 18},
				 {**ORDER_1129[1], "material": "МДФ", "thickness_mm": "10 мм"},
				 {**ORDER_1129[2]}]
		card = self._draft(lines=lines, material="МДФ", thickness_mm=16)
		self.addCleanup(self._drop, card["name"])
		self.assertEqual([(l["material"], l["thickness_mm"]) for l in card["lines"][:3]],
						 [("МДФ", 18), ("МДФ", 10), ("МДФ", 16)])  # the third takes the head's
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.price, [{**ORDER_1129[0], "thickness_mm": 99}], finish=PVC)
		from korkem_manufacturing.services import material_stock

		material_stock.put_option("Профиль кромки", "R3")
		r3 = next(e for e in self._as(MANAGER, mdf_dictionaries.dictionaries)["edge"] if e["value"] == "R3")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_dictionaries.remove, "edge", r3["id"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_dictionaries.rename, "edge", r3["id"], "R4")

	def test_each_group_has_its_coating_and_a_colour_from_that_coatings_list(self):
		from korkem_manufacturing.services import mdf_dictionaries

		self._as(MANAGER, mdf_dictionaries.add, "paint", "МДФ Тест RAL 9010")
		lines = [
			{**ORDER_1129[0], "coating": "pvc", "film": self.decor, "rate": 17_000},
			{**ORDER_1129[1], "coating": "paint", "film": "МДФ Тест RAL 9010", "rate": 24_000},
			{**ORDER_1129[2], "coating": "raw", "rate": 9_000},
		]
		# A paint group has its price too (the owner's order of 09.11.2026 failed on it).
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
						head={"thickness_mm": 16, "film_rates": {"МДФ Тест RAL 9010": 30_000}}, lines=lines)
		self.addCleanup(self._drop, card["name"])
		self.assertEqual(card["head"]["film_rates"], {"МДФ Тест RAL 9010": 30_000})
		self.assertEqual([(l["coating"], l["film"]) for l in card["lines"][:3]],
						 [("pvc", self.decor), ("paint", "МДФ Тест RAL 9010"), ("raw", None)])
		self.assertIsNotNone(card["head"]["finish"])  # the first group's, for whatever reads the head
		# A film group is pressed, a paint group painted: this order goes through both.
		self._as(MANAGER, mdf_orders.accept, card["name"])
		card = self._as(MANAGER, mdf_orders.card, card["name"])
		self.assertEqual([s["stage"] for s in card["stages"]], ["cut", "mill", "sand", "paint", "vacuum", "ready"])

		with self.assertRaises(frappe.ValidationError):  # a paint is not a film
			self._as(MANAGER, mdf_orders.price, [{**lines[0], "film": "МДФ Тест RAL 9010"}], finish=None)
		with self.assertRaises(frappe.ValidationError):  # nor a film a paint
			self._as(MANAGER, mdf_orders.price, [{**lines[1], "film": self.decor}], finish=None)
		with self.assertRaises(frappe.ValidationError):  # a raw facade has no colour
			self._as(MANAGER, mdf_orders.price, [{**lines[2], "film": self.decor}], finish=None)
		self.assertEqual(mdf_orders.stages_for(None, coatings="raw"), ["cut", "mill", "sand", "ready"])

	def test_the_paint_board_groups_by_colour_and_counts_the_drying_down(self):
		from korkem_manufacturing.services import mdf_dictionaries, mdf_paint

		colour = "МДФ Тест RAL 7035"
		self._as(MANAGER, mdf_dictionaries.add, "paint", colour)
		lines = [
			{**ORDER_1129[0], "coating": "pvc", "film": self.decor, "rate": 17_000},
			{**ORDER_1129[1], "coating": "paint", "film": colour, "rate": 24_000},  # 1,63 m²
		]
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
						head={"thickness_mm": 16}, lines=lines)
		self.addCleanup(self._drop, card["name"])
		name = card["name"]
		before = self._as(MANAGER, mdf_paint.board)
		self._as(MANAGER, mdf_orders.accept, name)

		def group(board):
			return next((g for g in board["by_colour"] if g["colour"] == colour), None)

		# Still at the saw: on its way to the paint, not at it — and only its painted m².
		board = self._as(MANAGER, mdf_paint.board)
		self.assertIsNone(group(board))
		self.assertAlmostEqual(board["coming_m2"] - before["coming_m2"], 1.63, places=2)
		# …and the painter sees which order it is, and where it is now.
		self.assertEqual(next(c for c in board["coming"] if c["name"] == name)["stage"], "cut")
		for stage in ("cut", "mill", "sand"):
			self._as(MANAGER, mdf_orders.set_stage, name, stage)
		board = self._as(MANAGER, mdf_paint.board)
		self.assertEqual([o["name"] for o in group(board)["orders"]], [name])
		self.assertAlmostEqual(group(board)["area_m2"], 1.63, places=2)

		# Put to dry: off the colour list, counting down from the factory's hours.
		self._as(MANAGER, mdf_paint.set_dry_hours, 12)
		self.addCleanup(lambda: frappe.db.set_default(f"{mdf_paint._DRY_KEY}:{COMPANY}", ""))
		board = self._as(MANAGER, mdf_paint.start_drying, name)
		self.assertIsNone(group(board))
		drying = next(d for d in board["drying"] if d["name"] == name)
		self.assertEqual((drying["dry"], drying["colours"], board["dry_hours"]), (False, [colour], 12))
		self.assertGreater(drying["minutes_left"], 11 * 60)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_paint.set_dry_hours, 0)
		# Dry: «краска» is ticked and it leaves the board.
		self._as(MANAGER, mdf_orders.set_stage, name, "paint")
		board = self._as(MANAGER, mdf_paint.board)
		self.assertNotIn(name, [d["name"] for d in board["drying"]])
		self.assertIn(colour, [p["colour"] for p in board["popular"]])
		with self.assertRaises(frappe.ValidationError):  # painted already
			self._as(MANAGER, mdf_paint.start_drying, name)
		with self.assertRaises(frappe.PermissionError):  # the board is the managers' screen for now
			self._as(CUTTER, mdf_paint.board)

	def test_the_customer_s_own_paint_and_facades(self):
		from korkem_manufacturing.services import facade_materials, mdf_dictionaries, mdf_paint

		colour = "МДФ Тест RAL 9005"
		self._as(MANAGER, mdf_dictionaries.add, "paint", colour)
		self._as(MANAGER, mdf_orders.set_client_paint_discount, 6_000)
		self.addCleanup(lambda: frappe.db.set_default(f"{mdf_orders._PAINT_DISCOUNT}:{COMPANY}", ""))
		line = {"height_mm": 1000, "width_mm": 500, "qty": 1, "milling": "Нет такой", "coating": "paint",
				"film": colour}
		# His paint is a group's: its m² costs the discount less; a price typed by hand stands.
		own = {**line, "client_paint": 1, "client_mdf": 1}
		priced = self._as(MANAGER, mdf_orders.price, [line, own, {**own, "rate": 25_000}], finish=None,
						  default_rate=20_000)
		self.assertEqual([l["amount"] for l in priced["lines"]], [10_000, 7_000, 12_500])

		# His film, on his facades, is pressed here; a film is no paint, so the
		# discount is the paint's alone.
		film = {**ORDER_1129[0], "coating": "pvc", "film": self.decor, "rate": 17_000, "client_film": 1,
				"client_mdf": 1, "client_paint": 1}
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
						head={"thickness_mm": 16, "default_rate": 20_000}, lines=[own, film])
		# The order carries them as tags, from its positions; the card's positions keep their flags.
		self.assertEqual(set(card["tags"]), {"client_paint", "client_film", "client_parts"})
		self.assertEqual([(l["client_paint"], l["client_film"], l["client_mdf"]) for l in card["lines"]],
						 [(True, False, True), (False, True, True)])
		self.assertEqual(card["total"], 7_000 + 2_380)
		self.addCleanup(self._drop, card["name"])
		name = card["name"]
		card = self._as(MANAGER, mdf_orders.accept, name)
		# His facades: nothing to cut or mill, but sanded here — and neither
		# MDF nor film from our shelf.
		self.assertEqual([s["stage"] for s in card["stages"]], ["sand", "paint", "vacuum", "ready"])
		self.assertEqual(card["client_paint"], {"note": None, "in": False})
		self.assertEqual(facade_materials.need(name)["materials"], [])

		def mine(board):
			return next(o for g in board["by_colour"] if g["colour"] == colour for o in g["orders"] if o["name"] == name)

		# At sanding, the painter already sees it coming — and that the paint is not here.
		coming = next(c for c in self._as(MANAGER, mdf_paint.board)["coming"] if c["name"] == name)
		self.assertEqual((coming["stage"], coming["waiting_paint"], coming["client_parts"]), ("sand", True, True))
		self._as(MANAGER, mdf_orders.set_stage, name, "sand")
		order = mine(self._as(MANAGER, mdf_paint.board))
		self.assertEqual((order["client_paint"], order["waiting_paint"]), (True, True))
		card = self._as(MANAGER, mdf_orders.set_client_paint, name, note="2 банки × 3 л", received=1)
		self.assertEqual(card["client_paint"], {"note": "2 банки × 3 л", "in": True})
		order = mine(self._as(MANAGER, mdf_paint.board))
		self.assertEqual((order["waiting_paint"], order["client_paint_note"]), (False, "2 банки × 3 л"))

	def test_a_payment_is_fixed_or_taken_back_the_same_day_and_an_old_one_only_by_the_owner(self):
		from korkem_manufacturing.api import mdf_orders as api

		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		self.addCleanup(self._cancel_payments, card["name"])
		card = self._as(MANAGER, api.add_payment, card["name"], 50_000, "Наличные")
		entry = card["payments"][0]["entry"]
		# Typed 50 000 for 5 000: cancelled and entered again, the old one struck through.
		card = self._as(MANAGER, api.fix_payment, card["name"], entry, "Ошибка в сумме", 5_000, "Наличные")
		self.assertEqual(card["paid"], 5_000)
		self.assertEqual([(p["amount"], p["cancelled"]) for p in card["payments"]],
						 [(50_000, True), (5_000, False)])
		self.assertTrue(any("Оплата исправлена" in h["text"] and "Ошибка в сумме" in h["text"]
							for h in card["history"]))
		with self.assertRaises(frappe.ValidationError):  # already cancelled
			self._as(MANAGER, api.delete_payment, card["name"], entry, "Дважды")
		with self.assertRaises(frappe.ValidationError):  # no reason
			self._as(MANAGER, api.delete_payment, card["name"], card["payments"][1]["entry"], " ")
		# Entered yesterday: the manager may not, the owner may.
		live = card["payments"][1]["entry"]
		frappe.db.set_value("Payment Entry", live, "creation", add_days(nowdate(), -1), update_modified=False)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, api.delete_payment, card["name"], live, "Не тот заказ")
		card = api.delete_payment(card["name"], live, "Не тот заказ")
		self.assertEqual(card["paid"], 0)
		self.assertTrue(all(p["cancelled"] for p in card["payments"]))

	def test_a_hand_over_says_who_took_it_and_goes_back_to_work_with_a_reason(self):
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		for stage in mdf_orders.stages_for(PVC):
			self._as(MANAGER, mdf_orders.set_stage, card["name"], stage)
		card = mdf_orders.hand_over(card["name"], comment="Доплатит", taken_by="Ерлан, водитель",
									taken_phone="87011234567")
		self.assertEqual((card["taken_by"], card["taken_phone"]), ("Ерлан, водитель", "87011234567"))
		self.assertTrue(any("Забрал: Ерлан, водитель" in h["text"] for h in card["history"]))
		with self.assertRaises(frappe.ValidationError):  # twice
			mdf_orders.hand_over(card["name"], comment="Ещё раз")
		with self.assertRaises(frappe.ValidationError):  # no reason
			self._as(MANAGER, mdf_orders.return_to_work, card["name"], "")
		# Handed over yesterday: only the owner takes it back.
		frappe.db.set_value("Sales Order", card["name"], "korkem_handed_over_on", add_days(nowdate(), -1))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.return_to_work, card["name"], "Скол на детали")
		card = mdf_orders.return_to_work(card["name"], "Скол на детали")
		self.assertEqual(card["status"], "in_shop")
		self.assertIsNone(card["taken_by"])
		self.assertIsNone(next(s for s in card["stages"] if s["stage"] == "ready")["done_on"])
		self.assertTrue(any("Возвращён в работу: Скол на детали" in h["text"] for h in card["history"]))

	def test_a_material_name_gives_the_thickness(self):
		self.assertEqual(mdf_orders.thickness_of("16 мм ЛМДФ"), 16)
		self.assertEqual(mdf_orders.thickness_of("3 мм ХДФ"), 3)
		self.assertIsNone(mdf_orders.thickness_of("ЛМДФ"))
		self.assertIsNone(mdf_orders.thickness_of(None))

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
