# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Отчёт по заказам» — OnayBaza's «Тапсырыс есебі»: what was taken in a period.

Every accepted MDF order dated in [since, until] (drafts are not orders yet,
cancelled ones are counted apart): how many, how many m², for how much, what
is paid and what is owed. Split by status, by film and by customer, so the
owner sees at once what sold and who brought the money.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import flt, getdate, nowdate

from korkem_manufacturing.services import directions, facade_order, facade_prices, mdf_orders
from korkem_manufacturing.services.scope import current_company

MAX_DAYS = 366
TOP = 10


def _period(since: str | None, until: str | None) -> tuple:
	until_d = getdate(until or nowdate())
	since_d = getdate(since or until_d.replace(day=1))
	if since_d > until_d:
		frappe.throw("Начало периода позже конца.")
	if (until_d - since_d).days >= MAX_DAYS:
		frappe.throw("Период — не больше года.")
	return since_d, until_d


def _areas(names: list[str]) -> dict[str, Decimal]:
	if not names:
		return {}
	rows = frappe.get_all(
		"Sales Order Item",
		filters={"parent": ["in", names], "item_code": facade_order.FACADE_ITEM},
		fields=["parent", "korkem_area_m2"],
		limit_page_length=0,
	)
	areas: dict[str, Decimal] = {}
	for r in rows:
		areas[r.parent] = areas.get(r.parent, Decimal(0)) + Decimal(str(flt(r.korkem_area_m2)))
	return areas


def _bucket() -> dict:
	return {"orders": 0, "area_m2": Decimal(0), "total": Decimal(0), "paid": Decimal(0), "debt": Decimal(0)}


def _add(bucket: dict, area: Decimal, total: Decimal, paid: Decimal, debt: Decimal) -> None:
	bucket["orders"] += 1
	bucket["area_m2"] += area
	bucket["total"] += total
	bucket["paid"] += paid
	bucket["debt"] += debt


def _plain(bucket: dict) -> dict:
	return {k: (float(v) if isinstance(v, Decimal) else v) for k, v in bucket.items()}


def report(since: str | None = None, until: str | None = None) -> dict:
	"""The orders of [since, until] (by the order's date); the month so far by default."""
	facade_prices.ensure_editor()
	since_d, until_d = _period(since, until)
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": current_company(), "korkem_direction": directions.FACADES, "docstatus": ["in", [1, 2]],
				 "transaction_date": ["between", [since_d, until_d]]},
		fields=["name", "docstatus", "transaction_date", "delivery_date", "customer", "customer_name",
				"grand_total", "advance_paid", "korkem_finish", "korkem_decor_top", "korkem_ready_on",
				"korkem_handed_over_on", "korkem_hold_reason", *mdf_orders.STAGES.values()],
		limit_page_length=0,
	)
	areas = _areas([r.name for r in rows if r.docstatus == 1])
	totals, cancelled = _bucket(), 0
	by_status: dict[str, dict] = {}
	by_decor: dict[str, dict] = {}
	by_customer: dict[str, dict] = {}
	for r in rows:
		if r.docstatus == 2:
			cancelled += 1
			continue
		area = areas.get(r.name, Decimal(0))
		total = Decimal(str(flt(r.grand_total)))
		paid = Decimal(str(flt(r.advance_paid)))
		debt = mdf_orders._debt(r)
		_add(totals, area, total, paid, debt)
		status = mdf_orders.status_of(r)
		_add(by_status.setdefault(status, {"status": status, **_bucket()}), area, total, paid, debt)
		decor = r.korkem_decor_top or "—"
		_add(by_decor.setdefault(decor, {"decor": decor, **_bucket()}), area, total, paid, debt)
		customer = by_customer.setdefault(r.customer, {"customer": r.customer, "customer_name": r.customer_name,
													   **_bucket()})
		_add(customer, area, total, paid, debt)

	def ranked(groups: dict, limit: int | None = None) -> list[dict]:
		items = sorted(groups.values(), key=lambda g: (-g["total"], -g["area_m2"]))
		return [_plain(g) for g in (items[:limit] if limit else items)]

	order = {s: i for i, s in enumerate(("accepted", "in_shop", "ready", "on_hold", "handed_over"))}
	return {
		"since": str(since_d),
		"until": str(until_d),
		**_plain(totals),
		"area_m2": flt(totals["area_m2"], 2),
		"cancelled": cancelled,
		"by_status": sorted((_plain(b) for b in by_status.values()), key=lambda b: order.get(b["status"], 99)),
		"by_decor": ranked(by_decor),
		"top_customers": ranked(by_customer, TOP),
	}
