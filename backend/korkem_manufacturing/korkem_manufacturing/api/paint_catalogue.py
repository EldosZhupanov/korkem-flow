# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Каталог красок: системы, цвета, похожие, по фото — `services.paint_catalogue`."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import paint_catalogue as service


@frappe.whitelist()
def catalogue() -> dict:
	"""Все цвета по системам: склад, ходовые, топ, тренды."""
	return service.catalogue()


@frappe.whitelist(methods=["POST"])
def take(value: str, system: str | None = None) -> dict:
	"""Цвет из каталога — в работу: в список «Краска»."""
	return service.take(value, system)


@frappe.whitelist(methods=["POST"])
def add_colour(name: str, system: str, code: str | None = None, hex: str | None = None,
			   note: str | None = None) -> dict:
	"""Свой цвет или цвет по коду системы."""
	return service.add_colour(name, system, code=code, hexcode=hex, note=note)


@frappe.whitelist(methods=["POST"])
def set_colour(key: str, title: str | None = None, hex: str | None = None, starred=None, hidden=None,
			   note: str | None = None) -> dict:
	"""Карточка цвета: название, оттенок, звезда, скрыть, заметка."""
	return service.set_colour(key, title=title, hexcode=hex, starred=starred, hidden=hidden, note=note)


@frappe.whitelist()
def similar(colour: str | None = None, hex: str | None = None, in_stock=False) -> dict:
	"""Похожие цвета — ближе выше."""
	return service.similar(colour=colour, hexcode=hex, in_stock=in_stock)


@frappe.whitelist(methods=["POST"])
def match_photo(content_b64: str) -> dict:
	"""Цвета, ближайшие к образцу на фото."""
	return service.match_photo(content_b64)
