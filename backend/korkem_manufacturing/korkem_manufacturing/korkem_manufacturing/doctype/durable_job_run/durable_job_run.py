# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class DurableJobRun(Document):
	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope
		enforce_tenant_scope(self.company)

		# Immutability once Completed
		if not self.is_new():
			old_status = frappe.db.get_value("Durable Job Run", self.name, "status")
			if old_status == "Completed" and self.status != "Completed":
				frappe.throw("Завершенная фоновая задача (Completed) неизменяема.", frappe.ValidationError)

	def on_trash(self):
		if self.status in ("Running", "Completed"):
			frappe.throw("Активные или успешно завершенные фоновые задачи запрещено удалять.", frappe.PermissionError)
