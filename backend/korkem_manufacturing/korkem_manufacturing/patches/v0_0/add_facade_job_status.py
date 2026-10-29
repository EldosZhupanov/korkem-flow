"""Where a facade line stands on the shop floor: queued, in work, done.

Kept on the order line itself (`allow_on_submit`), so a submitted order can
move through the shop without being amended, and so the person who sold it
sees the same status the cutter set.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELD = {
	"fieldname": "korkem_facade_status",
	"label": "Facade status",
	"fieldtype": "Select",
	"options": "В очереди\nВ работе\nГотово",
	"default": "В очереди",
	"insert_after": "korkem_customer_material",
	"allow_on_submit": 1,
	"read_only": 1,
	"in_list_view": 0,
}


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Sales Order Item", "fieldname": FIELD["fieldname"]}):
		create_custom_field("Sales Order Item", dict(FIELD))
	frappe.clear_cache(doctype="Sales Order Item")
