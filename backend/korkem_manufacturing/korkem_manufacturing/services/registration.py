# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Registration of new furniture companies and owners.

Allows a furniture maker to sign up from the mobile or desktop app,
creating their company, standard chart of accounts, warehouses, and owner
account with full manager roles in ERPNext and KORKEM.
"""

from __future__ import annotations

import frappe
from frappe.utils import validate_email_address
from frappe.utils.password import update_password

from korkem_ai.korkem_ai.onboarding import OWNER_ROLES
from korkem_manufacturing.services.provisioning import name_the_shipping_warehouse


def register_company(
	*,
	company_name: str,
	owner_name: str,
	email: str,
	password: str,
	phone: str = "",
	country: str = "Kazakhstan",
	currency: str = "KZT",
) -> dict:
	"""Register a new furniture maker: create company, owner user, roles and binding."""
	company_name = (company_name or "").strip()
	owner_name = (owner_name or "").strip()
	email = (email or "").strip().lower()
	password = password or ""

	if not company_name:
		frappe.throw("Укажите название компании или цеха.")
	if not email:
		frappe.throw("Укажите электронную почту.")
	if not password or len(password) < 6:
		frappe.throw("Пароль должен содержать не менее 6 символов.")

	validate_email_address(email, throw=True)

	caller = frappe.session.user
	frappe.set_user("Administrator")
	try:
		# 1. Check if user already exists
		if frappe.db.exists("User", email):
			frappe.throw(
				f"Пользователь с email {email} уже существует. Пожалуйста, выполните вход."
			)

		# 2. Ensure company exists or create new
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

		# 3. Create owner user
		first_name, _, last_name = owner_name.partition(" ")
		if not first_name:
			first_name = email.split("@")[0]

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

		# 6. Bind to company via User Permission
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

		return {
			"status": "ok",
			"email": email,
			"company": company_name,
			"user": email,
			"message": "Регистрация успешно завершена",
		}
	finally:
		frappe.set_user(caller)
