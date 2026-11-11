"""A film's collection (owner, 11.11.2026): ALDA, Solid Color, Древесные…

Each maker groups its films into collections of its own; a film's card names
the one it belongs to.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Item", "fieldname": "korkem_film_collection"}):
		create_custom_field(
			"Item",
			{
				"fieldname": "korkem_film_collection",
				"label": "Film collection",
				"fieldtype": "Data",
				"insert_after": "korkem_film_type",
			},
		)
	frappe.clear_cache(doctype="Item")
