"""Give Sales Order back the standard permissions `grant_order_read` hid.

Before 2026-10-26 `grant_order_read` inserted Custom DocPerm rows into a
doctype that had none. Frappe then stops reading that doctype's standard
DocPerm rows altogether, so on every site where it ran first, Sales User,
Sales Manager, Accounts User, Stock User and the rest could no longer open a
single sales order — only Administrator could.

This copies back each standard (role, permlevel) rule that has no Custom
DocPerm counterpart. A rule an administrator *changed* has a counterpart and is
left exactly as it is; only rules that were never copied are restored.
"""

import frappe

#: Sales Order is where the loss was found. The other two are where
#: price_visibility adds Custom DocPerm rows, so they are checked the same way.
DOCTYPES = ("Sales Order", "Delivery Note", "Purchase Order")

#: Columns of DocPerm that are permission data rather than row bookkeeping.
_SKIP = {"name", "parent", "parenttype", "parentfield", "idx", "owner", "creation", "modified", "modified_by", "doctype", "docstatus"}


def execute():
	for doctype in DOCTYPES:
		restore(doctype)


def restore(doctype: str) -> None:
	if not frappe.db.exists("Custom DocPerm", {"parent": doctype}):
		# No custom rules at all: Frappe still reads the standard ones.
		return

	have = {
		(row.role, row.permlevel)
		for row in frappe.get_all("Custom DocPerm", filters={"parent": doctype}, fields=["role", "permlevel"])
	}
	for standard in frappe.get_all("DocPerm", filters={"parent": doctype}, fields=["*"]):
		if (standard.role, standard.permlevel) in have:
			continue
		row = {key: value for key, value in standard.items() if key not in _SKIP}
		frappe.get_doc(
			{
				"doctype": "Custom DocPerm",
				"parent": doctype,
				"parenttype": "DocType",
				"parentfield": "permissions",
				**row,
			}
		).insert(ignore_permissions=True)

	frappe.clear_cache(doctype=doctype)
