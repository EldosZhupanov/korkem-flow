# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import flt


class PayAdjustment(Document):
	"""An advance, a fine or a one-off bonus against a worker's pay.

	Entered by the production manager or the administrator, approved by another
	person, reversed — never deleted — when wrong. See services/payroll.py.
	"""

	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope

		enforce_tenant_scope(self.company)
		if flt(self.amount) <= 0:
			frappe.throw("Сумма — больше нуля; вид («Аванс», «Штраф», «Премия») задаёт знак.")
		if not (self.reason or "").strip():
			frappe.throw("Укажите причину — работник увидит её.")

	def on_trash(self):
		frappe.throw("Удержание или премию не удаляют — их сторнируют.", frappe.PermissionError)
