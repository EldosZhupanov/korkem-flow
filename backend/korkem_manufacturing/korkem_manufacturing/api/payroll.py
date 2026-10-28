# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Ведомость, авансы, штрафы, премии — тонкая обёртка над services/payroll.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import payroll as service


@frappe.whitelist(methods=["GET"])
def statement(from_date: str | None = None, to_date: str | None = None) -> dict:
	"""Ведомость за период: сдельно, премии, штрафы, авансы, к выплате."""
	return service.statement(from_date=from_date, to_date=to_date)


@frappe.whitelist(methods=["GET"])
def statement_csv(from_date: str | None = None, to_date: str | None = None) -> dict:
	"""Та же ведомость в CSV для бухгалтерии."""
	return {"filename": f"vedomost_{from_date or ''}_{to_date or ''}.csv".replace("__", "_"),
			"csv": service.statement_csv(from_date=from_date, to_date=to_date)}


@frappe.whitelist(methods=["GET"])
def adjustments(from_date: str | None = None, to_date: str | None = None) -> list[dict]:
	"""Авансы, штрафы и премии за период."""
	return service.adjustments(from_date=from_date, to_date=to_date)


@frappe.whitelist(methods=["POST"])
def add_adjustment(
	employee: str,
	kind: str,
	amount: float | str,
	reason: str,
	on_date: str | None = None,
	sales_order: str | None = None,
) -> dict:
	"""Внести аванс, штраф или премию (начальник производства, администратор)."""
	return service.add_adjustment(
		employee=employee, kind=kind, amount=amount, reason=reason, on_date=on_date, sales_order=sales_order
	)


@frappe.whitelist(methods=["POST"])
def approve_adjustment(adjustment: str) -> dict:
	"""Утвердить — другой человек, не тот, кого касается, и не тот, кто вносил."""
	return service.approve_adjustment(adjustment)


@frappe.whitelist(methods=["POST"])
def reverse_adjustment(adjustment: str, reason: str) -> dict:
	"""Сторнировать с причиной; запись не удаляется."""
	return service.reverse_adjustment(adjustment, reason)


@frappe.whitelist(methods=["GET"])
def my_progress() -> dict:
	"""Мой путь к премии дня и месяца."""
	return service.my_progress()


@frappe.whitelist(methods=["GET"])
def workers() -> list[dict]:
	"""Сотрудники компании — только имена: для бригады и для удержаний."""
	return service.workers()
