# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import getdate


class PayPayout(Document):
	"""A worker's pay for a period, marked «Выплачено».

	Written only by `services/payroll.mark_paid`, which also marks the period's
	approved accruals «Paid». Final: a mistake is put right by an adjustment in
	the next period, not by editing or deleting this.
	"""

	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope

		enforce_tenant_scope(self.company)
		if getdate(self.from_date) > getdate(self.to_date):
			frappe.throw("Начало периода позже конца.")

	def on_trash(self):
		frappe.throw("Выплату не удаляют: ошибку исправляют удержанием или премией.", frappe.PermissionError)
