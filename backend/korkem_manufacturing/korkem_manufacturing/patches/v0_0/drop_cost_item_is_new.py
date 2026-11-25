"""A Cost Item field once named `is_new` (25.11.2026) shadowed
Document.is_new(): a site migrated with it keeps the column, and every
Cost Item loaded from it then breaks. The field is `from_floor` now; the
old column goes."""

import frappe


def execute():
	if frappe.db.table_exists("Cost Item") and frappe.db.has_column("Cost Item", "is_new"):
		frappe.db.sql_ddl("alter table `tabCost Item` drop column `is_new`")
