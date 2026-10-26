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
def set_status(line: str, status: str) -> dict:
	"""Отметить фасад: «В очереди», «В работе» или «Готово»."""
	return service.set_status(line=line, status=status)
