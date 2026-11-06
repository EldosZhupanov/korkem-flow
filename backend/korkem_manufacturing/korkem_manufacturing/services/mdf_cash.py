# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Касса» — OnayBaza's «Төлем есебі»: the money in and out over a period.

In: every payment on an MDF order (the Payment Entries `payments.record_payment`
submits), by day and by method — Kaspi, наличные, перевод, карта. Out: the
urgent expenses approved in that period (`urgent_expenses`), dated by the day
they were approved. The balance is in minus out.

Nothing is written here; the ledger stays ERPNext's. This is the owner's
evening question — «сколько пришло сегодня, сколько на Kaspi, сколько ушло» —
answered from what is already recorded.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import flt, getdate, nowdate

from korkem_manufacturing.services import directions, facade_prices, urgent_expenses
from korkem_manufacturing.services.scope import current_company

#: A period longer than this is a report, not a cash book.
MAX_DAYS = 366


def _period(since: str | None, until: str | None) -> tuple:
	until_d = getdate(until or nowdate())
	since_d = getdate(since or until_d)
	if since_d > until_d:
		frappe.throw("Начало периода позже конца.")
	if (until_d - since_d).days >= MAX_DAYS:
		frappe.throw("Период — не больше года.")
	return since_d, until_d


def _payments(company: str, since, until) -> list[dict]:
	return frappe.db.sql(
		"""
		select pe.posting_date as date, pe.mode_of_payment as method, pe.owner as received_by,
			   per.reference_name as order_name, so.customer_name, per.allocated_amount as amount
		from `tabPayment Entry Reference` per
		join `tabPayment Entry` pe on pe.name = per.parent
		join `tabSales Order` so on so.name = per.reference_name
		where per.reference_doctype = 'Sales Order' and pe.docstatus = 1 and pe.company = %(company)s
		  and so.korkem_direction = %(direction)s and pe.posting_date between %(since)s and %(until)s
		order by pe.posting_date asc, pe.creation asc
		""",
		{"company": company, "direction": directions.FACADES, "since": since, "until": until},
		as_dict=True,
	)


def _expenses(company: str, since, until) -> list[dict]:
	rows = frappe.get_all(
		urgent_expenses.DOCTYPE,
		filters={"company": company, "status": urgent_expenses.APPROVED,
				 "decided_at": ["between", [f"{since} 00:00:00", f"{until} 23:59:59.999999"]]},
		fields=["name", "decided_at", "amount", "purpose", "category", "requested_by", "sales_order"],
		order_by="decided_at asc",
		limit_page_length=5000,
	)
	return [
		{"name": r.name, "date": str(getdate(r.decided_at)), "amount": flt(r.amount), "purpose": r.purpose,
		 "category": r.category, "requested_by": r.requested_by, "order": r.sales_order}
		for r in rows
	]


def cash(since: str | None = None, until: str | None = None) -> dict:
	"""Money in by day and method, money out, and the balance, for [since, until]."""
	facade_prices.ensure_editor()
	company = current_company()
	since_d, until_d = _period(since, until)
	payments = [
		{"date": str(p.date), "method": p.method or "—", "order": p.order_name, "customer_name": p.customer_name,
		 "amount": flt(p.amount), "received_by": p.received_by}
		for p in _payments(company, since_d, until_d)
	]
	expenses = _expenses(company, since_d, until_d)

	days: dict[str, dict] = {}

	def day(date: str) -> dict:
		return days.setdefault(date, {"date": date, "in": Decimal(0), "out": Decimal(0), "by_method": {}})

	by_method: dict[str, Decimal] = {}
	for p in payments:
		amount = Decimal(str(p["amount"]))
		d = day(p["date"])
		d["in"] += amount
		d["by_method"][p["method"]] = d["by_method"].get(p["method"], Decimal(0)) + amount
		by_method[p["method"]] = by_method.get(p["method"], Decimal(0)) + amount
	for e in expenses:
		day(e["date"])["out"] += Decimal(str(e["amount"]))

	total_in = sum(by_method.values(), Decimal(0))
	total_out = sum((Decimal(str(e["amount"])) for e in expenses), Decimal(0))
	return {
		"since": str(since_d),
		"until": str(until_d),
		"days": [
			{"date": d["date"], "in": float(d["in"]), "out": float(d["out"]), "net": float(d["in"] - d["out"]),
			 "by_method": {m: float(v) for m, v in sorted(d["by_method"].items())}}
			for d in sorted(days.values(), key=lambda d: d["date"], reverse=True)
		],
		"by_method": [{"method": m, "amount": float(v)} for m, v in sorted(by_method.items(), key=lambda kv: -kv[1])],
		"payments": list(reversed(payments)),
		"expenses": list(reversed(expenses)),
		"total_in": float(total_in),
		"total_out": float(total_out),
		"net": float(total_in - total_out),
	}
