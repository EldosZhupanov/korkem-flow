# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Цех» — the shop at a glance (owner, 26.11.2026: «общий план м², которые
сделал каждый заказ, отдел, и сколько м² по факту, по плану»).

Three levels, one picture, and nothing counted that is not counted already:

- **the month**: the plan — the month's goal in m² (`mdf_summary.target`)
  or, with none set, the m² of the orders due this month — against what is
  ready; what should be ready by today, by working days (Monday to
  Saturday); and where the month ends at the pace of the last two weeks;
- **each stage**, in the order an order goes: what waits (`mdf_orders.plan`,
  «Жоспар»'s own queue), what was ticked today and this month
  (`mdf_volume._ticked`, «Объём работ»'s own count), how many days of work
  that is at the stage's pace, and its people — what each did today and
  how many open stages are given to him; a post with nobody on it says so;
- **the orders** late or about to be, from «Жоспар»'s own flags.

Beside the shop, the two departments that do not follow an order: film
sales and the warehouse, with their people and today's figures.
"""

from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta

import frappe
from frappe.utils import add_days, flt, get_first_day, get_last_day, getdate, nowdate

from korkem_manufacturing.services import (
	audit,
	directions,
	facade_prices,
	film_team,
	mdf_orders,
	mdf_summary,
	mdf_volume,
	search_text,
	team,
)
from korkem_manufacturing.services.scope import current_company

#: The order a facade goes through the shop; vacuum and paint are the two
#: branches after sanding (an order takes one, or both when reworked).
FLOW = ("cut", "mill", "sand", "vacuum", "paint", "ready")
#: Days the pace is taken over — working days, today not counted.
PACE_DAYS = 14
#: A stage with more waiting than this many days of its work is a jam.
JAM_DAYS = 2
_TARGET = "korkem_shop_target_m2"
#: Off the order's road, with their own posts.
SIDE = {"film_sales": ("film_sales.seller", "film_sales.loader"),
		"warehouse": ("warehouse.storekeeper", "warehouse.driver")}


def workday(d: date) -> bool:
	"""Monday to Saturday: the shop does not work on Sunday."""
	return d.weekday() < 6


def workdays(start: date, end: date) -> int:
	return sum(1 for i in range((end - start).days + 1) if workday(start + timedelta(days=i)))


def board(day: str | None = None) -> dict:
	"""The month, the stages and the late orders, as of [day] (today)."""
	facade_prices.ensure_editor()
	company = current_company()
	today = getdate(day or nowdate())
	first, last = get_first_day(today), get_last_day(today)
	plan = mdf_orders.plan(1)
	pace_from = _workdays_back(today, PACE_DAYS)
	ticks = mdf_volume._ticked(company, min(first, pace_from), today)
	areas = mdf_volume._areas({t[0] for t in ticks})
	done = defaultdict(lambda: {"today": 0.0, "month": 0.0, "pace": 0.0})
	by_person = defaultdict(float)
	for order, stage, who, on in ticks:
		on = getdate(on)
		m2 = flt(areas.get(order))
		if on == today:
			done[stage]["today"] += m2
			if who:
				by_person[(stage, who)] += m2
		if first <= on <= today:
			done[stage]["month"] += m2
		if pace_from <= on < today:
			done[stage]["pace"] += m2
	pace_days = max(workdays(pace_from, add_days(today, -1)), 1)
	return {
		"day": str(today),
		"month": _month(company, today, first, last, done["ready"], plan, pace_days),
		"stages": [_stage(company, s, plan, done[s], by_person, pace_days) for s in FLOW],
		"late": _late(plan),
		"side": _side(company, today, first),
	}


def target(company: str | None = None) -> float | None:
	"""The shop's own goal for the month, in m² made — not «Итоги»'s goal,
	which is m² taken in (`mdf_summary.target`)."""
	return flt(frappe.db.get_default(f"{_TARGET}:{company or current_company()}")) or None


def set_target(m2) -> dict:
	"""The shop's month goal in m² made; empty — the orders due this month."""
	facade_prices.ensure_editor()
	value = flt(m2) if m2 not in (None, "") else 0
	if value < 0 or value > 1_000_000:
		frappe.throw("План — число м² от нуля.")
	frappe.db.set_default(f"{_TARGET}:{current_company()}", str(value) if value else "")
	audit.record_audit(action="shop.target_set", entity_type="Company", entity_id=current_company(),
					   diff={"m2": value or None})
	return {"target_m2": value or None}


def _month(company: str, today: date, first: date, last: date, ready: dict, plan: dict, pace_days: int) -> dict:
	target_m2 = target(company)
	due = _area_of(frappe.get_all("Sales Order", filters={
		"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
		"delivery_date": ["between", [first, last]]}, pluck="name", limit_page_length=0))
	taken = frappe.get_all("Sales Order", filters={
		"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
		"transaction_date": ["between", [first, today]]}, pluck="name", limit_page_length=0)
	goal = target_m2 or due
	total, passed = workdays(first, last), workdays(first, today)
	per_day = ready["pace"] / pace_days
	return {
		"plan_m2": round(goal, 2),
		# Two plans, never mixed (owner, 26.11.2026): what the shop is to
		# make — its own goal, or the orders due this month — and what sales
		# are to take in, «Итоги»'s goal, beside what was taken.
		"plan_from": "target" if target_m2 else "due",
		"due_m2": round(due, 2),
		"done_m2": round(ready["month"], 2),
		# What should be ready by the end of today, the plan spread over the
		# month's working days.
		"expected_m2": round(goal * passed / total, 2) if total else 0.0,
		"forecast_m2": round(ready["month"] + per_day * max(total - passed, 0), 2),
		"in_shop_m2": round(flt(plan.get("in_work_m2")), 2),
		"in_shop_orders": sum(len(s["orders"]) for s in plan["stages"]),
		"taken_m2": round(_area_of(taken), 2),
		"taken_orders": len(taken),
		"sales_target_m2": mdf_summary.target(),
		"workdays": total,
		"workdays_passed": passed,
	}


def _stage(company: str, stage: str, plan: dict, done: dict, by_person: dict, pace_days: int) -> dict:
	queue = next((q for q in plan["stages"] if q["stage"] == stage), {"orders": [], "area_m2": 0})
	waiting = flt(queue["area_m2"])
	if stage == "ready":
		# Past the last stage nothing waits to be made: what lies ready to go.
		waiting = _ready_to_give(company)
	per_day = done["pace"] / pace_days
	days = round(waiting / per_day, 1) if per_day and stage != "ready" else None
	open_by = _open_by(company, stage)
	posts = []
	for post in team.STAGE_POSTS.get(stage, ()):
		people = [{"employee": p["employee"], "name": p["name"],
				   "today_m2": round(by_person.get((stage, p["employee"]), 0.0), 2),
				   "in_work": open_by.get(p["employee"], 0)}
				  for p in team.holders([post], company)]
		posts.append({"post": post, "title": team.POSTS.get(post, post), "people": people,
					  "department": team.DEPARTMENTS.get(team.department_of(post) or "", {}).get("title")})
	return {
		"stage": stage,
		"title": mdf_orders.STAGE_NAMES.get(stage, stage),
		"waiting_m2": round(waiting, 2),
		"waiting_orders": len(queue["orders"]) if stage != "ready" else None,
		"today_m2": round(done["today"], 2),
		"month_m2": round(done["month"], 2),
		"per_day_m2": round(per_day, 2),
		"days": days,
		"jam": bool(days and days > JAM_DAYS),
		"nobody": bool(posts) and not any(p["people"] for p in posts),
		"posts": posts,
	}


def _late(plan: dict) -> list[dict]:
	"""Overdue first, then those «Жоспар» says will not make it."""
	out = [{"order": o["name"], "number": search_text.number_in(o["name"]), "customer": o["customer_name"],
			"area_m2": o["area_m2"], "stage": o["stage"], "title": mdf_orders.STAGE_NAMES.get(o["stage"], o["stage"]),
			"delivery_date": o["delivery_date"], "days_left": o["days_left"], "overdue": bool(o["overdue"]),
			"stages_left": o["stages_left"]}
		   for s in plan["stages"] for o in s["orders"] if o["overdue"] or o["at_risk"]]
	out.sort(key=lambda o: (not o["overdue"], o["delivery_date"], o["order"]))
	return out[:20]


def _side(company: str, today: date, first: date) -> list[dict]:
	sold_today = film_team.sold(company, today, today)
	sold_month = film_team.sold(company, first, today)
	received = frappe.db.count("Stock Entry", {"company": company, "docstatus": 1,
											   "korkem_received_by": ["is", "set"], "posting_date": today})
	figures = {
		"film_sales": {"sales_today": sum(v["sales"] for v in sold_today.values()),
					   "metres_today": round(sum(v["metres"] for v in sold_today.values()), 2),
					   "metres_month": round(sum(v["metres"] for v in sold_month.values()), 2)},
		"warehouse": {"received_today": received},
	}
	out = []
	for key, posts in SIDE.items():
		dept = team.DEPARTMENTS.get(key, {})
		out.append({"department": key, "title": dept.get("title", key), **figures[key],
					"posts": [{"post": p, "title": team.POSTS.get(p, p),
							   "people": [{"employee": h["employee"], "name": h["name"]}
										  for h in team.holders([p], company)]} for p in posts]})
	return out


def _open_by(company: str, stage: str) -> dict[str, int]:
	"""How many open stages of this kind are given to each person."""
	counts: dict[str, int] = defaultdict(int)
	for r in frappe.get_all("Sales Order", filters={
			"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
			mdf_orders.STAGE_TO[stage]: ["is", "set"], mdf_orders.STAGES[stage]: ["is", "not set"],
			"korkem_handed_over_on": ["is", "not set"]},
			fields=[mdf_orders.STAGE_TO[stage] + " as person"], limit_page_length=0):
		counts[r.person] += 1
	return counts


def _ready_to_give(company: str) -> float:
	return _area_of(frappe.get_all("Sales Order", filters={
		"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
		mdf_orders.STAGES["ready"]: ["is", "set"], "korkem_handed_over_on": ["is", "not set"]},
		pluck="name", limit_page_length=0))


def _area_of(names: list[str]) -> float:
	return float(sum(mdf_volume._areas(set(names)).values())) if names else 0.0


def _workdays_back(today: date, n: int) -> date:
	"""The first of the last [n] working days before [today]."""
	d, left = today, n
	while left:
		d = add_days(d, -1)
		if workday(getdate(d)):
			left -= 1
	return getdate(d)
