# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Итоги МДФ» (owner, 12.11.2026: «итоговый отчёт по продажам, объёма, кто
сколько заказывает, какой клиент уснул… на шаг впереди»).

What the period brought, against the period before it of the same length;
and what is coming:

- **plan** — the month's goal in m² the owner sets, and where the month will
  end at this pace;
- **shop** — m² in work, what the shop finishes a day (the last 30 days), so
  the day a new order would really be ready;
- **customers** — who orders most; who is new; who **fell asleep** — judged
  by the customer's own rhythm (the mean gap between his orders), not one
  number for all: a furniture maker who orders every 12 days and has not for
  41 is gone, one who orders monthly is not yet. One order only: 45 days;
- **films** — what is ordered most and whether the film for the open orders
  is on the shelf (`film_shortage`), so it goes on «К заказу» in time;
- **deadlines and quality** — handed over on time, overdue now, reworks and
  warranty jobs and why they came back;
- **debts** by age, and **managers** — who took how much;
- **stages** — where the open orders wait now, and how many will not make
  their date at the shop's pace; **days** — what came in, day by day, for
  the chart (owner, 14.11.2026: a dashboard on every department).

Nothing is stored but the goal: every number is counted from the orders.
"""

from __future__ import annotations

import math
from collections import Counter

import frappe
from frappe.utils import add_days, date_diff, flt, get_fullname, get_last_day, getdate, nowdate

from korkem_manufacturing.services import (
	audit,
	directions,
	facade_prices,
	film_shortage,
	mdf_orders,
	mdf_report,
	mdf_tags,
)
from korkem_manufacturing.services.scope import current_company

#: A customer with one order is asleep after this many days.
ASLEEP_ONE_ORDER_DAYS = 45
#: Gone when the gap is this many of his usual ones — falling asleep at the first.
GONE_TIMES, DOZING_TIMES = 2.0, 1.5
#: Never asleep sooner than this, however often he ordered.
MIN_ASLEEP_DAYS = 14
#: The shop's pace: what it finished over this many days.
PACE_DAYS = 30
TOP = 10
_TARGET = "korkem_mdf_target_m2"
_FIELDS = ["name", "docstatus", "transaction_date", "delivery_date", "customer", "customer_name", "owner",
		   "grand_total", "advance_paid", "korkem_decor_top", "korkem_milling", "korkem_ready_on",
		   "korkem_handed_over_on", "korkem_hold_reason", "korkem_tags", "korkem_finish", "korkem_extra_stages",
		   "korkem_coatings", *mdf_orders.STAGES.values()]


def _orders(company: str, since=None, until=None, **extra) -> list:
	filters = {"company": company, "korkem_direction": directions.FACADES, "docstatus": 1, **extra}
	if since is not None:
		filters["transaction_date"] = ["between", [since, until]]
	return frappe.get_all("Sales Order", filters=filters, fields=_FIELDS, order_by="transaction_date asc",
						  limit_page_length=0)


def _totals(rows: list, areas: dict) -> dict:
	area = sum(flt(areas.get(r.name)) for r in rows)
	total = sum(flt(r.grand_total) for r in rows)
	n = len(rows)
	return {
		"orders": n,
		"area_m2": round(area, 2),
		"total": round(total, 2),
		"paid": round(sum(flt(r.advance_paid) for r in rows), 2),
		"debt": round(sum(float(mdf_orders._debt(r)) for r in rows), 2),
		"avg_total": round(total / n) if n else 0,
		"avg_area": round(area / n, 2) if n else 0,
		"rate_m2": round(total / area) if area else 0,
	}


def target() -> float | None:
	value = frappe.db.get_default(f"{_TARGET}:{current_company()}")
	return flt(value) or None


def set_target(m2) -> dict:
	"""The month's goal in m²; empty — none."""
	facade_prices.ensure_editor()
	value = flt(m2) if m2 not in (None, "") else 0
	if value < 0 or value > 1_000_000:
		frappe.throw("Цель — число м² от нуля.")
	frappe.db.set_default(f"{_TARGET}:{current_company()}", str(value) if value else "")
	audit.record_audit(action="mdf.target_set", entity_type="Company", entity_id=current_company(),
					   diff={"m2": value or None})
	return {"target_m2": value or None}


def summary(since: str | None = None, until: str | None = None) -> dict:
	"""The period against the one before it, and what is coming."""
	facade_prices.ensure_editor()
	company = current_company()
	start, end = mdf_report._period(since, until)
	days = date_diff(end, start) + 1
	before_end = add_days(start, -1)
	before_start = add_days(before_end, -(days - 1))
	everything = _orders(company)
	areas = mdf_report._areas([r.name for r in everything])
	areas = {k: flt(v) for k, v in areas.items()}
	now_rows = [r for r in everything if start <= getdate(r.transaction_date) <= end]
	before_rows = [r for r in everything if getdate(before_start) <= getdate(r.transaction_date) <= getdate(before_end)]
	first_order: dict[str, object] = {}
	for r in everything:
		first_order.setdefault(r.customer, getdate(r.transaction_date))
	new = {r.customer for r in now_rows if start <= first_order[r.customer] <= end}
	return {
		"since": str(start),
		"until": str(end),
		"before": {"since": str(before_start), "until": str(before_end), **_totals(before_rows, areas)},
		**_totals(now_rows, areas),
		"customers_count": len({r.customer for r in now_rows}),
		"new_customers": len(new),
		"plan": _plan(everything, areas),
		"shop": _shop(everything, areas),
		"top_customers": _top(now_rows, areas, new),
		"asleep": _asleep(everything),
		"films": _films(now_rows, areas),
		"millings": _millings(now_rows, areas),
		"deadlines": _deadlines(everything, start, end),
		"quality": _quality(company, now_rows, areas, start, end),
		"debts": _debts(everything),
		"managers": _managers(now_rows, areas),
		**_stages(everything, areas),
		"days": _days(now_rows, areas, start, end),
	}


def _stages(rows: list, areas: dict) -> dict:
	"""Where each open order waits — the first stage of its own not ticked,
	as «Жоспар» counts it — and how many will miss their date."""
	today = getdate(nowdate())
	by = {s: {"stage": s, "orders": 0, "area_m2": 0.0} for s in mdf_orders.STAGES}
	at_risk = 0
	for r in rows:
		if mdf_orders.status_of(r) not in ("accepted", "in_shop"):
			continue
		needed = mdf_orders.stages_of(r)
		waiting = next((s for s in needed if not r.get(mdf_orders.STAGES[s])), None)
		if waiting is None:
			continue
		by[waiting]["orders"] += 1
		by[waiting]["area_m2"] += areas.get(r.name, 0)
		if r.delivery_date:
			left = len(needed) - needed.index(waiting)
			if mdf_orders._at_risk(left, (getdate(r.delivery_date) - today).days):
				at_risk += 1
	return {
		"stages": [{**s, "area_m2": round(s["area_m2"], 2)} for s in by.values()],
		"at_risk": at_risk,
	}


def _days(rows: list, areas: dict, start, end) -> list[dict]:
	"""Every day of the period: orders taken in, their m² and sum. A year
	is twelve months, not 365 bars: past 62 days, by month."""
	monthly = date_diff(end, start) > 62
	by: dict[str, dict] = {}
	for r in rows:
		day = getdate(r.transaction_date)
		key = str(day)[:7] if monthly else str(day)
		d = by.setdefault(key, {"date": key, "orders": 0, "area_m2": 0.0, "total": 0.0})
		d["orders"] += 1
		d["area_m2"] += areas.get(r.name, 0)
		d["total"] += flt(r.grand_total)
	out = []
	day = getdate(start)
	while day <= getdate(end):
		key = str(day)[:7] if monthly else str(day)
		if not out or out[-1]["date"] != key:
			d = by.get(key) or {"date": key, "orders": 0, "area_m2": 0.0, "total": 0.0}
			out.append({**d, "area_m2": round(d["area_m2"], 2), "total": round(d["total"], 2)})
		day = getdate(add_days(day, 1))
	return out


def _plan(rows: list, areas: dict) -> dict:
	"""The month so far against the goal, and where it ends at this pace."""
	today = getdate(nowdate())
	first, last = today.replace(day=1), getdate(get_last_day(today))
	done = sum(areas.get(r.name, 0) for r in rows if first <= getdate(r.transaction_date) <= today)
	money = sum(flt(r.grand_total) for r in rows if first <= getdate(r.transaction_date) <= today)
	elapsed, length = today.day, last.day
	goal = target()
	return {
		"target_m2": goal,
		"done_m2": round(done, 2),
		"done_total": round(money, 2),
		"days_left": length - elapsed,
		"forecast_m2": round(done / elapsed * length, 1) if elapsed else None,
		"forecast_total": round(money / elapsed * length) if elapsed else None,
		"progress": round(done / goal, 3) if goal else None,
	}


def _shop(rows: list, areas: dict) -> dict:
	"""What is in work, the shop's pace, and when a new order would be ready."""
	today = getdate(nowdate())
	open_rows = [r for r in rows if mdf_orders.status_of(r) in ("accepted", "in_shop")]
	in_work = sum(areas.get(r.name, 0) for r in open_rows)
	since = add_days(today, -PACE_DAYS)
	finished = sum(areas.get(r.name, 0) for r in rows
				   if r.korkem_ready_on and getdate(since) < getdate(r.korkem_ready_on) <= today)
	pace = finished / PACE_DAYS
	queue = math.ceil(in_work / pace) if pace > 0 else None
	ready = None
	if queue is not None:
		ready = getdate(add_days(today, max(queue, 1)))
		if ready.weekday() == 6:  # the shop's day off
			ready = getdate(add_days(ready, 1))
	return {
		"in_work_m2": round(in_work, 2),
		"in_work_orders": len(open_rows),
		"pace_m2_day": round(pace, 1),
		"queue_days": queue,
		"ready_on": str(ready) if ready else None,
		"overdue": sum(1 for r in open_rows if mdf_orders._overdue(r)),
	}


def _top(rows: list, areas: dict, new: set) -> list[dict]:
	by: dict[str, dict] = {}
	for r in rows:
		c = by.setdefault(r.customer, {"customer": r.customer, "customer_name": r.customer_name, "orders": 0,
									   "area_m2": 0.0, "total": 0.0})
		c["orders"] += 1
		c["area_m2"] += areas.get(r.name, 0)
		c["total"] += flt(r.grand_total)
	out = sorted(by.values(), key=lambda c: (-c["area_m2"], -c["total"], c["customer_name"] or ""))[:TOP]
	for c in out:
		c["area_m2"] = round(c["area_m2"], 2)
		c["total"] = round(c["total"], 2)
		c["tags"] = mdf_tags.parse(frappe.db.get_value("Customer", c["customer"], "korkem_tags"))
		c["new"] = c["customer"] in new
	return out


def _asleep(rows: list) -> list[dict]:
	"""Customers whose silence is longer than their own rhythm."""
	today = getdate(nowdate())
	dates: dict[str, list] = {}
	names: dict[str, str] = {}
	for r in rows:
		day = getdate(r.transaction_date)
		ds = dates.setdefault(r.customer, [])
		if not ds or ds[-1] != day:
			ds.append(day)
		names[r.customer] = r.customer_name
	out = []
	for customer, ds in dates.items():
		ds.sort()
		idle = (today - ds[-1]).days
		if len(ds) >= 2:
			rhythm = (ds[-1] - ds[0]).days / (len(ds) - 1)
			gone = max(rhythm * GONE_TIMES, MIN_ASLEEP_DAYS)
			dozing = max(rhythm * DOZING_TIMES, MIN_ASLEEP_DAYS)
		else:
			rhythm = None
			gone = dozing = ASLEEP_ONE_ORDER_DAYS
		if idle < dozing:
			continue
		out.append({
			"customer": customer,
			"customer_name": names[customer],
			"phone": frappe.db.get_value("Customer", customer, "mobile_no"),
			"orders": len(ds),
			"rhythm_days": round(rhythm) if rhythm is not None else None,
			"idle_days": idle,
			"last": str(ds[-1]),
			"gone": idle >= gone,
			# How far past his own rhythm — the most worrying first.
			"_weight": idle / (rhythm or ASLEEP_ONE_ORDER_DAYS),
		})
	out.sort(key=lambda c: (-c["orders"] * c["_weight"], c["customer_name"] or ""))
	for c in out:
		del c["_weight"]
	return out


def _films(rows: list, areas: dict) -> list[dict]:
	"""What film the period's orders were in, most m² first — and, for the
	open orders, whether that film is on the shelf."""
	by: dict[str, dict] = {}
	for r in rows:
		decor = r.korkem_decor_top or "—"
		f = by.setdefault(decor, {"decor": decor, "orders": 0, "area_m2": 0.0})
		f["orders"] += 1
		f["area_m2"] += areas.get(r.name, 0)
	try:
		short = {f["decor"]: f for f in film_shortage.shortage()["by_film"]}
	except frappe.PermissionError:
		short = {}
	out = sorted(by.values(), key=lambda f: -f["area_m2"])[:TOP]
	for f in out:
		s = short.get(f["decor"]) or {}
		f["area_m2"] = round(f["area_m2"], 2)
		f["item"] = s.get("item")
		f["needed_m"] = s.get("needed")
		f["free_m"] = s.get("free")
		f["to_buy_m"] = s.get("to_buy") or 0
	# A film the open orders lack, even if not among the period's top.
	for decor, s in short.items():
		if s.get("to_buy") and decor not in by:
			out.append({"decor": decor, "orders": 0, "area_m2": 0, "item": s.get("item"),
						"needed_m": s.get("needed"), "free_m": s.get("free"), "to_buy_m": s.get("to_buy")})
	return out


def _millings(rows: list, areas: dict) -> list[dict]:
	by: Counter = Counter()
	for r in rows:
		by[r.korkem_milling or "—"] += areas.get(r.name, 0)
	whole = sum(by.values())
	return [{"milling": m, "area_m2": round(a, 2), "share": round(a / whole, 3) if whole else 0}
			for m, a in by.most_common(5)]


def _deadlines(rows: list, start, end) -> dict:
	"""Of the orders handed over in the period: how many on time, how late
	the late ones were."""
	gone = [r for r in rows if r.korkem_handed_over_on and start <= getdate(r.korkem_handed_over_on) <= end]
	late = [date_diff(r.korkem_handed_over_on, r.delivery_date) for r in gone
			if r.delivery_date and getdate(r.korkem_handed_over_on) > getdate(r.delivery_date)]
	return {
		"handed_over": len(gone),
		"on_time": len(gone) - len(late),
		"on_time_share": round((len(gone) - len(late)) / len(gone), 3) if gone else None,
		"late_days_avg": round(sum(late) / len(late), 1) if late else None,
	}


def _quality(company: str, rows: list, areas: dict, start, end) -> dict:
	"""Reworks and warranty jobs — our cost — and why orders came back."""
	ours = [r for r in rows if set(mdf_tags.parse(r.korkem_tags)) & mdf_tags.NOT_OWED]
	whole = sum(areas.get(r.name, 0) for r in rows)
	area = sum(areas.get(r.name, 0) for r in ours)
	reasons: Counter = Counter()
	for a in frappe.get_all("Domain Audit Event",
							filters={"company": company, "action": "mdf.returned_to_work",
									 "creation": ["between", [f"{start} 00:00:00", f"{end} 23:59:59"]]},
							fields=["diff_json"], limit_page_length=500):
		try:
			reason = (frappe.parse_json(a.diff_json or "{}") or {}).get("reason")
		except ValueError:
			reason = None
		if reason:
			reasons[" ".join(str(reason).split()).lower()[:80]] += 1
	return {
		"orders": len(ours),
		"area_m2": round(area, 2),
		"share": round(area / whole, 3) if whole else 0,
		"returned": sum(reasons.values()),
		"reasons": [{"reason": r, "count": n} for r, n in reasons.most_common(3)],
	}


def _debts(rows: list) -> dict:
	"""What is owed, by how old the order is: a week, a month, more."""
	today = getdate(nowdate())
	buckets = {"week": [0.0, set()], "month": [0.0, set()], "older": [0.0, set()]}
	debtors: dict[str, dict] = {}
	for r in rows:
		debt = float(mdf_orders._debt(r))
		if debt <= 0:
			continue
		age = (today - getdate(r.transaction_date)).days
		key = "week" if age <= 7 else "month" if age <= 30 else "older"
		buckets[key][0] += debt
		buckets[key][1].add(r.customer)
		if key == "older":
			d = debtors.setdefault(r.customer, {"customer": r.customer, "customer_name": r.customer_name,
												"debt": 0.0, "days": 0})
			d["debt"] += debt
			d["days"] = max(d["days"], age)
	old = sorted(debtors.values(), key=lambda d: -d["debt"])[:5]
	for d in old:
		d["debt"] = round(d["debt"], 2)
		d["phone"] = frappe.db.get_value("Customer", d["customer"], "mobile_no")
	return {
		**{k: {"amount": round(v[0], 2), "customers": len(v[1])} for k, v in buckets.items()},
		"oldest": old,
	}


def _managers(rows: list, areas: dict) -> list[dict]:
	"""Who took the period's orders in: how many, m², money."""
	by: dict[str, dict] = {}
	for r in rows:
		m = by.setdefault(r.owner, {"user": r.owner, "orders": 0, "area_m2": 0.0, "total": 0.0})
		m["orders"] += 1
		m["area_m2"] += areas.get(r.name, 0)
		m["total"] += flt(r.grand_total)
	out = sorted(by.values(), key=lambda m: -m["total"])
	for m in out:
		m["name"] = get_fullname(m["user"]) or m["user"]
		m["area_m2"] = round(m["area_m2"], 2)
		m["total"] = round(m["total"], 2)
	return out
