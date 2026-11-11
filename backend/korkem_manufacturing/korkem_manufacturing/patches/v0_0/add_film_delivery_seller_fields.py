"""How a roll came, who took it in, and who sold it (owner, 11.11.2026).

On a receipt: how it was brought (taxi, КАМАЗ…), from which city, what the
bringing cost, whether it was urgent, and who took it in at the shop. On a
sale: who sold it — the month's team bonus is counted by seller.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_received_by", "label": "Taken in by", "fieldtype": "Data"},
	{"fieldname": "korkem_delivery_transport", "label": "Brought by", "fieldtype": "Data"},
	{"fieldname": "korkem_delivery_city", "label": "Brought from", "fieldtype": "Data"},
	{"fieldname": "korkem_delivery_cost", "label": "Delivery cost", "fieldtype": "Currency"},
	{"fieldname": "korkem_delivery_urgent", "label": "Urgent delivery", "fieldtype": "Check"},
	{"fieldname": "korkem_film_seller", "label": "Sold by", "fieldtype": "Data"},
)


def execute():
	after = "korkem_film_fix_reason"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": field["fieldname"]}):
			create_custom_field(
				"Stock Entry", {**field, "insert_after": after, "read_only": 1, "allow_on_submit": 1}
			)
		after = field["fieldname"]
	frappe.clear_cache(doctype="Stock Entry")
