"""The MDF order card: the head of the order, the shop stages, and the line's
own note and price.

The owner runs facade orders from one window in OnayBaza (01.11.2026): a head
(thickness, finish, decor top and underneath, patina, milling, edge, an extra
name, a default price per m²), lines with their own milling and price, and a
row of stage ticks each with its date. These are the fields that card needs on
ERPNext's own Sales Order — see services/mdf_orders.py.

**The rate carries six decimals.** A line is priced the owner's way — its area
rounded to 0.01 m², times the price, to whole tenge — and that amount divided
by the pieces is rarely a two-decimal figure (10 000 ₸ for 3 pieces). ERPNext
then multiplies back and rounds to two decimals, which lands on the amount
exactly. The same precision on the invoice line keeps an invoice made from the
order on the same figure.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_fields
from frappe.custom.doctype.property_setter.property_setter import make_property_setter

ORDER = [
	{"fieldname": "korkem_mdf_section", "label": "MDF order", "fieldtype": "Section Break",
	 "insert_after": "korkem_prepayment_agreed", "collapsible": 1},
	{"fieldname": "korkem_thickness_mm", "label": "Thickness, mm", "fieldtype": "Int",
	 "insert_after": "korkem_mdf_section"},
	{"fieldname": "korkem_finish", "label": "Finish", "fieldtype": "Data", "insert_after": "korkem_thickness_mm"},
	{"fieldname": "korkem_decor_top", "label": "Decor, face", "fieldtype": "Data", "insert_after": "korkem_finish"},
	{"fieldname": "korkem_decor_bottom", "label": "Decor, back", "fieldtype": "Data",
	 "insert_after": "korkem_decor_top"},
	{"fieldname": "korkem_patina", "label": "Patina", "fieldtype": "Data", "insert_after": "korkem_decor_bottom"},
	{"fieldname": "korkem_milling", "label": "Milling", "fieldtype": "Data", "insert_after": "korkem_patina"},
	{"fieldname": "korkem_edge_profile", "label": "Edge profile", "fieldtype": "Data",
	 "insert_after": "korkem_milling"},
	{"fieldname": "korkem_extra_name", "label": "Extra name", "fieldtype": "Data",
	 "insert_after": "korkem_edge_profile"},
	{"fieldname": "korkem_default_rate", "label": "Default price per m²", "fieldtype": "Currency",
	 "insert_after": "korkem_extra_name", "non_negative": 1},
	# An order of several films (08.11.2026): the board for every position
	# unless one says otherwise, and each film's own price per m².
	{"fieldname": "korkem_material", "label": "Material", "fieldtype": "Data",
	 "insert_after": "korkem_default_rate"},
	{"fieldname": "korkem_film_rates", "label": "Price per m² by film", "fieldtype": "Small Text",
	 "insert_after": "korkem_material"},
	# «Срочный», «Переделка», «Гарантия» — the order's tags (08.11.2026).
	{"fieldname": "korkem_tags", "label": "Tags", "fieldtype": "Small Text", "insert_after": "korkem_film_rates"},
	{"fieldname": "korkem_mdf_stages", "label": "Stages", "fieldtype": "Column Break",
	 "insert_after": "korkem_tags"},
	{"fieldname": "korkem_stage_cut", "label": "Cut", "fieldtype": "Date", "insert_after": "korkem_mdf_stages"},
	{"fieldname": "korkem_stage_mill", "label": "Milled", "fieldtype": "Date", "insert_after": "korkem_stage_cut"},
	{"fieldname": "korkem_stage_sand", "label": "Sanded", "fieldtype": "Date", "insert_after": "korkem_stage_mill"},
	{"fieldname": "korkem_stage_vacuum", "label": "Vacuum press", "fieldtype": "Date",
	 "insert_after": "korkem_stage_sand"},
	{"fieldname": "korkem_stage_paint", "label": "Painted", "fieldtype": "Date", "insert_after": "korkem_stage_vacuum"},
	{"fieldname": "korkem_ready_on", "label": "Ready on", "fieldtype": "Date", "insert_after": "korkem_stage_paint"},
	{"fieldname": "korkem_handed_over_on", "label": "Handed over on", "fieldtype": "Date",
	 "insert_after": "korkem_ready_on"},
	{"fieldname": "korkem_hold_reason", "label": "On hold because", "fieldtype": "Small Text",
	 "insert_after": "korkem_handed_over_on"},
	# Who did each stage — the shop's work volume (OnayBaza «Жұмыс көлемі»), 07.11.2026.
	{"fieldname": "korkem_stage_cut_by", "label": "Cut by", "fieldtype": "Link", "options": "Employee",
	 "insert_after": "korkem_hold_reason"},
	{"fieldname": "korkem_stage_mill_by", "label": "Milled by", "fieldtype": "Link", "options": "Employee",
	 "insert_after": "korkem_stage_cut_by"},
	{"fieldname": "korkem_stage_sand_by", "label": "Sanded by", "fieldtype": "Link", "options": "Employee",
	 "insert_after": "korkem_stage_mill_by"},
	{"fieldname": "korkem_stage_vacuum_by", "label": "Pressed by", "fieldtype": "Link", "options": "Employee",
	 "insert_after": "korkem_stage_sand_by"},
	{"fieldname": "korkem_stage_paint_by", "label": "Painted by", "fieldtype": "Link", "options": "Employee",
	 "insert_after": "korkem_stage_vacuum_by"},
	# «Готово» — the last stage, checked and packed (owner, 09.11.2026).
	{"fieldname": "korkem_stage_ready", "label": "Checked and packed", "fieldtype": "Date",
	 "insert_after": "korkem_stage_paint"},
	{"fieldname": "korkem_stage_ready_by", "label": "Checked by", "fieldtype": "Link", "options": "Employee",
	 "insert_after": "korkem_stage_paint_by"},
	# A stage its finish does not have, added for a rework: paint, vacuum.
	{"fieldname": "korkem_extra_stages", "label": "Extra stages", "fieldtype": "Data",
	 "insert_after": "korkem_stage_ready_by"},
]

LINE = [
	{"fieldname": "korkem_line_note", "label": "Note", "fieldtype": "Data", "insert_after": "korkem_milling"},
	{"fieldname": "korkem_rate_m2", "label": "Price per m²", "fieldtype": "Currency",
	 "insert_after": "korkem_line_note", "non_negative": 1},
	{"fieldname": "korkem_manual_rate", "label": "Price set by hand", "fieldtype": "Check",
	 "insert_after": "korkem_rate_m2"},
	{"fieldname": "korkem_material", "label": "Material", "fieldtype": "Data", "insert_after": "korkem_manual_rate"},
	# A position's patina — rare, so a position's own (08.11.2026).
	{"fieldname": "korkem_line_patina", "label": "Patina", "fieldtype": "Data", "insert_after": "korkem_material"},
]

PRECISE = {
	"Sales Order Item": ("rate", "base_rate", "net_rate", "base_net_rate"),
	"Sales Invoice Item": ("rate", "base_rate", "net_rate", "base_net_rate"),
}


#: OnayBaza's customer list has an organisation beside the name and phone
#: (08.11.2026) — «ИП Куат», «Дом Мебели».
CUSTOMER = [
	{"fieldname": "korkem_organization", "label": "Organisation", "fieldtype": "Data",
	 "insert_after": "customer_name"},
	# «VIP», «Мебельщик», «Новый», «Только предоплата» (08.11.2026).
	{"fieldname": "korkem_tags", "label": "Tags", "fieldtype": "Small Text", "insert_after": "korkem_organization"},
]


#: The bank of a transfer or a card payment (Kaspi, Halyk, Forte …), beside
#: its method — перевод, наличные, карта (owner, 09.11.2026).
PAYMENT = [
	{"fieldname": "korkem_bank", "label": "Bank", "fieldtype": "Data", "insert_after": "mode_of_payment"},
]


def execute():
	create_custom_fields(
		{
			"Payment Entry": [f for f in PAYMENT if not _exists("Payment Entry", f["fieldname"])],
			"Sales Order": [f for f in ORDER if not _exists("Sales Order", f["fieldname"])],
			"Sales Order Item": [f for f in LINE if not _exists("Sales Order Item", f["fieldname"])],
			"Customer": [f for f in CUSTOMER if not _exists("Customer", f["fieldname"])],
		},
		update=True,
	)
	for doctype, fields in PRECISE.items():
		for field in fields:
			make_property_setter(doctype, field, "precision", "6", "Select", validate_fields_for_doctype=False)
	for doctype in ("Sales Order", "Sales Order Item", "Sales Invoice Item", "Customer", "Payment Entry"):
		frappe.clear_cache(doctype=doctype)


def _exists(doctype: str, fieldname: str) -> bool:
	return bool(frappe.db.exists("Custom Field", {"dt": doctype, "fieldname": fieldname}))
