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


@frappe.whitelist(methods=["POST"])
def add(
	maker: str,
	colour: str,
	thickness: str | None = None,
	width: str | None = None,
	collection: str | None = None,
) -> dict:
	"""Новая плёнка производителя — прямо из каталога, сразу в коллекцию."""
	return service.add(maker, colour, thickness=thickness, width=width, collection=collection)


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
def set_card(
	item: str,
	code: str | None = None,
	type: str | None = None,  # noqa: A002 — the client's own name for it
	hex: str | None = None,  # noqa: A002
	ral: str | None = None,
	supplier: str | None = None,
	price_m: float | str | None = None,
	url: str | None = None,
	retail_m: float | str | None = None,
	wholesale_m: float | str | None = None,
	collection: str | None = None,
) -> dict:
	"""Карточка плёнки: код, тип, образец, RAL, поставщик, цена за метр, ссылка."""
	sent = frappe.form_dict
	card = {
		key: value
		for key, value in {
			"code": code, "type": type, "hex": hex, "ral": ral,
			"supplier": supplier, "price_m": price_m, "url": url,
			"retail_m": retail_m, "wholesale_m": wholesale_m, "collection": collection,
		}.items()
		if key in sent
	}
	return service.set_card(item, **card)
