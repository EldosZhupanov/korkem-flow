"""The film department (owner, 10.11.2026): its prices, its movements, its customers.

The department buys film from wholesalers and sells it by the running metre —
a cut or a whole roll — to its own customers, and hands film to the shop. All
of it is ERPNext's own stock: a sale, a hand-over to the shop and a write-off
are each a Material Issue (`Stock Entry`) that says which it is, so there is
one ledger and the metres on hand are ERPNext's figure.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = {
	"Item": (
		{"fieldname": "korkem_film_retail_m", "label": "Retail price per metre", "fieldtype": "Currency",
		 "insert_after": "korkem_film_price_m"},
		{"fieldname": "korkem_film_wholesale_m", "label": "Wholesale price per metre", "fieldtype": "Currency",
		 "insert_after": "korkem_film_retail_m"},
	),
	"Stock Entry": (
		{"fieldname": "korkem_film_kind", "label": "Film movement", "fieldtype": "Data",
		 "insert_after": "korkem_material_receipt", "read_only": 1},
		{"fieldname": "korkem_film_customer", "label": "Film customer", "fieldtype": "Link", "options": "Customer",
		 "insert_after": "korkem_film_kind"},
		{"fieldname": "korkem_film_amount", "label": "Film sale amount", "fieldtype": "Currency",
		 "insert_after": "korkem_film_customer"},
		{"fieldname": "korkem_film_paid", "label": "Film sale paid", "fieldtype": "Currency",
		 "insert_after": "korkem_film_amount", "allow_on_submit": 1},
		{"fieldname": "korkem_film_pay_method", "label": "Film sale paid by", "fieldtype": "Data",
		 "insert_after": "korkem_film_paid", "allow_on_submit": 1},
		{"fieldname": "korkem_film_pay_bank", "label": "Film sale bank", "fieldtype": "Data",
		 "insert_after": "korkem_film_pay_method", "allow_on_submit": 1},
		{"fieldname": "korkem_film_reason", "label": "Film movement reason", "fieldtype": "Small Text",
		 "insert_after": "korkem_film_pay_bank"},
		{"fieldname": "korkem_film_order", "label": "Film for order", "fieldtype": "Data",
		 "insert_after": "korkem_film_reason"},
	),
	"Stock Entry Detail": (
		{"fieldname": "korkem_film_price_m", "label": "Sold at, per metre", "fieldtype": "Currency",
		 "insert_after": "basic_rate"},
	),
	"Customer": (
		{"fieldname": "korkem_film_customer", "label": "Buys film", "fieldtype": "Check",
		 "insert_after": "customer_name"},
		{"fieldname": "korkem_film_tier", "label": "Film price", "fieldtype": "Data",
		 "insert_after": "korkem_film_customer"},
		{"fieldname": "korkem_film_discount", "label": "Film discount, %", "fieldtype": "Float",
		 "insert_after": "korkem_film_tier"},
	),
}


def execute():
	for doctype, fields in FIELDS.items():
		for field in fields:
			if not frappe.db.exists("Custom Field", {"dt": doctype, "fieldname": field["fieldname"]}):
				create_custom_field(doctype, dict(field))
		frappe.clear_cache(doctype=doctype)
