# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document
from frappe.query_builder import Interval
from frappe.query_builder.functions import Now


class DomainOutboxEvent(Document):
	@staticmethod
	def clear_old_events(days: int = 30) -> None:
		table = frappe.qb.DocType("Domain Outbox Event")
		frappe.db.delete(
			table,
			filters=(
				(table.status == "Completed")
				& (table.creation < (Now() - Interval(days=days)))
			),
		)
