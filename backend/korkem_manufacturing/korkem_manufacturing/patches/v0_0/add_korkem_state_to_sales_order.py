import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field


def execute():
	"""Add Sales Order.korkem_state (Select) for Canonical Order Lifecycle State Machine."""
	doctype = "Sales Order"

	if frappe.db.get_value("Custom Field", {"dt": doctype, "fieldname": "korkem_state"}):
		return

	create_custom_field(
		doctype,
		{
			"fieldname": "korkem_state",
			"label": "KORKEM State",
			"fieldtype": "Select",
			"options": "\nDraft\nLead\nMeasurement Pending\nMeasured\nDesign Pending\nDesign Approved\nQuote Pending\nQuote Sent\nContract Pending\nDeposit Pending\nReady for Production\nIn Production\nQuality Control\nReady for Delivery\nDelivery\nInstallation\nAcceptance Pending\nCompleted\nWarranty\nCancelled",
			"default": "Draft",
			"insert_after": "status",
			"allow_on_submit": 1,
			"description": "Canonical furniture order lifecycle state.",
		},
	)

	frappe.clear_cache(doctype=doctype)
