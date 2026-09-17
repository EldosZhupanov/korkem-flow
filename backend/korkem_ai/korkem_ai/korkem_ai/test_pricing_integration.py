"""Dated prices must reach the existing ledger, not live only in a utility."""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import usage
from korkem_ai.korkem_ai.orchestrator.protocol import AIUsage


class TestPricingLedger(IntegrationTestCase):
	def test_configured_dated_price_is_recorded(self):
		rates = [
			dict(
				provider="test-provider",
				model="test-model",
				effective_from="2026-01-01",
				currency="USD",
				input_price_per_million="0.1",
				output_price_per_million="0.3",
			)
		]
		with patch.dict(frappe.conf, {"korkem_ai_pricing": rates}):
			name = usage.record(
				AIUsage(input_tokens=1000, output_tokens=500),
				provider="test-provider",
				model="test-model",
				status="answered",
			)
		self.assertIsNotNone(name)
		row = frappe.get_doc(usage.DOCTYPE, name)
		self.assertAlmostEqual(row.estimated_cost, 0.00025, places=6)
		self.assertEqual(row.cost_currency, "USD")
		self.assertEqual(row.cost_basis, "provider rate")

	def test_invalid_rate_does_not_lose_token_accounting(self):
		with patch.dict(
			frappe.conf, {"korkem_ai_pricing": [{"provider": "test-provider", "model": "test-model"}]}
		):
			name = usage.record(
				AIUsage(input_tokens=1000, output_tokens=500),
				provider="test-provider",
				model="test-model",
				status="answered",
			)
		self.assertIsNotNone(name)
		self.assertEqual(frappe.db.get_value(usage.DOCTYPE, name, "total_tokens"), 1500)
