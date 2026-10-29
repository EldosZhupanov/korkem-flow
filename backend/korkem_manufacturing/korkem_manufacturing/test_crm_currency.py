# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""A tenge organization is saved without asking the internet for a rate."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import setup
from korkem_manufacturing.services import crm_currency

RATE_LOOKUP = "crm.fcrm.doctype.crm_organization.crm_organization.get_exchange_rate"


def _offline(*args, **kwargs):
	raise AssertionError(f"asked the internet for a rate: {args}")


class TestCrmCurrency(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")

	def test_the_base_becomes_the_company_currency(self):
		frappe.db.set_single_value(crm_currency.SETTINGS, "currency", "INR")

		self.assertEqual(crm_currency.align(setup.COMPANY), setup.CURRENCY)
		self.assertEqual(frappe.db.get_single_value(crm_currency.SETTINGS, "currency"), setup.CURRENCY)

	def test_aligning_twice_changes_nothing(self):
		crm_currency.align(setup.COMPANY)
		self.assertIsNone(crm_currency.align(setup.COMPANY))

	def test_a_rate_measured_against_the_old_base_is_reset(self):
		frappe.db.set_single_value(crm_currency.SETTINGS, "currency", "INR")
		# Written straight to the table: a real insert would ask the internet.
		org = frappe.get_doc({"doctype": "CRM Organization", "organization_name": "Old Base LLC"})
		org.name = "Old Base LLC"
		org.db_insert()
		frappe.db.set_value("CRM Organization", org.name, {"currency": setup.CURRENCY, "exchange_rate": 0.18})

		crm_currency.align(setup.COMPANY)
		self.assertEqual(frappe.db.get_value("CRM Organization", org.name, "exchange_rate"), 1)

	def test_a_tenge_organization_needs_no_network(self):
		crm_currency.align(setup.COMPANY)
		with patch(RATE_LOOKUP, side_effect=_offline):
			org = frappe.get_doc(
				{
					"doctype": "CRM Organization",
					"organization_name": "Offline Buyer LLC",
					"currency": setup.CURRENCY,
				}
			).insert()
		self.assertEqual(org.exchange_rate, 1)
