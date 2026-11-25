# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Рейтинг клиентов» (owner, 25.11.2026): who brings the most money, who
pays fast, who drags it out.

Every customer with accepted facade or CNC orders in the period, by the
money his orders came to, most first:

- **share and class.** His part of all the period's money, and the class it
  puts him in — A, the few who together bring 80 %; B, the next 15 %; C,
  the rest. A is who the shop cannot lose.
- **how fast he pays.** For each order paid up, the days from when he took
  it (the day it was handed over; an order paid before that — 0) to its
  last payment; their average. Orders still owing are not in it: they say
  how long he owes now, apart.
- **the mark.** «Платит быстро» — three days or less on average and nothing
  owed past a week. «Тянет» — more than two weeks on average, or something
  owed past a month. The rest pay as usual; without a paid order there is
  nothing to say yet.

Two queries for the whole list — the orders and their payments' days —
whatever the number of customers.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import add_months, date_diff, flt, getdate, nowdate

from korkem_manufacturing.services import cnc_orders, directions, facade_prices, mdf_orders
from korkem_manufacturing.services.scope import current_company

#: Periods to rank by, months back from today; 0 — all his time.
PERIODS = {"3m": 3, "12m": 12, "all": 0}
FAST_DAYS = 3
SLOW_DAYS = 14
#: Owed this long, days, and he drags it out whatever his average.
LONG_DEBT_DAYS = 30
#: Owed longer than this, days, and he is not «fast».
OLD_DEBT_DAYS = 7
_CLASS_A, _CLASS_B = Decimal("0.80"), Decimal("0.95")


def rating(period: str | None = None) -> dict:
	facade_prices.ensure_editor()
	months = PERIODS.get(period or "12m", 12)
	company = current_company()
	today = getdate(nowdate())
	filters = {"company": company, "docstatus": 1,
			   "korkem_direction": ["in", [directions.FACADES, directions.CNC]]}
	if months:
		filters["transaction_date"] = [">=", add_months(today, -months)]
	rows = frappe.get_all(
		"Sales Order", filters=filters,
		fields=["name", "docstatus", "customer", "customer_name", "transaction_date", "grand_total",
				"advance_paid", "korkem_direction", "korkem_tags", "korkem_handed_over_on"],
		limit_page_length=0,
	)
	paid_on = _last_payments([r.name for r in rows])
	people: dict[str, dict] = {}
	for r in rows:
		p = people.setdefault(r.customer, {
			"customer": r.customer, "name": r.customer_name or r.customer, "orders": 0,
			"total": Decimal(0), "paid": Decimal(0), "debt": Decimal(0), "days": [], "oldest_debt_days": None,
			"last_order": None,
		})
		total = Decimal(str(flt(r.grand_total)))
		debt = (cnc_orders._debt if r.korkem_direction == directions.CNC else mdf_orders._debt)(r)
		p["orders"] += 1
		p["total"] += total
		p["paid"] += Decimal(str(flt(r.advance_paid)))
		p["debt"] += debt
		day = str(r.transaction_date)
		p["last_order"] = max(p["last_order"] or day, day)
		taken = r.korkem_handed_over_on or r.transaction_date
		if debt > 0:
			owed = max(0, date_diff(today, taken))
			p["oldest_debt_days"] = max(p["oldest_debt_days"] or 0, owed)
		elif flt(r.advance_paid) >= flt(r.grand_total) - 0.5 and r.name in paid_on:
			p["days"].append(pay_days(r.korkem_handed_over_on, paid_on[r.name]))
	everyone = sum((p["total"] for p in people.values()), Decimal(0))
	ranked = sorted(people.values(), key=lambda p: (-p["total"], p["name"]))
	out, running = [], Decimal(0)
	for p in ranked:
		share = p["total"] / everyone if everyone else Decimal(0)
		running += share
		average = round(sum(p["days"]) / len(p["days"]), 1) if p["days"] else None
		out.append({
			"customer": p["customer"],
			"name": p["name"],
			"orders": p["orders"],
			"total": float(p["total"]),
			"paid": float(p["paid"]),
			"debt": float(p["debt"]),
			"share": round(float(share) * 100, 1),
			# The first to cross 80 % is still an A: he is one of the few.
			"class": "A" if running - share < _CLASS_A else "B" if running - share < _CLASS_B else "C",
			"pay_days": average,
			"paid_orders": len(p["days"]),
			"oldest_debt_days": p["oldest_debt_days"],
			"mark": mark(average, p["oldest_debt_days"]),
			"last_order": p["last_order"],
		})
	return {"period": period if period in PERIODS else "12m", "total": float(everyone), "customers": out}


def pay_days(handed_over_on, paid_on) -> int:
	"""Days from the order taken to its last payment; paid before — 0."""
	if not handed_over_on:
		return 0
	return max(0, date_diff(paid_on, handed_over_on))


def mark(average: float | None, oldest_debt_days: int | None) -> str | None:
	"""fast / slow / usual — or None while there is nothing to go by."""
	owes = oldest_debt_days or 0
	if owes > LONG_DEBT_DAYS or (average is not None and average > SLOW_DAYS):
		return "slow"
	if average is None:
		return None
	if average <= FAST_DAYS and owes <= OLD_DEBT_DAYS:
		return "fast"
	return "usual"


def _last_payments(orders: list[str]) -> dict[str, str]:
	"""Each order's last payment day, in one query."""
	if not orders:
		return {}
	rows = frappe.db.sql(
		"""
		select per.reference_name as order_name, max(pe.posting_date) as day
		from `tabPayment Entry Reference` per
		join `tabPayment Entry` pe on pe.name = per.parent
		where per.reference_doctype = 'Sales Order' and pe.docstatus = 1 and per.reference_name in %(orders)s
		group by per.reference_name
		""",
		{"orders": tuple(orders)},
		as_dict=True,
	)
	return {r.order_name: str(r.day) for r in rows}
