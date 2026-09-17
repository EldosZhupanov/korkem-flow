# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class DomainAuditEvent(Document):
	def before_save(self):
		if not self.is_new():
			frappe.throw(
				"Domain Audit Events are append-only and cannot be modified.",
				frappe.PermissionError,
			)

	def on_trash(self):
		frappe.throw(
			"Domain Audit Events are immutable and cannot be deleted.",
			frappe.PermissionError,
		)
