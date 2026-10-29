# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class MaterialOption(Document):
	"""One entry in a list the administrator keeps: a thickness, a maker, a colour.

	Written through `services/material_stock.py`; this only refuses duplicates
	so the desk and the API agree.
	"""

	def validate(self):
		self.value = " ".join((self.value or "").split())
		if not self.value:
			frappe.throw("Пустое значение.")
		if frappe.db.exists(
			"Material Option",
			{"company": self.company, "kind": self.kind, "value": self.value, "name": ["!=", self.name]},
		):
			frappe.throw(f"«{self.value}» уже есть в списке «{self.kind}».")
