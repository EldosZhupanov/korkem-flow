"""A film sale's invoice to the customer (owner, 14.11.2026: «выставить счёт
на оплату»): its number — one after another within the company and the
year — the day it was made, and the day it is to be paid by.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_film_invoice_no", "label": "Invoice no.", "fieldtype": "Data"},
	{"fieldname": "korkem_film_invoice_on", "label": "Invoice date", "fieldtype": "Date"},
	{"fieldname": "korkem_film_invoice_due", "label": "Invoice to be paid by", "fieldtype": "Date"},
)


def execute():
	after = "korkem_supplier_paid_from"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": field["fieldname"]}):
			create_custom_field(
				"Stock Entry", {**field, "insert_after": after, "read_only": 1, "allow_on_submit": 1, "no_copy": 1}
			)
		after = field["fieldname"]
	frappe.clear_cache(doctype="Stock Entry")
