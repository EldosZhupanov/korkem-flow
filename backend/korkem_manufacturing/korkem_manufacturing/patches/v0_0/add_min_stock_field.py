"""«Минимум на складе» on a material's card: below it, the owner is told.

See services/stock_alerts.py. A plain Float on ERPNext's own Item; zero or
empty means nobody asked to be warned about this material.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELD = {
	"fieldname": "korkem_min_stock",
	"label": "Minimum on hand (warn below)",
	"fieldtype": "Float",
	"insert_after": "korkem_film_textured",
	"non_negative": 1,
}


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Item", "fieldname": FIELD["fieldname"]}):
		create_custom_field("Item", dict(FIELD))
	frappe.clear_cache(doctype="Item")
