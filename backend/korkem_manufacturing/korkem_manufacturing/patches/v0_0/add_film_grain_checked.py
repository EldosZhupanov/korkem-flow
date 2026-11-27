"""«Рисунок проверен» on a film's card (owner, 27.11.2026).

A film is textured, plain — or nobody has looked yet. Until somebody has,
the press lays it unturned, as a textured one: a few centimetres of film
are cheaper than a set of facades with the pattern across. The person at
the press, holding the roll, answers once (`material_stock.set_film_grain`).

A film already marked «Текстурная» has been looked at.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

FIELD = {
	"fieldname": "korkem_film_grain_checked",
	"label": "Film pattern checked (textured or plain)",
	"fieldtype": "Check",
	"insert_after": "korkem_film_textured",
	"default": "0",
}


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Item", "fieldname": FIELD["fieldname"]}):
		create_custom_field("Item", dict(FIELD))
		frappe.clear_cache(doctype="Item")
	frappe.db.sql(
		"update `tabItem` set korkem_film_grain_checked = 1 "
		"where korkem_film_textured = 1 and ifnull(korkem_film_grain_checked, 0) = 0"
	)
	frappe.clear_cache(doctype="Item")
