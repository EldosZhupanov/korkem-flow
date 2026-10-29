# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import flt


class PieceRate(Document):
	"""What one unit of an operation pays, per company. Set by the administrator."""

	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope

		enforce_tenant_scope(self.company)
		self.operation = (self.operation or "").strip()
		if not self.operation:
			frappe.throw("Укажите операцию.")
		if flt(self.rate) <= 0:
			frappe.throw("Тариф должен быть больше нуля. Чтобы убрать — отключите.")
		if frappe.db.exists(
			"Piece Rate", {"company": self.company, "operation": self.operation, "name": ["!=", self.name]}
		):
			frappe.throw(f"Тариф для «{self.operation}» уже есть — измените его.")

	def on_trash(self):
		frappe.throw("Тарифы не удаляются — отключите. Старые начисления ссылаются на них.")
