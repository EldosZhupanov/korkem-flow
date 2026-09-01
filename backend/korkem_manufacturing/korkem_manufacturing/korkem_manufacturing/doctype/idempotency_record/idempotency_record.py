# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document
from frappe.query_builder import Interval
from frappe.query_builder.functions import Now


class IdempotencyRecord(Document):
	@staticmethod
	def clear_old_logs(days: int = 30) -> None:
		"""Use Frappe's daily Log Settings cleanup instead of another scheduler."""
		table = frappe.qb.DocType("Idempotency Record")
		frappe.db.delete(table, filters=(table.creation < (Now() - Interval(days=days))))
