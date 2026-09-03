# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Должность и доступ сотрудника — тонкая обёртка над services/staff.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import staff as service


@frappe.whitelist()
def members() -> list[dict]:
	"""Кто в компании и кем работает."""
	return service.members()


@frappe.whitelist()
def can_invite() -> bool:
	"""Может ли спрашивающий звать людей."""
	return service.can_invite()


@frappe.whitelist(methods=["POST"])
def change_position(email: str, position: str) -> dict:
	"""Сменить должность человека — то есть набор его прав."""
	return service.change_position(email=email, position=position)


@frappe.whitelist(methods=["POST"])
def deactivate(email: str) -> dict:
	"""Закрыть вход ушедшему."""
	return service.deactivate(email=email)


@frappe.whitelist(methods=["POST"])
def reactivate(email: str) -> dict:
	"""Вернуть доступ."""
	return service.reactivate(email=email)
