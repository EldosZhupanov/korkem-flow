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
def set_card(
	item: str,
	code: str | None = None,
	type: str | None = None,  # noqa: A002 — the client's own name for it
	hex: str | None = None,  # noqa: A002
	ral: str | None = None,
	supplier: str | None = None,
	price_m: float | str | None = None,
	url: str | None = None,
) -> dict:
	"""Карточка плёнки: код, тип, образец, RAL, поставщик, цена за метр, ссылка."""
	sent = frappe.form_dict
	card = {
		key: value
		for key, value in {
			"code": code, "type": type, "hex": hex, "ral": ral,
			"supplier": supplier, "price_m": price_m, "url": url,
		}.items()
		if key in sent
	}
	return service.set_card(item, **card)
