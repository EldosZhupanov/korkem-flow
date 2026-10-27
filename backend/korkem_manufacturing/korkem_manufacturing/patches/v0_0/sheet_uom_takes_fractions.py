"""«Лист» counts fractions again, as furniture BOMs need.

`material_stock._ensure_uom` used to mark an existing «Лист» whole-number the
first time a sheet material was defined. Furniture BOMs consume part of a
sheet, so after that every Work Order transfer failed with «Quantity (8.4)
cannot be a fraction». The store's own receipts stay whole-sheet by its own
rule (`material_stock._whole_units`), which does not read this flag for «лист».
"""

import frappe

UNIT = "Лист"


def execute():
	if frappe.db.exists("UOM", UNIT) and frappe.db.get_value("UOM", UNIT, "must_be_whole_number"):
		frappe.db.set_value("UOM", UNIT, "must_be_whole_number", 0)
