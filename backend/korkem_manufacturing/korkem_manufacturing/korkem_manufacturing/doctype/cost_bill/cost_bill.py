# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class CostBill(Document):
	"""A month's bill for a cost item (свет, аренда…). Written only through `services/cost_bills.py`."""

	def on_trash(self):
		frappe.throw("Не удаляется — уберите в архив. История денег остаётся целой.")
