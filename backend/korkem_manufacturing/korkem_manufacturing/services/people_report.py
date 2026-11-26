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
  advances, what was paid out and what is left — for every person, with a
  login or without (owner, 26.11.2026: «можно начислять»). Piece pay is
  booked to whoever marks the work, so a person with no login has none of
  it; his advances, fines, bonuses and payouts are his all the same.

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

from korkem_manufacturing.services import (
	film_team,
	mdf_orders,
	mdf_volume,
	payroll,
	search_text,
	team,
	team_people,
)
from korkem_manufacturing.services.scope import current_company

PERIODS = ("day", "week", "month")
_MONEY = ("piece", "pending", "daily_bonus", "monthly_bonus", "bonus", "sales_bonus", "fine", "advance", "to_pay",
		  "paid", "left")


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
	"""Everyone for the period: posts, volume, days with work, money — the
	money for those who see pay; the work for the team's editors too."""
	_ensure_reader()
	company = current_company()
	start, end = span(period, day)
	people = _people(company)
	work = _work(company, start, end)
	other = _other_work(company, start, end)
	sees_pay = _sees_pay()
	money = {r["employee"]: r for r in payroll.sheet_rows(company, start, end)} if sees_pay else {}
	rows = [_row(p, work, money, other, sees_pay) for p in people]
	rows.sort(key=lambda r: (-r["m2"], -r["stages_done"], r["name"].lower()))
	roles = set(frappe.get_roles())
	return {
		"period": period if period in PERIODS else "month",
		"from_date": str(start),
		"to_date": str(end),
		"people": rows,
		"sees_pay": sees_pay,
		# What the money tab offers: «+ Аванс, штраф, премия» and «Отдать»
		# (after the period is over — during it, it is an advance).
		"can_adjust": bool(payroll.EDITORS & roles),
		"adjusts_at_once": payroll.counts_at_once(),
		"can_pay": bool(payroll.PAYERS & roles) and end < getdate(nowdate()),
		"pending": _waiting(company, start, end) if sees_pay else [],
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
	p = next((x for x in _people(company, include_left=True) if x["employee"] == employee), None)
	if not p:
		frappe.throw("Такого сотрудника нет.", frappe.DoesNotExistError)
	me = bool(p["user"] and p["user"] == frappe.session.user)
	if not (_is_reader() or me):
		frappe.throw("Карточку сотрудника видят он сам, руководители и бухгалтерия.", frappe.PermissionError)
	# His own pay he sees; another's — those who see pay. A manager who runs
	# the team sees the work and the history, without the money.
	sees_pay = me or _sees_pay()
	start, end = span(period, day)
	work = _work(company, start, end, employee)
	other = _other_work(company, start, end, p["user"])
	money = {r["employee"]: r for r in payroll.sheet_rows(company, start, end)} if sees_pay else {}
	row = _row(p, work, money, other, sees_pay)
	days = []
	current = start
	# Piece pay is booked under a login; a person with none has only his
	# advances, fines and bonuses — paid all the same (26.11.2026).
	earned = _earned_by_day(company, start, end, p["user"]) if p["user"] and sees_pay else {}
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
		"entries": _entries(company, start, end, p["user"]) if p["user"] and sees_pay else [],
		"adjustments": _adjustments(company, start, end, employee, p["user"]) if sees_pay else [],
		"payouts": _payouts(company, start, end, employee, p["user"]) if sees_pay else [],
		"me": me,
		"sees_pay": sees_pay,
		"can_adjust": bool(payroll.EDITORS & set(frappe.get_roles())) and not me,
		"adjusts_at_once": payroll.counts_at_once(),
		"can_pay": bool(payroll.PAYERS & set(frappe.get_roles())) and not me and end < getdate(nowdate()),
		# What the card may change: his posts, «Уволен» — the team's editors.
		"active": p["active"],
		"can_edit": team.can_edit(),
		"history": team_people.history(employee) if (team.can_edit() or _is_reader()) else [],
	}


def _row(p: dict, work: dict, money: dict, other: dict | None = None, sees_pay: bool = True) -> dict:
	emp = p["employee"]
	stages = [{"stage": s, "title": mdf_orders.STAGE_NAMES.get(s, s), "orders": n, "m2": round(work["m2"].get((emp, s), 0.0), 2)}
			  for s, n in sorted(work["orders"].get(emp, {}).items(), key=lambda kv: list(mdf_orders.STAGES).index(kv[0]))]
	# Nothing booked this period is nothing earned — zeros, not «—»; with a
	# login or without, the pay is the person's (26.11.2026).
	m = (money.get(emp) or {}) if sees_pay else None
	extra = (other or {}).get(p["user"]) or {} if p["user"] else {}
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
		# The work that is not a facade stage: orders taken in, film sold,
		# deliveries received (owner, 26.11.2026: «у них сейчас 0»).
		"intake": extra.get("intake"),
		"sales": extra.get("sales"),
		"received": extra.get("received"),
	}


def _money(m: dict) -> dict:
	out = {k: round(flt(m.get(k)), 2) for k in _MONEY}
	# Earned — before the advance and the fine come off: «сколько зп получает».
	out["earned"] = round(out["piece"] + out["daily_bonus"] + out["monthly_bonus"] + out["bonus"]
						  + out["sales_bonus"], 2)
	return out


def _other_work(company: str, start: date, end: date, user: str | None = None) -> dict[str, dict]:
	"""By login: facade orders accepted (who pressed «Принять», from its audit
	row), film sold (`film_team.sold`), deliveries taken in (`korkem_received_by`)."""
	out: dict[str, dict] = defaultdict(dict)
	accepted = frappe.get_all(
		"Domain Audit Event",
		filters={"action": "mdf.order_accepted", "entity_type": "Sales Order",
				 "creation": ["between", [f"{start} 00:00:00", f"{end} 23:59:59.999999"]],
				 **({"actor": user} if user else {})},
		fields=["actor", "entity_id"],
		limit_page_length=0,
	)
	orders = {r.entity_id for r in accepted}
	mine = dict(frappe.get_all("Sales Order", filters={"name": ["in", list(orders)], "company": company,
														"docstatus": 1},
							   fields=["name", "grand_total"], as_list=True)) if orders else {}
	areas = mdf_volume._areas(sorted(mine))
	for r in accepted:
		if r.entity_id not in mine:
			continue
		i = out[r.actor].setdefault("intake", {"orders": 0, "m2": 0.0, "amount": 0.0})
		i["orders"] += 1
		i["m2"] = round(i["m2"] + flt(areas.get(r.entity_id)), 2)
		i["amount"] = round(i["amount"] + flt(mine[r.entity_id]), 2)
	for seller, v in film_team.sold(company, start, end).items():
		if not user or seller == user:
			out[seller]["sales"] = v
	for r in frappe.get_all(
		"Stock Entry",
		filters={"company": company, "docstatus": 1, "korkem_received_by": user or ["is", "set"],
				 "posting_date": ["between", [start, end]]},
		fields=["korkem_received_by"],
		limit_page_length=0,
	):
		rec = out[r.korkem_received_by].setdefault("received", {"count": 0})
		rec["count"] += 1
	return out


def _waiting(company: str, start: date, end: date) -> list[dict]:
	"""Advances, fines and bonuses waiting for a «Да» — and whether the one
	looking may give it (not his own, not one he entered)."""
	editor = bool(payroll.EDITORS & set(frappe.get_roles()))
	me = frappe.session.user
	return [{**payroll._adjustment(r), "can_approve": editor and me not in (r.employee, r.created_by)}
			for r in frappe.get_all(
				payroll.DOCTYPE,
				filters={"company": company, "status": "Pending Approval", "on_date": ["between", [start, end]]},
				fields=["name", "person", "employee", "employee_name", "kind", "amount", "on_date", "reason",
						"status", "sales_order", "created_by", "approved_by", "reversal_reason"],
				order_by="on_date asc", limit_page_length=100)]


def _work(company: str, start: date, end: date, employee: str | None = None) -> dict:
	"""Each stage ticked in [start, end] with a person, with the order's m² —
	counted as «Объём работ» counts it (`mdf_volume`), so the two agree."""
	# A stage done by several: each his part of its m² (26.11.2026).
	ticks = [t for t in mdf_volume._ticked_people(company, start, end) if t[2] and (not employee or t[2] == employee)]
	names = sorted({order for order, *_ in ticks})
	areas = mdf_volume._areas(names)
	customers = dict(frappe.get_all("Sales Order", filters={"name": ["in", names]}, fields=["name", "customer_name"],
									as_list=True)) if names else {}
	out = {"orders": defaultdict(dict), "m2": defaultdict(float), "order_set": defaultdict(set),
		   "days": defaultdict(set), "by_day": defaultdict(float), "count_by_day": defaultdict(int),
		   "works": defaultdict(list)}
	for order, stage, who, day, share in ticks:
		area = flt(areas.get(order, 0)) * float(share)
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


def _people(company: str, include_left: bool = False) -> list[dict]:
	"""The company's people with their posts and login — the active ones,
	unless the departed are asked for too (a card opened from «Ушли»)."""
	filters = {"company": company} if include_left else {"company": company, "status": "Active"}
	rows = frappe.get_all("Employee", filters=filters,
						  fields=["name", "employee_name", "first_name", "last_name", "user_id", "status",
								  team.ROLES_FIELD],
						  order_by="employee_name asc", limit_page_length=0)
	return [{"employee": r.name,
			 "name": r.employee_name or " ".join(x for x in (r.first_name, r.last_name) if x) or r.name,
			 "user": r.user_id, "posts": team.parse(r.get(team.ROLES_FIELD)), "active": r.status == "Active"}
			for r in rows]


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


def _adjustments(company: str, start: date, end: date, employee: str, user: str | None) -> list[dict]:
	"""His advances, fines and bonuses, each with what the one looking may
	do to it: «Да» to one waiting (not his own entry), «Отменить» to any."""
	editor = bool(payroll.EDITORS & set(frappe.get_roles()))
	me = frappe.session.user
	return [{"adjustment": r.name, "on": str(r.on_date), "kind": r.kind, "amount": flt(r.amount), "reason": r.reason,
			 "status": r.status,
			 "can_approve": editor and r.status == "Pending Approval" and me not in (r.employee, r.created_by),
			 "can_reverse": editor and r.status in ("Pending Approval", "Approved") and me != r.employee}
			for r in sorted(payroll._theirs(payroll.DOCTYPE, company, employee, user,
											{"on_date": ["between", [start, end]]},
											["name", "on_date", "kind", "amount", "reason", "status", "employee",
											 "created_by", "creation"]),
							key=lambda r: (r.on_date, r.creation), reverse=True)[:200]]


def _payouts(company: str, start: date, end: date, employee: str, user: str | None) -> list[dict]:
	return [{"from_date": str(r.from_date), "to_date": str(r.to_date), "amount": flt(r.amount),
			 "on": str(getdate(r.paid_at or r.creation))}
			for r in sorted(payroll._theirs(payroll.PAYOUT, company, employee, user,
											{"from_date": ["<=", end], "to_date": [">=", start]},
											["from_date", "to_date", "amount", "paid_at", "creation"]),
							key=lambda r: r.creation, reverse=True)[:50]]


def _sees_pay() -> bool:
	return bool(payroll.READERS.intersection(frappe.get_roles()))


def _is_reader() -> bool:
	"""Who may open «Сотрудники»: those who see pay, and those who run the team."""
	return _sees_pay() or team.can_edit()


def _ensure_reader() -> None:
	if not _is_reader():
		frappe.throw("Сотрудников за период видят руководители и бухгалтерия.", frappe.PermissionError)
