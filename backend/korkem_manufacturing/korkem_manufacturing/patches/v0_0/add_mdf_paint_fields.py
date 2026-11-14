"""When a painted order went to dry (owner, 14.11.2026: the paint department).

A coat of paint is not done when the gun is put down: it dries, and a facade
touched too soon is painted again. «Сохнет с» is set when the painter puts the
order to dry; the paint department's board counts down from it, and the stage
«краска» is ticked once it is dry.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_paint_drying_since", "label": "Drying since", "fieldtype": "Datetime"},
	# The customer's own paint (owner, 14.11.2026): what he brought, and whether it is here.
	{"fieldname": "korkem_client_paint_note", "label": "Customer's paint", "fieldtype": "Data"},
	{"fieldname": "korkem_client_paint_in", "label": "Customer's paint is here", "fieldtype": "Check"},
)


def execute():
	after = "korkem_stage_paint_by"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Sales Order", "fieldname": field["fieldname"]}):
			create_custom_field(
				"Sales Order",
				{**field, "insert_after": after, "read_only": 1, "allow_on_submit": 1, "no_copy": 1},
			)
		after = field["fieldname"]
	frappe.clear_cache(doctype="Sales Order")
