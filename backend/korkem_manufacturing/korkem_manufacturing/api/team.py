# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Команда по отделам и должностям — обёртка над services/team.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import team as service


@frappe.whitelist(methods=["GET"])
def people(include_left: bool | int | str = 0) -> dict:
	"""Отделы, должности и люди компании — с телефоном и входом, если есть."""
	return service.people(str(include_left).lower() in ("1", "true", "yes"))


@frappe.whitelist(methods=["POST"])
def add_person(name: str, posts: str | list | None = None, phone: str | None = None) -> dict:
	"""Новый сотрудник — без входа в программу; за него отмечает менеджер."""
	return service.add_person(name, posts=posts, phone=phone)


@frappe.whitelist(methods=["POST"])
def set_person(employee: str, name: str | None = None, posts: str | list | None = None,
			   phone: str | None = None) -> dict:
	"""Имя, телефон или должности — меняется то, что прислано."""
	return service.set_person(employee, name=name, posts=posts, phone=phone)


@frappe.whitelist(methods=["POST"])
def set_active(employee: str, active: bool | int | str) -> dict:
	"""Уволен — выключен, не удалён: его работа остаётся за ним."""
	return service.set_active(employee, active)


@frappe.whitelist(methods=["POST"])
def link_user(employee: str, user: str | None = None) -> dict:
	"""Привязать сотрудника к его входу — чтобы он видел свои заказы с телефона."""
	return service.link_user(employee, user or None)
