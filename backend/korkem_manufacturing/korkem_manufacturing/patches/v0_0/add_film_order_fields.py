"""«К заказу» и приход несколькими плёнками (owner, 12.11.2026).

`korkem_film_batch` ties the rolls of one delivery together: one supplier,
one day, one car — several films. `korkem_src_order_until` is the hour a
source takes the day's orders until, «16:00».
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": "korkem_film_batch"}):
		create_custom_field(
			"Stock Entry",
			{
				"fieldname": "korkem_film_batch",
				"label": "Delivery batch",
				"fieldtype": "Data",
				"insert_after": "korkem_film_issued_by",
				"read_only": 1,
				"allow_on_submit": 1,
			},
		)
	if not frappe.db.exists("Custom Field", {"dt": "Supplier", "fieldname": "korkem_src_order_until"}):
		create_custom_field(
			"Supplier",
			{
				"fieldname": "korkem_src_order_until",
				"label": "Takes orders until",
				"fieldtype": "Data",
				"insert_after": "korkem_src_min_order",
			},
		)
	frappe.clear_cache(doctype="Stock Entry")
	frappe.clear_cache(doctype="Supplier")
