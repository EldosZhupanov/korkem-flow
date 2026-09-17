# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Registration of new furniture companies and owners.

Allows a furniture maker to sign up natively from mobile or web:
1. Phone verification with OTP (+7 Kazakhstan format)
2. Personal profile (Full name, optional email)
3. Company details (Name, optional logo upload, fallback initials)
4. Full manager and owner permissions in ERPNext and KORKEM Flow
"""

from __future__ import annotations

import base64
import re
import secrets
import frappe
from frappe.utils import validate_email_address
from frappe.utils.file_manager import save_file
from frappe.utils.password import update_password

from korkem_ai.korkem_ai.onboarding import OWNER_ROLES
from korkem_manufacturing.services import auth_otp
from korkem_manufacturing.services.provisioning import name_the_shipping_warehouse


def get_initials(name: str) -> str:
	"""Generate 1 or 2 letter initials from company or person name."""
	parts = [p.strip() for p in (name or "").split() if p.strip()]
	if not parts:
		return "K"
	if len(parts) == 1:
		return parts[0][:2].upper()
	return f"{parts[0][0]}{parts[1][0]}".upper()


def register_company(
	*,
	company_name: str,
	owner_name: str,
	email: str = "",
	password: str = "",
	phone: str = "",
	logo_base64: str | None = None,
	country: str = "Kazakhstan",
	currency: str = "KZT",
) -> dict:
	"""Register a new furniture maker: create company, owner user, roles and binding."""
	company_name = (company_name or "").strip()
	owner_name = (owner_name or "").strip()
	phone = auth_otp.normalize_phone(phone)

	if not company_name:
		frappe.throw("Укажите название компании или цеха.", frappe.ValidationError)
	if not owner_name:
		frappe.throw("Укажите ваше имя и фамилию.", frappe.ValidationError)

	email = (email or "").strip().lower()
	if not email:
		if phone:
			digits = re.sub(r"\D", "", phone)
			email = f"owner_{digits}@korkem.user"
		else:
			frappe.throw("Укажите номер телефона или email.", frappe.ValidationError)
	else:
		validate_email_address(email, throw=True)

	if not password:
		password = secrets.token_urlsafe(12)
	elif len(password) < 6:
		frappe.throw("Пароль должен содержать не менее 6 символов.", frappe.ValidationError)

	caller = frappe.session.user
	frappe.set_user("Administrator")
	try:
		# 1. Check if user already exists
		if frappe.db.exists("User", email):
			frappe.throw(
				f"Пользователь с email {email} уже существует. Пожалуйста, выполните вход.",
				frappe.DuplicateEntryError,
			)

		# 2. Ensure company exists or create new
		logo_url = None
		if not frappe.db.exists("Company", company_name):
			letters = [c for c in company_name.upper() if c.isalnum()]
			base_abbr = "".join(letters[:5]) or "MFG"
			abbr = base_abbr
			idx = 1
			while frappe.db.exists("Company", {"abbr": abbr}):
				suffix = str(idx)
				abbr = f"{base_abbr[: max(1, 5 - len(suffix))]}{suffix}"
				idx += 1

			company_doc = frappe.get_doc(
				{
					"doctype": "Company",
					"company_name": company_name,
					"abbr": abbr,
					"default_currency": currency,
					"country": country,
				}
			)
			company_doc.insert(ignore_permissions=True)
			name_the_shipping_warehouse(company_name)

			# Attach logo if provided
			if logo_base64:
				try:
					raw_b64 = logo_base64.split(",", 1)[1] if "," in logo_base64 else logo_base64
					data = base64.b64decode(raw_b64)
					file_name = f"logo_{abbr.lower()}.png"
					file_doc = save_file(file_name, data, "Company", company_name, is_private=0)
					company_doc.company_logo = file_doc.file_url
					company_doc.save(ignore_permissions=True)
					logo_url = file_doc.file_url
				except Exception:
					pass

		# 3. Create owner user
		first_name, _, last_name = owner_name.partition(" ")
		if not first_name:
			first_name = owner_name

		user_doc = frappe.new_doc("User")
		user_doc.update(
			{
				"email": email,
				"first_name": first_name,
				"last_name": last_name,
				"mobile_no": phone,
				"user_type": "System User",
				"enabled": 1,
				"send_welcome_email": 0,
			}
		)
		for role in OWNER_ROLES:
			if frappe.db.exists("Role", role):
				user_doc.append("roles", {"role": role})

		user_doc.insert(ignore_permissions=True)

		# 4. Set password
		update_password(email, password)

		# 5. Bind to company via User Permission
		if not frappe.db.exists(
			"User Permission", {"user": email, "allow": "Company", "for_value": company_name}
		):
			frappe.get_doc(
				{
					"doctype": "User Permission",
					"user": email,
					"allow": "Company",
					"for_value": company_name,
					"apply_to_all_doctypes": 1,
				}
			).insert(ignore_permissions=True)

		frappe.db.commit()

		initials = get_initials(company_name)

		from korkem_manufacturing.services import analytics
		analytics.track_event("profile_completed", user=email, company=company_name, properties={"phone": phone, "has_logo": bool(logo_url)})
		analytics.track_event("company_created", user=email, company=company_name, properties={"company": company_name})
		analytics.track_event("onboarding_completed", user=email, company=company_name, properties={"role": "OWNER"})

		return {
			"status": "ok",
			"email": email,
			"phone": phone,
			"company": company_name,
			"user": email,
			"company_logo": logo_url or "",
			"company_initials": initials,
			"role": "OWNER",
			"setup_progress": 25,
			"message": "Регистрация успешно завершена",
		}
	finally:
		frappe.set_user(caller)
