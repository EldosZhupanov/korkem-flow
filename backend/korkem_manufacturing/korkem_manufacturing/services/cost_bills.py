# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Счета за месяц» (owner, 25.11.2026): the bills that come once a month —
свет, аренда, связь, оклады, налоги.

Every cost item counted as a `bill` has one line a month. The list repeats
itself: a month not filled in yet shows last month's sum beside it, so the
owner changes only what changed. Electricity may carry the meter's two
readings; the kWh used are what they differ by, and a month that used much
more power for no more m² is worth a look (`money_flow`).
"""

from __future__ import annotations

import frappe
from frappe.utils import add_months, flt, get_first_day, getdate, nowdate

from korkem_manufacturing.services import audit, cost_items
from korkem_manufacturing.services.scope import current_company

DOCTYPE = "Cost Bill"


def month_of(value: str | None = None):
	"""The first day of [value]'s month; this month by default."""
	return get_first_day(getdate(value or nowdate()))


def month(value: str | None = None) -> dict:
	"""The month's bills: each bill item with its sum, or last month's as a
	hint, and the meter."""
	cost_items.ensure_owner()
	company = current_company()
	cost_items.seed(company)
	first = month_of(value)
	before = add_months(first, -1)
	items = frappe.get_all(
		cost_items.DOCTYPE,
		filters={"company": company, "mode": "bill", "archived": 0, "merged_into": ["is", "not set"]},
		fields=["name", "title", "cost_group", "behaviour", "area", "unit", "monthly_limit"],
		order_by="title asc", limit_page_length=0,
	)
	bills = {(b.cost_item, str(b.month)): b for b in frappe.get_all(
		DOCTYPE, filters={"company": company, "month": ["in", [first, before]]},
		fields=["name", "cost_item", "month", "amount", "meter_from", "meter_to", "note"], limit_page_length=0)}
	rows, total = [], 0.0
	for i in items:
		now, last = bills.get((i.name, str(first))), bills.get((i.name, str(before)))
		amount = flt(now.amount) if now else None
		total += amount or 0
		rows.append({
			"item": i.name, "title": i.title, "group": i.cost_group, "behaviour": i.behaviour, "area": i.area,
			"unit": i.unit, "monthly_limit": flt(i.monthly_limit),
			"amount": amount, "last_amount": flt(last.amount) if last else None,
			"meter_from": flt(now.meter_from) if now and now.meter_from else None,
			"meter_to": flt(now.meter_to) if now and now.meter_to else None,
			# The meter carries on: this month starts where the last one ended.
			"meter_start": flt(last.meter_to) if last and last.meter_to else None,
			"used": _used(now), "last_used": _used(last),
			"note": now.note if now else None,
		})
	return {"month": str(first), "bills": rows, "total": round(total, 2),
			"filled": sum(1 for r in rows if r["amount"] is not None), "count": len(rows)}


def put(cost_item: str, month_value: str, amount, meter_from=None, meter_to=None, note: str | None = None) -> dict:
	"""The month's bill for [cost_item]: written, or changed."""
	cost_items.ensure_owner()
	company = current_company()
	item = cost_items.live(cost_item, company)
	first = month_of(month_value)
	if first > month_of():
		frappe.throw("Счёт за месяц, который ещё не наступил, не вносится.")
	value = flt(amount)
	if value < 0:
		frappe.throw("Сумма не меньше нуля.")
	start = flt(meter_from) if meter_from not in (None, "") else None
	end = flt(meter_to) if meter_to not in (None, "") else None
	if start is not None and end is not None and end < start:
		frappe.throw("Показание на конец месяца меньше, чем на начало.")
	name = frappe.db.get_value(DOCTYPE, {"company": company, "cost_item": item.name, "month": first}, "name")
	doc = frappe.get_doc(DOCTYPE, name) if name else frappe.get_doc(
		{"doctype": DOCTYPE, "company": company, "cost_item": item.name, "month": first})
	before = flt(doc.amount) if name else None
	doc.update({"amount": value, "meter_from": start, "meter_to": end,
				"note": " ".join(str(note or "").split())[:300] or None})
	doc.save(ignore_permissions=True)
	from korkem_manufacturing.services import money_flow

	frappe.cache().delete_value(money_flow.RATE_KEY.format(company=company))
	audit.record_audit(action="cost_bill.put", entity_type=DOCTYPE, entity_id=doc.name, company=company,
					   diff={"item": item.title, "month": str(first), "before": before, "amount": value})
	return month(str(first))


def _used(bill) -> float | None:
	if not bill or not bill.meter_to or bill.meter_from in (None, ""):
		return None
	return round(flt(bill.meter_to) - flt(bill.meter_from), 2)
