# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import now_datetime


class DomainStockMovement(Document):
	def before_insert(self):
		if not self.timestamp:
			self.timestamp = now_datetime()

	def before_save(self):
		if not self.is_new():
			frappe.throw(
				"Движения склада (Domain Stock Movement) неизменяемы (append-only) и не подлежат редактированию.",
				frappe.PermissionError,
			)

	def on_trash(self):
		frappe.throw(
			"Движения склада (Domain Stock Movement) запрещено удалять. Для исправления создайте сторнирующую проводку (compensation).",
			frappe.PermissionError,
		)
