# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The facade price matrix: who edits it, what it starts with, what it refuses."""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import facade_prices as service

SELLER = "facade.seller@example.com"
CUTTER = "facade.cutter@example.com"
COMPANY = "KORKEM"


def _user(email: str, role: str) -> str:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0}
		).insert(ignore_permissions=True)
	user = frappe.get_doc("User", email)
	if role not in {row.role for row in user.roles}:
		user.append("roles", {"role": role})
		user.save(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)
	return email


class TestFacadePrices(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(SELLER, "Sales User")
		_user(CUTTER, "Manufacturing User")
		service.seed_company(COMPANY)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _cell(self, milling: str, finish: str) -> dict | None:
		return next(
			(row for row in service.table()["prices"] if (row["milling"], row["finish"]) == (milling, finish)),
			None,
		)

	def test_the_company_starts_with_the_factorys_price_list(self):
		for (milling, finish), price in service.STARTING_PRICES.items():
			cell = self._cell(milling, finish)
			self.assertIsNotNone(cell, f"{milling} / {finish}")
		self.assertEqual(service.price_for("Квадро", service.ENAMEL, COMPANY), Decimal("35000"))

	def test_a_cell_the_factory_does_not_sell_has_no_price(self):
		self.assertIsNone(service.price_for("Квадро", service.ROUGH, COMPANY))

	def test_seeding_again_never_overwrites_an_edited_price(self):
		service.set_price("Тегіс", service.PVC, 18_250)
		self.assertEqual(service.seed_company(COMPANY), 0)
		self.assertEqual(service.price_for("Тегіс", service.PVC, COMPANY), Decimal("18250"))

	def test_the_manager_who_takes_orders_changes_a_price(self):
		frappe.set_user(SELLER)
		result = service.set_price("Классика", service.PVC, 20_000)
		self.assertTrue(result["can_edit"])
		self.assertEqual(service.price_for("Классика", service.PVC, COMPANY), Decimal("20000"))
		frappe.set_user("Administrator")
		self.assertTrue(
			frappe.db.exists("Domain Audit Event", {"action": "settings.facade_price", "actor": SELLER})
		)

	def test_a_new_milling_can_be_added(self):
		service.set_price("Волна", service.ENAMEL, 36_000)
		self.assertEqual(service.price_for("Волна", service.ENAMEL, COMPANY), Decimal("36000"))

	def test_a_disabled_cell_is_not_sold(self):
		service.set_price("Рифлёный", service.ROUGH, 9_500, enabled=0)
		self.assertIsNone(service.price_for("Рифлёный", service.ROUGH, COMPANY))

	def test_the_shop_floor_does_not_see_prices(self):
		frappe.set_user(CUTTER)
		with self.assertRaises(frappe.PermissionError):
			service.table()
		with self.assertRaises(frappe.PermissionError):
			service.set_price("Квадро", service.PVC, 1)
		# Nor through Frappe's own REST.
		self.assertFalse(frappe.has_permission("Facade Price", "read", user=CUTTER))

	def test_nonsense_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.set_price("Квадро", "Золото", 1000)
		with self.assertRaises(frappe.ValidationError):
			service.set_price("Квадро", service.PVC, 0)
		with self.assertRaises(frappe.ValidationError):
			service.set_price("Квадро", service.PVC, "дорого")

	def test_a_second_row_for_the_same_cell_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc(
				{
					"doctype": "Facade Price",
					"company": COMPANY,
					"milling": "Квадро",
					"finish": service.PVC,
					"price_per_m2": 1,
				}
			).insert()

	def test_a_price_is_never_deleted(self):
		name = frappe.db.get_value("Facade Price", {"company": COMPANY, "milling": "Квадро"}, "name")
		with self.assertRaises(frappe.ValidationError):
			frappe.delete_doc("Facade Price", name)
