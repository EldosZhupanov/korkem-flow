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
def set_person(employee: str | None = None, name: str | None = None, posts: str | list | None = None,
			   phone: str | None = None, user: str | None = None) -> dict:
	"""Имя, телефон или должности — меняется то, что прислано. Вход без
	сотрудника (`user`) становится сотрудником здесь же."""
	return service.set_person(employee or None, name=name, posts=posts, phone=phone, user=user or None)


@frappe.whitelist(methods=["POST"])
def set_active(active: bool | int | str, employee: str | None = None, user: str | None = None) -> dict:
	"""Уволен — выключен, не удалён: его работа остаётся за ним; вход — вместе с ним."""
	return service.set_active(employee or None, active, user=user or None)


@frappe.whitelist(methods=["POST"])
def link_user(employee: str, user: str | None = None) -> dict:
	"""Привязать сотрудника к его входу — чтобы он видел свои заказы с телефона."""
	return service.link_user(employee, user or None)


@frappe.whitelist(methods=["GET"])
def report(period: str = "month", day: str | None = None) -> dict:
	"""Сотрудники за день, неделю или месяц: должности, объём, дни с работой, зарплата и остаток."""
	from korkem_manufacturing.services import people_report

	return people_report.overview(period, day)


@frappe.whitelist(methods=["GET"])
def person_card(employee: str | None = None, period: str = "month", day: str | None = None) -> dict:
	"""Карточка сотрудника за период: по дням, каждый этап, авансы и выплаты. Без employee — своя."""
	from korkem_manufacturing.services import people_report

	return people_report.person(employee, period, day)


@frappe.whitelist(methods=["POST"])
def set_post(post: str, on: bool | int | str = 1, employee: str | None = None, user: str | None = None) -> dict:
	"""Дать человеку одну должность или снять её."""
	from korkem_manufacturing.services import team_people

	return team_people.set_post(post, on, employee=employee or None, user=user or None)


@frappe.whitelist(methods=["GET"])
def open_work(employee: str, post: str | None = None) -> list[dict]:
	"""Этапы заказов, отданные ему и ещё не сделанные — только этой должности, если сказано."""
	from korkem_manufacturing.services import team_people

	return team_people.open_work(employee, post or None)


@frappe.whitelist(methods=["POST"])
def hand_over(employee: str, to: str | None = None, post: str | None = None) -> dict:
	"""Его незакрытые этапы — другому; без `to` — никому, менеджер раздаст снова."""
	from korkem_manufacturing.services import team_people

	return team_people.hand_over(employee, to or None, post or None)


@frappe.whitelist(methods=["GET"])
def dismissal(employee: str) -> dict:
	"""Перед «Уволен»: его незакрытые этапы и несведённые деньги."""
	from korkem_manufacturing.services import team_people

	return team_people.dismissal(employee)


@frappe.whitelist(methods=["GET"])
def duplicates(name: str | None = None, phone: str | None = None) -> list[dict]:
	"""Уже есть человек с таким именем или телефоном — и ушедшие тоже."""
	from korkem_manufacturing.services import team_people

	return team_people.duplicates(name, phone)
