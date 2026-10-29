# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Сдельная оплата — тонкая обёртка над services/piece_rates.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import piece_rates as service


@frappe.whitelist(methods=["GET"])
def rates() -> dict:
	"""Тарифы и коэффициенты компании."""
	return service.rates()


@frappe.whitelist(methods=["POST"])
def set_rate(operation: str, rate_type: str, rate: float | str, enabled: bool | int | str = True) -> dict:
	"""Тариф операции (администратор, начальник производства)."""
	return service.set_rate(operation, rate_type, rate, enabled)


@frappe.whitelist(methods=["POST"])
def save_rules(
	shift_end: str | None = None,
	overtime_factor: float | str | None = None,
	weekend_factor: float | str | None = None,
	saturday_is_weekend: int | str | None = None,
	sunday_is_weekend: int | str | None = None,
	daily_bonus_threshold: float | str | None = None,
	daily_bonus: float | str | None = None,
	monthly_bonus_threshold: float | str | None = None,
	monthly_bonus: float | str | None = None,
) -> dict:
	"""Коэффициенты сверхурочных и выходных, пороги премий; не присланное поле не меняется."""
	sent = {
		key: value
		for key, value in {
			"shift_end": shift_end,
			"overtime_factor": overtime_factor,
			"weekend_factor": weekend_factor,
			"saturday_is_weekend": saturday_is_weekend,
			"sunday_is_weekend": sunday_is_weekend,
			"daily_bonus_threshold": daily_bonus_threshold,
			"daily_bonus": daily_bonus,
			"monthly_bonus_threshold": monthly_bonus_threshold,
			"monthly_bonus": monthly_bonus,
		}.items()
		if value is not None
	}
	return service.save_rules(**sent)


@frappe.whitelist(methods=["GET"])
def pending() -> list[dict]:
	"""Начисления, ждущие утверждения."""
	return service.pending()


@frappe.whitelist(methods=["POST"])
def approve(entry: str) -> dict:
	"""Утвердить начисление (не своё)."""
	return service.approve(entry)


@frappe.whitelist(methods=["POST"])
def reject(entry: str, reason: str) -> dict:
	"""Отклонить начисление с причиной — работник её увидит."""
	return service.reject(entry, reason)


@frappe.whitelist(methods=["GET"])
def my_work(days: int = 31) -> dict:
	"""Моя выработка и заработок за последние дни."""
	return service.my_work(days)
