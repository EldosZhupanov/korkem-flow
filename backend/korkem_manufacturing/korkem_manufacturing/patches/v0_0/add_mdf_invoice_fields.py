"""«Счёт на оплату» for an MDF order (owner, 20.11.2026): the order keeps the
invoices issued for it, the customer who pays for him — a ТОО, an ИП — by
name; his БИН is ERPNext's own `tax_id`."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	("Sales Order", {"fieldname": "korkem_invoices", "label": "Invoices to pay", "fieldtype": "Long Text",
					 "hidden": 1, "no_copy": 1, "insert_after": "korkem_tags"}),
	("Customer", {"fieldname": "korkem_payer", "label": "Pays as (invoices)", "fieldtype": "Data",
				  "insert_after": "korkem_source"}),
)


def execute():
	for doctype, field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": doctype, "fieldname": field["fieldname"]}):
			create_custom_field(doctype, field)
		frappe.clear_cache(doctype=doctype)
