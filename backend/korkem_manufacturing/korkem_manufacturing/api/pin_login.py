# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Вход по PIN на планшете цеха — тонкая обёртка над services/pin_login.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import pin_login as service


@frappe.whitelist(methods=["POST"])
def set_pin(user: str, pin: str) -> dict:
	"""Администратор назначает сотруднику PIN."""
	return service.set_pin(user, pin)


@frappe.whitelist(methods=["POST"])
def clear_pin(user: str) -> dict:
	"""Администратор снимает PIN."""
	return service.clear_pin(user)


@frappe.whitelist(methods=["GET"])
def people() -> list[dict]:
	"""У кого есть PIN (для экрана администратора)."""
	return service.people_with_pin()


@frappe.whitelist(methods=["POST"])
def register_device(label: str) -> dict:
	"""Сделать этот планшет планшетом для входа по PIN. Токен показывается один раз."""
	return service.register_device(label)


@frappe.whitelist(methods=["POST"])
def revoke_device(device: str) -> dict:
	"""Отключить планшет."""
	return service.revoke_device(device)


@frappe.whitelist(methods=["GET"])
def devices() -> list[dict]:
	"""Планшеты компании."""
	return service.devices()


@frappe.whitelist(allow_guest=True, methods=["POST"])
def device_people(device_token: str) -> dict:
	"""Кто может войти на этом планшете (только имена)."""
	return service.device_people(device_token)


@frappe.whitelist(allow_guest=True, methods=["POST"])
def login(device_token: str, user: str, pin: str) -> dict:
	"""Вход по PIN на зарегистрированном планшете."""
	return service.login(device_token, user, pin)
