"""Which line of business an order belongs to, whether it is urgent, and a customer's tier.

The factory runs two lines on one floor: made-to-measure facades sold to other
workshops, and furniture for end customers. They share the stock, the people
and the money, but not the path an order takes or the reports the owner reads,
so every order says which line it is (`services/directions.py`).

Orders that already exist are classified once, from what they contain: an
order with a facade line is a facade order, everything else is furniture.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

ORDER_FIELDS = (
	{
		"fieldname": "korkem_direction",
		"label": "Direction",
		"fieldtype": "Select",
		"options": "Furniture\nFacades",
		"default": "Furniture",
		"insert_after": "korkem_state",
		"allow_on_submit": 1,
		"in_standard_filter": 1,
		"in_list_view": 1,
	},
	{
		"fieldname": "korkem_urgent",
		"label": "Urgent",
		"fieldtype": "Check",
		"insert_after": "korkem_direction",
		"allow_on_submit": 1,
		"in_standard_filter": 1,
	},
)

CUSTOMER_FIELD = {
	"fieldname": "korkem_tier",
	"label": "Client tier",
	"fieldtype": "Select",
	"options": "\nNew\nRegular\nVIP",
	"insert_after": "customer_group",
	"in_standard_filter": 1,
}

#: The item every facade line is sold as (`services/facade_order.py`).
FACADE_ITEM = "KORKEM-FACADE"


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Sales Order", "fieldname": "korkem_state"}):
		# Placed after korkem_state; that patch runs first on upgrade and in install.
		from korkem_manufacturing.patches.v0_0.add_korkem_state_to_sales_order import execute as add_state

		add_state()
	for field in ORDER_FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Sales Order", "fieldname": field["fieldname"]}):
			create_custom_field("Sales Order", dict(field))
	if not frappe.db.exists("Custom Field", {"dt": "Customer", "fieldname": CUSTOMER_FIELD["fieldname"]}):
		create_custom_field("Customer", dict(CUSTOMER_FIELD))
	frappe.clear_cache(doctype="Sales Order")
	frappe.clear_cache(doctype="Customer")

	frappe.db.sql(
		"""
		update `tabSales Order` so
		set so.korkem_direction = if(
			exists(select 1 from `tabSales Order Item` i where i.parent = so.name and i.item_code = %s),
			'Facades', 'Furniture')
		where ifnull(so.korkem_direction, '') = ''
		""",
		FACADE_ITEM,
	)
