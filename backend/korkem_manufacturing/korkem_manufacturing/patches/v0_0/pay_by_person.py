# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Pay is a person's, not a login's (owner, 26.11.2026: «можно начислять …
бывают люди возраста 50 лет, они же не умеют пользоваться»).

An advance, a fine, a bonus and a payout now name the person (`Employee`);
the login stays on the row when there is one. Rows written before name only
the login: each gets the person whose login it is, in the row's company.
A login with no person stays as it was — the statement still finds it by the
login (`payroll._key`), so nothing written is lost. Idempotent: a row that
has its person is left alone.
"""

from __future__ import annotations

import frappe


def execute():
	for doctype in ("Pay Adjustment", "Pay Payout"):
		if not frappe.db.has_column(doctype, "person"):
			continue
		for row in frappe.get_all(doctype, filters={"person": ["is", "not set"], "employee": ["is", "set"]},
								  fields=["name", "company", "employee"], limit_page_length=0):
			person = frappe.db.get_value("Employee", {"user_id": row.employee, "company": row.company}, "name")
			if person:
				frappe.db.set_value(doctype, row.name, "person", person, update_modified=False)
