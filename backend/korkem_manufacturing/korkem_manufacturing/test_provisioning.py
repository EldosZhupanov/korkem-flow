# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Claiming a node — the one action that runs before anybody has an account.

These tests run on a bench that has a company, which makes it claimed — see
`is_claimed` for why a company is enough and ERPNext's own flag is not. So the
refusals are tested for real here, and the happy path against a patched
`is_claimed`; the full build of a company by ERPNext's wizard needs a genuinely
fresh site and was verified there (ADR-0027 records the measurements).
"""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.api import provisioning as api
from korkem_manufacturing.services import provisioning


class TestNodeIsAlreadyClaimed(IntegrationTestCase):
	"""Any bench with a company is claimed, and every door must be shut.

	The first version of this class assumed a developer bench is claimed
	because ERPNext's wizard has run. CI disagreed, and CI was right: our own
	`bootstrap.sh` seeds a company without ever running that wizard, so the
	flag is 0 on a bench that plainly belongs to somebody. The lesson is in
	`is_claimed`, not here — a node with a company must never be claimable,
	whatever ERPNext thinks of its own setup.
	"""

	def test_a_company_is_enough_to_count_as_claimed(self):
		"""Even with ERPNext's own flag unset, as on a bootstrapped bench."""
		self.assertTrue(frappe.db.count("Company"))
		with patch.object(provisioning.frappe, "is_setup_complete", return_value=False):
			self.assertTrue(provisioning.is_claimed())

	def test_status_reports_claimed(self):
		self.assertTrue(provisioning.is_claimed())
		self.assertEqual(api.status()["claimed"], True)

	def test_status_tells_a_stranger_nothing_else(self):
		"""An unauthenticated caller learns the state and the languages.

		Not the company, not the owner, not how many people work here. A node
		on a tunnel answers this to anyone who asks.
		"""
		self.assertEqual(set(api.status()), {"claimed", "languages"})

	def test_a_claimed_node_refuses_even_with_a_right_code(self):
		with self.assertRaises(provisioning.NodeAlreadyClaimed):
			provisioning.claim(
				code="WHATEVER",
				company="Second Company",
				owner_email="intruder@example.com",
				owner_name="Intruder",
				owner_password="x",
			)

	def test_the_endpoint_answers_409_rather_than_a_traceback(self):
		result = api.claim(
			code="WHATEVER",
			company="Second Company",
			owner_email="intruder@example.com",
			owner_password="x",
		)
		self.assertEqual(result["status"], "already_claimed")
		self.assertEqual(frappe.local.response.get("http_status_code"), 409)

	def test_no_claim_code_is_minted_for_a_claimed_node(self):
		with self.assertRaises(provisioning.NodeAlreadyClaimed):
			provisioning.claim_code()


class TestClaimCode(IntegrationTestCase):
	"""The code is the only thing between an unclaimed node and a stranger."""

	def setUp(self):
		self.addCleanup(frappe.db.set_default, provisioning.CLAIM_CODE_KEY, "")
		self.addCleanup(frappe.db.set_default, provisioning.CLAIM_ATTEMPTS_KEY, "")

	def test_a_code_is_long_and_unambiguous(self):
		with patch.object(provisioning, "is_claimed", return_value=False):
			code = provisioning.claim_code()

		self.assertEqual(len(code), 16)
		# No I, L, O or U: a code is read off a screen and typed on a phone in a
		# workshop, and those four are what people get wrong.
		self.assertFalse(set(code) & set("ILOU"))

	def test_the_plain_code_is_never_stored(self):
		with patch.object(provisioning, "is_claimed", return_value=False):
			code = provisioning.claim_code()

		stored = frappe.db.get_default(provisioning.CLAIM_CODE_KEY)
		self.assertNotEqual(stored, code)
		self.assertNotIn(code, stored)
		self.assertEqual(len(stored), 64)

	def test_two_codes_are_not_the_same(self):
		with patch.object(provisioning, "is_claimed", return_value=False):
			first = provisioning.claim_code()
			second = provisioning.claim_code()
		self.assertNotEqual(first, second)

	def test_a_wrong_code_is_refused_and_counted(self):
		with patch.object(provisioning, "is_claimed", return_value=False):
			provisioning.claim_code()

			with self.assertRaises(provisioning.ClaimCodeRefused):
				provisioning.claim(
					code="WRONGWRONGWRONG1",
					company="X",
					owner_email="a@example.com",
					owner_name="A",
					owner_password="p",
				)

		self.assertEqual(int(frappe.db.get_default(provisioning.CLAIM_ATTEMPTS_KEY)), 1)

	def test_guessing_stops_after_ten_tries(self):
		with patch.object(provisioning, "is_claimed", return_value=False):
			provisioning.claim_code()
			frappe.db.set_default(
				provisioning.CLAIM_ATTEMPTS_KEY, str(provisioning.MAX_ATTEMPTS)
			)

			with self.assertRaises(provisioning.ClaimCodeRefused) as refusal:
				provisioning.claim(
					code="ANYTHINGATALL123",
					company="X",
					owner_email="a@example.com",
					owner_name="A",
					owner_password="p",
				)

		self.assertIn("Restart the node", str(refusal.exception))

	def test_a_node_with_no_code_yet_refuses_rather_than_letting_anyone_in(self):
		frappe.db.set_default(provisioning.CLAIM_CODE_KEY, "")
		with patch.object(provisioning, "is_claimed", return_value=False):
			with self.assertRaises(provisioning.ClaimCodeRefused):
				provisioning.claim(
					code="",
					company="X",
					owner_email="a@example.com",
					owner_name="A",
					owner_password="p",
				)


class TestTheCompanyAbbreviation(IntegrationTestCase):
	"""It ends up inside every warehouse and account name, permanently."""

	def test_punctuation_never_reaches_a_warehouse_name(self):
		self.assertEqual(provisioning._abbreviation("Мебель+"), "МЕБЕЛ")
		self.assertEqual(provisioning._abbreviation('ТОО "Астана"'), "ТООАС")

	def test_a_nameless_company_still_gets_something_usable(self):
		self.assertEqual(provisioning._abbreviation("!!!"), "KRK")
