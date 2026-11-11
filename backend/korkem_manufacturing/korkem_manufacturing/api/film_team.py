# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Команда отдела плёнки: месяц по продавцам и командный бонус — обёртка над services/film_team.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import film_team as service


@frappe.whitelist(methods=["GET"])
def team(month: str | None = None) -> dict:
	"""Месяц по продавцам: метры, продажи, оплачено, наценка; котёл и доли."""
	return service.team(month)


@frappe.whitelist(methods=["POST"])
def set_settings(plan_m: float | str | None = None, pct: float | str | None = None,
				 pct_below: float | str | None = None) -> dict:
	"""План команды на месяц (метры) и доли котла — задаёт владелец."""
	return service.set_settings(plan_m=plan_m, pct=pct, pct_below=pct_below)
