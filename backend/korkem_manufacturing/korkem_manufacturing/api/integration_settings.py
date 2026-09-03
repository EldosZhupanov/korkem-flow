# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Настройки TrustMe и Kaspi — тонкая обёртка над сервисом.

Ни один из этих ответов не содержит секрета: `status` говорит «настроено» или
«нет», и этого экрану достаточно.
"""

from __future__ import annotations

import json

import frappe

from korkem_manufacturing.services import integration_settings as service


@frappe.whitelist(methods=["GET"])
def status() -> dict:
	"""Что подключено, без единого значения."""
	return service.status()


@frappe.whitelist(methods=["POST"])
def save(provider: str, values: str | dict) -> dict:
	"""Записать настройки; пустое поле означает «не менять»."""
	if isinstance(values, str):
		values = json.loads(values)
	return service.save(provider=provider, values=values)


@frappe.whitelist(methods=["POST"])
def clear_secret(provider: str, field: str) -> dict:
	"""Убрать ключ — отдельным намеренным действием."""
	return service.clear_secret(provider=provider, field=field)
