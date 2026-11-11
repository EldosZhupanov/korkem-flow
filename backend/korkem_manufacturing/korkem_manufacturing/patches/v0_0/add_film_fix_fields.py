"""A film movement entered wrong and made again right (owner, 11.11.2026).

The wrong one is cancelled, not deleted, and points to the right one; the
right one points back, with why it was made again. The history shows both:
the wrong one struck through.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_film_replaced_by", "label": "Corrected by", "fieldtype": "Data"},
	{"fieldname": "korkem_film_replaces", "label": "Corrects", "fieldtype": "Data"},
	{"fieldname": "korkem_film_fix_reason", "label": "Why corrected", "fieldtype": "Small Text"},
)


def execute():
	after = "korkem_film_payments"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": field["fieldname"]}):
			create_custom_field(
				"Stock Entry", {**field, "insert_after": after, "read_only": 1, "allow_on_submit": 1}
			)
		after = field["fieldname"]
	frappe.clear_cache(doctype="Stock Entry")
