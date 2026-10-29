# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class LogisticsDelivery(Document):
	"""What bringing material in cost: a Газель for MDF, a taxi for one film.

	Written only through `services/logistics.py`; a mistake is cancelled
	there, never deleted, so the month's logistics total keeps its history.
	"""

	def on_trash(self):
		frappe.throw("Доставки не удаляются — отмените. История денег остаётся целой.")
