# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Lists the managers keep, materials described from them, receipts in ERPNext."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import flt

from korkem_manufacturing.services import material_stock as service
from korkem_manufacturing.services import price_visibility

COMPANY = "KORKEM"
MANAGER = "stock.manager@example.com"
CUTTER = "stock.cutter@example.com"
SUPPLIER = "Profi Test Supplier"


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestMaterialStock(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(MANAGER, "Sales Manager")
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		frappe.set_user("Administrator")
		price_visibility.set_floor_sees_prices(False)
		for kind, value in (
			("Толщина МДФ", "16"),
			("Производитель", "Kastamonu"),
			("Цвет плёнки", "Графит"),
			("Ширина плёнки", "1400"),
			("Толщина плёнки", "0,30"),
		):
			service.add_option(kind, value)
		service.add_supplier(SUPPLIER)
		self.supplier = frappe.db.get_value("Supplier", {"supplier_name": SUPPLIER}, "name")

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _mdf(self) -> str:
		return self._as(MANAGER, service.define_material, service.MDF, "лист", thickness="16", manufacturer="Kastamonu")["item"]

	# --- lists ----------------------------------------------------------------

	def test_the_manager_keeps_the_lists(self):
		lists = self._as(MANAGER, service.add_option, "Производитель", "Kronospan")["lists"]
		self.assertIn("Kronospan", [o["value"] for o in lists["Производитель"]])

	def test_an_unused_entry_is_deleted_a_used_one_switched_off(self):
		self._as(MANAGER, service.add_option, "Толщина МДФ", "22")
		unused = frappe.db.get_value("Material Option", {"company": COMPANY, "kind": "Толщина МДФ", "value": "22"}, "name")
		self.assertEqual(self._as(MANAGER, service.remove_option, unused)["outcome"], "deleted")

		self._mdf()
		used = frappe.db.get_value("Material Option", {"company": COMPANY, "kind": "Толщина МДФ", "value": "16"}, "name")
		self.assertEqual(self._as(MANAGER, service.remove_option, used)["outcome"], "disabled")
		self.assertTrue(frappe.db.exists("Material Option", used))

	def test_the_shop_floor_cannot_change_the_lists(self):
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.add_option, "Производитель", "Чужой")

	# --- materials --------------------------------------------------------------

	def test_a_material_is_described_from_the_lists(self):
		material = self._as(MANAGER, service.material, self._mdf())
		self.assertEqual(material["title"], "МДФ 16 мм Kastamonu")
		self.assertEqual((material["thickness"], material["manufacturer"]), ("16", "Kastamonu"))

	def test_the_same_description_is_the_same_material(self):
		self.assertEqual(self._mdf(), self._mdf())

	def test_a_value_not_in_the_lists_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.define_material, service.MDF, "лист", thickness="17", manufacturer="Kastamonu")

	def test_a_film_carries_colour_width_and_thickness(self):
		item = self._as(
			MANAGER, service.define_material, service.FILM, "м",
			color="Графит", width="1400", film_thickness="0,30", manufacturer="Kastamonu",
		)["item"]
		self.assertEqual(frappe.db.get_value("Item", item, "korkem_color"), "Графит")
		self.assertIn("1400", frappe.db.get_value("Item", item, "item_name"))

	# --- receipts -----------------------------------------------------------------

	def test_a_receipt_is_an_erpnext_material_receipt_and_moves_stock(self):
		item = self._mdf()
		result = self._as(MANAGER, service.receive, item, 45, 21_000, self.supplier)
		entry = frappe.get_doc("Stock Entry", result["receipt"])
		self.assertEqual((entry.docstatus, entry.purpose, entry.korkem_supplier), (1, "Material Receipt", self.supplier))
		self.assertGreaterEqual(result["material"]["on_hand"], 45)
		self.assertEqual(flt(entry.items[0].basic_rate), 21_000)

	def test_the_shop_floor_sees_quantities_not_prices(self):
		item = self._mdf()
		self._as(MANAGER, service.receive, item, 10, 21_000, self.supplier)
		row = next(m for m in self._as(CUTTER, service.materials)["materials"] if m["item"] == item)
		self.assertGreaterEqual(row["on_hand"], 10)
		self.assertIsNone(row["average_price"])
		receipt = next(r for r in self._as(CUTTER, service.receipts)["receipts"] if r["item"] == item)
		self.assertIsNone(receipt["price_per_unit"])

	def test_the_shop_floor_cannot_receive(self):
		item = self._mdf()
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, service.receive, item, 1, 21_000, self.supplier)

	def test_whole_sheets_only(self):
		item = self._mdf()
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, service.receive, item, 1.5, 21_000, self.supplier)

	def test_nonsense_receipts_are_refused(self):
		item = self._mdf()
		for qty, price in ((0, 21_000), (5, 0), ("много", 21_000), (5, "дорого")):
			with self.assertRaises(frappe.ValidationError, msg=f"{qty} {price}"):
				self._as(MANAGER, service.receive, item, qty, price, self.supplier)

	def test_a_disabled_supplier_cannot_deliver(self):
		item = self._mdf()
		service.disable_supplier(self.supplier)
		with self.assertRaises(frappe.DoesNotExistError):
			self._as(MANAGER, service.receive, item, 5, 21_000, self.supplier)

	def test_a_mistaken_receipt_is_cancelled_not_deleted(self):
		item = self._mdf()
		before = self._as(MANAGER, service.material, item)["on_hand"]
		receipt = self._as(MANAGER, service.receive, item, 3, 21_000, self.supplier)["receipt"]
		self._as(MANAGER, service.cancel_receipt, receipt)
		self.assertEqual(frappe.db.get_value("Stock Entry", receipt, "docstatus"), 2)
		self.assertEqual(self._as(MANAGER, service.material, item)["on_hand"], before)

	def test_receiving_is_audited(self):
		item = self._mdf()
		receipt = self._as(MANAGER, service.receive, item, 2, 21_000, self.supplier)["receipt"]
		self.assertTrue(frappe.db.exists("Domain Audit Event", {"action": "stock.material_received", "entity_id": receipt}))
