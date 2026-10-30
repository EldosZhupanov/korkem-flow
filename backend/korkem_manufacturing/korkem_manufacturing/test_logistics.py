# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Logistics kept apart from material: the owner's own deliveries of
29.10.2026 — a Газель of MDF, film by taxi and by a transport company."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing import testing
from korkem_manufacturing.services import facade_order, facade_prices, logistics, material_stock

COMPANY = "KORKEM"
MANAGER = "log.manager@example.com"
ACCOUNTANT = "log.accountant@example.com"
CUTTER = "log.cutter@example.com"
SELLER = "log.seller@example.com"
SUPPLIER = "LOG GreenWood Test"
MONTH = "2026-09"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestLogistics(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(MANAGER, "Sales Manager")
		_user(ACCOUNTANT, "Accounts User")
		_user(CUTTER, "Manufacturing User")
		_user(SELLER, "Sales User")
		facade_prices.seed_company(COMPANY)
		for kind, value in (("Толщина МДФ", "16"), ("Производитель", "LOG-Kastamonu"), ("Цвет плёнки", "LOG Кварц Грей")):
			material_stock.add_option(kind, value)
		material_stock.add_supplier(SUPPLIER)
		cls.supplier = frappe.db.get_value("Supplier", {"supplier_name": SUPPLIER}, "name")
		cls.mdf = material_stock.define_material(
			material_stock.MDF, "лист", thickness="16", manufacturer="LOG-Kastamonu"
		)["item"]
		frappe.db.commit()

	def setUp(self):
		frappe.set_user("Administrator")
		self._clear()
		self.orders: list[str] = []

	def tearDown(self):
		frappe.set_user("Administrator")
		self._clear()
		for order in self.orders:
			testing.remove_order(order)

	@staticmethod
	def _clear():
		# Deliveries refuse deletion through the document; the test clears its own.
		frappe.db.delete(logistics.DOCTYPE, {"company": COMPANY, "note": ["like", "LOG-TEST%"]})

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _record(self, user=MANAGER, **kwargs):
		kwargs.setdefault("note", "LOG-TEST")
		return self._as(user, logistics.record, **kwargs)

	def _owners_month(self):
		"""The five deliveries the owner described, in one month."""
		film = material_stock.FILM
		self._record(amount=10_000, from_city="Астана", transport="Газель", category=material_stock.MDF,
					 what="МДФ 16 мм", qty=30, unit="лист", delivered_on=f"{MONTH}-03")
		self._record(amount=5_000, from_city="Астана", transport="Такси", category=film, supplier=self.supplier,
					 what="FRS 840-2-L Кварц Грей 0.25", qty=3.1, unit="м", delivered_on=f"{MONTH}-05")
		self._record(amount=1_500, from_city="Алматы", transport="Транспортная компания", carrier="Тайбазаров",
					 category=film, what="Белый СМ", qty=27.9, unit="м",
					 ordered_on=f"{MONTH}-06", delivered_on=f"{MONTH}-13")
		self._record(amount=4_000, from_city="Семей", transport="Такси", category=film, urgent=1,
					 what="Титан TI-05", qty=1.1, unit="м", delivered_on=f"{MONTH}-15")
		self._record(amount=25_000, from_city="Караганда", transport="Такси", category=film,
					 what="Белый глянец DM1010", qty=150, unit="м", delivered_on=f"{MONTH}-20")

	def test_the_owner_s_month_is_counted_apart_for_mdf_and_for_film(self):
		self._owners_month()
		s = self._as(ACCOUNTANT, logistics.summary, MONTH)
		self.assertEqual((s["total"], s["count"]), (45_500, 5))
		by_category = {g["name"]: g["amount"] for g in s["by_category"]}
		self.assertEqual(by_category, {material_stock.MDF: 10_000, material_stock.FILM: 35_500})
		self.assertEqual(s["by_city"][0], {"name": "Караганда", "amount": 25_000, "count": 1, "average_days": None})
		self.assertEqual({g["name"]: g["amount"] for g in s["by_transport"]}["Такси"], 34_000)
		self.assertEqual(s["by_carrier"], [{"name": "Тайбазаров", "amount": 1_500, "count": 1, "average_days": 7.0}])
		self.assertEqual(s["urgent"], {"count": 1, "amount": 4_000})

	def test_per_sheet_and_per_metre(self):
		self._owners_month()
		per_unit = {(p["category"], p["unit"]): p for p in self._as(MANAGER, logistics.summary, MONTH)["per_unit"]}
		self.assertEqual(per_unit[(material_stock.MDF, "лист")]["per_unit"], 333.33)
		film = per_unit[(material_stock.FILM, "м")]
		self.assertEqual((film["qty"], film["per_unit"]), (182.1, round(35_500 / 182.1, 2)))

	def test_a_delivery_with_its_receipt_takes_the_material_from_it(self):
		receipt = self._as(MANAGER, material_stock.receive, self.mdf, 30, 21_000, self.supplier)["receipt"]
		self.assertIn(receipt, [r["receipt"] for r in self._as(MANAGER, logistics.unlinked_receipts)])

		row = self._record(amount=10_000, from_city="Астана", transport="Газель", receipt=receipt)

		self.assertEqual((row["category"], row["qty"], row["unit"]), (material_stock.MDF, 30, "лист"))
		self.assertEqual((row["item"], row["supplier"]), (self.mdf, self.supplier))
		self.assertNotIn(receipt, [r["receipt"] for r in self._as(MANAGER, logistics.unlinked_receipts)])
		# The sheet keeps the supplier's price: logistics is its own line.
		self.assertEqual(material_stock.material(self.mdf)["average_price"], 21_000)
		material_stock.cancel_receipt(receipt)

	def test_the_receipt_form_writes_the_delivery_with_it(self):
		result = self._as(
			MANAGER, material_stock.receive, self.mdf, 30, 21_000, self.supplier,
			delivery={"amount": 10_000, "from_city": "Астана", "transport": "Газель"},
		)
		delivery = result["delivery"]
		self.assertEqual((delivery["receipt"], delivery["amount"], delivery["qty"]), (result["receipt"], 10_000, 30))
		frappe.db.set_value(logistics.DOCTYPE, delivery["delivery"], "note", "LOG-TEST")
		# A cancelled receipt takes its delivery out of the month.
		material_stock.cancel_receipt(result["receipt"])
		self.assertTrue(frappe.db.get_value(logistics.DOCTYPE, delivery["delivery"], "cancelled"))

	def test_a_free_delivery_is_written_as_zero(self):
		receipt = self._as(MANAGER, material_stock.receive, self.mdf, 5, 21_000, self.supplier)["receipt"]
		self._record(amount=0, from_city="Астана", transport="Привёз поставщик", receipt=receipt)
		self.assertNotIn(receipt, [r["receipt"] for r in self._as(MANAGER, logistics.unlinked_receipts)])
		material_stock.cancel_receipt(receipt)

	def test_an_order_carries_its_own_logistics(self):
		order = self._as(
			SELLER, facade_order.create_order,
			customer=frappe.db.get_value("Customer", {"disabled": 0}, "name"),
			delivery_date=add_days(nowdate(), 10),
			lines=[{"width_mm": 598, "height_mm": 298, "qty": 2, "milling": "Квадро", "finish": facade_prices.PVC,
					"thickness_mm": 16, "decor_top": "LOG Кварц Грей"}],
		)["sales_order"]
		self.orders.append(order)
		self._record(amount=5_000, from_city="Астана", transport="Такси", category=material_stock.FILM,
					 sales_order=order, qty=3.1, unit="м")
		result = self._as(MANAGER, logistics.for_order, order)
		self.assertEqual((result["total"], len(result["deliveries"])), (5_000, 1))

	def test_a_mistake_is_cancelled_with_a_reason_and_leaves_the_total(self):
		row = self._record(amount=7_000, from_city="Астана", transport="Газель", category=material_stock.MDF,
						   delivered_on=f"{MONTH}-10")
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, logistics.cancel, row["delivery"], "")
		cancelled = self._as(MANAGER, logistics.cancel, row["delivery"], "Записали дважды")
		self.assertTrue(cancelled["cancelled"])
		self.assertEqual(self._as(MANAGER, logistics.summary, MONTH)["total"], 0)
		self.assertTrue(frappe.db.exists(logistics.DOCTYPE, row["delivery"]))
		with self.assertRaises(frappe.ValidationError):
			frappe.delete_doc(logistics.DOCTYPE, row["delivery"], ignore_permissions=True)

	def test_what_cannot_be_true_is_refused(self):
		base = {"from_city": "Астана", "transport": "Такси", "category": material_stock.FILM}
		for wrong in (
			{"amount": -1},
			{"amount": 5_000, "delivered_on": add_days(nowdate(), 2)},
			{"amount": 5_000, "ordered_on": f"{MONTH}-10", "delivered_on": f"{MONTH}-05"},
			{"amount": 5_000, "category": "Мебель"},
			{"amount": 5_000, "from_city": ""},
		):
			with self.assertRaises(frappe.ValidationError, msg=wrong):
				self._record(**{**base, **wrong})

	def test_the_shop_floor_neither_sees_nor_writes_the_money(self):
		with self.assertRaises(frappe.PermissionError):
			self._record(user=CUTTER, amount=5_000, from_city="Астана", transport="Такси")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, logistics.summary, MONTH)

	def test_the_form_offers_what_the_shop_uses_first(self):
		self._record(amount=3_000, from_city="Талдыкорган", transport="Такси", category=material_stock.FILM)
		self._record(amount=3_000, from_city="Талдыкорган", transport="Такси", category=material_stock.FILM)
		offered = self._as(MANAGER, logistics.suggestions)
		self.assertEqual(offered["cities"][0], "Талдыкорган")
		self.assertIn("Алматы", offered["cities"])
		self.assertEqual(offered["transports"].count("Такси"), 1)

	def test_a_receipt_left_without_its_delivery_is_asked_about_after_a_day(self):
		from unittest.mock import patch

		from korkem_manufacturing import domain_events

		old = material_stock.receive(self.mdf, 7, 21_000, self.supplier, received_on=add_days(nowdate(), -2))["receipt"]
		fresh = material_stock.receive(self.mdf, 3, 21_000, self.supplier)["receipt"]
		written = material_stock.receive(self.mdf, 4, 21_000, self.supplier, received_on=add_days(nowdate(), -2))["receipt"]
		self._record(amount=0, from_city="Астана", transport="Привёз поставщик", receipt=written)
		try:
			asked = []
			with patch.object(
				domain_events, "emit", side_effect=lambda event, **kw: asked.append((event, kw["receipt"]))
			):
				logistics.remind()
			mine = [r for e, r in asked if e == logistics.DELIVERY_MISSING and r in (old, fresh, written)]
			# The one from two days ago; not today's, not the one already written.
			self.assertEqual(mine, [old])
		finally:
			for receipt in (written, fresh, old):
				material_stock.cancel_receipt(receipt)

	def test_the_owner_is_told_in_words_and_only_about_their_company(self):
		from korkem_ai.korkem_ai.notifications import events

		receipt = material_stock.receive(self.mdf, 7, 21_000, self.supplier)["receipt"]
		try:
			self.assertEqual(
				events.delivery_missing(company="Мебель Тест Цех", receipt=receipt, date=nowdate()), []
			)
			events.delivery_missing(
				company=COMPANY, receipt=receipt, date=nowdate(), title="МДФ 16 мм", qty=7, unit="лист"
			)
			body = frappe.db.get_value(
				"Notification Delivery",
				{"event": logistics.DELIVERY_MISSING, "reference_name": receipt},
				"body",
			)
			if body:  # only when this site has an owner bound to KORKEM
				self.assertIn("МДФ 16 мм — 7 лист", body)
				self.assertIn("0 ₸", body)
		finally:
			frappe.db.delete("Notification Delivery", {"reference_name": receipt})
			material_stock.cancel_receipt(receipt)
