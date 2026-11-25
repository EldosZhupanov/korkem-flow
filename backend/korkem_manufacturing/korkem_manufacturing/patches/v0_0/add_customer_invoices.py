"""«Счёт на долг» (owner, 25.11.2026): the customer keeps the invoices issued
for all he owes, as printed, with what was paid by each."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Customer", "fieldname": "korkem_invoices"}):
		create_custom_field("Customer", {
			"fieldname": "korkem_invoices", "label": "Invoices for the debt", "fieldtype": "Long Text",
			"hidden": 1, "no_copy": 1, "insert_after": "korkem_payer",
		})
	frappe.clear_cache(doctype="Customer")
