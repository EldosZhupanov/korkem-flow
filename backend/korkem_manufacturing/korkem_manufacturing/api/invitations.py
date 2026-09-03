# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Приглашение сотрудника — тонкая обёртка над services/invitations.py.

Существует ради одного пункта плана: каждый раз, когда владелец открывает
панель ERPNext, это дефект продукта. Завести замерщика — первое, ради чего он
её открывал.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import invitations as service


@frappe.whitelist(methods=["POST"])
def invite(email: str, position: str, first_name: str = "") -> dict:
	"""Завести сотрудника с ролями его должности."""
	return service.invite_employee(
		email=email, first_name=first_name, position=position
	)


@frappe.whitelist(methods=["GET"])
def positions() -> list[dict]:
	"""Должности, которые можно выбрать, и роли за каждой.

	Список отдаёт сервер, а не экран: должность здесь — это набор прав, и
	держать его вторым списком в приложении значит однажды дать человеку
	не то, что показали.
	"""
	return [
		{"position": position, "roles": list(roles)}
		for position, roles in sorted(service.POSITIONS.items())
	]
