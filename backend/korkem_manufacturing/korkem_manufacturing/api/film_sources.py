# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Где берём плёнку: поставщики и оптовики — тонкая обёртка над services/film_sources.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import film_sources as service

_KEYS = ("name", "makers", *service.CARD)


def _card() -> dict:
	sent = frappe.form_dict
	return {key: sent.get(key) for key in _KEYS if key in sent}


@frappe.whitelist(methods=["GET"])
def sources() -> dict:
	"""Все поставщики с карточками; производители для отметки."""
	return service.sources()


@frappe.whitelist(methods=["POST"])
def add(name: str) -> dict:
	"""Новый поставщик: название и карточка."""
	card = _card()
	card.pop("name", None)
	return service.add(name, **card)


@frappe.whitelist(methods=["POST"])
def set_card(supplier: str) -> dict:
	"""Карточка поставщика: город, контакт, телефоны, чьи плёнки продаёт."""
	return service.set_card(supplier, **_card())


@frappe.whitelist(methods=["POST"])
def remove(supplier: str) -> dict:
	"""Убрать поставщика из списка (приходы его помнят)."""
	return service.remove(supplier)


@frappe.whitelist(methods=["GET"])
def maker(name: str) -> dict:
	"""Карточка производителя: сайт, заметка и где берём его плёнку."""
	return service.maker(name)


@frappe.whitelist(methods=["POST"])
def set_maker(name: str, site: str | None = None, note: str | None = None) -> dict:
	"""Сайт и заметка производителя."""
	return service.set_maker(name, site=site, note=note)
