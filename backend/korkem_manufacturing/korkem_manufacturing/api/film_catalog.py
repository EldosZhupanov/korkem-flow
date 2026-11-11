# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Каталог плёнок ПВХ по производителям — тонкая обёртка над services/film_catalog.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import film_catalog as service


@frappe.whitelist(methods=["GET"])
def catalog() -> dict:
	"""Все плёнки с карточками и остатком; производители и типы для выбора."""
	return service.catalog()


_CARD_KEYS = (*service.CARD, *service.SHAPE)


def _sent(keys) -> dict:
	sent = frappe.form_dict
	return {key: sent.get(key) for key in keys if key in sent}


@frappe.whitelist(methods=["POST"])
def add(maker: str, colour: str, thickness: str | None = None, width: str | None = None) -> dict:
	"""Новая плёнка производителя — сразу с кодом, поверхностью, поставщиком и ценами."""
	return service.add(maker, colour, thickness=thickness, width=width, **_sent(service.CARD))


@frappe.whitelist(methods=["POST"])
def archive(item: str) -> dict:
	"""Плёнку в архив: из списков уходит, история и остаток остаются."""
	return service.archive(item)


@frappe.whitelist(methods=["POST"])
def restore(item: str) -> dict:
	"""Вернуть плёнку из архива."""
	return service.restore(item)


@frappe.whitelist(methods=["POST"])
def delete(item: str) -> dict:
	"""Удалить плёнку, по которой ничего не было; иначе — только архив."""
	return service.delete(item)


@frappe.whitelist(methods=["GET"])
def changes(item: str) -> list:
	"""История изменений плёнки: кто, когда и что поменял."""
	return service.changes(item)


@frappe.whitelist(methods=["POST"])
def drop_unassigned(colour: str) -> dict:
	"""Убрать старый цвет без производителя; заказы с ним остаются как записаны."""
	return service.drop_unassigned(colour)


@frappe.whitelist(methods=["POST"])
def add_collection(maker: str, name: str) -> dict:
	"""Новая коллекция производителя."""
	return service.add_collection(maker, name)


@frappe.whitelist(methods=["POST"])
def rename_collection(maker: str, name: str, new_name: str) -> dict:
	"""Переименовать коллекцию; её плёнки переходят следом."""
	return service.rename_collection(maker, name, new_name)


@frappe.whitelist(methods=["POST"])
def remove_collection(maker: str, name: str) -> dict:
	"""Убрать коллекцию; её плёнки остаются в каталоге без коллекции."""
	return service.remove_collection(maker, name)


@frappe.whitelist(methods=["POST"])
def set_card(item: str) -> dict:
	"""Карточка плёнки: название, толщина, ширина, код, поверхность, коллекция, поставщик, цены, ссылка."""
	return service.set_card(item, **_sent(_CARD_KEYS))
