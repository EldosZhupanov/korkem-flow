# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The facade tools reach the same services the buttons do, and writes wait for a person."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401
from korkem_ai.korkem_ai.tools.registry import Risk

COMPANY = "KORKEM"
#: The finish name as the price table spells it.
PVC = "ПВХ плёнка"


class TestFacadeTools(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		from korkem_manufacturing.services import facade_prices

		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)

	def setUp(self):
		frappe.set_user("Administrator")

	def test_reading_is_free_and_writing_waits_for_a_person(self):
		self.assertEqual(registry.get("sales.facade_quote").risk, Risk.READ)
		self.assertEqual(registry.get("manufacturing.facade_queue").risk, Risk.READ)
		for name in ("sales.set_order_urgent", "sales.set_customer_tier", "manufacturing.set_color_group"):
			with self.subTest(tool=name):
				self.assertTrue(registry.get(name).requires_confirmation)

	def test_the_quote_is_the_price_table_s_not_the_model_s(self):
		from korkem_manufacturing.services import facade_quote

		line = {"width_mm": 500, "height_mm": 400, "qty": 2, "milling": "Квадро", "finish": PVC}
		result = registry.execute("sales.facade_quote", {"lines": [line]})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["total"], facade_quote.quote([line])["total"])

	def test_an_unknown_milling_is_refused_not_guessed(self):
		line = {"width_mm": 500, "height_mm": 400, "qty": 1, "milling": "Нет такой", "finish": PVC}
		result = registry.execute("sales.facade_quote", {"lines": [line]})
		self.assertFalse(result["ok"])

	def test_the_queue_is_readable(self):
		result = registry.execute("manufacturing.facade_queue", {})
		self.assertTrue(result["ok"], result.get("error"))
		self.assertIn("jobs", result["data"])

	def test_the_person_agrees_to_a_sentence_that_names_the_order(self):
		spec = registry.get("sales.set_order_urgent")
		self.assertIn("SO-1", spec.summarise(sales_order="SO-1", urgent=True))
		self.assertIn("Снять", spec.summarise(sales_order="SO-1", urgent=False))
