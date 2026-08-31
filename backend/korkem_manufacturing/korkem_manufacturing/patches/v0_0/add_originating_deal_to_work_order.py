import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	"""Add Work Order.originating_deal (Link -> CRM Deal), per domain_model.md §3.4:
	closes the loop from the CRM sales pipeline back to the manufacturing Production
	Order once a Deal converts. Additive metadata on top of the core Work Order
	doctype -- erpnext itself is never modified, only extended via Custom Field.
	"""
	doctype = "Work Order"

	if frappe.db.get_value("Custom Field", {"dt": doctype, "fieldname": "originating_deal"}):
		return

	create_custom_field(
		doctype,
		{
			"fieldname": "originating_deal",
			"label": "Originating Deal",
			"fieldtype": "Link",
			"options": "CRM Deal",
			"insert_after": "sales_order",
			"allow_on_submit": 1,
			"description": "The CRM Deal this Production Order was created from, if any.",
		},
	)

	frappe.clear_cache(doctype=doctype)
