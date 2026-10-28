# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import flt


class PieceWorkRules(Document):
	"""Overtime and weekend coefficients for piece work, per company."""

	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope

		enforce_tenant_scope(self.company)
		for field, label in (("overtime_factor", "сверхурочных"), ("weekend_factor", "выходных")):
			value = flt(self.get(field))
			if value and not 1 <= value <= 5:
				frappe.throw(f"Коэффициент {label} — от 1 до 5.")
		if flt(self.overtime_factor) and not self.shift_end:
			frappe.throw("Для сверхурочных укажите, во сколько заканчивается смена.")
		for period, threshold, bonus in (
			("дня", "daily_bonus_threshold", "daily_bonus"),
			("месяца", "monthly_bonus_threshold", "monthly_bonus"),
		):
			if flt(self.get(threshold)) < 0 or flt(self.get(bonus)) < 0:
				frappe.throw("Порог и премия не бывают отрицательными.")
			if bool(flt(self.get(threshold))) != bool(flt(self.get(bonus))):
				frappe.throw(f"Для премии {period} укажите и порог, и сумму — или оставьте оба пустыми.")
