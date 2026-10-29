# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class UrgentExpense(Document):
	"""Money somebody spent, or must spend now, outside a purchase order.

	Written only through `services/urgent_expenses.py`; the desk is read-only
	for everyone but accounting, so a decision always has a person and a time.
	"""

	def on_trash(self):
		frappe.throw("Расходы не удаляются — отклоните. История денег остаётся целой.")
