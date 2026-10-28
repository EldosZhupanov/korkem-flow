# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class ShopTrade(Document):
	"""A trade on the shop floor — «Раскройщик», «Сборщик» — as the company names
	it. A trade says what a person does, not what they may see: rights stay
	with the position (`services/staff.py`). See services/shop_trades.py.
	"""

	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope

		enforce_tenant_scope(self.company)
		self.title = " ".join((self.title or "").split())
		if not self.title:
			frappe.throw("Назовите профессию.")
		if frappe.db.exists("Shop Trade", {"company": self.company, "title": self.title, "name": ["!=", self.name]}):
			frappe.throw(f"Профессия «{self.title}» уже есть.")

	def on_trash(self):
		frappe.throw("Профессию не удаляют — её выключают: у людей остаётся история.", frappe.PermissionError)
