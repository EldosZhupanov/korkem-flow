# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Профессии цеха и у кого какие — тонкая обёртка над services/shop_trades.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import shop_trades as service


@frappe.whitelist(methods=["GET"])
def trades() -> dict:
	"""Профессии компании и кто их имеет."""
	return service.trades()


@frappe.whitelist(methods=["POST"])
def add_trade(title: str) -> dict:
	"""Добавить свою профессию («Фрезеровщик»)."""
	return service.add_trade(title)


@frappe.whitelist(methods=["POST"])
def set_enabled(trade: str, enabled: bool | int | str) -> dict:
	"""Включить или выключить профессию. Удалять нельзя — у людей история."""
	return service.set_enabled(trade, enabled)


@frappe.whitelist(methods=["POST"])
def set_member_trades(user: str, titles: str | list) -> dict:
	"""Профессии человека — весь список сразу, их может быть несколько."""
	return service.set_member_trades(user, titles)
