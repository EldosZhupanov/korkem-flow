# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class StockReservation(Document):
	def validate(self):
		# 1. Tenant scope
		from korkem_manufacturing.services.scope import enforce_tenant_scope
		enforce_tenant_scope(self.company)

		# 2. Status transitions
		if not self.is_new():
			old_status = frappe.db.get_value("Stock Reservation", self.name, "status")
			if old_status in ("Released", "Consumed") and self.status != old_status:
				frappe.throw(
					f"Резерв в статусе '{old_status}' заблокирован от изменений.",
					frappe.ValidationError,
				)

	def on_trash(self):
		if self.status == "Active":
			frappe.throw(
				"Активный резерв материалов нельзя удалять. Выполните освобождение резерва (release).",
				frappe.PermissionError,
			)
