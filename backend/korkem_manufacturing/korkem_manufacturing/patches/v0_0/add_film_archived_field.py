"""A film in the archive (owner, 11.11.2026).

A film with receipts, sales or orders behind it is not deleted: it goes to
the archive — off the maker's list and off the order's pick — and comes back
with one button. Its metres, if any are left, can still be sold.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Item", "fieldname": "korkem_film_archived"}):
		create_custom_field(
			"Item",
			{
				"fieldname": "korkem_film_archived",
				"label": "Film archived",
				"fieldtype": "Check",
				"insert_after": "korkem_film_collection",
			},
		)
	frappe.clear_cache(doctype="Item")
