# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Приложение сообщает узлу адрес своего устройства.

Тонкая обёртка над `integrations.push`, по соседству с `channels_api`. Правило
одно: клиент называет только свой адрес и только за себя. Кто это, сервер берёт
из сессии и никогда из запроса — иначе подписаться на чужие уведомления или
отписать чужой телефон можно было бы одним параметром.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai.integrations import push as service


@frappe.whitelist(methods=["POST"])
def register(token: str) -> dict:
	"""Запомнить этот телефон для вошедшего человека."""
	return service.register_device(token)


@frappe.whitelist(methods=["POST"])
def forget(token: str) -> dict:
	"""Выход из приложения: на этот телефон больше не присылать.

	Отвязывается только названный адрес и только если он принадлежит этому
	человеку. Иначе выход одного работника отключал бы уведомления другому —
	достаточно было бы знать чужой адрес, а адреса устройств живут в базе рядом.
	"""
	name = frappe.db.get_value(
		service.IDENTITY_DOCTYPE,
		{"channel": service.CHANNEL, "external_id": (token or "").strip()},
		["name", "user"],
		as_dict=True,
	)
	if not name:
		return {"forgotten": False}
	if name.user != frappe.session.user:
		frappe.throw("Этот телефон привязан к другому человеку.", frappe.PermissionError)
	return service.forget_device(token)
