"""Who handed the film out of the stock on a sale (owner, 12.11.2026): the
seller answers for the sale, the one who cut and gave it out — for the goods.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": "korkem_film_issued_by"}):
		create_custom_field(
			"Stock Entry",
			{
				"fieldname": "korkem_film_issued_by",
				"label": "Handed out by",
				"fieldtype": "Data",
				"insert_after": "korkem_delivery_phone",
				"read_only": 1,
				"allow_on_submit": 1,
			},
		)
	frappe.clear_cache(doctype="Stock Entry")
