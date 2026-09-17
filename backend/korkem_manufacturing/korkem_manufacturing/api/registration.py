# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Registration API endpoint for new furniture makers."""

from __future__ import annotations

import frappe
from korkem_manufacturing.services import registration as service


@frappe.whitelist(allow_guest=True, methods=["POST"])
def register(
	company_name: str,
	owner_name: str,
	email: str,
	password: str,
	phone: str = "",
) -> dict:
	"""Public endpoint for registering a new furniture company and owner."""
	return service.register_company(
		company_name=company_name,
		owner_name=owner_name,
		email=email,
		password=password,
		phone=phone,
	)
