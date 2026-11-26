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
from frappe.utils import add_days, add_months, flt, get_fullname, get_last_day, getdate, nowdate

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


def _previous(since_d, until_d) -> tuple:
	"""The period to compare with (owner, 26.11.2026: «лучше или хуже, чем в
	прошлом месяце?»): a month so far — the same days of the month before;
	a whole month — the whole month before; anything else — as many days
	just before it."""
	if since_d.day == 1 and since_d.month == 1 and until_d.year == since_d.year and until_d.month > 1:
		# The year so far: the same days of the year before.
		return add_months(since_d, -12), add_months(until_d, -12)
	if since_d.day == 1 and since_d.month == until_d.month and since_d.year == until_d.year:
		start = add_months(since_d, -1)
		last = get_last_day(start)
		end = last if until_d == get_last_day(until_d) else min(last, add_months(until_d, -1))
		return start, end
	days = (until_d - since_d).days + 1
	return add_days(since_d, -days), add_days(since_d, -1)


def _orders(since_d, until_d) -> list:
	return frappe.get_all(
		"Sales Order",
		filters={"company": current_company(), "korkem_direction": directions.FACADES, "docstatus": ["in", [1, 2]],
				 "transaction_date": ["between", [since_d, until_d]]},
		fields=["name", "docstatus", "transaction_date", "delivery_date", "customer", "customer_name",
				"grand_total", "advance_paid", "korkem_finish", "korkem_decor_top", "korkem_ready_on",
				"korkem_handed_over_on", "korkem_hold_reason", "korkem_tags", "owner",
				*mdf_orders.STAGES.values()],
		limit_page_length=0,
	)


def _totals(rows) -> dict:
	"""Orders, m², money of accepted orders — for the period compared with."""
	areas = _areas([r.name for r in rows if r.docstatus == 1])
	totals = _bucket()
	for r in rows:
		if r.docstatus == 2:
			continue
		_add(totals, areas.get(r.name, Decimal(0)), Decimal(str(flt(r.grand_total))),
			 Decimal(str(flt(r.advance_paid))), mdf_orders._debt(r))
	return {**_plain(totals), "area_m2": flt(totals["area_m2"], 2)}


def _lines(names: list[str]) -> list:
	if not names:
		return []
	return frappe.get_all(
		"Sales Order Item",
		filters={"parent": ["in", names], "item_code": facade_order.FACADE_ITEM},
		fields=["parent", "korkem_area_m2", "amount", "korkem_milling", "korkem_line_coating", "korkem_finish"],
		limit_page_length=0,
	)


#: What a coating is called in the report.
COATING_NAMES = {"pvc": "ПВХ плёнка", "paint": "Краска", "raw": "Черновой"}


def report(since: str | None = None, until: str | None = None) -> dict:
	"""The orders of [since, until] (by the order's date); the month so far by default.

	With the period before it to compare (owner, 26.11.2026), and cut by film,
	customer, milling, coating and the manager who took the order."""
	facade_prices.ensure_editor()
	since_d, until_d = _period(since, until)
	rows = _orders(since_d, until_d)
	prev_since, prev_until = _previous(since_d, until_d)
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

	# Milling and coating are a position's, not an order's: m² and money by line.
	by_milling: dict[str, dict] = {}
	by_coating: dict[str, dict] = {}
	by_manager: dict[str, dict] = {}
	accepted = {r.name: r for r in rows if r.docstatus == 1}
	for line in _lines(list(accepted)):
		order = accepted[line.parent]
		area = Decimal(str(flt(line.korkem_area_m2)))
		amount = Decimal(str(flt(line.amount)))
		coating = line.korkem_line_coating or mdf_orders.coating_of(line.korkem_finish or order.korkem_finish)
		for groups, key, label in (
			(by_milling, line.korkem_milling or "—", None),
			(by_coating, coating or "—", COATING_NAMES.get(coating or "", None)),
		):
			bucket = groups.setdefault(key, {"key": key, "label": label, "orders": set(), "area_m2": Decimal(0),
											 "total": Decimal(0)})
			bucket["orders"].add(order.name)
			bucket["area_m2"] += area
			bucket["total"] += amount
	for r in rows:
		if r.docstatus != 1:
			continue
		who = r.owner or "—"
		_add(by_manager.setdefault(who, {"manager": who, "manager_name": get_fullname(who) if who != "—" else who,
										 **_bucket()}),
			 areas.get(r.name, Decimal(0)), Decimal(str(flt(r.grand_total))), Decimal(str(flt(r.advance_paid))),
			 mdf_orders._debt(r))

	def by_line(groups: dict) -> list[dict]:
		items = sorted(groups.values(), key=lambda g: (-g["total"], -g["area_m2"]))
		return [{"key": g["key"], "label": g["label"], "orders": len(g["orders"]),
				 "area_m2": flt(g["area_m2"], 2), "total": float(g["total"])} for g in items]

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
		"by_milling": by_line(by_milling),
		"by_coating": by_line(by_coating),
		"by_manager": ranked(by_manager),
		"previous": {"since": str(prev_since), "until": str(prev_until),
					 **_totals(_orders(prev_since, prev_until))},
	}
