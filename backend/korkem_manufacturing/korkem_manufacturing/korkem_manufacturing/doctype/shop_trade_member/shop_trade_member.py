# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

from frappe.model.document import Document


class ShopTradeMember(Document):
	"""One of a worker's trades. A person may have several. See services/shop_trades.py."""

	def validate(self):
		from korkem_manufacturing.services.scope import enforce_tenant_scope

		enforce_tenant_scope(self.company)
