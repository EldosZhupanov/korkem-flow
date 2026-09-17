"""Pure input-boundary tests; also runnable without a bench."""

import unittest

from korkem_ai.korkem_ai.tools import schema


class TestSchemaBoundaries(unittest.TestCase):
	def test_nonfinite_numbers_are_not_json_business_values(self):
		for value in (float("nan"), float("inf"), float("-inf")):
			with self.subTest(value=value):
				self.assertTrue(schema.validate(value, {"type": "number"}))

	def test_empty_properties_does_not_allow_arbitrary_arguments(self):
		self.assertTrue(schema.validate({"company": "foreign"}, {"type": "object", "properties": {}}))

	def test_positive_dimensions_exclude_zero(self):
		self.assertTrue(schema.validate(0, {"type": "number", "exclusiveMinimum": 0}))
		self.assertEqual(schema.validate(0.1, {"type": "number", "exclusiveMinimum": 0}), [])

	def test_string_and_array_bounds(self):
		self.assertTrue(schema.validate("", {"type": "string", "minLength": 1}))
		self.assertTrue(schema.validate("abcd", {"type": "string", "maxLength": 3}))
		self.assertTrue(schema.validate([], {"type": "array", "minItems": 1}))

	def test_explicit_open_object_remains_supported(self):
		self.assertEqual(schema.validate({"x": 1}, {"type": "object", "additionalProperties": True}), [])
