"""Who brought a roll, and how to reach him (owner, 12.11.2026: «контакт
такси на всякий случай»): the driver's name and phone, both optional.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_delivery_driver", "label": "Driver", "fieldtype": "Data"},
	{"fieldname": "korkem_delivery_phone", "label": "Driver's phone", "fieldtype": "Data"},
)


def execute():
	after = "korkem_delivery_settled_method"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": field["fieldname"]}):
			create_custom_field(
				"Stock Entry", {**field, "insert_after": after, "read_only": 1, "allow_on_submit": 1}
			)
		after = field["fieldname"]
	frappe.clear_cache(doctype="Stock Entry")
