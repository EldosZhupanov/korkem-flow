# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The film department: metres in, metres out — sold, to the shop, written off."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_manufacturing.services import film_catalog, film_dept as service
from korkem_manufacturing.services import material_stock, price_visibility

COMPANY = "KORKEM"
MANAGER = "filmdept.manager@example.com"
CUTTER = "filmdept.cutter@example.com"
SUPPLIER = "Film Dept Test Supplier"
BUYER = "Film Dept Test Buyer"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestFilmDept(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(MANAGER, "Sales Manager")
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		frappe.set_user("Administrator")
		price_visibility.set_floor_sees_prices(False)
		material_stock.add_option("Производитель", "KIRA")
		material_stock.add_supplier(SUPPLIER)
		self.supplier = frappe.db.get_value("Supplier", {"supplier_name": SUPPLIER}, "name")
		if not frappe.db.exists("Customer", {"customer_name": BUYER}):
			frappe.get_doc({"doctype": "Customer", "customer_name": BUYER, "customer_type": "Company"}).insert(
				ignore_permissions=True
			)
		self.buyer = frappe.db.get_value("Customer", {"customer_name": BUYER}, "name")
		frappe.db.set_value("Customer", self.buyer, {"korkem_film_tier": None, "korkem_film_discount": 0})
		# A film of its own for each test, so one test's metres are not another's.
		self.film = self._as(MANAGER, film_catalog.add, "KIRA", f"Тест {frappe.generate_hash(length=6)}")["item"]
		self._as(MANAGER, film_catalog.set_card, self.film, retail_m=3900, wholesale_m=3400)
		self._as(MANAGER, service.receive, self.film, 50, 3200, self.supplier)

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _free(self) -> float:
		row = next(f for f in self._as(MANAGER, service.stock)["films"] if f["item"] == self.film)
		return row["free"]

	def test_a_receipt_is_metres_on_the_shelf(self):
		self.assertEqual(self._free(), 50)
		first = self._as(MANAGER, service.history, self.film)[-1]
		self.assertEqual((first["kind"], first["metres"], first["price_m"]), ("receipt", 50, 3200))

	def test_a_sale_takes_metres_and_records_what_was_charged(self):
		sale = self._as(
			MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 12}], paid=20000, method="Наличные",
		)
		# Over the counter, no discount: 12 m × 3 900.
		self.assertEqual((sale["kind"], sale["amount"], sale["paid"], sale["debt"]), ("sale", 46800, 20000, 26800))
		self.assertEqual(sale["lines"][0]["price_m"], 3900)
		self.assertEqual(self._free(), 38)
		# A facade customer who buys film is a film customer from then on.
		row = next(c for c in self._as(MANAGER, service.customers) if c["customer"] == self.buyer)
		self.assertGreaterEqual(row["month_m"], 12)
		self.assertGreaterEqual(row["debt"], 26800)
		self.assertFalse(row["asleep"])
		# The debt is paid off, and no more than is owed.
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.pay, sale["entry"], 30000, "Наличные")
		paid = self._as(MANAGER, service.pay, sale["entry"], 26800, "Перевод", "Kaspi")
		self.assertEqual((paid["debt"], paid["method"], paid["bank"]), (0, "Перевод", "Kaspi"))

	def test_a_receipt_updates_the_purchase_price_unless_told_not_to(self):
		card = film_catalog.film(self.film)
		self.assertEqual(card["price_m"], 3200)
		self.assertEqual(card["price_since"]["price_m"]["via"], "приход")
		self._as(MANAGER, service.receive, self.film, 10, 3400, self.supplier)
		self.assertEqual(film_catalog.film(self.film)["price_m"], 3400)
		# A one-off discount leaves the card as it was.
		self._as(MANAGER, service.receive, self.film, 10, 2900, self.supplier, update_price="0")
		self.assertEqual(film_catalog.film(self.film)["price_m"], 3400)
		log = self._as(MANAGER, film_catalog.changes, self.film)
		self.assertIn(("цена поставщика", "3200", "3400", "приход"), {(c["what"], c["before"], c["after"], c["via"]) for c in log})

	def test_a_price_typed_at_a_sale_is_remembered_where_the_card_had_none(self):
		bare = self._as(MANAGER, film_catalog.add, "KIRA", f"Без Цены {frappe.generate_hash(length=6)}")["item"]
		self._as(MANAGER, service.receive, bare, 20, 3000, self.supplier)
		self.assertIsNone(film_catalog.film(bare)["retail_m"])
		self._as(MANAGER, service.sell, self.buyer, [{"item": bare, "metres": 2, "price_m": 4200, "remember": True}],
				 paid=8400, method="Наличные")
		card = film_catalog.film(bare)
		self.assertEqual((card["retail_m"], card["price_since"]["retail_m"]["via"]), (4200, "продажа"))
		# A price the card already has is not overwritten by a sale.
		self._as(MANAGER, service.sell, self.buyer, [{"item": bare, "metres": 1, "price_m": 3900, "remember": True}],
				 paid=3900, method="Наличные")
		self.assertEqual(film_catalog.film(bare)["retail_m"], 4200)

	def test_a_sale_is_paid_several_ways_at_once_and_the_rest_is_a_debt(self):
		sale = self._as(
			MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 10}],
			payments=[
				{"amount": 10000, "method": "Наличные"},
				{"amount": 15000, "method": "Перевод", "bank": "Kaspi"},
				{"amount": 5000, "method": "Карта", "bank": "Halyk"},
			],
		)
		# 10 m × 3 900 = 39 000; 30 000 paid three ways, 9 000 owed.
		self.assertEqual((sale["amount"], sale["paid"], sale["debt"]), (39000, 30000, 9000))
		self.assertEqual(
			[(p["amount"], p["method"], p["bank"]) for p in sale["payments"]],
			[(10000, "Наличные", None), (15000, "Перевод", "Kaspi"), (5000, "Карта", "Halyk")],
		)
		# More than the sum is refused, however it is split.
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 1}],
					 payments=[{"amount": 3000, "method": "Наличные"}, {"amount": 1000, "method": "Карта"}])
		# The debt is paid off in parts too; every payment is kept.
		paid = self._as(MANAGER, service.pay, sale["entry"],
						payments=[{"amount": 4000, "method": "Наличные"}, {"amount": 5000, "method": "Перевод"}])
		self.assertEqual((paid["paid"], paid["debt"], len(paid["payments"])), (39000, 0, 5))

	def test_a_movement_entered_wrong_is_made_again_right_and_the_wrong_one_struck(self):
		# The receipt of 50 was really 45, at 3 100.
		first = self._as(MANAGER, service.history, self.film)[-1]
		fixed = self._as(MANAGER, service.correct, first["entry"], self.film, "ошибся в метраже",
						 metres=45, price_m=3100)
		self.assertEqual(self._free(), 45)
		log = self._as(MANAGER, service.history, self.film)
		new = next(m for m in log if m["entry"] == fixed["entry"])
		old = next(m for m in log if m["entry"] == first["entry"])
		self.assertEqual((new["metres"], new["price_m"], new["struck"]), (45, 3100, False))
		self.assertEqual(new["fix"]["reason"], "ошибся в метраже")
		self.assertTrue(old["struck"])
		# A sale: fewer metres, the payment carried over.
		sale = self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 12}],
						payments=[{"amount": 20000, "method": "Наличные"}])
		again = self._as(MANAGER, service.correct, sale["entry"], self.film, "не те метры", metres=10)
		moved = self._as(MANAGER, service.movement, again["entry"])
		self.assertEqual((moved["amount"], moved["paid"], moved["debt"]), (39000, 20000, 19000))
		self.assertEqual(self._free(), 35)
		# A reason is a must; a struck movement is not corrected twice.
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.correct, again["entry"], self.film, "", metres=9)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.correct, sale["entry"], self.film, "ещё раз", metres=9)
		# A write-off: other metres, other words.
		off = self._as(MANAGER, service.write_off, self.film, 2, "брак при резке")
		redo = self._as(MANAGER, service.correct, off["entry"], self.film, "был 1 метр", metres=1,
						why="брак, край")
		self.assertEqual(self._as(MANAGER, service.movement, redo["entry"])["reason"], "брак, край")
		self.assertEqual(self._free(), 34)

	def test_a_receipt_says_how_it_came_and_who_took_it_in(self):
		got = self._as(MANAGER, service.receive, self.film, 10, 3200, self.supplier,
					   delivery={"transport": "Такси", "from_city": "Алматы", "amount": 5000})
		row = next(m for m in self._as(MANAGER, service.history, self.film) if m["entry"] == got["receipt"])
		self.assertEqual((row["delivery"]["transport"], row["delivery"]["city"], row["delivery"]["cost"]),
						 ("Такси", "Алматы", 5000))
		self.assertEqual(row["delivery"]["per_m"], 500)
		self.assertTrue(frappe.db.exists("Logistics Delivery", {"receipt": got["receipt"], "amount": 5000}))
		# Nothing said: as the last roll of this supplier came, free, taken in by whoever entered it.
		plain = self._as(MANAGER, service.receive, self.film, 5, 3200, self.supplier)
		head = frappe.db.get_value("Stock Entry", plain["receipt"],
								   ["korkem_delivery_transport", "korkem_delivery_cost", "korkem_received_by"],
								   as_dict=True)
		self.assertEqual((head.korkem_delivery_transport, flt(head.korkem_delivery_cost), head.korkem_received_by),
						 ("Такси", 0, MANAGER))
		options = self._as(MANAGER, service.delivery_options)
		self.assertIn("Такси", options["transports"])
		self.assertIn("Привёз поставщик", options["transports"])

	def test_a_film_that_ran_low_says_what_to_order(self):
		def row() -> dict:
			return next(f for f in self._as(MANAGER, service.stock)["films"] if f["item"] == self.film)

		self.assertIsNone(row()["reorder"])
		material_stock.set_min_stock(self.film, 60)
		# 50 m left, the minimum 60: as much as last time, from the same place.
		order = row()["reorder"]
		self.assertEqual((order["metres"], order["supplier"], order["price_m"]), (50, self.supplier, 3200))
		# Ordered: on its way, enough — nothing more is asked.
		self._as(MANAGER, service.receive, self.film, order["metres"], order["price_m"], order["supplier"],
				 arrives_on=add_days(nowdate(), 2))
		self.assertIsNone(row()["reorder"])

	def test_a_roll_on_its_way_is_not_on_the_shelf_until_it_comes(self):
		def row() -> dict:
			return next(f for f in self._as(MANAGER, service.stock)["films"] if f["item"] == self.film)

		got = self._as(MANAGER, service.receive, self.film, 30, 3200, self.supplier,
					   arrives_on=add_days(nowdate(), 2), delivery={"amount": 6000})
		# Bought, on its way: shown as coming, not free, not in the history.
		self.assertEqual(self._free(), 50)
		coming = row()["coming"]
		self.assertEqual([(c["entry"], c["metres"], c["late_days"]) for c in coming], [(got["receipt"], 30, 0)])
		self.assertNotIn(got["receipt"], [m["entry"] for m in self._as(MANAGER, service.history, self.film)])
		# The supplier is late: another day; a day gone by is refused.
		self._as(MANAGER, service.reschedule, got["receipt"], add_days(nowdate(), 5))
		self.assertEqual(row()["coming"][0]["due"], str(add_days(nowdate(), 5)))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.reschedule, got["receipt"], add_days(nowdate(), -1))
		# It came, 28 m of the 30: on the shelf today.
		self._as(MANAGER, service.arrived, got["receipt"], metres=28)
		self.assertEqual(self._free(), 78)
		self.assertEqual(row()["coming"], [])
		self.assertEqual(frappe.db.get_value("Stock Entry", got["receipt"], "posting_date"), getdate(nowdate()))
		with self.assertRaises(frappe.DoesNotExistError):
			self._as(MANAGER, service.arrived, got["receipt"])
		# One that will not come is struck off with why; the floor may do none of it.
		other = self._as(MANAGER, service.receive, self.film, 10, 3200, self.supplier,
						 arrives_on=add_days(nowdate(), 1))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.drop_coming, other["receipt"], " ")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.arrived, other["receipt"])
		self._as(MANAGER, service.drop_coming, other["receipt"], "поставщик отказал")
		self.assertEqual(row()["coming"], [])
		self.assertEqual(self._free(), 78)

	def test_the_film_cash_book_keeps_the_departments_own_money(self):
		from korkem_manufacturing.services import film_cash

		def got(**delivery) -> str:
			return self._as(MANAGER, service.receive, self.film, 10, 3200, self.supplier, delivery=delivery)["receipt"]

		by_cash = got(transport="Такси", amount=5000)
		by_me = got(transport="Такси", amount=3000, payer="employee", paid_by=MANAGER)
		owed = got(transport="КАМАЗ", amount=2000, payer="unpaid", driver="Ерлан", phone="+7 701 555 12 34")
		free = got(transport="Привёз поставщик", amount=900, payer="supplier")
		with self.assertRaises(frappe.ValidationError):
			got(amount=100, payer="кто-то")
		self.assertEqual(flt(frappe.db.get_value("Stock Entry", free, "korkem_delivery_cost")), 0)
		before_in = self._as(MANAGER, film_cash.book)["in_total"]
		self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 2, "price_m": 4000}],
				 payments=[{"amount": 8000, "method": "Наличные"}])
		book = self._as(MANAGER, film_cash.book)
		self.assertEqual(book["in_total"] - before_in, 8000)
		# Out of the department's cash: only what the cash paid.
		self.assertEqual([o["amount"] for o in book["out"] if o["receipt"] in (by_cash, by_me, owed, free)], [5000])
		self.assertIn(by_me, [e["receipt"] for e in book["owed"]["employees"]])
		carrier = next(c for c in book["owed"]["carriers"] if c["receipt"] == owed)
		self.assertEqual((carrier["driver"], carrier["phone"]), ("Ерлан", "+7 701 555 12 34"))
		self.assertIn({"driver": "Ерлан", "phone": "+7 701 555 12 34", "transport": "КАМАЗ"},
					  self._as(MANAGER, service.delivery_options)["drivers"])
		# Given back: out of the cash today, off the list; twice is refused.
		self._as(MANAGER, film_cash.settle, by_me, "Перевод")
		book = self._as(MANAGER, film_cash.book)
		self.assertEqual(sorted(o["amount"] for o in book["out"] if o["receipt"] in (by_cash, by_me)), [3000, 5000])
		self.assertNotIn(by_me, [e["receipt"] for e in book["owed"]["employees"]])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, film_cash.settle, by_me)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, film_cash.book)
		row = next(m for m in self._as(MANAGER, service.history, self.film) if m["entry"] == by_me)
		self.assertEqual((row["delivery"]["payer"], row["delivery"]["settled"]), ("employee", True))

	def test_the_team_month_counts_the_paid_margin_by_seller(self):
		from korkem_manufacturing.services import film_team

		film_team.set_settings(plan_m=1, pct=10, pct_below=5)

		def mine_now() -> dict:
			rows = [r for r in film_team.team()["rows"] if r["seller"] == MANAGER]
			return rows[0] if rows else {"metres": 0.0, "margin": 0.0}

		# Other tests sell this month too: count what this sale adds.
		before = mine_now()
		sale = self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 10, "price_m": 4200}],
						payments=[{"amount": 21000, "method": "Наличные"}])
		self.assertEqual(frappe.db.get_value("Stock Entry", sale["entry"], "korkem_film_seller"), MANAGER)
		month = film_team.team()
		mine = mine_now()
		# Bought at 3 200, sold at 4 200: 10 000 margin; half paid — 5 000 counted.
		self.assertAlmostEqual(mine["metres"] - before["metres"], 10, delta=0.01)
		self.assertAlmostEqual(mine["margin"] - before["margin"], 5000, delta=1)
		self.assertGreaterEqual(month["pot"], 500)
		# A manager sees only his own row; the floor sees nothing.
		seen = self._as(MANAGER, film_team.team)
		self.assertTrue(all(r["seller"] == MANAGER for r in seen["rows"]))
		self.assertIsNone(seen["settings"])
		with self.assertRaises(frappe.PermissionError):
			self._as(MANAGER, film_team.set_settings, pct=20)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, film_team.team)

	def test_the_month_report_ranks_films_and_their_margin(self):
		from korkem_manufacturing.services import film_team

		self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 5, "price_m": 4200}])
		report = self._as(MANAGER, film_team.report)
		row = next(r for r in report["top"] if r["item"] == self.film)
		# Bought at 3 200, sold at 4 200: 1 000 a metre, 5 000 on five.
		self.assertEqual((row["metres"], row["amount"], row["margin"], row["margin_m"]), (5, 21000, 5000, 1000))
		self.assertIn("KIRA", row["title"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, film_team.report)

	def test_metres_put_by_for_a_customer_are_not_sold_to_another(self):
		other = "Film Dept Other Buyer"
		if not frappe.db.exists("Customer", {"customer_name": other}):
			frappe.get_doc({"doctype": "Customer", "customer_name": other, "customer_type": "Company"}).insert(
				ignore_permissions=True
			)
		other = frappe.db.get_value("Customer", {"customer_name": other}, "name")
		held = self._as(MANAGER, service.hold, self.film, self.buyer, 30)
		self.assertEqual(self._free(), 20)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.hold, self.film, other, 25)
		# Another customer may have only what is free; the press too.
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.sell, other, [{"item": self.film, "metres": 25, "price_m": 4000}])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.to_shop, self.film, 25)
		# The one it was put by for takes it: the hold is used up.
		self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 30, "price_m": 4000}])
		self.assertEqual(frappe.db.get_value("Film Hold", held["hold"], "status"), "Sold")
		self.assertEqual(self._free(), 20)
		again = self._as(MANAGER, service.hold, self.film, other, 5)
		self._as(MANAGER, service.release_hold, again["hold"])
		self.assertEqual(self._free(), 20)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.hold, self.film, other, 1)

	def test_a_customer_in_debt_says_how_long(self):
		self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 1, "price_m": 4000}],
				 payments=[{"amount": 1000, "method": "Наличные"}])
		row = next(c for c in self._as(MANAGER, service.customers) if c["customer"] == self.buyer)
		self.assertGreater(row["debt"], 0)
		self.assertIsNotNone(row["debt_days"])
		self.assertGreaterEqual(row["debt_days"], 0)

	def test_the_customers_card_sets_the_price(self):
		self.assertEqual(self._as(MANAGER, service.price_for, self.film, self.buyer)["price_m"], 3900)
		self._as(MANAGER, service.set_customer, self.buyer, tier="wholesale", discount=5)
		price = self._as(MANAGER, service.price_for, self.film, self.buyer)
		self.assertEqual((price["tier"], price["base_m"], price["price_m"]), ("wholesale", 3400, 3230))
		sale = self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 10}], paid=32300,
						method="Карта", bank="Halyk")
		self.assertEqual((sale["amount"], sale["debt"]), (32300, 0))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.set_customer, self.buyer, discount=80)

	def test_no_more_is_sold_than_lies_on_the_shelf(self):
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 51}])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 5}], paid=999999,
					 method="Наличные")
		self.assertEqual(self._free(), 50)

	def test_film_goes_to_the_shop_and_is_written_off_with_a_reason(self):
		shop = self._as(MANAGER, service.to_shop, self.film, 6, order="SAL-ORD-2026-00017")
		self.assertEqual((shop["kind"], shop["order"]), ("shop", "SAL-ORD-2026-00017"))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.write_off, self.film, 1, " ")
		off = self._as(MANAGER, service.write_off, self.film, 1.5, "Образец для клиента")
		self.assertEqual((off["kind"], off["reason"]), ("write_off", "Образец для клиента"))
		self.assertEqual(self._free(), 42.5)
		kinds = [h["kind"] for h in self._as(MANAGER, service.history, self.film)]
		self.assertEqual(kinds, ["write_off", "shop", "receipt"])

	def test_a_mistake_is_cancelled_the_same_day_and_an_old_one_only_by_the_owner(self):
		sale = self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 10}])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.cancel, sale["entry"], " ")
		self._as(MANAGER, service.cancel, sale["entry"], "Не тот клиент")
		self.assertEqual(self._free(), 50)
		old = self._as(MANAGER, service.to_shop, self.film, 4)
		frappe.db.set_value("Stock Entry", old["entry"], "creation", add_days(nowdate(), -1), update_modified=False)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.cancel, old["entry"], "Ошибка")
		service.cancel(old["entry"], "Ошибка")
		self.assertEqual(self._free(), 50)

	def test_the_shop_floor_sees_metres_not_money_and_sells_nothing(self):
		self._as(MANAGER, service.sell, self.buyer, [{"item": self.film, "metres": 2}])
		rows = self._as(CUTTER, service.history, self.film)
		self.assertTrue(all(r["price_m"] is None for r in rows))
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.sell, self.buyer, [{"item": self.film, "metres": 1}])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.write_off, self.film, 1, "Просто так")
