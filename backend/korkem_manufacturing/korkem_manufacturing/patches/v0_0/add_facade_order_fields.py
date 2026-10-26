"""Fields a facade order needs that ERPNext does not have.

On each order line: the facade's size, milling, finish and options, so the
shop floor reads what to make from fields rather than from a description.
On the order: the prepayment agreed with the customer. It is a promise, not a
payment — what was actually paid stays in ERPNext's own `advance_paid` — and
it is money, so it sits at permission level 1 like every other amount the
floor does not see (`services/price_visibility.py`).
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

ITEM_FIELDS = (
	{"fieldname": "korkem_facade_section", "label": "Facade", "fieldtype": "Section Break", "insert_after": "description", "collapsible": 1},
	{"fieldname": "korkem_width_mm", "label": "Width, mm", "fieldtype": "Int", "insert_after": "korkem_facade_section"},
	{"fieldname": "korkem_height_mm", "label": "Height, mm", "fieldtype": "Int", "insert_after": "korkem_width_mm"},
	{"fieldname": "korkem_area_m2", "label": "Area, m²", "fieldtype": "Float", "precision": "4", "insert_after": "korkem_height_mm"},
	{"fieldname": "korkem_facade_column", "fieldtype": "Column Break", "insert_after": "korkem_area_m2"},
	{"fieldname": "korkem_milling", "label": "Milling", "fieldtype": "Data", "insert_after": "korkem_facade_column"},
	{"fieldname": "korkem_finish", "label": "Finish", "fieldtype": "Data", "insert_after": "korkem_milling"},
	{"fieldname": "korkem_double_sided", "label": "Double-sided", "fieldtype": "Check", "insert_after": "korkem_finish"},
	{"fieldname": "korkem_customer_material", "label": "Customer's material", "fieldtype": "Check", "insert_after": "korkem_double_sided"},
)

ORDER_FIELD = {
	"fieldname": "korkem_prepayment_agreed",
	"label": "Prepayment agreed",
	"fieldtype": "Currency",
	"options": "currency",
	"insert_after": "advance_paid",
	"permlevel": 1,
	"read_only": 1,
	"description": "Предоплата, о которой договорились с клиентом. Фактически оплаченное — в «Advance Paid».",
}


def execute():
	for field in ITEM_FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Sales Order Item", "fieldname": field["fieldname"]}):
			create_custom_field("Sales Order Item", dict(field))
	if not frappe.db.exists("Custom Field", {"dt": "Sales Order", "fieldname": ORDER_FIELD["fieldname"]}):
		create_custom_field("Sales Order", dict(ORDER_FIELD))
	frappe.clear_cache(doctype="Sales Order")
	frappe.clear_cache(doctype="Sales Order Item")
