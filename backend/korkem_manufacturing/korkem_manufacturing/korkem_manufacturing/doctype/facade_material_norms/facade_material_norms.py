# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import cint, flt


class FacadeMaterialNorms(Document):
	"""Per-company figures that turn facade square metres into sheets and film.

	The factory's own: sheet size depends on the supplier, waste on the shop.
	"""

	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope

		enforce_tenant_scope(self.company)
		for field, label in (("sheet_length_mm", "Длина листа"), ("sheet_width_mm", "Ширина листа")):
			if not 500 <= cint(self.get(field)) <= 6000:
				frappe.throw(f"{label} — от 500 до 6000 мм.")
		for field, label in (("mdf_waste_percent", "Запас МДФ"), ("film_waste_percent", "Запас плёнки")):
			if not 0 <= flt(self.get(field)) <= 100:
				frappe.throw(f"{label} — от 0 до 100%.")
