# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Видимость цен для цеха — тонкая обёртка над services/price_visibility.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import price_visibility as service


@frappe.whitelist(methods=["GET"])
def read() -> dict:
	"""Включено ли цеху видеть цены, видит ли их сам спрашивающий, может ли он это менять."""
	return service.status()


@frappe.whitelist(methods=["POST"])
def save(enabled: bool | int | str) -> dict:
	"""Администратор включает или выключает цены для цеха, склада и водителей."""
	return service.set_floor_sees_prices(enabled)
