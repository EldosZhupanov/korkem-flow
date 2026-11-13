"""Whether the film itself was paid for, or taken from the supplier on credit.

A receipt says what the roll cost a metre; until now it did not say whether
that money had gone. Film taken on credit is a debt to the supplier until it
is paid — the cash tab lists it, and «Оплатили» closes it.

`korkem_supplier_owed` is set only on credit: every receipt made before it
existed was paid on the spot, and stays so.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELDS = (
	{"fieldname": "korkem_supplier_owed", "label": "Film taken on credit", "fieldtype": "Check"},
	{"fieldname": "korkem_supplier_paid_on", "label": "Supplier paid on", "fieldtype": "Date"},
	{"fieldname": "korkem_supplier_paid_method", "label": "Supplier paid in", "fieldtype": "Data"},
)


def execute():
	after = "korkem_delivery_phone"
	for field in FIELDS:
		if not frappe.db.exists("Custom Field", {"dt": "Stock Entry", "fieldname": field["fieldname"]}):
			create_custom_field(
				"Stock Entry", {**field, "insert_after": after, "read_only": 1, "allow_on_submit": 1}
			)
		after = field["fieldname"]
	frappe.clear_cache(doctype="Stock Entry")
