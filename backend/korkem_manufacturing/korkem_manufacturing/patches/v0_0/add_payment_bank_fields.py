"""Which bank a supplier, a carrier or an employee was paid through
(owner, 15.11.2026: «Перевод — Каспи, Форте, Халык…»).

A transfer or a card is a bank's money, and the cash book keeps each bank
apart: a payment that says only «Перевод» cannot be put on any of them.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	("korkem_supplier_paid_bank", "Supplier paid through", "korkem_supplier_paid_method"),
	("korkem_delivery_bank", "Delivery paid through", "korkem_delivery_method"),
	("korkem_delivery_settled_bank", "Delivery settled through", "korkem_delivery_settled_method"),
)


def execute():
	for fieldname, label, after in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": fieldname}):
			create_custom_field("Stock Entry", {
				"fieldname": fieldname, "label": label, "fieldtype": "Data", "insert_after": after,
				"read_only": 1, "allow_on_submit": 1,
			})
	frappe.clear_cache(doctype="Stock Entry")
