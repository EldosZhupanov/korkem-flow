# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Материалы — то, что видит экран и спрашивает ассистент."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import materials as service


@frappe.whitelist(methods=["GET"])
def materials(
	query: str | None = None,
	kind: str | None = None,
	thickness: float | str | None = None,
	color_family: str | None = None,
	limit: int | str = service.DEFAULT_PAGE,
	start: int | str = 0,
) -> dict:
	"""Страница каталога материалов этой компании."""
	return service.search(
		query=query,
		kind=kind,
		thickness=float(thickness) if thickness else None,
		color_family=color_family,
		limit=int(limit or service.DEFAULT_PAGE),
		start=int(start or 0),
	)


@frappe.whitelist(methods=["GET"])
def edges(thickness: float | str) -> dict:
	"""Кромка под эту толщину плиты."""
	return {"edges": service.edges_for(float(thickness))}
