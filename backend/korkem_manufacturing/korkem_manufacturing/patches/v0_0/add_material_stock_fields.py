"""Fields a stocked material needs, on ERPNext's own Item and Stock Entry.

A material *is* an ERPNext Item — stock and valuation stay in ERPNext's ledger,
never in a second one — and these fields say what kind of sheet or film it is,
so the warehouse can pick «МДФ 16, Kastamonu» from lists instead of typing.
A receipt *is* a Material Receipt Stock Entry; the supplier it came from is
recorded on it.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

ITEM_FIELDS = (
	{"fieldname": "korkem_material_section", "label": "KORKEM material", "fieldtype": "Section Break", "insert_after": "description", "collapsible": 1},
	{"fieldname": "korkem_material_kind", "label": "Material kind", "fieldtype": "Select", "options": "\nМДФ\nПлёнка ПВХ\nПрочее", "insert_after": "korkem_material_section"},
	{"fieldname": "korkem_material_company", "label": "Material company", "fieldtype": "Link", "options": "Company", "insert_after": "korkem_material_kind"},
	{"fieldname": "korkem_thickness_mm", "label": "Thickness, mm", "fieldtype": "Data", "insert_after": "korkem_material_company"},
	{"fieldname": "korkem_manufacturer", "label": "Manufacturer", "fieldtype": "Data", "insert_after": "korkem_thickness_mm"},
	{"fieldname": "korkem_material_column", "fieldtype": "Column Break", "insert_after": "korkem_manufacturer"},
	{"fieldname": "korkem_color", "label": "Colour / article", "fieldtype": "Data", "insert_after": "korkem_material_column"},
	{"fieldname": "korkem_film_width_mm", "label": "Film width, mm", "fieldtype": "Data", "insert_after": "korkem_color"},
	{"fieldname": "korkem_film_thickness_mm", "label": "Film thickness, mm", "fieldtype": "Data", "insert_after": "korkem_film_width_mm"},
)

STOCK_ENTRY_FIELDS = (
	{"fieldname": "korkem_supplier", "label": "Bought from", "fieldtype": "Link", "options": "Supplier", "insert_after": "stock_entry_type", "allow_on_submit": 0},
	{"fieldname": "korkem_material_receipt", "label": "KORKEM material receipt", "fieldtype": "Check", "insert_after": "korkem_supplier", "read_only": 1},
)


def execute():
	for doctype, fields in (("Item", ITEM_FIELDS), ("Stock Entry", STOCK_ENTRY_FIELDS)):
		for field in fields:
			if not frappe.db.exists("Custom Field", {"dt": doctype, "fieldname": field["fieldname"]}):
				create_custom_field(doctype, dict(field))
		frappe.clear_cache(doctype=doctype)
