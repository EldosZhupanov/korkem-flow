# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Сотрудники» — who did what, earned what, was paid what, for a day, a
week or a month (owner, 25.11.2026: «кто что как работает, сколько зп
получает, сколько аванса получил, сколько объёма закончил, какую роль…»).

Nothing here is entered: it is one picture of what three places already
keep —

- **the posts** (`team`): the department and the post of each person;
- **the work**: every order stage a person ticked or was given and ticked
  (`mdf_orders.STAGE_BY`), with its order's m² — so a worker without a
  login, whose stages the manager ticks, has his volume too; and the days
  on which he did any;
- **the money** (`payroll.sheet_rows`): piece pay, bonuses, fines,
  advances, what was paid out and what is left — for a person with a login,
  since piece pay is booked to a login.

Days «with work» are the days a stage of his was ticked — not hours: the
shop does not clock in, and this does not pretend it does.

The whole list is the production manager's, the administrator's and
accounting's (the statement's readers). A worker sees his own card only.
"""

from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta

import frappe
from frappe.utils import flt, get_first_day, get_last_day, getdate, nowdate

from korkem_manufacturing.services import mdf_orders, mdf_volume, payroll, search_text, team
from korkem_manufacturing.services.scope import current_company

PERIODS = ("day", "week", "month")
_MONEY = ("piece", "pending", "daily_bonus", "monthly_bonus", "bonus", "fine", "advance", "to_pay", "paid", "left")


def span(period: str | None, day: str | None = None) -> tuple[date, date]:
	"""The day, the Monday-to-Sunday week, or the month [day] falls in."""
	at = getdate(day or nowdate())
	if period == "day":
		return at, at
	if period == "week":
		monday = at - timedelta(days=at.weekday())
		return monday, monday + timedelta(days=6)
	return get_first_day(at), get_last_day(at)


def overview(period: str | None = "month", day: str | None = None) -> dict:
	"""Everyone for the period: posts, volume, days with work, money."""
	_ensure_reader()
	company = current_company()
	start, end = span(period, day)
	people = _people(company)
	work = _work(company, start, end)
	money = {r["employee"]: r for r in payroll.sheet_rows(company, start, end)}
	rows = [_row(p, work, money) for p in people]
	rows.sort(key=lambda r: (-r["m2"], -r["stages_done"], r["name"].lower()))
	return {
		"period": period if period in PERIODS else "month",
		"from_date": str(start),
		"to_date": str(end),
		"people": rows,
		"total": {
			"m2": round(sum(r["m2"] for r in rows), 2),
			"stages_done": sum(r["stages_done"] for r in rows),
			"earned": round(sum((r["money"] or {}).get("earned", 0) for r in rows), 2),
			"advance": round(sum((r["money"] or {}).get("advance", 0) for r in rows), 2),
			"to_pay": round(sum((r["money"] or {}).get("to_pay", 0) for r in rows), 2),
			"left": round(sum((r["money"] or {}).get("left", 0) for r in rows), 2),
		},
	}


def person(employee: str | None, period: str | None = "month", day: str | None = None) -> dict:
	"""One person's card: the row, day by day, every stage, every advance
	and payout of the period. No [employee] — the one asking, his own."""
	company = current_company()
	if not employee:
		# Looked up, not made: a GET writes nothing.
		employee = frappe.db.get_value("Employee", {"user_id": frappe.session.user, "company": company}, "name")
		if not employee:
			frappe.throw("Вас нет в «Команде» — попросите менеджера добавить вас.", frappe.DoesNotExistError)
	p = next((x for x in _people(company) if x["employee"] == employee), None)
	if not p:
		frappe.throw("Такого сотрудника нет.", frappe.DoesNotExistError)
	if not (_is_reader() or (p["user"] and p["user"] == frappe.session.user)):
		frappe.throw("Карточку сотрудника видят он сам, начальник производства и бухгалтерия.",
					 frappe.PermissionError)
	start, end = span(period, day)
	work = _work(company, start, end, employee)
	money = {r["employee"]: r for r in payroll.sheet_rows(company, start, end)} if p["user"] else {}
	row = _row(p, work, money)
	days = []
	current = start
	earned = _earned_by_day(company, start, end, p["user"]) if p["user"] else {}
	while current <= end:
		key = str(current)
		days.append({"day": key, "m2": round(work["by_day"].get((employee, key), 0.0), 2),
					 "stages": work["count_by_day"].get((employee, key), 0),
					 "earned": round(earned.get(current, 0.0), 2)})
		current += timedelta(days=1)
	return {
		**row,
		"period": period if period in PERIODS else "month",
		"from_date": str(start),
		"to_date": str(end),
		"by_day": days,  # not «days»: that is the row's count of days with work
		"works": sorted(work["works"].get(employee, []), key=lambda w: (w["on"], w["number"] or 0), reverse=True),
		"entries": _entries(company, start, end, p["user"]) if p["user"] else [],
		"adjustments": _adjustments(company, start, end, p["user"]) if p["user"] else [],
		"payouts": _payouts(company, start, end, p["user"]) if p["user"] else [],
		"me": bool(p["user"] and p["user"] == frappe.session.user),
	}


def _row(p: dict, work: dict, money: dict) -> dict:
	emp = p["employee"]
	stages = [{"stage": s, "title": mdf_orders.STAGE_NAMES.get(s, s), "orders": n, "m2": round(work["m2"].get((emp, s), 0.0), 2)}
			  for s, n in sorted(work["orders"].get(emp, {}).items(), key=lambda kv: list(mdf_orders.STAGES).index(kv[0]))]
	# A login with nothing booked this period earned nothing — zeros, not «—».
	m = (money.get(p["user"]) or {}) if p["user"] else None
	return {
		"employee": emp,
		"name": p["name"],
		"user": p["user"],
		"posts": p["posts"],
		"post_titles": [team.POSTS.get(x, x) for x in p["posts"]],
		"stages": stages,
		"stages_done": sum(s["orders"] for s in stages),
		"m2": round(sum(s["m2"] for s in stages), 2),
		"orders": len(work["order_set"].get(emp, ())),
		"days": len(work["days"].get(emp, ())),
		"money": _money(m) if m is not None else None,
	}


def _money(m: dict) -> dict:
	out = {k: round(flt(m.get(k)), 2) for k in _MONEY}
	# Earned — before the advance and the fine come off: «сколько зп получает».
	out["earned"] = round(out["piece"] + out["daily_bonus"] + out["monthly_bonus"] + out["bonus"], 2)
	return out


def _work(company: str, start: date, end: date, employee: str | None = None) -> dict:
	"""Each stage ticked in [start, end] with a person, with the order's m² —
	counted as «Объём работ» counts it (`mdf_volume`), so the two agree."""
	ticks = [t for t in mdf_volume._ticked(company, start, end) if t[2] and (not employee or t[2] == employee)]
	names = sorted({order for order, *_ in ticks})
	areas = mdf_volume._areas(names)
	customers = dict(frappe.get_all("Sales Order", filters={"name": ["in", names]}, fields=["name", "customer_name"],
									as_list=True)) if names else {}
	out = {"orders": defaultdict(dict), "m2": defaultdict(float), "order_set": defaultdict(set),
		   "days": defaultdict(set), "by_day": defaultdict(float), "count_by_day": defaultdict(int),
		   "works": defaultdict(list)}
	for order, stage, who, day in ticks:
		area = flt(areas.get(order, 0))
		out["orders"][who][stage] = out["orders"][who].get(stage, 0) + 1
		out["m2"][(who, stage)] += area
		out["order_set"][who].add(order)
		out["days"][who].add(day)
		out["by_day"][(who, day)] += area
		out["count_by_day"][(who, day)] += 1
		out["works"][who].append({"order": order, "number": search_text.number_in(order),
								  "customer": customers.get(order), "stage": stage,
								  "title": mdf_orders.STAGE_NAMES.get(stage, stage), "on": day, "m2": round(area, 2)})
	return out


def _people(company: str) -> list[dict]:
	"""The company's active people with their posts and login."""
	rows = frappe.get_all("Employee", filters={"company": company, "status": "Active"},
						  fields=["name", "employee_name", "first_name", "last_name", "user_id", team.ROLES_FIELD],
						  order_by="employee_name asc", limit_page_length=0)
	return [{"employee": r.name,
			 "name": r.employee_name or " ".join(x for x in (r.first_name, r.last_name) if x) or r.name,
			 "user": r.user_id, "posts": team.parse(r.get(team.ROLES_FIELD))} for r in rows]


def _earned_by_day(company: str, start: date, end: date, user: str) -> dict:
	return payroll._earned_by_day(company, start, end, employee=user)


def _entries(company: str, start: date, end: date, user: str) -> list[dict]:
	return [{"on": str(getdate(r.creation)), "operation": r.operation, "quantity": flt(r.quantity), "unit": r.unit,
			 "amount": flt(r.amount), "status": r.status, "order": r.sales_order}
			for r in frappe.get_all(
				"Piece Work Entry",
				filters={"company": company, "employee": user, "reversed_entry": ["is", "not set"],
						 "creation": ["between", [f"{start} 00:00:00", f"{end} 23:59:59.999999"]]},
				fields=["creation", "operation", "quantity", "unit", "amount", "status", "sales_order"],
				order_by="creation desc", limit_page_length=500)]


def _adjustments(company: str, start: date, end: date, user: str) -> list[dict]:
	return [{"on": str(r.on_date), "kind": r.kind, "amount": flt(r.amount), "reason": r.reason, "status": r.status}
			for r in frappe.get_all(
				payroll.DOCTYPE,
				filters={"company": company, "employee": user, "on_date": ["between", [start, end]]},
				fields=["on_date", "kind", "amount", "reason", "status"], order_by="on_date desc",
				limit_page_length=200)]


def _payouts(company: str, start: date, end: date, user: str) -> list[dict]:
	return [{"from_date": str(r.from_date), "to_date": str(r.to_date), "amount": flt(r.amount),
			 "on": str(getdate(r.paid_at or r.creation))}
			for r in frappe.get_all(
				payroll.PAYOUT,
				filters={"company": company, "employee": user, "from_date": ["<=", end], "to_date": [">=", start]},
				fields=["from_date", "to_date", "amount", "paid_at", "creation"], order_by="creation desc", limit_page_length=50)]


def _is_reader() -> bool:
	return bool(payroll.READERS.intersection(frappe.get_roles()))


def _ensure_reader() -> None:
	if not _is_reader():
		frappe.throw("Сотрудников за период видят начальник производства, администратор и бухгалтерия.",
					 frappe.PermissionError)
