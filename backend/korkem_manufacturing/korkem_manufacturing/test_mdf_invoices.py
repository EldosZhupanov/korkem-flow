# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Счёт на оплату» for an MDF order (owner, 20.11.2026): issued for the
whole order or a part of it, paid by a payment «по счёту», and kept as it was
printed."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, nowdate

from korkem_manufacturing.api import mdf_orders as api
from korkem_manufacturing.services import facade_prices, film_invoice, mdf_invoices, mdf_orders

COMPANY = "KORKEM"
MANAGER = "mdf.invoice.manager@example.com"
CUTTER = "mdf.invoice.cutter@example.com"
PVC = facade_prices.PVC
FLAT = "МДФ Тест Тегіс 90°"
LINES = [
	{"height_mm": 1000, "width_mm": 500, "qty": 2, "milling": FLAT},  # 1,00 m²
	{"height_mm": 500, "width_mm": 400, "qty": 1, "milling": FLAT},  # 0,20 m²
]


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


class TestMdfInvoices(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		_user(MANAGER, "Sales User")
		_user(CUTTER, "Manufacturing User")
		cls.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		assert cls.customer, "the seeded site has customers; no silent skip"

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price(FLAT, PVC, 20_000)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _order(self) -> dict:
		card = self._as(MANAGER, mdf_orders.save_draft, customer=self.customer,
						delivery_date=add_days(nowdate(), 7), head={"finish": PVC, "thickness_mm": 16},
						lines=LINES)
		self.addCleanup(self._drop, card["name"])
		self.addCleanup(self._cancel_payments, card["name"])
		return self._as(MANAGER, mdf_orders.accept, card["name"])

	def test_the_whole_order_on_one_invoice_then_paid_by_it(self):
		card = self._order()
		self.assertEqual(card["total"], 24_000)
		self.assertEqual(card["invoices"], [])
		made = self._as(MANAGER, api.invoice_issue, card["name"], 24_000, payer="ТОО «Мебель-Юг»",
						bin="123456789012")
		inv = made["invoice"]
		self.assertEqual((inv["amount"], inv["payer"], inv["bin"], inv["state"]),
						 (24_000, "ТОО «Мебель-Юг»", "123456789012", "open"))
		self.assertEqual(inv["due_on"], str(frappe.utils.getdate(add_days(nowdate(), film_invoice.DUE_DAYS))))
		# The facades as an accountant reads them: thickness, coating, m².
		self.assertEqual([(line["name"], line["qty"], line["unit"], line["amount"]) for line in inv["lines"]],
						 [("Фасады МДФ 16 мм, плёнка ПВХ", 1.2, "м²", 24_000)])
		self.assertIn("iik", made["requisites"])
		# The payer is remembered on the customer card for the next time.
		self.assertEqual(made["order"]["payer"], {"name": "ТОО «Мебель-Юг»", "bin": "123456789012"})
		# Paid by it: the invoice closes.
		card = self._as(MANAGER, api.add_payment, card["name"], 24_000, "Перевод", invoice=inv["no"])
		self.assertEqual(card["invoices"][0]["state"], "paid")
		self.assertTrue(any(f"по счёту № {inv['no']}" in h["text"] for h in card["history"]))
		# Printed again, the same paper.
		again = self._as(MANAGER, api.invoice_print, card["name"], inv["no"])
		self.assertEqual(again["invoice"]["lines"], inv["lines"])

	def test_a_prepayment_is_one_line_numbered_after_the_last_and_never_over_the_debt(self):
		card = self._order()
		first = self._as(MANAGER, api.invoice_issue, card["name"], 12_000)["invoice"]
		self.assertEqual(first["lines"], [{"name": f"Предоплата по заказу № {card['name']} (фасады МДФ)",
										   "qty": 1.0, "unit": "усл.", "price": 12_000, "amount": 12_000}])
		self.assertEqual(first["vat"], mdf_invoices.vat_default(COMPANY))
		second = self._as(MANAGER, api.invoice_issue, card["name"], 12_000, vat=1)["invoice"]
		self.assertEqual(int(second["no"]), int(first["no"]) + 1)
		self.assertEqual(second["vat"], mdf_invoices.VAT_RATE)
		# VAT once chosen is the shop's way after.
		self.assertEqual(mdf_invoices.vat_default(COMPANY), mdf_invoices.VAT_RATE)
		self.addCleanup(lambda: frappe.db.set_default(f"{mdf_invoices._VAT}:{COMPANY}", ""))
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, api.invoice_issue, card["name"], 30_000)
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, api.invoice_issue, card["name"], 1_000, bin="123")
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, api.invoice_issue, card["name"], 1_000)

	def test_a_part_payment_leaves_it_part_paid_and_a_fixed_payment_still_counts(self):
		card = self._order()
		inv = self._as(MANAGER, api.invoice_issue, card["name"], 24_000)["invoice"]
		card = self._as(MANAGER, api.add_payment, card["name"], 10_000, "Перевод", invoice=inv["no"])
		row = card["invoices"][0]
		self.assertEqual((row["state"], row["paid"]), ("part", 10_000))
		entry = card["payments"][0]["entry"]
		card = self._as(MANAGER, api.fix_payment, card["name"], entry, "Ошибка в сумме", 24_000, "Перевод")
		self.assertEqual(card["invoices"][0]["state"], "paid")

	def test_an_open_invoice_is_cancelled_with_a_reason_a_paid_one_never(self):
		card = self._order()
		inv = self._as(MANAGER, api.invoice_issue, card["name"], 5_000)["invoice"]
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, api.invoice_cancel, card["name"], inv["no"], " ")
		card = self._as(MANAGER, api.invoice_cancel, card["name"], inv["no"], "Не та сумма")
		self.assertEqual(card["invoices"][0]["state"], "cancelled")
		with self.assertRaises(frappe.ValidationError):  # no paying a cancelled one
			self._as(MANAGER, api.add_payment, card["name"], 5_000, "Перевод", invoice=inv["no"])
		paid = self._as(MANAGER, api.invoice_issue, card["name"], 5_000)["invoice"]
		self._as(MANAGER, api.add_payment, card["name"], 5_000, "Перевод", invoice=paid["no"])
		with self.assertRaises(frappe.ValidationError):
			self._as(MANAGER, api.invoice_cancel, card["name"], paid["no"], "Передумали")
		self.assertEqual(flt(frappe.db.get_value("Sales Order", card["name"], "advance_paid")), 5_000)

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
			doc.cancel()
