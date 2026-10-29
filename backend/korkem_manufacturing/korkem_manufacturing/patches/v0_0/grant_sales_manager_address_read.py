# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A Sales Manager may read addresses and contacts, as a Sales User already may.

The same gap as `grant_sales_manager_account_read`, one step further along
the order. Found 2026-10-29 by CI: a user holding only «Sales Manager» could
not create a facade order for a customer **with an address** — ERPNext
renders the billing address onto the order (`render_address`) and checks
`read` on that Address first; its standard DocPerm grants that to Sales User
and not to Sales Manager. Every bench here happened to pick a customer
without one, so the order went through.

Read only, level 0. ERPNext and Frappe are not modified (ADR-0004).
"""

from korkem_manufacturing.patches.v0_0.grant_sales_manager_account_read import ROLE, grant_read


def execute():
	for doctype in ("Address", "Contact"):
		grant_read(doctype, ROLE)
