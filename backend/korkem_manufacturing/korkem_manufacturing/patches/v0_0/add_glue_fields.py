"""PVC glue (owner, 17.11.2026): a material of its own kind, bought from the
suppliers who sell it — the same company may sell film and glue, and is one
supplier, marked with what it sells — and taken off the store by itself when
an order's facades come out of the vacuum press, each entry saying for which
order, why and for how many m²."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

KINDS = "\nМДФ\nПлёнка ПВХ\nПрочее\nКраска\nКлей"
ENTRY_FIELDS = (
	{"fieldname": "korkem_glue_use", "label": "Glue taken for", "fieldtype": "Data"},
	{"fieldname": "korkem_glue_order", "label": "Glue for order", "fieldtype": "Data"},
	{"fieldname": "korkem_glue_m2", "label": "Glue for m²", "fieldtype": "Float"},
)


def execute():
	name = frappe.db.get_value("Custom Field", {"dt": "Item", "fieldname": "korkem_material_kind"}, "name")
	if name and frappe.db.get_value("Custom Field", name, "options") != KINDS:
		frappe.db.set_value("Custom Field", name, "options", KINDS)
	if not frappe.db.exists("Custom Field", {"dt": "Supplier", "fieldname": "korkem_supplier_sells"}):
		create_custom_field("Supplier", {"fieldname": "korkem_supplier_sells", "label": "Sells (KORKEM)",
										 "fieldtype": "Small Text", "insert_after": "korkem_supplier_dept",
										 "read_only": 1})
	after = "korkem_paint_m2"
	for field in ENTRY_FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": field["fieldname"]}):
			create_custom_field("Stock Entry", {**field, "insert_after": after, "read_only": 1,
												"allow_on_submit": 1})
		after = field["fieldname"]
	frappe.clear_cache(doctype="Item")
	frappe.clear_cache(doctype="Supplier")
	frappe.clear_cache(doctype="Stock Entry")
