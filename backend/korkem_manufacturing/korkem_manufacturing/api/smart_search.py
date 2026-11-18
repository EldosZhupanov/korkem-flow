# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Общий умный поиск — тонкая обёртка над services/smart_search.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import smart_search as service


@frappe.whitelist(methods=["GET"])
def find(q: str | None = None, limit: int | None = None) -> dict:
	"""Всё, что этот человек может видеть, по одной строке: клиенты и их долг, заказы фасадов и ЧПУ,
	оплаты, плёнки и декоры поставщиков, прочие заказы, производство и склад. Понимает телефон,
	номер заказа, неверную раскладку, латиницу и опечатку."""
	return service.find(q, limit)
