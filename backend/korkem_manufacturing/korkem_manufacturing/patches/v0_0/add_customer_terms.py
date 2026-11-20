"""A customer's own terms (owner, 20.11.2026): a furniture maker pays «по
разному» — a discount off the price list, or a price of his own a m² — a
debt limit of his own over the shop's, and where he came from."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_price_discount_pct", "label": "Discount off the price list, %", "fieldtype": "Float"},
	{"fieldname": "korkem_price_pvc_m2", "label": "Own price a m², PVC", "fieldtype": "Float"},
	{"fieldname": "korkem_price_paint_m2", "label": "Own price a m², paint", "fieldtype": "Float"},
	{"fieldname": "korkem_debt_limit", "label": "Debt limit", "fieldtype": "Float"},
	{"fieldname": "korkem_source", "label": "Came from", "fieldtype": "Data"},
)


def execute():
	after = "korkem_tags"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Customer", "fieldname": field["fieldname"]}):
			create_custom_field("Customer", {**field, "insert_after": after})
		after = field["fieldname"]
	frappe.clear_cache(doctype="Customer")
