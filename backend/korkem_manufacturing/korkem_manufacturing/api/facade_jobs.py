# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Задание цеху по фасадам — тонкая обёртка над services/facade_jobs.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import facade_jobs as service


@frappe.whitelist(methods=["GET"])
def jobs(status: str | None = None, limit: int = 100) -> dict:
	"""Фасады к изготовлению: размеры, фрезеровка, отделка. Без цен."""
	return service.jobs(status=status, limit=limit)


@frappe.whitelist(methods=["POST"])
def set_status(line: str, status: str, crew: str | list | None = None) -> dict:
	"""Отметить фасад: «В очереди», «В работе» или «Готово».

	`crew` — при «Готово»: кто делал и доли в % ([{"user", "share"}]); пусто — тот, кто отмечает.
	"""
	return service.set_status(line=line, status=status, crew=crew)


@frappe.whitelist(methods=["POST"])
def set_color_group(lines: str | list, group: str | None = None) -> dict:
	"""Назначить цветовую группу любым позициям фасадов — или снять её."""
	from korkem_manufacturing.services import facade_spec

	return facade_spec.set_color_group(lines=lines, group=group)
