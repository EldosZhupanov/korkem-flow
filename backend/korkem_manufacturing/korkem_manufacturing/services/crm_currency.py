# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Frappe CRM's base currency is the company's own currency.

CRM converts every organization and deal into one base currency
(`FCRM Settings.currency`). Left at its default, that base is not tenge, so
every new organization in tenge asks an exchange-rate website for KZT → INR.
Offline the save fails outright ("Failed to fetch exchange rate"), which breaks
a factory without internet (R8) and turned twelve tests red for a reason that
was not theirs. With the base equal to the company currency, a tenge record
needs no conversion and no network at all.
"""

from __future__ import annotations

import frappe

SETTINGS = "FCRM Settings"
#: CRM documents that store a rate into the base currency.
CONVERTED = ("CRM Organization", "CRM Deal")


def align(company: str | None = None) -> str | None:
	"""Make CRM's base currency the company's. Returns it when changed, else None.

	Stored rates were measured against the old base, so they are reset: 1 where
	the record is already in the new base, empty elsewhere — CRM fetches a fresh
	one the next time that record is saved.
	"""
	if not frappe.db.exists("DocType", SETTINGS):
		return None
	company = company or _default_company()
	currency = company and frappe.db.get_value("Company", company, "default_currency")
	if not currency or frappe.db.get_single_value(SETTINGS, "currency") == currency:
		return None

	frappe.db.set_single_value(SETTINGS, "currency", currency)
	for doctype in CONVERTED:
		if not (frappe.db.has_column(doctype, "exchange_rate") and frappe.db.has_column(doctype, "currency")):
			continue
		frappe.db.sql(
			f"update `tab{doctype}` set exchange_rate = 1 where ifnull(currency, '') in ('', %s)",
			currency,
		)
		frappe.db.sql(
			f"update `tab{doctype}` set exchange_rate = 0 where ifnull(currency, '') not in ('', %s)",
			currency,
		)
	return currency


def on_company_created(doc, method=None) -> None:
	"""The first company on a node decides CRM's base currency."""
	if frappe.db.count("Company") == 1:
		align(doc.name)


def _default_company() -> str | None:
	return frappe.defaults.get_global_default("company") or frappe.db.get_value("Company", {}, "name")
