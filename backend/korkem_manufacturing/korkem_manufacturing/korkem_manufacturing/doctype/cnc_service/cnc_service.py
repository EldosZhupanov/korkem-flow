# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class CNCService(Document):
	"""One line of the CNC price list: «Еврозапил», «Вырез под мойку»…

	Written through `services/cnc_orders.py`; this keeps titles unique within
	a company so the list and the API agree.
	"""

	def validate(self):
		self.title = " ".join((self.title or "").split())
		if not self.title:
			frappe.throw("Пустое название услуги.")
		if frappe.db.exists(
			"CNC Service", {"company": self.company, "title": self.title, "name": ["!=", self.name]}
		):
			frappe.throw(f"Услуга «{self.title}» уже есть в прайсе.")
