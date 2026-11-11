"""Who paid for bringing a roll, and when it was settled (owner, 11.11.2026).

From the film department's own cash; by an employee out of his pocket — to
be given back; not paid yet — owed to the carrier; or by the supplier. The
film department keeps its own cash book: these are its expenses.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_delivery_payer", "label": "Delivery paid by (how)", "fieldtype": "Data"},
	{"fieldname": "korkem_delivery_paid_by", "label": "Delivery paid by (who)", "fieldtype": "Data"},
	{"fieldname": "korkem_delivery_method", "label": "Delivery paid in", "fieldtype": "Data"},
	{"fieldname": "korkem_delivery_settled_on", "label": "Delivery settled on", "fieldtype": "Date"},
	{"fieldname": "korkem_delivery_settled_method", "label": "Delivery settled in", "fieldtype": "Data"},
)


def execute():
	after = "korkem_film_due"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": field["fieldname"]}):
			create_custom_field(
				"Stock Entry", {**field, "insert_after": after, "read_only": 1, "allow_on_submit": 1}
			)
		after = field["fieldname"]
	frappe.clear_cache(doctype="Stock Entry")
