"""Real registry -> API -> domain; model double only at the provider boundary."""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import catalog, registry


class TestCalculationTools(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")
		super().tearDown()

	def test_facade_tool_calls_domain(self):
		result = registry.execute(
			"manufacturing.calculate_facade_area", {"width_mm": 600, "height_mm": 720, "quantity": 4}
		)
		self.assertTrue(result["ok"], result)
		self.assertEqual(result["data"]["area_m2"], "1.728")

	def test_bad_dimensions_are_refused(self):
		for value in (0, -1, True, float("nan")):
			with self.subTest(value=value):
				result = registry.execute(
					"manufacturing.calculate_facade_area",
					{"width_mm": value, "height_mm": 720, "quantity": 4},
				)
				self.assertFalse(result["ok"])
				self.assertEqual(result["error"]["code"], "invalid_arguments")

	def test_guest_cannot_execute_calculation(self):
		frappe.set_user("Guest")
		self.assertFalse(
			registry.execute(
				"manufacturing.calculate_facade_area", {"width_mm": 600, "height_mm": 720, "quantity": 4}
			)["ok"]
		)

	def test_arbitrary_company_cannot_be_passed(self):
		result = registry.execute(
			"manufacturing.calculate_facade_area",
			{"width_mm": 600, "height_mm": 720, "quantity": 4, "company": "foreign"},
		)
		self.assertEqual(result["error"]["code"], "invalid_arguments")

	def test_calculation_has_no_side_effect_and_uses_same_api(self):
		from korkem_manufacturing.api import calculations

		spec = registry.get("manufacturing.calculate_facade_area")
		self.assertFalse(spec.requires_confirmation)
		self.assertIs(spec.handler, calculations.calculate_facade_area)

	def test_ru_kk_and_mixed_keep_calculation_tool_in_shortlist(self):
		from korkem_ai.korkem_ai.context import tools

		for question in (
			"Посчитай площадь четырех фасадов 600 на 720",
			"600-ге 720 өлшемдегі төрт фасадтың жалпы ауданын есепте",
			"Брат, 600 на 720 төрт фасад, квадратын санап берші",
		):
			with self.subTest(question=question):
				offered, _ = tools.offered(question)
				self.assertIn("manufacturing.calculate_facade_area", [spec.name for spec in offered])
