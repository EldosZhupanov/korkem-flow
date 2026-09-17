"""Exact geometry, no database, model, implicit units or invented waste factor."""

import unittest
from importlib import import_module


class TestCalculations(unittest.TestCase):
	def service(self):
		try:
			return import_module("korkem_manufacturing.services.calculations")
		except ModuleNotFoundError:
			self.fail("Missing deterministic domain calculation service")

	def test_four_facades(self):
		result = self.service().calculate_facade_area(600, 720, 4)
		self.assertEqual(result["area_m2"], "1.728")
		self.assertEqual(result["unit"], "m²")
		self.assertEqual(result["quantity"], 4)

	def test_panel_uses_same_geometry(self):
		service = self.service()
		self.assertEqual(
			service.calculate_panel_area(600, 720, 4), service.calculate_facade_area(600, 720, 4)
		)

	def test_decimal_dimensions_are_exact(self):
		self.assertEqual(self.service().calculate_panel_area(100.1, 200.2, 3)["area_m2"], "0.06012006")

	def test_invalid_dimensions_and_quantity(self):
		service = self.service()
		for value in (0, -1, True, float("nan"), float("inf"), "600", None, 1000001):
			with self.subTest(value=value), self.assertRaises(ValueError):
				service.calculate_panel_area(value, 720, 4)
		for value in (0, -1, 1.5, True, "4", 1000001):
			with self.subTest(quantity=value), self.assertRaises(ValueError):
				service.calculate_panel_area(600, 720, value)

	def test_selected_edges_in_metres(self):
		result = self.service().calculate_edge_length(600, 720, 4, width_edges=2, height_edges=1)
		self.assertEqual(result["length_m"], "7.68")
		self.assertEqual(result["unit"], "m")

	def test_edge_count_is_explicit_and_bounded(self):
		for count in (-1, 3, True, 0.5):
			with self.subTest(count=count), self.assertRaises(ValueError):
				self.service().calculate_edge_length(600, 720, 4, width_edges=count, height_edges=1)

	def test_sheet_quantity_is_only_area_lower_bound_not_cut_plan(self):
		result = self.service().calculate_material_quantity(
			600, 720, 4, sheet_width_mm=2800, sheet_height_mm=2070, waste_percent=10
		)
		self.assertEqual(result["required_area_m2"], "1.9008")
		self.assertEqual(result["minimum_sheets"], 1)
		self.assertFalse(result["cut_plan_verified"])

	def test_cannot_claim_that_oversize_panel_fits_a_sheet(self):
		with self.assertRaises(ValueError):
			self.service().calculate_material_quantity(
				3000, 3000, 1, sheet_width_mm=2800, sheet_height_mm=2070, waste_percent=0
			)

	def test_waste_is_required_and_not_invented(self):
		with self.assertRaises(TypeError):
			self.service().calculate_material_quantity(600, 720, 4, sheet_width_mm=2800, sheet_height_mm=2070)

	def test_waste_cannot_be_negative_or_nonfinite(self):
		for waste in (-1, 101, float("nan"), True):
			with self.subTest(waste=waste), self.assertRaises(ValueError):
				self.service().calculate_material_quantity(
					600, 720, 4, sheet_width_mm=2800, sheet_height_mm=2070, waste_percent=waste
				)
