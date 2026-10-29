# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A Sales Manager may read accounts, as a Sales User already may.

Found 2026-10-27: a user holding only «Sales Manager» could not create a facade
order. ERPNext fills the order's receivable account (`get_party_account`) and
checks `read` on that Account first; its standard DocPerm grants that read to
Sales User and not to Sales Manager. The order failed with «User don't have
permissions to select/read this account» while a plain seller succeeded.

Read only, level 0 — the same row Sales User has upstream. No write: a Sales
Manager edits no chart of accounts. `Custom DocPerm` extends the doctype;
ERPNext itself is not modified (ADR-0004).
"""

import frappe

DOCTYPE = "Account"
ROLE = "Sales Manager"


def execute():
	grant_read(DOCTYPE, ROLE)


def grant_read(doctype: str, role: str) -> None:
	"""Read and select on `doctype` for `role`, as a Custom DocPerm. Idempotent."""
	if not frappe.db.exists("Role", role):
		return
	if frappe.db.exists("Custom DocPerm", {"parent": doctype, "role": role, "permlevel": 0, "read": 1}):
		return
	# Copy the standard rows first: Frappe ignores every standard DocPerm of a
	# doctype once it has one Custom DocPerm (see grant_order_read.py).
	from frappe.permissions import setup_custom_perms

	setup_custom_perms(doctype)
	existing = frappe.db.get_value("Custom DocPerm", {"parent": doctype, "role": role, "permlevel": 0}, "name")
	if existing:
		frappe.db.set_value("Custom DocPerm", existing, {"read": 1, "select": 1})
	else:
		frappe.get_doc(
			{
				"doctype": "Custom DocPerm",
				"parent": doctype,
				"parenttype": "DocType",
				"parentfield": "permissions",
				"role": role,
				"permlevel": 0,
				"read": 1,
				"select": 1,
			}
		).insert(ignore_permissions=True)
	frappe.clear_cache(doctype=doctype)
