"""PVC glue sold on with the film (owner, 17.11.2026: «можем перепродавать с
наценкой… продаётся ведром и литром»): a sale's line keeps how it was sold —
two buckets, five litres — and the price of one, beside the kilograms the
store counts and their price a kilo."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_sale_unit", "label": "Sold by", "fieldtype": "Data"},
	{"fieldname": "korkem_sale_units", "label": "Sold, units", "fieldtype": "Float"},
	{"fieldname": "korkem_sale_unit_price", "label": "Sold at, per unit", "fieldtype": "Currency"},
)


def execute():
	after = "korkem_film_price_m"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Stock Entry Detail", "fieldname": field["fieldname"]}):
			create_custom_field("Stock Entry Detail", {**field, "insert_after": after, "read_only": 1})
		after = field["fieldname"]
	frappe.clear_cache(doctype="Stock Entry Detail")
