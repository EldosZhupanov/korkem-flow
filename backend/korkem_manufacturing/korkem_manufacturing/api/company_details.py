# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Реквизиты компании — тонкая обёртка над services/company_details.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import company_details as service


@frappe.whitelist(methods=["GET"])
def read() -> dict:
	"""Что записано о компании сейчас."""
	return service.read()


@frappe.whitelist(methods=["POST"])
def save(
	bin: str | None = None,
	phone: str | None = None,
	email: str | None = None,
	website: str | None = None,
	address: str | None = None,
	city: str | None = None,
	bank_name: str | None = None,
	bank_account: str | None = None,
	bik: str | None = None,
) -> dict:
	"""Записать реквизиты; пустое поле означает «пока не знаю»."""
	return service.save(
		bin=bin,
		phone=phone,
		email=email,
		website=website,
		address=address,
		city=city,
		bank_name=bank_name,
		bank_account=bank_account,
		bik=bik,
	)
