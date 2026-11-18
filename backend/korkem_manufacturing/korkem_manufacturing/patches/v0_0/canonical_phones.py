# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Every phone already written down, in the one spelling (owner, 18.11.2026):
`+77015551234` (`services/phones`). A number that does not read as a phone
is left exactly as it was and listed — corrected by a person, never guessed."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import phones

#: (doctype, field) — where phones are kept.
PLACES = (
	("Customer", "mobile_no"),
	("Employee", "cell_number"),
	("Supplier", "korkem_src_phone"),
	("Supplier", "korkem_src_phone2"),
	("Supplier", "korkem_src_whatsapp"),
	("Sales Order", "korkem_taken_phone"),
)


def execute():
	changed, unread = 0, []
	for doctype, field in PLACES:
		if not frappe.db.has_column(doctype, field):
			continue
		for row in frappe.get_all(doctype, filters={field: ["is", "set"]}, fields=["name", field],
								  limit_page_length=0):
			value = row.get(field)
			try:
				phone = phones.canonical(value)
			except ValueError:
				unread.append(f"{doctype} {row.name}: {value}")
				continue
			if phone and phone != value:
				frappe.db.set_value(doctype, row.name, field, phone, update_modified=False)
				changed += 1
	frappe.db.commit()
	print(f"Телефоны: приведено к +7… — {changed}; не прочитаны (оставлены как были) — {len(unread)}")
	for line in unread:
		print("  ", line)
