# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""One spelling per phone (owner, 18.11.2026): typed any way, kept as
+77015551234, shown as +7 (701) 555-12-34."""

from __future__ import annotations

from unittest import TestCase

from korkem_manufacturing.services import phones


class TestPhones(TestCase):
	def test_every_way_of_typing_a_kazakh_phone_is_one_phone(self):
		for typed in ("8 701 555 12 34", "87015551234", "+7 (701) 555-12-34", "7015551234", "+77015551234",
					  "7 701 555 1234", " 8-701-555-12-34 "):
			with self.subTest(typed=typed):
				self.assertEqual(phones.canonical(typed), "+77015551234")

	def test_a_foreign_phone_keeps_its_own_code(self):
		self.assertEqual(phones.canonical("+996 555 123 456"), "+996555123456")
		self.assertEqual(phones.canonical("+998 90 123 45 67"), "+998901234567")

	def test_nothing_typed_is_nothing_and_a_wrong_number_is_refused(self):
		self.assertIsNone(phones.canonical(""))
		self.assertIsNone(phones.canonical(None))
		for typed in ("123", "555 12 34", "+7 701 555", "8 701 555 12 34 5", "звонить"):
			with self.subTest(typed=typed), self.assertRaises(ValueError):
				phones.canonical(typed)

	def test_lenient_keeps_what_does_not_read_as_a_phone(self):
		self.assertEqual(phones.lenient("8 701 555 12 34"), "+77015551234")
		self.assertEqual(phones.lenient(" 222 "), "222")
		self.assertIsNone(phones.lenient(""))

	def test_shown_with_brackets_and_dashes(self):
		self.assertEqual(phones.pretty("+77015551234"), "+7 (701) 555-12-34")
		self.assertEqual(phones.pretty("+996555123456"), "+996555123456")

	def test_the_same_phone_whatever_its_spelling(self):
		self.assertTrue(phones.same("8 701 555 12 34", "+77015551234"))
		self.assertFalse(phones.same("8 701 555 12 34", "8 701 555 12 35"))
		self.assertFalse(phones.same(None, None))
