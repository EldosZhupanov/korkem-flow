"""Dated provider pricing is exact and never invents a rate."""

import unittest
from importlib import import_module


class TestDatedPricing(unittest.TestCase):
	def price(self, **kwargs):
		try:
			pricing = import_module("korkem_ai.korkem_ai.pricing")
		except ModuleNotFoundError:
			self.fail("Missing exact dated pricing")
		return pricing.estimate(**kwargs)

	def arguments(self):
		return dict(
			provider="test-provider",
			model="test-model",
			on="2026-09-13",
			input_tokens=1000,
			output_tokens=500,
			rates=[
				dict(
					provider="test-provider",
					model="test-model",
					effective_from="2026-01-01",
					currency="USD",
					input_price_per_million="0.1",
					output_price_per_million="0.3",
				)
			],
		)

	def test_exact_decimal_cost(self):
		self.assertEqual(self.price(**self.arguments())["cost"], "0.00025")

	def test_rate_is_model_specific(self):
		args = self.arguments()
		args["model"] = "another-model"
		self.assertIsNone(self.price(**args))

	def test_future_rate_is_not_applied_early(self):
		args = self.arguments()
		args["rates"].append(
			{**args["rates"][0], "effective_from": "2027-01-01", "input_price_per_million": "900"}
		)
		self.assertEqual(self.price(**args)["cost"], "0.00025")

	def test_latest_effective_rate_wins(self):
		args = self.arguments()
		args["rates"].append(
			{**args["rates"][0], "effective_from": "2026-09-01", "input_price_per_million": "1"}
		)
		self.assertEqual(self.price(**args)["cost"], "0.00115")

	def test_unknown_usage_is_not_free(self):
		args = self.arguments()
		args["input_tokens"] = None
		self.assertIsNone(self.price(**args))

	def test_explicit_free_rate_is_distinct_from_no_price(self):
		args = self.arguments()
		args["rates"][0].update(input_price_per_million="0", output_price_per_million="0")
		self.assertEqual(self.price(**args)["cost"], "0")

	def test_negative_nan_and_boolean_rates_are_refused(self):
		for value in ("-1", "NaN", True):
			args = self.arguments()
			args["rates"][0]["input_price_per_million"] = value
			with self.subTest(value=value), self.assertRaises(ValueError):
				self.price(**args)
