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

	def test_a_film_from_a_makers_catalogue_saves_and_is_ordered_from_him(self):
		"""Owner, 18.11.2026: «MC Group · сиена верде» picked in the catalogue,
		not on our shelf — the order saves, says whom the film comes from, and
		once accepted the film is on «К заказу» by itself."""
		import uuid

		from korkem_manufacturing.services import film_catalog, film_orders, material_stock

		material_stock.add_option("Производитель", "Каталог Тест")
		material_stock.add_supplier("Каталог Тест Поставщик")
		supplier = frappe.db.get_value("Supplier", {"supplier_name": "Каталог Тест Поставщик"}, "name")
		colour = f"Сиена {uuid.uuid4().hex[:6]}"
		item = film_catalog.add("Каталог Тест", colour, supplier=supplier)["item"]
		label = film_catalog.label("Каталог Тест", colour)

		card = self._draft(decor_top=label)  # before: «нет в списке «Цвет плёнки»»
		self.addCleanup(self._drop, card["name"])
		lacking = card["film_to_buy"][label]
		self.assertGreater(lacking["short"], 0)
		self.assertEqual(lacking["from"], "Каталог Тест Поставщик")

		self._as(MANAGER, mdf_orders.accept, card["name"])
		lines = [line for g in self._as(MANAGER, film_orders.wanted)["suppliers"] for line in g["open"]]
		mine = next(line for line in lines if line["item"] == item)
		self.assertTrue(mine["auto"])
		self.assertEqual((mine["supplier"], mine["for_orders"]), (supplier, 1))
		self.assertGreater(mine["metres"], 0)

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
		# Cut by milling, coating and manager; with the period before to compare.
		self.assertTrue(any(m["orders"] >= 1 for m in report["by_milling"]))
		self.assertIn("pvc", [c["key"] for c in report["by_coating"]])
		self.assertTrue(report["by_manager"])
		self.assertLess(report["previous"]["until"], nowdate())
		self.assertIn("total", report["previous"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, mdf_report.report)

	def test_the_report_compares_with_the_period_before(self):
		from datetime import date

		from korkem_manufacturing.services.mdf_report import _previous

		# The month so far: the same days of the month before.
		self.assertEqual(_previous(date(2026, 11, 1), date(2026, 11, 26)), (date(2026, 10, 1), date(2026, 10, 26)))
		# A whole month: the whole month before, however long.
		self.assertEqual(_previous(date(2026, 3, 1), date(2026, 3, 31)), (date(2026, 2, 1), date(2026, 2, 28)))
		self.assertEqual(_previous(date(2026, 3, 1), date(2026, 3, 30)), (date(2026, 2, 1), date(2026, 2, 28)))
		# The year so far: the same days of the year before.
		self.assertEqual(_previous(date(2026, 1, 1), date(2026, 11, 26)), (date(2025, 1, 1), date(2025, 11, 26)))
		# Anything else: as many days just before.
		self.assertEqual(_previous(date(2026, 11, 10), date(2026, 11, 16)), (date(2026, 11, 3), date(2026, 11, 9)))

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

	# --- the team: departments, posts, each stage's people (owner, 17.11.2026) ---

	def _person(self, name, posts):
		from korkem_manufacturing.services import team

		self._as(MANAGER, team.add_person, name, posts)
		return frappe.db.get_value("Employee", {"employee_name": name, "company": COMPANY}, "name",
								   order_by="creation desc")

	def test_the_team_gives_each_stage_its_people_and_a_worker_ticks_his_own(self):
		from korkem_manufacturing.services import my_work, team

		# This test's posts only; the cutter's login is free to be linked.
		frappe.db.sql("update `tabEmployee` set korkem_team_roles = null where company = %s", COMPANY)
		frappe.db.sql("update `tabEmployee` set user_id = null where user_id in %s", [(CUTTER, MANAGER)])

		with self.assertRaises(frappe.PermissionError):  # a shop worker does not hire
			self._as(CUTTER, team.add_person, "Кто-то Новый", ["cut.cutter"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, team.add_person, "Кто-то Новый", ["pvc.boss"])
		cutter = self._person("Ерлан Раскройщиков", ["cut.cutter"])
		cnc = self._person("Асет Фрезеров", ["cnc.operator"])
		sander = self._person("Нурлан Шкурщиков", ["paint.sander", "pvc.sander"])
		press_1 = self._person("Бек Вакуумов", ["pvc.vacuum"])
		press_2 = self._person("Дана Вакуумова", ["pvc.vacuum"])

		listing = self._as(MANAGER, team.people)
		nurlan = next(p for p in listing["people"] if p["employee"] == sander)
		self.assertEqual((nurlan["posts"], nurlan["user"]), (["pvc.sander", "paint.sander"], None))  # both departments
		self.assertEqual([d["key"] for d in listing["departments"]][:3], ["intake", "cut", "cnc"])
		self._as(MANAGER, team.link_user, cutter, CUTTER)
		with self.assertRaises(frappe.ValidationError):  # one login, one person
			self._as(MANAGER, team.link_user, cnc, CUTTER)

		# «Команда» and its people are one list (owner, 17.11.2026): a login
		# is a mark on a person, never a second entry.
		listing = self._as(MANAGER, team.people)["people"]
		self.assertEqual([p["employee"] for p in listing if p["user"] == CUTTER], [cutter])
		self.assertTrue(next(p for p in listing if p["employee"] == cutter)["login"])
		self.assertEqual([p["employee"] for p in listing if p["user"] == MANAGER], [None])  # a login with no person yet
		taker = self._person("Айгерим Приёмова", ["intake.manager"])
		frappe.db.set_value("Employee", taker, "cell_number", "8 701 555 12 34")
		self.assertEqual(team.join(MANAGER, "Айгерим", "+77015551234", COMPANY), taker)  # the invited phone joins her
		listing = self._as(MANAGER, team.people)["people"]
		self.assertEqual([p["employee"] for p in listing if p["user"] == MANAGER], [taker])
		frappe.db.set_value("Employee", taker, "user_id", None)
		self._as(MANAGER, lambda: team.set_person(None, posts=["intake.manager"], user=MANAGER))  # given a post, becomes one
		mine = [p for p in self._as(MANAGER, team.people)["people"] if p["user"] == MANAGER]
		self.assertEqual((len(mine), mine[0]["posts"], bool(mine[0]["employee"])), (1, ["intake.manager"], True))
		frappe.db.set_value("Employee", mine[0]["employee"], {"user_id": None, "status": "Left"})
		self._as(MANAGER, team.set_active, taker, 0)

		# Accepted: a post with one person gets the stage, one with two waits for the manager.
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		card = self._as(MANAGER, mdf_orders.accept, card["name"])
		given = {s["stage"]: s["given_to"] for s in card["stages"]}
		self.assertEqual(given, {"cut": cutter, "mill": cnc, "sand": sander, "vacuum": None, "ready": None})
		pressers = self._as(MANAGER, mdf_orders.stage_people, card["name"], "vacuum")["people"]
		self.assertEqual(sorted(p["employee"] for p in pressers), sorted([press_1, press_2]))
		card = self._as(MANAGER, mdf_orders.assign, card["name"], "vacuum", press_2)
		self.assertEqual(next(s for s in card["stages"] if s["stage"] == "vacuum")["given_to_name"],
						 "Дана Вакуумова")

		# From his phone: his stage, ticked with his name, his m².
		work = self._as(CUTTER, my_work.work)
		self.assertEqual(work["me"]["employee"], cutter)
		self.assertEqual([r["stage"] for r in work["ready"] if r["order"] == card["name"]], ["cut"])
		with self.assertRaises(frappe.PermissionError):  # milling is not his
			self._as(CUTTER, my_work.done, card["name"], "mill")
		before = work["month"]["area_m2"]
		work = self._as(CUTTER, my_work.done, card["name"], "cut")
		self.assertFalse([r for r in work["ready"] if r["order"] == card["name"]])
		self.assertEqual(flt(work["month"]["area_m2"] - before, 2), 3.04)
		self.assertEqual(frappe.db.get_value("Sales Order", card["name"], mdf_orders.STAGE_BY["cut"]), cutter)

		# The CNC operator has no phone: the manager ticks, the stage's person gets it.
		card = self._as(MANAGER, mdf_orders.set_stage, card["name"], "mill")
		self.assertEqual(next(s for s in card["stages"] if s["stage"] == "mill")["worker"], cnc)

		# His own tick, taken back the same day.
		self._as(CUTTER, my_work.done, card["name"], "cut", 1)
		self.assertIsNone(frappe.db.get_value("Sales Order", card["name"], mdf_orders.STAGES["cut"]))
		with self.assertRaises(frappe.PermissionError):  # the manager's tick is not his to take back
			self._as(CUTTER, my_work.done, card["name"], "mill", 1)

		# Left the company: off the list, his work still his.
		self._as(MANAGER, team.set_active, press_1, 0)
		self.assertNotIn(press_1, [p["employee"] for p in self._as(MANAGER, team.people)["people"]])
		left = next(p for p in self._as(MANAGER, team.people, True)["people"] if p["employee"] == press_1)
		self.assertFalse(left["active"])

	# --- the order form's dictionaries (OnayBaza's blue button) ---

	def test_a_dictionary_value_is_added_renamed_with_its_price_and_deleted(self):
		from korkem_manufacturing.services import mdf_dictionaries as dicts

		lists = self._as(MANAGER, dicts.dictionaries)
		self.assertEqual(set(lists), {"material", "thickness", "finish", "decor", "patina", "milling", "edge", "bank", "paint", "paint_system", "maker", "film_type", "film_thickness", "film_width", "transport", "city", "textured_films"})
		# The textured films are named for the form (owner, 26.11.2026).
		self.assertIsInstance(lists["textured_films"], list)
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

	def test_millings_are_groups_with_variants(self):
		from korkem_manufacturing.services import mdf_dictionaries as dicts

		group = f"МДФ Тест Рифленый {frappe.generate_hash(length=4)}"
		lists = self._as(MANAGER, dicts.add, "milling", group)
		self._as(MANAGER, facade_prices.set_price, group, PVC, 18_000)
		# «16-14» under the group is «<group> 16-14», filed under it.
		for variant in ("16-14", "6-11"):
			lists = self._as(MANAGER, dicts.add, "milling", variant, group=group)
		mine = {v["value"]: v for v in lists["milling"] if v["value"].startswith(group)}
		self.assertEqual({v: e["group"] for v, e in mine.items()},
						 {group: None, f"{group} 16-14": group, f"{group} 6-11": group})
		self.assertEqual(facade_prices.price_for(f"{group} 16-14", PVC, COMPANY), 18_000)  # priced as its group

		# The group renamed: its variants follow, price and all.
		renamed = group.replace("Рифленый", "Рифлёный")
		lists = self._as(MANAGER, dicts.rename, "milling", mine[group]["id"], renamed)
		mine = {v["value"]: v for v in lists["milling"] if v["value"].startswith(renamed)}
		self.assertEqual({v: e["group"] for v, e in mine.items()},
						 {renamed: None, f"{renamed} 16-14": renamed, f"{renamed} 6-11": renamed})
		self.assertEqual(facade_prices.price_for(f"{renamed} 6-11", PVC, COMPANY), 18_000)

		# The group deleted: its variants leave the list with it.
		lists = self._as(MANAGER, dicts.remove, "milling", mine[renamed]["id"])
		self.assertFalse([v for v in lists["milling"] if v["value"].startswith(renamed)])

	def test_paints_are_filed_by_colour_system(self):
		from korkem_manufacturing.services import mdf_dictionaries as dicts
		from korkem_manufacturing.services import mdf_paints

		mdf_paints.seed_company(COMPANY)  # once: a second time changes nothing
		lists = self._as(MANAGER, dicts.dictionaries)
		self.assertTrue({"RAL Classic", "NCS", "По образцу"} <= {v["value"] for v in lists["paint_system"]})
		self.assertEqual(mdf_paints.guess_system("RAL 9010"), "RAL Classic")
		self.assertEqual(mdf_paints.guess_system("RAL 110-M"), "RAL Effect")
		self.assertEqual(mdf_paints.guess_system("RAL 210 50 20"), "RAL Design")
		self.assertEqual(mdf_paints.guess_system("NCS S 0502-Y"), "NCS")

		h = frappe.generate_hash(length=4)
		system = f"RAL Тест {h}"
		self._as(MANAGER, dicts.add, "paint_system", system)
		# A bare number under a RAL system is written as RAL does.
		lists = self._as(MANAGER, dicts.add, "paint", f"{h} Белый", group=system)
		paint = next(v for v in lists["paint"] if v["value"] == f"RAL {h} Белый")
		self.assertEqual(paint["group"], system)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, dicts.add, "paint", "x", group=f"Нет такой {h}")

		# The system renamed: its colours are filed under the new name.
		system_id = next(v["id"] for v in lists["paint_system"] if v["value"] == system)
		lists = self._as(MANAGER, dicts.rename, "paint_system", system_id, f"{system} 2")
		self.assertEqual(next(v for v in lists["paint"] if v["id"] == paint["id"])["group"], f"{system} 2")
		# Deleted: the colour stays, filed under none.
		lists = self._as(MANAGER, dicts.remove, "paint_system", system_id)
		self.assertIsNone(next(v for v in lists["paint"] if v["id"] == paint["id"])["group"])

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
		# Kept in one spelling (owner, 18.11.2026): «8 701 …» is +7701….
		self.assertEqual(listed[added["name"]]["phone"], "+7" + phone.replace(" ", "")[1:])

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

	def test_a_customer_s_own_terms_his_price_and_his_debt_limit(self):
		"""«По разному» (owner, 20.11.2026): a discount off the list, or his
		own price a m²; a debt limit of his own over the shop's, an order over
		it accepted only with a reason."""
		from korkem_manufacturing.services import mdf_customers

		listed = self._as(MANAGER, mdf_orders.price, ORDER_1129[:1], finish=PVC)["lines"][0]["rate_m2"]
		self.assertGreater(listed, 0)
		maker = self._as(MANAGER, mdf_customers.add, "МДФ Тест Цех", terms={"discount_pct": 10, "source": "word"})
		self.assertEqual((maker["discount_pct"], maker["source"]), (10, "word"))
		line = self._as(MANAGER, mdf_orders.price, ORDER_1129[:1], finish=PVC, customer=maker["name"])["lines"][0]
		self.assertEqual((line["rate_m2"], line["customer_price"]), (round(listed * 0.9), True))
		# His own price a m² for PVC wins over the discount; a typed one over both.
		self._as(MANAGER, mdf_customers.update, maker["name"], "МДФ Тест Цех", terms={"price_pvc_m2": 12_345})
		line = self._as(MANAGER, mdf_orders.price, ORDER_1129[:1], finish=PVC, customer=maker["name"])["lines"][0]
		self.assertEqual(line["rate_m2"], 12_345)
		typed = [{**ORDER_1129[0], "rate": 15_000}]
		line = self._as(MANAGER, mdf_orders.price, typed, finish=PVC, customer=maker["name"])["lines"][0]
		self.assertEqual((line["rate_m2"], line["customer_price"]), (15_000, False))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_customers.update, maker["name"], "МДФ Тест Цех", terms={"discount_pct": 150})
		# The debt limit: his own, over the shop's.
		self._as(MANAGER, mdf_customers.set_default_debt_limit, 1_000_000)
		self.addCleanup(lambda: frappe.db.set_default(f"korkem_debt_limit:{COMPANY}", 0))
		self._as(MANAGER, mdf_customers.update, maker["name"], "МДФ Тест Цех", terms={"debt_limit": 100})
		card = self._as(MANAGER, mdf_orders.save_draft, customer=maker["name"], delivery_date=add_days(nowdate(), 7),
						head={"finish": PVC, "thickness_mm": 16}, lines=ORDER_1129)
		self.addCleanup(self._drop, card["name"])
		check = self._as(MANAGER, mdf_customers.debt_check, maker["name"], card["total"])
		self.assertEqual((check["limit"], check["over"]), (100, True))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, mdf_orders.accept, card["name"])
		card = self._as(MANAGER, mdf_orders.accept, card["name"], over_limit="Ерлан разрешил, свой цех")
		self.assertEqual(card["status"], "accepted")

	def test_the_customer_list_says_his_last_order_debt_and_what_is_in_work(self):
		"""The order form's customer window (owner, 20.11.2026): before he is
		chosen, what he had last, what he owes, what is in work; found by an
		order number or an object as well."""
		from korkem_manufacturing.services import mdf_customers

		made = self._as(MANAGER, mdf_customers.add, "МДФ Тест Сводка")
		card = self._as(MANAGER, mdf_orders.save_draft, customer=made["name"], delivery_date=add_days(nowdate(), 7),
						head={"finish": PVC, "thickness_mm": 16, "extra_name": "Кухня, Абая 10"},
						lines=ORDER_1129)
		self.addCleanup(self._drop, card["name"])
		card = self._as(MANAGER, mdf_orders.accept, card["name"])
		row = next(c for c in self._as(MANAGER, mdf_customers.customers) if c["name"] == made["name"])
		self.assertEqual((row["orders"], row["in_work"], row["last_order"]), (1, 1, card["name"]))
		self.assertEqual(row["debt"], card["debt"])
		self.assertEqual(row["objects"], ["Кухня, Абая 10"])
		self.assertIn(card["name"], row["order_names"])
		self.assertEqual(sorted(row["last_millings"]), sorted({FLAT, PATTERN}))
		self.assertEqual([g["coating"] for g in row["last_groups"]], ["pvc"])
		# A customer without orders carries no summary at all.
		bare = self._as(MANAGER, mdf_customers.add, "МДФ Тест Без заказов")
		self.addCleanup(lambda: frappe.delete_doc("Customer", bare["name"], force=True, ignore_permissions=True))
		row = next(c for c in self._as(MANAGER, mdf_customers.customers) if c["name"] == bare["name"])
		self.assertNotIn("orders", row)

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

	def test_painted_takes_the_paint_off_the_store_by_the_recipe(self):
		from korkem_manufacturing.services import (
			material_stock,
			mdf_dictionaries,
			mdf_margin,
			mdf_paint,
			paint_recipe,
			paint_stock,
		)

		# The store is kept by whoever buys (material_stock's editors); the
		# write-off happens for whoever ticks «Покрашено».
		BUYER = "Administrator"
		colour = f"RAL {frappe.generate_hash(length=4)} Тест"
		self._as(MANAGER, mdf_dictionaries.add, "paint", colour)
		supplier_name = f"МДФ Тест Краски {frappe.generate_hash(length=4)}"
		self._as("Administrator", paint_stock.add_supplier, supplier_name)
		supplier = frappe.db.get_value("Supplier", {"supplier_name": supplier_name}, "name")
		# The shop's recipe (owner, 15.11.2026): a coat of primer, two of
		# enamel, a hardener in both; no lacquer.
		hardener = f"Отвердитель {frappe.generate_hash(length=4)}"
		primer = f"Грунт {frappe.generate_hash(length=4)}"
		recipe = {"layers": [
			{"name": primer, "g_m2": 100, "coats": 1, "parts": [{"name": hardener, "per_kg": 0.5}]},
			{"name": "Эмаль", "colour": True, "g_m2": 150, "coats": 2, "parts": [{"name": hardener, "per_kg": 0.5}]},
			{"name": "Лак", "g_m2": 100, "coats": 0},
		]}
		with self.assertRaises(frappe.ValidationError):
			self._as(BUYER, paint_stock.set_recipe, {"layers": [{"name": "А", "colour": 1}, {"name": "Б", "colour": 1}]})
		with self.assertRaises(frappe.ValidationError):
			self._as(BUYER, paint_stock.set_recipe, {"layers": [{"name": "А", "g_m2": -1}]})
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, paint_stock.set_recipe, recipe)
		got = self._as(BUYER, paint_stock.set_recipe, recipe)
		# 0,1 × 1,5 + 0,3 × 1,5 kg a m², every material together.
		self.assertAlmostEqual(got["kg_per_m2"], 0.6, places=3)
		got = self._as(BUYER, paint_stock.receive, colour, 10, 4000, supplier, base="Эмаль", note="2 × 5 кг")
		item = next(p["item"] for p in got["paints"] if p["colour"] == colour)
		# How it came last time, for this time's cans; the invoice's photo
		# kept with the receipt (owner, 20.11.2026).
		self.assertEqual(next(p for p in got["paints"] if p["item"] == item)["last"]["note"], "2 × 5 кг")
		import base64

		png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
		photo = self._as(BUYER, paint_stock.attach_photo, got["receipt"], "накладная.png", png)
		self.assertEqual(self._as(BUYER, paint_stock.history, item)["receipts"][0]["photo"], photo["file"])
		with self.assertRaises(frappe.ValidationError):
			self._as(BUYER, paint_stock.attach_photo, got["receipt"], "накладная.exe", b"MZ")
		# Primer and hardener come with no colour, whatever was picked.
		got = self._as(BUYER, paint_stock.receive, colour, 5, 2000, supplier, base=primer)
		primer_item = next(p["item"] for p in got["paints"] if p["base"] == primer)
		self.assertIsNone(next(p for p in got["paints"] if p["item"] == primer_item)["colour"])
		got = self._as(BUYER, paint_stock.receive, "", 5, 3000, supplier, base=hardener)
		hardener_item = next(p["item"] for p in got["paints"] if p["base"] == hardener)

		def on_hand(of: str = item) -> float:
			return next(p["on_hand_kg"] for p in self._as(BUYER, paint_stock.stock)["paints"] if p["item"] == of)

		# A gloss is the paint shop's mark: its own batch, the same paint.
		lines = [{**ORDER_1129[1], "coating": "paint", "film": colour, "rate": 24_000, "gloss": "gloss"}]  # 1,63 m²
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
						head={"thickness_mm": 16}, lines=lines)
		self.assertEqual(card["lines"][0]["gloss"], "gloss")
		with self.assertRaises(frappe.ValidationError):
			mdf_orders.price([{**lines[0], "gloss": "шершавая"}], finish=None, company=COMPANY)
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		# The queue knows what it needs: the enamel by its colour, 1,63 × 0,3;
		# the primer and the hardener for the queue as a whole.
		board = self._as(BUYER, paint_stock.stock)
		need = next(n for n in board["queue"] if n["colour"] == f"{colour} · глянец")
		self.assertAlmostEqual(need["need_kg"], 0.49, places=2)
		names = {m["name"] for m in board["materials"]}
		self.assertTrue({primer, hardener} <= names)
		# A plan: each material, its kilograms and price; the total and a m².
		plan = self._as(BUYER, paint_recipe.plan, 1.63, colour)
		kg = {line["name"]: line["kg"] for line in plan["lines"]}
		self.assertEqual(kg, {primer: 0.16, hardener: 0.33, "Эмаль": 0.49})
		self.assertAlmostEqual(plan["cost"], 0.16 * 2000 + 0.33 * 3000 + 0.49 * 4000, places=0)
		self.assertTrue(plan["priced"])
		self.assertIn("Эмаль 0,49 кг", paint_recipe.request_text(1.63, colour))
		# The order's card says it too, by its colour, ready to send.
		paint = self._as(MANAGER, mdf_orders.card, card["name"])["paint"]
		self.assertEqual([p["colour"] for p in paint], [f"{colour} · глянец"])
		self.assertIn("Эмаль 0,49 кг", paint[0]["text"])
		# The margin counts the paint now: by the recipe until it is taken.
		margin = self._as(MANAGER, mdf_margin.of_order, card["name"])
		rows = {r["title"]: r for r in margin["material_rows"]}
		self.assertAlmostEqual(rows[f"Эмаль · {colour}"]["cost"], 0.49 * 4000, places=0)
		self.assertIn(primer, rows)
		before = {i: on_hand(i) for i in (item, primer_item, hardener_item)}
		for stage in ("cut", "mill", "sand"):
			self._as(MANAGER, mdf_orders.set_stage, card["name"], stage)
		# At the paint: the painter is told the norm — 0,49 kg of a 10 kg
		# batch; the rest stays on the shelf (owner, 15.11.2026).
		group = next(g for g in self._as(MANAGER, mdf_paint.board)["by_colour"]
					 if g["colour"] == f"{colour} · глянец")
		self.assertEqual((group["norm"]["enamel_kg"], group["norm"]["batch_kg"]), (0.49, 10))
		self.assertAlmostEqual(group["norm"]["left_kg"], before[item] - 0.49, places=2)
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "paint")
		# «Покрашено»: each material off its shelf; ticked twice, taken once.
		self.assertAlmostEqual(on_hand(), before[item] - 0.49, places=3)
		self.assertAlmostEqual(on_hand(primer_item), before[primer_item] - 0.16, places=3)
		self.assertAlmostEqual(on_hand(hardener_item), before[hardener_item] - 0.33, places=3)
		# … and what was taken, once taken.
		margin = self._as(MANAGER, mdf_margin.of_order, card["name"])
		taken = {r["item"]: r for r in margin["material_rows"] if r["item"]}
		self.assertAlmostEqual(taken[item]["cost"], 0.49 * 4000, places=0)
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "paint")
		self.assertAlmostEqual(on_hand(), before[item] - 0.49, places=3)
		usage = self._as(BUYER, paint_stock.stock)["usage"]
		self.assertGreaterEqual(usage["m2"], 1.63)
		# Unticked: put back.
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "paint", 0)
		self.assertAlmostEqual(on_hand(), before[item], places=3)
		self.assertAlmostEqual(on_hand(hardener_item), before[hardener_item], places=3)

		# The painter weighs 9 kg: a kilo is found missing, and counts as used.
		after = self._as(BUYER, paint_stock.count, item, "9")
		self.assertEqual(next(p["on_hand_kg"] for p in after["paints"] if p["item"] == item), 9)
		self.assertGreaterEqual(after["usage"]["kg_counted"], 1)
		# A price written in the recipe is the price (owner: «цены — в
		# настройках»); the shop's price a m² and markup come back with a plan.
		priced = {**recipe, "price_m2": 9000, "markup_pct": 40}
		priced["layers"] = [{**recipe["layers"][0], "price_kg": 2500}, *recipe["layers"][1:]]
		self._as(BUYER, paint_stock.set_recipe, priced)
		plan = self._as(BUYER, paint_recipe.plan, 1.63, colour)
		line = next(line for line in plan["lines"] if line["name"] == primer)
		self.assertEqual((line["price_kg"], plan["price_m2"], plan["markup_pct"]), (2500, 9000, 40))
		self._as(BUYER, paint_stock.set_recipe, paint_recipe.DEFAULT)

	def test_vacuum_takes_the_glue_off_the_store_by_its_positions(self):
		from korkem_manufacturing.services import glue_stock, material_stock, mdf_margin

		# Owner, 17.11.2026: glue is bought in Almaty, Astana, Semey from
		# companies that may sell film too; one barrel, glue and hardener
		# together; sold on by the bucket and the litre with a mark-up.
		BUYER = "Administrator"
		tag = frappe.generate_hash(length=4)
		supplier_name = f"МДФ Тест Клей {tag}"
		frappe.set_user("Administrator")
		material_stock.add_supplier(supplier_name)  # known already — sells film
		got = self._as(BUYER, glue_stock.add_supplier, supplier_name, city="Алматы")
		self.assertEqual(frappe.db.count("Supplier", {"supplier_name": supplier_name}), 1)  # one company, one supplier
		supplier = frappe.db.get_value("Supplier", {"supplier_name": supplier_name}, "name")
		self.assertEqual(next(s for s in got["suppliers"] if s["supplier"] == supplier)["city"], "Алматы")
		frappe.set_user("Administrator")
		material_stock.add_supplier(f"МДФ Тест Не клей {tag}")
		stranger = frappe.db.get_value("Supplier", {"supplier_name": f"МДФ Тест Не клей {tag}"}, "name")

		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, glue_stock.add_glue, f"Клей {tag}")
		with self.assertRaises(frappe.ValidationError):
			self._as(BUYER, glue_stock.add_glue, f"Клей {tag} густой", kg_per_litre=5)
		got = self._as(BUYER, glue_stock.add_glue, f"Клей {tag}", origin="Китай", bucket_kg=20, kg_per_litre="1,04",
					   norm_g_m2=100, markup_bucket=20, markup_litre=50)
		item = next(g["item"] for g in got["glues"] if g["title"] == f"Клей {tag}")
		self._as(BUYER, glue_stock.set_in_work, item)
		with self.assertRaises(frappe.ValidationError):  # not a glue supplier
			self._as(BUYER, glue_stock.receive, item, 1, "ведро", 40_000, "ведро", stranger)
		# Two buckets at 40 000 a bucket — 2 000 a kilo — brought for 4 000:
		# 2 100 a kilo landed, 210 a m² at 100 g/m².
		got = self._as(BUYER, glue_stock.receive, item, 2, "ведро", 40_000, "ведро", supplier,
					   delivery={"amount": 4000})
		glue = next(g for g in got["glues"] if g["item"] == item)
		self.assertEqual(glue["on_hand_kg"], 40)
		self.assertTrue(glue["in_work"])
		self.assertAlmostEqual(glue["cost_kg"], 2100, places=0)
		self.assertAlmostEqual(glue["cost_m2"], 210, places=0)
		self.assertEqual(glue["sell"], {"bucket": round(2100 * 20 * 1.2), "litre": round(2100 * 1.04 * 1.5)})
		bought = next(s for s in got["suppliers"] if s["supplier"] == supplier)["bought"]
		self.assertAlmostEqual(bought[0]["landed_kg"], 2100, places=0)
		# Ten litres at 2 080 a litre: 10,4 kg at 2 000 a kilo.
		got = self._as(BUYER, glue_stock.receive, item, 10, "л", 2080, "л", supplier)
		self.assertAlmostEqual(next(g for g in got["glues"] if g["item"] == item)["on_hand_kg"], 50.4, places=2)

		def on_hand() -> float:
			return next(g["on_hand_kg"] for g in self._as(BUYER, glue_stock.stock)["glues"] if g["item"] == item)

		# 1577×517 ×2, 16 mm: face 1,63 m², edges 2·(1,577+0,517)·0,016·2 =
		# 0,134 m² twice — (1,63 + 0,268) × 0,1 = 0,19 kg.
		lines = [{**ORDER_1129[1], "coating": "pvc", "film": self.decor, "rate": 17_000}]
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 7),
						head={"thickness_mm": 16}, lines=lines)
		self.addCleanup(self._drop, card["name"])
		self._as(MANAGER, mdf_orders.accept, card["name"])
		glue = self._as(MANAGER, mdf_orders.card, card["name"])["glue"]
		self.assertAlmostEqual(glue["kg"], 0.19, places=2)
		self.assertEqual((glue["item"], len(glue["lines"])), (item, 1))
		# A patterned milling takes half as much again: (2,445 + 0,268) × 0,1.
		frappe.set_user("Administrator")
		material_stock.put_option(glue_stock.MILLING_LIST, PATTERN)
		self._as(BUYER, glue_stock.set_milling, {PATTERN: "1,5"})
		self.assertAlmostEqual(self._as(MANAGER, mdf_orders.card, card["name"])["glue"]["kg"], 0.27, places=2)
		self.assertGreaterEqual(self._as(BUYER, glue_stock.stock)["queue"]["kg"], 0.27)
		# The margin counts it: by the positions until it is taken.
		rows = {r["title"]: r for r in self._as(MANAGER, mdf_margin.of_order, card["name"])["material_rows"]}
		self.assertAlmostEqual(rows[f"Клей {tag}"]["qty"], 0.27, places=2)
		before = on_hand()
		for stage in ("cut", "mill", "sand"):
			self._as(MANAGER, mdf_orders.set_stage, card["name"], stage)
		self.assertAlmostEqual(on_hand(), before, places=3)
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "vacuum")
		self.assertAlmostEqual(on_hand(), before - 0.27, places=3)
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "vacuum")  # ticked twice, taken once
		self.assertAlmostEqual(on_hand(), before - 0.27, places=3)
		taken = {r["item"]: r for r in self._as(MANAGER, mdf_margin.of_order, card["name"])["material_rows"]
				 if r["item"]}
		self.assertAlmostEqual(taken[item]["qty"], 0.27, places=3)
		month = self._as(BUYER, glue_stock.stock)["usage"]["glues"][item]
		self.assertGreaterEqual(month["m2"], 1.63)
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "vacuum", 0)  # unticked: put back
		self.assertAlmostEqual(on_hand(), before, places=3)
		# The storekeeper weighs 50 kg: 0,4 kg found missing, counted as used.
		after = self._as(BUYER, glue_stock.count, item, "50")
		self.assertEqual(next(g["on_hand_kg"] for g in after["glues"] if g["item"] == item), 50)
		self.assertGreater(after["usage"]["glues"][item]["kg_counted"], 0.3)
		# The month's reconciliation: the count makes the fact, and what the
		# difference cost (owner: «сверка за месяц»).
		# Weighed, but nothing glued in the month: no fact to show.
		month = self._as(BUYER, glue_stock.reconcile)
		row = next(r for r in month["glues"] if r["item"] == item)
		self.assertGreaterEqual(row["counts"], 1)
		self.assertEqual((row["fact_g_m2"], row["deviation_pct"]), (None, None))
		self.assertGreater(row["money_counted"], 0)
		self.assertEqual(month["month"], nowdate()[:7])
		# The order glued again: the norm's kilograms and the missing ones
		# over its m² — more than the norm, and a dearer m².
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "vacuum")
		row = next(r for r in self._as(BUYER, glue_stock.reconcile)["glues"] if r["item"] == item)
		self.assertGreaterEqual(row["m2"], 1.63)
		self.assertAlmostEqual(row["fact_g_m2"], (row["kg_by_norm"] + row["kg_counted"]) * 1000 / row["m2"], delta=2)
		self.assertGreater(row["deviation_pct"], 0)
		self.assertGreater(row["cost_m2_fact"], row["cost_m2_norm"])
		self._as(MANAGER, mdf_orders.set_stage, card["name"], "vacuum", 0)
		self.assertAlmostEqual(on_hand(), 50, places=3)
		earlier = self._as(BUYER, glue_stock.reconcile, "2001-01")
		self.assertEqual((earlier["glues"], earlier["to"]), ([], "2001-01-31"))
		for wrong in ("2026-13", "2999-01", "ноябрь"):
			with self.assertRaises(frappe.ValidationError):
				self._as(BUYER, glue_stock.reconcile, wrong)

		# Sold on with the film (owner: «ведром и литром», with a mark-up): a
		# bucket at a typed price, the store gives 20 kg.
		from korkem_manufacturing.services import film_dept

		sale = self._as(BUYER, film_dept.sell, self.customer,
						[{"item": item, "units": 1, "unit": "ведро", "price_unit": 52_000}],
						paid=52_000, method="Наличные")
		line = sale["lines"][0]
		self.assertEqual((line["unit"], line["units"], line["unit_price"]), ("ведро", 1, 52_000))
		self.assertEqual(sale["amount"], 52_000)
		self.assertAlmostEqual(on_hand(), 30, places=3)
		# Litres at the glue's own litre price; the shop's 25 kg kept back is
		# not sold without saying so.
		self._as(BUYER, glue_stock.set_glue, item, reserve_kg=25)
		with self.assertRaises(frappe.ValidationError):
			self._as(BUYER, film_dept.sell, self.customer, [{"item": item, "units": 6, "unit": "л"}])
		sale = self._as(BUYER, film_dept.sell, self.customer, [{"item": item, "units": 6, "unit": "л"}],
						glue_reserve_ok=1)
		self.assertEqual(sale["lines"][0]["unit"], "л")
		self.assertGreater(sale["lines"][0]["unit_price"], 0)
		self.assertAlmostEqual(on_hand(), 30 - 6 * 1.04, places=2)
		with self.assertRaises(frappe.ValidationError):  # a glue is sold by the bucket or the litre
			self._as(BUYER, film_dept.sell, self.customer, [{"item": item, "units": 1, "unit": "кг"}],
					 glue_reserve_ok=1)

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

	def test_the_list_says_where_each_order_is_and_the_overview_counts_what_burns(self):
		before = self._as(MANAGER, mdf_orders.overview)
		card = self._draft()
		self.addCleanup(self._drop, card["name"])
		name = card["name"]
		self._as(MANAGER, mdf_orders.accept, name)
		self._as(MANAGER, mdf_orders.set_stage, name, "cut")

		def row():
			return next(o for o in self._as(MANAGER, mdf_orders.listing, search=name)["orders"] if o["name"] == name)

		r = row()
		self.assertEqual([(s["stage"], s["done"]) for s in r["stages"]],
						 [("cut", True), ("mill", False), ("sand", False), ("vacuum", False), ("ready", False)])
		# Whom each stage is given to: the row's bar asks who did one given to nobody.
		self.assertTrue(all("given" in s for s in r["stages"]))
		self.assertEqual((r["waiting"], r["days_left"], r["ready_days"]), ("mill", 7, None))
		# Its debt is in the overview; made late, it is counted as late, and found by «сдать скоро» no more.
		after = self._as(MANAGER, mdf_orders.overview)
		self.assertAlmostEqual(after["debt"] - before["debt"], 58_680, places=0)
		frappe.db.set_value("Sales Order", name, "delivery_date", add_days(nowdate(), 1), update_modified=False)
		self.assertEqual(self._as(MANAGER, mdf_orders.overview)["due_soon"], before["due_soon"] + 1)
		self.assertIn(name, [o["name"] for o in self._as(MANAGER, mdf_orders.listing, due_soon=1, limit=200)["orders"]])
		frappe.db.set_value("Sales Order", name, "delivery_date", add_days(nowdate(), -2), update_modified=False)
		self.assertEqual(self._as(MANAGER, mdf_orders.overview)["overdue"], before["overdue"] + 1)
		self.assertEqual(row()["days_left"], -2)
		# Ready and waiting for its customer.
		for stage in ("mill", "sand", "vacuum", "ready"):
			self._as(MANAGER, mdf_orders.set_stage, name, stage)
		self.assertEqual(self._as(MANAGER, mdf_orders.overview)["ready"], before["ready"] + 1)
		self.assertEqual((row()["waiting"], row()["ready_days"]), (None, 0))

	def test_the_overview_names_the_stage_the_late_orders_wait_at(self):
		# Owner, 26.11.2026: 22 overdue, nearly all «сейчас: Раскрой» — say the
		# cause, not 22 rows.
		def order(name, days, done=()):
			return frappe._dict(
				name=name, docstatus=1, delivery_date=add_days(nowdate(), days), korkem_ready_on=None,
				korkem_handed_over_on=None, korkem_hold_reason=None, korkem_finish=PVC, korkem_extra_stages=None,
				korkem_coatings=None, korkem_tags=None,
				**{field: (nowdate() if stage in done else None) for stage, field in mdf_orders.STAGES.items()},
			)

		rows = [order(f"BN-{i}", -3) for i in range(4)] + [order("BN-mill", -1, done=("cut",)),
														   order("BN-new", 5)]
		found = mdf_orders.bottleneck(rows)
		self.assertEqual((found["stage"], found["late"], found["late_total"], found["queue_orders"]), ("cut", 4, 5, 5))
		# Lateness spread over the stages has no one cause.
		spread = [order("BN-a", -2), order("BN-b", -2, done=("cut",)), order("BN-c", -2, done=("cut", "mill")),
				  order("BN-d", -2, done=("cut", "mill", "sand"))]
		self.assertIsNone(mdf_orders.bottleneck(spread))
		self.assertIn("bottleneck", self._as(MANAGER, mdf_orders.overview))

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
		self.assertEqual((card["taken_by"], card["taken_phone"]), ("Ерлан, водитель", "+77011234567"))
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
