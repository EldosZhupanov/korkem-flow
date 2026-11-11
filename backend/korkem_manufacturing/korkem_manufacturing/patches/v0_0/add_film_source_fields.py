"""Where film is bought (owner, 11.11.2026): a source's own card.

One maker is bought in several places — its Astana branch, its Almaty branch,
a local wholesaler — and each has its own telephone and its own person. A
source is ERPNext's own `Supplier`; these fields are its card.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_src_kind", "label": "Source kind", "fieldtype": "Data"},
	{"fieldname": "korkem_src_city", "label": "City", "fieldtype": "Data"},
	{"fieldname": "korkem_src_contact", "label": "Contact person", "fieldtype": "Data"},
	{"fieldname": "korkem_src_phone", "label": "Phone", "fieldtype": "Data"},
	{"fieldname": "korkem_src_phone2", "label": "Second phone", "fieldtype": "Data"},
	{"fieldname": "korkem_src_whatsapp", "label": "WhatsApp", "fieldtype": "Data"},
	{"fieldname": "korkem_src_address", "label": "Warehouse address", "fieldtype": "Data"},
	{"fieldname": "korkem_src_lead", "label": "Delivery time", "fieldtype": "Data"},
	{"fieldname": "korkem_src_min_order", "label": "Smallest order", "fieldtype": "Data"},
	{"fieldname": "korkem_src_note", "label": "Note", "fieldtype": "Small Text"},
	{"fieldname": "korkem_src_makers", "label": "Makers sold", "fieldtype": "Small Text"},
)


def execute():
	after = "supplier_name"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Supplier", "fieldname": field["fieldname"]}):
			create_custom_field("Supplier", {**field, "insert_after": after})
		after = field["fieldname"]
	frappe.clear_cache(doctype="Supplier")
