# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

from frappe.model.document import Document


class AccountingExportSettings(Document):
	"""Whether the company exchanges with 1C — one switch, on until somebody
	turns it off. See services/accounting_export.py."""

	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope

		enforce_tenant_scope(self.company)
