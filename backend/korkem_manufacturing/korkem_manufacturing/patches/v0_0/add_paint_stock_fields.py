"""Paint is bought and kept like film (owner, 15.11.2026): a paint is a
material of its own kind, with what it is — «эмаль ПУ матовая», «грунт» —
beside its colour; and a receipt says which department bought it, so a can of
paint is not counted in the film department's cash."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

KINDS = "\nМДФ\nПлёнка ПВХ\nПрочее\nКраска"


def execute():
	name = frappe.db.get_value("Custom Field", {"dt": "Item", "fieldname": "korkem_material_kind"}, "name")
	if name and frappe.db.get_value("Custom Field", name, "options") != KINDS:
		frappe.db.set_value("Custom Field", name, "options", KINDS)
	if not frappe.db.exists("Custom Field", {"dt": "Item", "fieldname": "korkem_paint_base"}):
		create_custom_field("Item", {"fieldname": "korkem_paint_base", "label": "Paint: what it is",
									 "fieldtype": "Data", "insert_after": "korkem_color"})
	if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": "korkem_receipt_dept"}):
		create_custom_field("Stock Entry", {"fieldname": "korkem_receipt_dept", "label": "Bought for",
											"fieldtype": "Data", "insert_after": "korkem_supplier_due_on",
											"read_only": 1, "allow_on_submit": 1})
	frappe.clear_cache(doctype="Item")
	frappe.clear_cache(doctype="Stock Entry")
