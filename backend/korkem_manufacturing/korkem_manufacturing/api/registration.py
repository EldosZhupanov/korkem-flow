# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Registration and OTP API endpoints for furniture makers and workshop owners."""

from __future__ import annotations

import frappe
from korkem_manufacturing.services import auth_otp
from korkem_manufacturing.services import registration as service


@frappe.whitelist(allow_guest=True, methods=["POST"])
def register(
	company_name: str,
	owner_name: str,
	email: str = "",
	password: str = "",
	phone: str = "",
	logo_base64: str | None = None,
) -> dict:
	"""Public endpoint for registering a new furniture company and owner."""
	return service.register_company(
		company_name=company_name,
		owner_name=owner_name,
		email=email,
		password=password,
		phone=phone,
		logo_base64=logo_base64,
	)


@frappe.whitelist(allow_guest=True, methods=["POST"])
def request_otp(phone: str) -> dict:
	"""Public endpoint: Request OTP code for a phone number."""
	return auth_otp.request_otp(phone=phone)


@frappe.whitelist(allow_guest=True, methods=["POST"])
def verify_otp(phone: str, code: str, session_id: str = "") -> dict:
	"""Public endpoint: Verify OTP code."""
	return auth_otp.verify_otp(phone=phone, code=code, session_id=session_id)


@frappe.whitelist(allow_guest=True, methods=["GET"])
def get_initials(name: str) -> dict:
	"""Generate company initials avatar letters."""
	return {"initials": service.get_initials(name)}
