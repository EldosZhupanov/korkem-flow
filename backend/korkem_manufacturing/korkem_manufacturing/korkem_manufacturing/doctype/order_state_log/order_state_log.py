# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document


class OrderStateLog(Document):
	def on_trash(self):
		frappe.throw("Order state history is immutable and cannot be deleted.")
