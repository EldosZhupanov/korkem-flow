# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""CNC services (owner, 15.11.2026): a kitchen worktop brought in — a
euro-joint, a cut-out for an under-mount sink and one for the hob — and,
sometimes, a sheet of the shop's own LDSP sold with the job."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import cnc_orders, directions, material_stock

COMPANY = "KORKEM"
MANAGER = "cnc.manager@example.com"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestCncOrders(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		cnc_orders.seed_company(COMPANY)
		_user(MANAGER, "Sales User")
		cls.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		assert cls.customer, "the seeded site has customers; no silent skip"

	def setUp(self):
		frappe.set_user("Administrator")
		frappe.db.set_value("Customer", self.customer, "korkem_tags", None)
		cnc_orders.set_settings(urgent_pct=20, min_order=0, day_minutes=480)
		self.joint = self._service("Еврозапил", price=6000, price_trade=5000)
		self.sink = self._service("Вырез под мойку — подстольная (с полировкой)", price=12000)
		self.lattice = self._service("Решётка / узор")

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _service(self, title: str, **values) -> str:
		row = next(s for s in cnc_orders.services(include_disabled=True) if s["title"] == title)
		if values:
			cnc_orders.save_service(title, row["unit"], group=row["group"], minutes=row["minutes"],
									service=row["id"], **values)
		return row["id"]

	def _drop(self, name: str) -> None:
		frappe.set_user("Administrator")
		if not frappe.db.exists("Sales Order", name):
			return
		doc = frappe.get_doc("Sales Order", name)
		if doc.docstatus == 1:
			cnc_orders._return_material(name)
			doc.cancel()

	def test_a_company_starts_with_the_usual_services_and_no_prices(self):
		titles = {s["title"]: s for s in cnc_orders.services(include_disabled=True)}
		self.assertIn("Еврозапил", titles)
		self.assertEqual(titles["Решётка / узор"]["unit"], cnc_orders.BY_AGREEMENT)
		self.assertEqual(titles["Вырез под розетку"]["price"], 0)
		# Once: a list that exists is the owner's.
		cnc_orders.seed_company(COMPANY)
		self.assertEqual(len(cnc_orders.services(include_disabled=True)), len(titles))
		# The list and its settings are the owner's.
		with self.assertRaises(frappe.PermissionError):
			self._as(MANAGER, cnc_orders.save_service, "Новое", "шт")

	def test_a_furniture_maker_has_his_price_a_lattice_is_priced_for_the_job(self):
		lines = [{"service": self.joint, "qty": 1}, {"service": self.lattice, "qty": 1}]
		quote = self._as(MANAGER, cnc_orders.price, lines, customer=self.customer)
		self.assertEqual(quote["lines"][0]["rate"], 6000)
		# «договорная»: no list price until it is typed.
		self.assertEqual(quote["no_price_lines"], [2])
		frappe.db.set_value("Customer", self.customer, "korkem_tags", "furniture_maker")
		quote = self._as(MANAGER, cnc_orders.price, [{"service": self.joint, "qty": 2},
													 {"service": self.lattice, "qty": 1.5, "rate": 18000}],
						 customer=self.customer)
		self.assertEqual([line["amount"] for line in quote["lines"]], [10000, 27000])
		self.assertEqual(quote["no_price_lines"], [])
		self.assertTrue(quote["maker_prices"])

	def test_urgent_costs_more_and_a_small_order_is_brought_to_the_minimum(self):
		cnc_orders.set_settings(urgent_pct=20, min_order=10000)
		quote = self._as(MANAGER, cnc_orders.price, [{"service": self.joint, "qty": 1}], tags=["urgent"])
		# 6 000 + 20 % = 7 200, then up to the minimum 10 000.
		self.assertEqual([e["amount"] for e in quote["extras"]], [1200, 2800])
		self.assertEqual(quote["total"], 10000)

	def test_a_worktop_is_taken_in_queued_on_the_machine_ready_and_handed_over(self):
		card = self._as(
			MANAGER, cnc_orders.save_draft, customer=self.customer, delivery_date=add_days(nowdate(), 3),
			lines=[{"service": self.joint, "qty": 1}, {"service": self.sink, "qty": 1, "note": "мойка 50×40"}],
			intake=[{"what": "Столешница искусственный камень 3000×600", "qty": 1, "defects": "скол на углу"}],
			terms=True, tags=["urgent"])
		self.addCleanup(self._drop, card["name"])
		self.assertEqual(frappe.db.get_value("Sales Order", card["name"], "korkem_direction"), directions.CNC)
		self.assertEqual((card["status"], card["terms"], card["intake"][0]["defects"]), ("draft", True, "скол на углу"))
		self.assertEqual(card["total"], 21600)  # 18 000 + 20 %
		self.assertEqual(card["minutes"], 70)  # 30 + 40 by the list

		card = self._as(MANAGER, cnc_orders.accept, card["name"])
		self.assertEqual(card["status"], "queued")
		self.assertTrue(card["queue"]["eta"])
		listing = self._as(MANAGER, cnc_orders.listing)
		self.assertGreaterEqual(listing["queue_minutes"], 70)
		self.assertEqual(self._as(MANAGER, cnc_orders.start, card["name"])["status"], "on_machine")
		self.assertEqual(self._as(MANAGER, cnc_orders.ready, card["name"])["status"], "ready")
		# Not handed over with a debt by a manager.
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, cnc_orders.hand_over, card["name"])
		from korkem_manufacturing.api import cnc_orders as api

		frappe.set_user(MANAGER)
		try:
			paid = api.add_payment(card["name"], 21600, "Наличные")
		finally:
			frappe.set_user("Administrator")
		self.assertEqual(paid["debt"], 0)
		done = self._as(MANAGER, cnc_orders.hand_over, card["name"], taken_by="Водитель", taken_phone="+77010000000")
		self.assertEqual((done["status"], done["taken_by"]), ("handed_over", "Водитель"))

	def test_the_shops_own_sheet_is_sold_with_the_job_and_put_back_if_cancelled(self):
		sheet = material_stock.define_material(material_stock.OTHER, "лист",
											   name=f"ЛДСП Тест ЧПУ {frappe.generate_hash(length=4)}")["item"]
		material_stock.add_supplier("ЧПУ Тест Поставщик")
		supplier = frappe.db.get_value("Supplier", {"supplier_name": "ЧПУ Тест Поставщик"}, "name")
		material_stock.receive(sheet, 5, 15000, supplier)

		def on_hand() -> float:
			return material_stock._stock([sheet], COMPANY)[sheet][0]

		with self.assertRaises(frappe.ValidationError):
			cnc_orders.price([{"material": sheet, "qty": 2}])  # the customer's price is asked
		card = self._as(MANAGER, cnc_orders.save_draft, customer=self.customer,
						lines=[{"material": sheet, "qty": 2, "rate": 21000},
							   {"service": self._service("Распил ЛДСП", price=3000), "qty": 2}])
		self.addCleanup(self._drop, card["name"])
		self.assertEqual(card["total"], 48000)
		self._as(MANAGER, cnc_orders.accept, card["name"])
		self.assertEqual(on_hand(), 3)
		self._as(MANAGER, cnc_orders.cancel, card["name"], "клиент передумал")
		self.assertEqual(on_hand(), 5)
		self.assertEqual(cnc_orders.card(card["name"])["status"], "cancelled")
