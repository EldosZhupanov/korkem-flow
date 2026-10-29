# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Мало листов»: the owner hears before the shop stands waiting for MDF."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities
from korkem_ai.korkem_ai.notifications import events, recipients
from korkem_manufacturing import setup
from korkem_manufacturing.services import material_stock, stock_alerts

COMPANY = setup.COMPANY
#: The same owner test_reminders uses. A second System Manager bound to
#: KORKEM would be a second recipient of every owner message, and the
#: reminder tests count exactly one (29.10.2026).
OWNER = "reminder.owner@korkem.test"
MANAGER = "stockalert.manager@example.com"
CUTTER = "stockalert.cutter@example.com"
EXTERNAL_ID = "31999003"
MAKER = "SA-Kastamonu"
SUPPLIER = "SA Supplier Test"


def _user(email: str, role: str, bind: bool = False) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)
	if bind and not frappe.db.exists("User Permission", {"user": email, "allow": "Company", "for_value": COMPANY}):
		frappe.get_doc(
			{"doctype": "User Permission", "user": email, "allow": "Company", "for_value": COMPANY,
			 "apply_to_all_doctypes": 1}
		).insert(ignore_permissions=True)
	frappe.clear_cache(user=email)


class TestLowStock(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.clear_cache()  # the worker may hold hooks.py from before stock.low existed
		frappe.set_user("Administrator")
		_user(OWNER, "System Manager", bind=True)
		_user(MANAGER, "Sales Manager")
		_user(CUTTER, "Manufacturing User")
		for kind, value in (("Толщина МДФ", "16"), ("Производитель", MAKER)):
			material_stock.add_option(kind, value)
		material_stock.add_supplier(SUPPLIER)
		cls.supplier = frappe.db.get_value("Supplier", {"supplier_name": SUPPLIER}, "name")
		cls.mdf = material_stock.define_material(material_stock.MDF, "лист", thickness="16", manufacturer=MAKER)["item"]
		frappe.db.commit()

	def setUp(self):
		frappe.set_user("Administrator")
		self.receipts: list[str] = []
		self.sent = []
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=lambda channel, external_id, text, **kwargs: self.sent.append(text) or {"message_id": "sa"},
		)
		patcher.start()
		self.addCleanup(patcher.stop)
		identity = identities.observe("Telegram", EXTERNAL_ID, "Reminder Owner")
		identity.db_set("user", OWNER)

	def tearDown(self):
		frappe.set_user("Administrator")
		for receipt in reversed(self.receipts):
			material_stock.cancel_receipt(receipt)
		frappe.db.set_value("Item", self.mdf, "korkem_min_stock", 0)
		frappe.db.delete("Notification Delivery", {"reference_doctype": "Item", "reference_name": self.mdf})
		frappe.db.commit()

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _receive(self, qty):
		self.receipts.append(material_stock.receive(self.mdf, qty, 21_000, self.supplier)["receipt"])

	def _deliveries(self):
		return frappe.get_all(
			"Notification Delivery",
			filters={"event": stock_alerts.LOW, "reference_doctype": "Item", "reference_name": self.mdf},
			fields=["name", "recipient_user", "body"],
		)

	def test_the_manager_sets_a_minimum_the_floor_cannot(self):
		row = self._as(MANAGER, material_stock.set_min_stock, self.mdf, 10)
		self.assertEqual(row["min_stock"], 10)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, material_stock.set_min_stock, self.mdf, 3)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, material_stock.set_min_stock, self.mdf, 2.5)  # sheets come whole
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, material_stock.set_min_stock, self.mdf, -1)

	def test_below_the_minimum_the_material_reads_low_and_the_owner_is_told(self):
		self._receive(4)
		row = self._as(MANAGER, material_stock.set_min_stock, self.mdf, 10)

		self.assertTrue(row["low"])
		low = {r["item"]: r for r in stock_alerts.low(COMPANY)}
		self.assertEqual((low[self.mdf]["free"], low[self.mdf]["minimum"]), (4, 10))
		sent = self._deliveries()
		mine = [r for r in sent if r.recipient_user == OWNER]
		self.assertEqual(len(mine), 1)
		self.assertIn("свободно 4", mine[0].body)
		self.assertIn("минимум 10", mine[0].body)

	def test_enough_on_hand_says_nothing(self):
		self._receive(25)
		row = self._as(MANAGER, material_stock.set_min_stock, self.mdf, 10)

		self.assertFalse(row["low"])
		self.assertNotIn(self.mdf, [r["item"] for r in stock_alerts.low(COMPANY)])
		self.assertEqual(self._deliveries(), [])

	def test_the_hourly_run_says_it_once_a_day(self):
		self._receive(3)
		frappe.db.set_value("Item", self.mdf, "korkem_min_stock", 10)

		stock_alerts.run()
		stock_alerts.run()
		self.assertEqual(len([r for r in self._deliveries() if r.recipient_user == OWNER]), 1)

		# The next morning, if nothing came in, it is said again.
		row = stock_alerts.low(COMPANY, [self.mdf])[0]
		events.stock_low(company=COMPANY, day=add_days(nowdate(), 1), **row)
		self.assertEqual(len([r for r in self._deliveries() if r.recipient_user == OWNER]), 2)

	def test_what_is_promised_to_orders_is_not_free(self):
		self._receive(15)
		frappe.db.set_value("Item", self.mdf, "korkem_min_stock", 10)
		self.assertNotIn(self.mdf, [r["item"] for r in stock_alerts.low(COMPANY)])

		with patch.object(material_stock, "_reserved", return_value={self.mdf: 12.0}):
			row = stock_alerts.low(COMPANY, [self.mdf])[0]
		self.assertEqual((row["on_hand"], row["reserved"], row["free"]), (15, 12, 3))

	def test_only_the_owner_of_this_company_hears(self):
		self.assertIn(OWNER, recipients.owners_for_company(COMPANY))
		self._receive(2)
		frappe.db.set_value("Item", self.mdf, "korkem_min_stock", 5)
		stock_alerts.check(COMPANY, [self.mdf])
		self.assertNotIn(MANAGER, [r.recipient_user for r in self._deliveries()])
