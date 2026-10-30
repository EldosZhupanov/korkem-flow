"""A month-end count is an ERPNext Stock Reconciliation marked as ours.

See services/stock_count.py. The mark tells the warehouse's own counts apart
from any reconciliation an accountant posts in the desk.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELD = {
	"fieldname": "korkem_stock_count",
	"label": "KORKEM stock count",
	"fieldtype": "Check",
	"insert_after": "purpose",
	"read_only": 1,
	"default": "0",
}


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Stock Reconciliation", "fieldname": FIELD["fieldname"]}):
		create_custom_field("Stock Reconciliation", dict(FIELD))
	frappe.clear_cache(doctype="Stock Reconciliation")
