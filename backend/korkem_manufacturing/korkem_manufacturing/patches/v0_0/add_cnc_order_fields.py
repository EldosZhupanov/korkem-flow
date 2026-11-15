"""CNC services, a third line of business (owner, 15.11.2026: «мы делаем
услуги фрезеровки: МДФ, ЛДСП, каменные столешницы, еврозапил, вырез под
мойку, решётки из фанеры»).

An order of it is a Sales Order of the direction «CNC»: the customer's own
material taken in (what, how many, its defects) and his consent that hidden
defects are his; when the machine started it. A line says which service of
the price list it is, in what unit, and the machine minutes it takes."""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

DIRECTIONS = "Furniture\nFacades\nCNC"
ORDER = (
	{"fieldname": "korkem_cnc_intake", "label": "CNC: material taken in", "fieldtype": "Long Text"},
	{"fieldname": "korkem_cnc_terms", "label": "CNC: hidden defects are the customer's", "fieldtype": "Check"},
	{"fieldname": "korkem_cnc_started_on", "label": "CNC: machine started", "fieldtype": "Datetime"},
)
ITEM = (
	{"fieldname": "korkem_cnc_service", "label": "CNC service", "fieldtype": "Data"},
	{"fieldname": "korkem_cnc_unit", "label": "CNC unit", "fieldtype": "Data"},
	{"fieldname": "korkem_cnc_minutes", "label": "CNC machine minutes", "fieldtype": "Float"},
	{"fieldname": "korkem_cnc_kind", "label": "CNC line kind", "fieldtype": "Data"},
)


def execute():
	name = frappe.db.get_value("Custom Field", {"dt": "Sales Order", "fieldname": "korkem_direction"}, "name")
	if name and frappe.db.get_value("Custom Field", name, "options") != DIRECTIONS:
		frappe.db.set_value("Custom Field", name, "options", DIRECTIONS)
	after = "korkem_direction"
	for field in ORDER:
		if not frappe.db.exists("Custom Field", {"dt": "Sales Order", "fieldname": field["fieldname"]}):
			create_custom_field("Sales Order", {**field, "insert_after": after, "allow_on_submit": 1})
		after = field["fieldname"]
	after = "korkem_line_note"
	for field in ITEM:
		if not frappe.db.exists("Custom Field", {"dt": "Sales Order Item", "fieldname": field["fieldname"]}):
			create_custom_field("Sales Order Item", {**field, "insert_after": after, "allow_on_submit": 1})
		after = field["fieldname"]
	if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": "korkem_cnc_order"}):
		create_custom_field("Stock Entry", {"fieldname": "korkem_cnc_order", "label": "Material for CNC order",
											"fieldtype": "Data", "insert_after": "korkem_paint_m2", "read_only": 1,
											"allow_on_submit": 1})
	frappe.clear_cache(doctype="Sales Order")
	frappe.clear_cache(doctype="Sales Order Item")
	frappe.clear_cache(doctype="Stock Entry")
	from korkem_manufacturing.services import cnc_orders

	cnc_orders.seed_all_companies()
