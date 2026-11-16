"""Paint is bought from its own companies and people (owner, 15.11.2026:
«поставщики краски — это отдельные компании и люди, не надо смешивать с
поставщиками ПВХ плёнок»).

A supplier is ERPNext's one `Supplier` either way — a receipt names it — and
this field says whose it is: «paint», or nothing for film and the rest. One
already bought from for paint and never for anything else is marked here.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELD = "korkem_supplier_dept"


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Supplier", "fieldname": FIELD}):
		create_custom_field("Supplier", {
			"fieldname": FIELD, "label": "Supplies department", "fieldtype": "Data",
			"insert_after": "supplier_name", "read_only": 1,
		})
		frappe.clear_cache(doctype="Supplier")
	paint = {r[0] for r in frappe.db.sql(
		"""select distinct korkem_supplier from `tabStock Entry`
		where korkem_receipt_dept = 'paint' and docstatus = 1 and ifnull(korkem_supplier, '') != ''""")}
	other = {r[0] for r in frappe.db.sql(
		"""select distinct korkem_supplier from `tabStock Entry`
		where ifnull(korkem_receipt_dept, '') != 'paint' and docstatus = 1 and ifnull(korkem_supplier, '') != ''""")}
	for supplier in paint - other:
		frappe.db.set_value("Supplier", supplier, FIELD, "paint", update_modified=False)
