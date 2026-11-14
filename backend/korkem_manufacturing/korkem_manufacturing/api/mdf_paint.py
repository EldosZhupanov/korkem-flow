# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Отдел краски — тонкая обёртка над services/mdf_paint.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import mdf_paint as service


@frappe.whitelist(methods=["GET"])
def board() -> dict:
	"""Что красить по цветам, что сохнет, что едет, популярные цвета."""
	return service.board()


@frappe.whitelist(methods=["POST"])
def start_drying(order: str) -> dict:
	"""«Покрасил — сушится»."""
	return service.start_drying(order)


@frappe.whitelist(methods=["POST"])
def stop_drying(order: str) -> dict:
	"""Поставили сушиться по ошибке."""
	return service.stop_drying(order)


@frappe.whitelist(methods=["POST"])
def set_dry_hours(hours: int | str) -> dict:
	"""Сколько часов сохнет краска на этом заводе."""
	return service.set_dry_hours(hours)


@frappe.whitelist(methods=["POST"])
def client_paint_in(order: str, note: str | None = None) -> dict:
	"""«Краска клиента принесена»."""
	return service.client_paint_in(order, note)


@frappe.whitelist(methods=["POST"])
def settings(dry_hours: int | str | None = None, client_paint_discount: float | str | None = None) -> dict:
	"""Сушка в часах и скидка за м² при краске клиента."""
	return service.settings(dry_hours, client_paint_discount)
