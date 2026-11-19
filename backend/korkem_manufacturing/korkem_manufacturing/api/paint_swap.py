# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Замена цвета в заказе — `services.paint_swap`."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import paint_swap as service


@frappe.whitelist()
def options(order: str, colour: str) -> dict:
	"""Что предложить вместо цвета, которого нет у поставщиков."""
	return service.options(order, colour)


@frappe.whitelist(methods=["POST"])
def propose(order: str, colour: str, how: str, to: str | None = None, wait_until: str | None = None,
			note: str | None = None) -> dict:
	"""Заменить, заколеровать или ждать — спросить клиента."""
	return service.propose(order, colour, how, to=to, wait_until=wait_until, note=note)


@frappe.whitelist(methods=["POST"])
def agree(order: str, colour: str, via: str = "phone", who: str | None = None) -> dict:
	"""Клиент согласен."""
	return service.agree(order, colour, via=via, who=who)


@frappe.whitelist(methods=["POST"])
def cancel(order: str, colour: str) -> dict:
	"""Не спрашиваем — убрать, пока клиент не согласился."""
	return service.cancel(order, colour)
