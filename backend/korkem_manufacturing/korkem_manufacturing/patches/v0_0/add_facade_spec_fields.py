"""The technical line of a facade position: thickness, decors, edge profile, colour group.

See `services/facade_spec.py`. The colour group may change on a submitted
order — grouping a batch for the press is planning, not a change to what was
sold — so it alone is `allow_on_submit`.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{
		"fieldname": "korkem_thickness_mm",
		"label": "Thickness, mm",
		"fieldtype": "Int",
		"insert_after": "korkem_finish",
	},
	{
		"fieldname": "korkem_decor_top",
		"label": "Decor, face",
		"fieldtype": "Data",
		"insert_after": "korkem_thickness_mm",
	},
	{
		"fieldname": "korkem_decor_bottom",
		"label": "Decor, back",
		"fieldtype": "Data",
		"insert_after": "korkem_decor_top",
	},
	{
		"fieldname": "korkem_edge_profile",
		"label": "Edge profile",
		"fieldtype": "Data",
		"insert_after": "korkem_decor_bottom",
	},
	{
		"fieldname": "korkem_color_group",
		"label": "Colour group",
		"fieldtype": "Data",
		"insert_after": "korkem_edge_profile",
		"allow_on_submit": 1,
	},
)


def execute():
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Sales Order Item", "fieldname": field["fieldname"]}):
			create_custom_field("Sales Order Item", dict(field))
	frappe.clear_cache(doctype="Sales Order Item")
