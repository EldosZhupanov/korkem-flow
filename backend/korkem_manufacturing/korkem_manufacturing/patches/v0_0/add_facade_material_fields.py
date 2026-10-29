"""A write-off made for a facade order names the order.

See `services/facade_materials.py`: when a facade order goes into work its
held material is issued by one ERPNext Material Issue, and this field is how
the order finds what was already written off for it.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELD = {
	"fieldname": "korkem_sales_order",
	"label": "For sales order",
	"fieldtype": "Link",
	"options": "Sales Order",
	"insert_after": "stock_entry_type",
	"read_only": 1,
	"search_index": 1,
}


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": FIELD["fieldname"]}):
		create_custom_field("Stock Entry", dict(FIELD))
	frappe.clear_cache(doctype="Stock Entry")
