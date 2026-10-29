# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import flt


class FacadePrice(Document):
	"""One cell of the facade price matrix: milling × finish, per m², per company.

	Rules live here so the desk form and the API refuse the same things.
	"""

	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope

		# Starting prices are written for a company as it is created, before
		# anybody works in it; every other write is checked against the session.
		if not self.flags.korkem_seed:
			enforce_tenant_scope(self.company)
		self.milling = (self.milling or "").strip()
		if not self.milling:
			frappe.throw("Укажите фрезеровку.")
		if flt(self.price_per_m2) <= 0:
			frappe.throw("Цена за м² должна быть больше нуля. Чтобы убрать позицию, отключите её.")
		duplicate = frappe.db.exists(
			"Facade Price",
			{
				"company": self.company,
				"milling": self.milling,
				"finish": self.finish,
				"name": ["!=", self.name],
			},
		)
		if duplicate:
			frappe.throw(f"Цена для «{self.milling} — {self.finish}» уже есть. Измените её, а не добавляйте вторую.")

	def on_trash(self):
		frappe.throw("Цены не удаляются — отключите позицию. Так в старых заказах видно, по какой цене считали.")
