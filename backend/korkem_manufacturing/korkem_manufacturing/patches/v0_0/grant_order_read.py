# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Let the people who act on an order be allowed to read it.

Found by a review of the five published endpoints, and confirmed against
`DocPerm` on a live site rather than reasoned about: ERPNext grants `read` on
`Sales Order` to Sales, Stock, Accounts and Maintenance roles — and to none of
the manufacturing or delivery ones.

That is a defensible default for stock ERPNext and wrong for a factory. A
cutting operator starting a job, and a driver loading it, both act **on** a
sales order:

    services/production.py   order.check_permission("read")   → start_production
    services/dispatch.py     order.check_permission("read")   → create_delivery

Without this the role gate at the API lets them through and the service
refuses them three calls later, with a permission error about a document they
were never told they could not see.

`Custom DocPerm` extends the doctype rather than editing it — `erpnext` itself
is never modified (ADR-0004). Read only: none of these roles gains write,
submit or cancel on a sales order, and none of them needs it.
"""

import frappe

DOCTYPE = "Sales Order"

#: Roles whose *own* work requires reading the order they are acting on.
NEEDS_READ = (
	"Manufacturing User",
	"Manufacturing Manager",
	"Delivery User",
	"Delivery Manager",
)


def execute():
	for role in NEEDS_READ:
		if not frappe.db.exists("Role", role):
			# An app that installs those roles may not be present on every site.
			continue
		if frappe.db.exists(
			"Custom DocPerm", {"parent": DOCTYPE, "role": role, "permlevel": 0}
		):
			continue
		if frappe.db.exists("DocPerm", {"parent": DOCTYPE, "role": role, "read": 1}):
			# Already granted upstream. Nothing to add, and adding it anyway
			# would leave a second row saying the same thing.
			continue

		frappe.get_doc(
			{
				"doctype": "Custom DocPerm",
				"parent": DOCTYPE,
				"parenttype": "DocType",
				"parentfield": "permissions",
				"role": role,
				"permlevel": 0,
				"read": 1,
				"select": 1,
			}
		).insert(ignore_permissions=True)

	frappe.clear_cache(doctype=DOCTYPE)
