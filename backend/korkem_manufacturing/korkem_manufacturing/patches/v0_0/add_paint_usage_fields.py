"""Paint is taken off the store by itself (owner, 15.11.2026: «водишь м² —
система сама определяет, сколько уходит краски»): «Покрашено» issues the
order's m² times the shop's kilograms a m²; a count puts the store right. Each
such entry says which order it was for, why, and how many m² it painted."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_paint_use", "label": "Paint taken for", "fieldtype": "Data"},
	{"fieldname": "korkem_paint_order", "label": "Paint for order", "fieldtype": "Data"},
	{"fieldname": "korkem_paint_m2", "label": "Paint for m²", "fieldtype": "Float"},
)


def execute():
	after = "korkem_receipt_dept"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": field["fieldname"]}):
			create_custom_field("Stock Entry", {**field, "insert_after": after, "read_only": 1, "allow_on_submit": 1})
		after = field["fieldname"]
	frappe.clear_cache(doctype="Stock Entry")
