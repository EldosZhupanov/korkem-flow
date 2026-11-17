# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Мои заказы» — этапы сотрудника с его телефона; обёртка над services/my_work.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import my_work as service


@frappe.whitelist(methods=["GET"])
def work() -> dict:
	"""Мои этапы: можно делать, скоро дойдут; мой объём за месяц."""
	return service.work()


@frappe.whitelist(methods=["POST"])
def done(order: str, stage: str, undo: bool | int | str = 0) -> dict:
	"""«Сделал» — свой этап заказа, с моим именем; «Отменить» — в тот же день."""
	return service.done(order, stage, undo)
