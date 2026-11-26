"""Which way a textured film's pattern runs on a facade (owner, 26.11.2026):
along its height — the usual — or «по ширине», as on a drawer front. The
press lays every textured part with its pattern along the table, the way
the roll runs."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Sales Order Item", "fieldname": "korkem_grain"}):
		create_custom_field("Sales Order Item", {"fieldname": "korkem_grain", "label": "Pattern runs",
												 "fieldtype": "Data", "insert_after": "korkem_paint_gloss",
												 "allow_on_submit": 1})
	frappe.clear_cache(doctype="Sales Order Item")
