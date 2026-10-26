# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Pricing a facade order from the company's own rules — and refusing to guess."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import facade_prices, facade_quote

COMPANY = "KORKEM"
CUTTER = "quote.cutter@example.com"
PVC, ENAMEL = facade_prices.PVC, facade_prices.ENAMEL


def _line(**overrides) -> dict:
	# 500 × 400 mm = 0.2 m² a piece; 2 pieces = 0.4 m².
	return {"width_mm": 500, "height_mm": 400, "qty": 2, "milling": "Квадро", "finish": PVC, **overrides}


class TestFacadeQuote(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		if not frappe.db.exists("User", CUTTER):
			frappe.get_doc(
				{"doctype": "User", "email": CUTTER, "first_name": "cutter", "send_welcome_email": 0,
				 "roles": [{"role": "Manufacturing User"}]}
			).insert(ignore_permissions=True)
		frappe.defaults.set_user_default("Company", COMPANY, user=CUTTER)

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price("Квадро", PVC, 21_000)
		facade_prices.set_price("Квадро", ENAMEL, 35_000)
		frappe.db.delete("Facade Pricing Settings", {"company": COMPANY})

	def tearDown(self):
		frappe.set_user("Administrator")

	def _rules(self, **values):
		facade_quote.save_settings(**values)

	def test_area_times_the_matrix_price(self):
		result = facade_quote.quote([_line()])
		self.assertEqual(result["pieces"], 2)
		self.assertEqual(result["area_m2"], 0.4)
		self.assertEqual(result["total"], 8_400)  # 0.4 × 21 000

	def test_lines_add_up_to_the_total(self):
		result = facade_quote.quote([_line(), _line(finish=ENAMEL, qty=1)])
		self.assertEqual(result["facades_total"], sum(line["amount"] for line in result["lines"]))
		self.assertEqual(result["total"], 8_400 + 7_000)

	def test_double_sided_uses_the_factor_the_admin_set(self):
		self._rules(double_sided_factor=1.8)
		result = facade_quote.quote([_line(double_sided=1)])
		self.assertEqual(result["total"], 15_120)  # 8 400 × 1.8

	def test_double_sided_without_a_factor_is_refused_not_guessed(self):
		with self.assertRaises(frappe.ValidationError) as caught:
			facade_quote.quote([_line(double_sided=1)])
		self.assertIn("не настроены", str(caught.exception))

	def test_customer_material_takes_the_set_discount(self):
		self._rules(customer_material_offered=1, customer_material_discount_percent=25)
		self.assertEqual(facade_quote.quote([_line(customer_material=1)])["total"], 6_300)

	def test_customer_material_when_not_accepted_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			facade_quote.quote([_line(customer_material=1)])

	def test_demolition_per_m2_per_piece_and_per_order(self):
		for unit, expected in (
			(facade_quote.PER_M2, 400),  # 0.4 m² × 1000
			(facade_quote.PER_PIECE, 2_000),  # 2 pcs × 1000
			(facade_quote.PER_ORDER, 1_000),
		):
			self._rules(demolition_unit=unit, demolition_rate=1_000)
			result = facade_quote.quote([_line()], demolition=1)
			self.assertEqual(result["demolition"], expected, unit)
			self.assertEqual(result["total"], 8_400 + expected, unit)

	def test_demolition_not_set_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			facade_quote.quote([_line()], demolition=1)

	def test_prepayment_from_settings_and_the_balance(self):
		self._rules(prepayment_percent=50)
		result = facade_quote.quote([_line()])
		self.assertEqual((result["prepayment"], result["balance"]), (4_200, 4_200))
		self.assertEqual(result["prepayment_source"], "settings")

	def test_the_manager_can_take_a_different_prepayment(self):
		self._rules(prepayment_percent=50)
		result = facade_quote.quote([_line()], prepayment_amount=3_000)
		self.assertEqual((result["prepayment"], result["balance"]), (3_000, 5_400))
		self.assertEqual(result["prepayment_source"], "manager")

	def test_a_prepayment_above_the_total_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			facade_quote.quote([_line()], prepayment_amount=9_000)

	def test_a_combination_not_in_the_price_list_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			facade_quote.quote([_line(finish=facade_prices.ROUGH)])  # Квадро is not sold rough

	def test_typos_in_sizes_are_refused(self):
		for bad in ({"width_mm": 5}, {"height_mm": 40_000}, {"qty": 1.5}, {"width_mm": "широкий"}):
			with self.assertRaises(frappe.ValidationError, msg=str(bad)):
				facade_quote.quote([_line(**bad)])

	def test_impossible_rules_are_refused(self):
		with self.assertRaises(frappe.ValidationError):
			self._rules(double_sided_factor=0.5)
		with self.assertRaises(frappe.ValidationError):
			self._rules(prepayment_percent=150)
		with self.assertRaises(frappe.ValidationError):
			self._rules(demolition_unit=facade_quote.PER_M2)  # a unit without a price

	def test_the_shop_floor_cannot_quote_or_change_rules(self):
		frappe.set_user(CUTTER)
		with self.assertRaises(frappe.PermissionError):
			facade_quote.quote([_line()])
		with self.assertRaises(frappe.PermissionError):
			facade_quote.save_settings(prepayment_percent=10)

	def test_rule_changes_are_audited(self):
		self._rules(prepayment_percent=40)
		self.assertTrue(
			frappe.db.exists("Domain Audit Event", {"action": "settings.facade_pricing", "entity_id": COMPANY})
		)
