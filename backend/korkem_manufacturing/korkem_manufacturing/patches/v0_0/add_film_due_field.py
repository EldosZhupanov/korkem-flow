"""When a roll on its way is due (owner, 11.11.2026: «прибытие плёнки»).

A roll ordered but not yet here is a receipt not yet posted: it lies in
nobody's stock until it comes. This is the day it is expected.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": "korkem_film_due"}):
		create_custom_field(
			"Stock Entry",
			{
				"fieldname": "korkem_film_due",
				"label": "Due on",
				"fieldtype": "Date",
				"insert_after": "korkem_film_seller",
				"read_only": 1,
				"allow_on_submit": 1,
			},
		)
	frappe.clear_cache(doctype="Stock Entry")
