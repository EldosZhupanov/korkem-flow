"""A PVC film's card (owner, 10.11.2026): what the film is, and what it costs us.

Each film is its maker's own — «Белый Матовый» from KIRA and from JS Group are
two films of two shades — so the card lives on the film's ERPNext Item, next
to its maker, colour, width and thickness. Everything is per running metre:
the shop buys and counts film by the metre, never by m².
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_film_code", "label": "Film code", "fieldtype": "Data",
	 "insert_after": "korkem_film_textured"},
	{"fieldname": "korkem_film_type", "label": "Film type", "fieldtype": "Data",
	 "insert_after": "korkem_film_code"},
	{"fieldname": "korkem_film_hex", "label": "Film sample colour", "fieldtype": "Data",
	 "insert_after": "korkem_film_type"},
	{"fieldname": "korkem_film_ral", "label": "Nearest RAL", "fieldtype": "Data",
	 "insert_after": "korkem_film_hex"},
	{"fieldname": "korkem_film_supplier", "label": "Film supplier", "fieldtype": "Link",
	 "options": "Supplier", "insert_after": "korkem_film_ral"},
	{"fieldname": "korkem_film_price_m", "label": "Supplier price per metre", "fieldtype": "Currency",
	 "insert_after": "korkem_film_supplier"},
	{"fieldname": "korkem_film_url", "label": "Film page", "fieldtype": "Data",
	 "insert_after": "korkem_film_price_m"},
)


def execute():
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Item", "fieldname": field["fieldname"]}):
			create_custom_field("Item", dict(field))
	frappe.clear_cache(doctype="Item")
