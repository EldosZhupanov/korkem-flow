# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class DurableStepRun(Document):
	def before_save(self):
		if not self.is_new():
			frappe.throw(
				"Контрольные точки шагов фоновых задач (Durable Step Run) неизменяемы (append-only).",
				frappe.PermissionError,
			)

	def on_trash(self):
		frappe.throw(
			"Контрольные точки шагов фоновых задач (Durable Step Run) запрещено удалять.",
			frappe.PermissionError,
		)
