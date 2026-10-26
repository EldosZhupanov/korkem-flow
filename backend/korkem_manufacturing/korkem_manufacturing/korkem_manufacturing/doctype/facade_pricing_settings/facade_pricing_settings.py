# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import flt


class FacadePricingSettings(Document):
	"""Per-company rules for a facade order, set by the administrator and sales.

	Every rule may be left empty, and empty means "not offered": the quote
	refuses a double-sided facade rather than guessing what one costs.
	"""

	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope

		enforce_tenant_scope(self.company)
		if self.double_sided_factor and flt(self.double_sided_factor) < 1:
			frappe.throw("Коэффициент двустороннего фасада не может быть меньше 1.")
		for field, label in (
			("customer_material_discount_percent", "Скидка за материал заказчика"),
			("prepayment_percent", "Предоплата"),
		):
			value = self.get(field)
			if value is not None and not 0 <= flt(value) <= 100:
				frappe.throw(f"{label} — от 0 до 100%.")
		if flt(self.demolition_rate) < 0:
			frappe.throw("Цена демонтажа не может быть отрицательной.")
		if bool(self.demolition_unit) != bool(flt(self.demolition_rate)):
			frappe.throw("Для демонтажа укажите и способ расчёта, и цену — или оставьте оба пустыми.")
