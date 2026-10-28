# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Trades on the shop floor: named by the company, several per person, no rights."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import shop_trades, staff

COMPANY = "KORKEM"
CHIEF = "trades.chief@example.com"
CUTTER = "trades.cutter@example.com"
SELLER = "trades.seller@example.com"
STRANGER = "trades.stranger@example.com"


def _user(email: str, role: str, company: str = COMPANY) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", company, user=email)
	if not frappe.db.exists("User Permission", {"user": email, "allow": "Company", "for_value": company}):
		frappe.get_doc(
			{"doctype": "User Permission", "user": email, "allow": "Company", "for_value": company,
			 "apply_to_all_doctypes": 1}
		).insert(ignore_permissions=True)


class TestShopTrades(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(CHIEF, "Manufacturing Manager")
		_user(CUTTER, "Manufacturing User")
		_user(SELLER, "Sales User")
		other = frappe.db.get_value("Company", {"name": ["!=", COMPANY]}, "name")
		_user(STRANGER, "Manufacturing User", other or COMPANY)
		cls.stranger_elsewhere = bool(other)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _titles(self) -> set[str]:
		return {t["title"] for t in self._as(CHIEF, shop_trades.trades)["trades"] if t["enabled"]}

	def test_a_company_starts_with_the_usual_trades(self):
		self.assertIn("Раскройщик", self._titles())
		self.assertIn("Сборщик", self._titles())

	def test_a_company_names_its_own_trade(self):
		self._as(CHIEF, shop_trades.add_trade, "  Фрезеровщик  ")
		self.assertIn("Фрезеровщик", self._titles())
		# The usual ones are kept when the first own one is added.
		self.assertIn("Сборщик", self._titles())

	def test_a_person_has_several_trades_and_gains_no_rights(self):
		roles_before = set(frappe.get_roles(CUTTER))
		self._as(CHIEF, shop_trades.set_member_trades, CUTTER, ["Раскройщик", "Кромщик"])
		self.assertEqual(shop_trades.of_users(COMPANY)[CUTTER], ["Раскройщик", "Кромщик"])
		self.assertEqual(set(frappe.get_roles(CUTTER)), roles_before)
		# The list replaces: one left, one gone.
		self._as(CHIEF, shop_trades.set_member_trades, CUTTER, '["Кромщик"]')
		self.assertEqual(shop_trades.of_users(COMPANY)[CUTTER], ["Кромщик"])

	def test_the_team_list_shows_them(self):
		self._as(CHIEF, shop_trades.set_member_trades, CUTTER, ["Сборщик"])
		frappe.set_user("Administrator")
		frappe.defaults.set_user_default("Company", COMPANY, user="Administrator")
		row = next(p for p in staff.members() if p["email"] == CUTTER)
		self.assertEqual(row["trades"], ["Сборщик"])

	def test_a_switched_off_trade_is_kept_but_not_offered(self):
		self._as(CHIEF, shop_trades.add_trade, "Обивщик")
		trade = next(t["trade"] for t in self._as(CHIEF, shop_trades.trades)["trades"] if t["title"] == "Обивщик")
		self._as(CHIEF, shop_trades.set_enabled, trade, 0)
		self.assertNotIn("Обивщик", self._titles())
		with self.assertRaises(frappe.ValidationError):
			self._as(CHIEF, shop_trades.set_member_trades, CUTTER, ["Обивщик"])
		with self.assertRaises(frappe.PermissionError):
			frappe.delete_doc("Shop Trade", trade, ignore_permissions=True)

	def test_only_the_shop_s_managers_assign_trades(self):
		for outsider in (CUTTER, SELLER):
			with self.assertRaises(frappe.PermissionError):
				self._as(outsider, shop_trades.set_member_trades, CUTTER, ["Сборщик"])
			with self.assertRaises(frappe.PermissionError):
				self._as(outsider, shop_trades.add_trade, "Столяр")
		# Reading is for the staff: a crew picker needs it.
		self.assertTrue(self._as(CUTTER, shop_trades.trades)["trades"])

	def test_nobody_from_elsewhere_and_no_unknown_trade(self):
		with self.assertRaises(frappe.ValidationError):
			self._as(CHIEF, shop_trades.set_member_trades, CUTTER, ["Космонавт"])
		if self.stranger_elsewhere:
			with self.assertRaises(frappe.DoesNotExistError):
				self._as(CHIEF, shop_trades.set_member_trades, STRANGER, ["Сборщик"])
