"""A film sale paid several ways at once (owner, 11.11.2026): cash and a
transfer, two transfers to two banks. Each part is kept, as JSON on the sale.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": "korkem_film_payments"}):
		create_custom_field(
			"Stock Entry",
			{
				"fieldname": "korkem_film_payments",
				"label": "Film payments",
				"fieldtype": "Long Text",
				"insert_after": "korkem_film_pay_bank",
				"read_only": 1,
			},
		)
	frappe.clear_cache(doctype="Stock Entry")
