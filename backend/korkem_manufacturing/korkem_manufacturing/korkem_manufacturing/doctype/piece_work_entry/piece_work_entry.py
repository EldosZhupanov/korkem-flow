# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import flt


class PieceWorkEntry(Document):
	def before_insert(self):
		self.amount = round(flt(self.quantity) * flt(self.rate), 2)

	def validate(self):
		# 1. Tenant scope check
		from korkem_manufacturing.services.scope import enforce_tenant_scope
		enforce_tenant_scope(self.company)

		# 2. Compute amount
		self.amount = round(flt(self.quantity) * flt(self.rate), 2)

		# 3. Immutability checks once processed
		if not self.is_new():
			old = frappe.db.get_value(
				"Piece Work Entry",
				self.name,
				["status", "amount", "quantity", "rate"],
				as_dict=True,
			)
			if old and old.status in ("Approved", "Paid", "Reversed"):
				# Cannot change quantity, rate or amount once approved/paid/reversed
				if (
					flt(self.quantity) != flt(old.quantity)
					or flt(self.rate) != flt(old.rate)
					or flt(self.amount) != flt(old.amount)
				):
					frappe.throw(
						f"Запись сдельной оплаты в статусе '{old.status}' заблокирована от изменения финансовых параметров. "
						"Используйте операцию сторнирования (reversal).",
						frappe.ValidationError,
					)

	def on_trash(self):
		frappe.throw(
			"Записи сдельной оплаты (Piece Work Entry) запрещено удалять. Для отмены создайте сторнирующую запись (reversal).",
			frappe.PermissionError,
		)
