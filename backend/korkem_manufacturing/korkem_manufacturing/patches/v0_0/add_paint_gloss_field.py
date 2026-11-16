"""A paint group says its finish — matt, gloss, metallic… (owner, 15.11.2026:
«вид покрытия»): a mark for the paint shop, which paints a gloss as another
batch; the price stays what the manager types."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Sales Order Item", "fieldname": "korkem_paint_gloss"}):
		create_custom_field("Sales Order Item", {"fieldname": "korkem_paint_gloss", "label": "Paint finish",
												 "fieldtype": "Data", "insert_after": "korkem_line_coating",
												 "allow_on_submit": 1})
	frappe.clear_cache(doctype="Sales Order Item")
