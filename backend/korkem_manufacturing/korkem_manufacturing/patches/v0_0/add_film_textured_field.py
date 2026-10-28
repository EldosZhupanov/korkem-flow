"""«Текстурная» on a film's card: its parts are laid on the press unturned.

See services/press_layout.py. A plain Check on ERPNext's own Item, next to the
film's width and thickness.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELD = {
	"fieldname": "korkem_film_textured",
	"label": "Textured film (never turned on the press)",
	"fieldtype": "Check",
	"insert_after": "korkem_film_thickness_mm",
	"default": "0",
}


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Item", "fieldname": FIELD["fieldname"]}):
		create_custom_field("Item", dict(FIELD))
	frappe.clear_cache(doctype="Item")
