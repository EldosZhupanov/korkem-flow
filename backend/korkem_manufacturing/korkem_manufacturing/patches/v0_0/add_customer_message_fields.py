"""When the customer was told (owner, 18.11.2026): «заказ готов» and the
debt reminders — so the list «Кому написать» does not ask twice, and the
order's card says who was told and when."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_told_on", "label": "Customer told it is ready on", "fieldtype": "Date"},
	{"fieldname": "korkem_reminded_on", "label": "Debt reminder sent on", "fieldtype": "Date"},
	{"fieldname": "korkem_reminders", "label": "Debt reminders sent", "fieldtype": "Int"},
)


def execute():
	after = "korkem_handed_over_on"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Sales Order", "fieldname": field["fieldname"]}):
			create_custom_field("Sales Order", {**field, "insert_after": after, "read_only": 1,
												"allow_on_submit": 1, "no_copy": 1})
		after = field["fieldname"]
	frappe.clear_cache(doctype="Sales Order")
