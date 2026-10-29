# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""What each worker is owed for a period: piece pay, bonuses, advances, fines.

`piece_work` keeps the accruals and `piece_rates` decides what is accrued.
This module adds the rest of a pay sheet and adds it up:

- **Adjustments** (`Pay Adjustment`): an advance paid out, a fine for a defect,
  a one-off bonus. Entered by the production manager or the administrator,
  approved by somebody else — never by the worker it concerns, nor by the
  person who entered it — and reversed, not deleted, when wrong.
- **Threshold bonuses**, from the company's own `Piece Work Rules`: a day on
  which a worker's piece pay reaches the daily threshold earns the daily
  bonus; a calendar month that reaches the monthly threshold earns the
  monthly one. Empty rules mean no bonus, not a guess. Computed from the
  ledger each time, never stored, so a reversed accrual takes its bonus away.
- **The statement** for a period: per worker, approved piece pay + bonuses +
  one-off bonuses − fines − advances = to pay. Pending accruals are shown but
  not counted: nobody is paid for work nobody has checked.
- **«Выплачено»** (`mark_paid`): a worker's period is paid out — a `Pay
  Payout` records the sum, the period's approved accruals become «Paid», and
  the period's advances, fines and bonuses can no longer be entered, approved
  or reversed. Nothing still waiting for approval may be left in it. Work
  approved later in the same period is paid by marking it again.

A worker sees their own progress to the next bonus (`my_progress`), so the
tablet can say «до дневной премии осталось 4 200 ₸».

Money is people's pay: the statement is for the production manager, the
administrator and accounting; a worker sees only their own figures.
"""

from __future__ import annotations

import csv
import io
from datetime import date

import frappe
from frappe.utils import flt, get_first_day, get_last_day, getdate, now_datetime, nowdate

from korkem_manufacturing.services import audit
from korkem_manufacturing.services.identity import is_staff
from korkem_manufacturing.services.scope import current_company

DOCTYPE = "Pay Adjustment"
PAYOUT = "Pay Payout"
ADVANCE, FINE, BONUS = "Аванс", "Штраф", "Премия"
KINDS = (ADVANCE, FINE, BONUS)
EDITORS = frozenset({"System Manager", "Manufacturing Manager"})
READERS = EDITORS | {"Accounts Manager", "Accounts User"}
#: Who may mark pay as paid out: the people who hand it over.
PAYERS = EDITORS | {"Accounts Manager"}
MAX_DAYS = 93
COUNTED = ("Approved", "Paid")


def _ensure(roles: frozenset, message: str) -> None:
	if not roles.intersection(frappe.get_roles()):
		frappe.throw(message, frappe.PermissionError)


# --------------------------------------------------------------------------
# Adjustments
# --------------------------------------------------------------------------


def add_adjustment(
	employee: str,
	kind: str,
	amount,
	reason: str,
	on_date: str | None = None,
	sales_order: str | None = None,
) -> dict:
	_ensure(EDITORS, "Авансы, штрафы и премии вносит начальник производства или администратор.")
	company = current_company()
	if kind not in KINDS:
		frappe.throw(f"Вид — один из: {', '.join(KINDS)}.")
	if employee == frappe.session.user:
		frappe.throw("Себе удержание или премию вносит другой человек.", frappe.PermissionError)
	_ensure_worker(employee, company)
	try:
		value = flt(amount)
	except (TypeError, ValueError):
		value = 0
	if value <= 0:
		frappe.throw("Сумма — больше нуля.")
	day = getdate(on_date) if on_date else getdate(nowdate())
	if day > getdate(nowdate()):
		frappe.throw("Дата не может быть в будущем.")
	_ensure_open(employee, day, company)
	if sales_order:
		from korkem_manufacturing.services.scope import ensure_company

		ensure_company("Sales Order", sales_order)
	doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"company": company,
			"employee": employee,
			"employee_name": frappe.db.get_value("User", employee, "full_name") or employee,
			"kind": kind,
			"amount": value,
			"on_date": str(day),
			"reason": (reason or "").strip()[:500],
			"sales_order": sales_order or None,
			"status": "Pending Approval",
			"created_by": frappe.session.user,
		}
	)
	doc.insert(ignore_permissions=True)
	audit.record_audit(
		action="payroll.adjustment_added",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={"employee": employee, "kind": kind, "amount": value, "on_date": str(day)},
	)
	return _adjustment(doc)


def approve_adjustment(adjustment: str) -> dict:
	_ensure(EDITORS, "Утверждает начальник производства или администратор.")
	doc = _own(adjustment)
	if doc.status != "Pending Approval":
		frappe.throw(f"Уже в статусе «{doc.status}».")
	if frappe.session.user in (doc.employee, doc.created_by):
		frappe.throw("Утверждает другой человек — не тот, кого это касается, и не тот, кто вносил.", frappe.PermissionError)
	_ensure_open(doc.employee, getdate(doc.on_date), doc.company)
	doc.db_set({"status": "Approved", "approved_by": frappe.session.user, "approved_at": now_datetime()})
	audit.record_audit(action="payroll.adjustment_approved", entity_type=DOCTYPE, entity_id=doc.name)
	return _adjustment(doc)


def reverse_adjustment(adjustment: str, reason: str) -> dict:
	_ensure(EDITORS, "Сторнирует начальник производства или администратор.")
	doc = _own(adjustment)
	reason = (reason or "").strip()
	if not reason:
		frappe.throw("Укажите причину — работник увидит её.")
	if doc.status == "Reversed":
		return _adjustment(doc)
	_ensure_open(doc.employee, getdate(doc.on_date), doc.company)
	doc.db_set({"status": "Reversed", "reversal_reason": reason[:500]})
	audit.record_audit(
		action="payroll.adjustment_reversed", entity_type=DOCTYPE, entity_id=doc.name, diff={"reason": reason}
	)
	return _adjustment(doc)


def adjustments(from_date: str | None = None, to_date: str | None = None) -> list[dict]:
	_ensure(READERS, "Ведомость видят начальник производства, администратор и бухгалтерия.")
	start, end = _period(from_date, to_date)
	return [
		_adjustment(r)
		for r in frappe.get_all(
			DOCTYPE,
			filters={"company": current_company(), "on_date": ["between", [start, end]]},
			fields=["name", "employee", "employee_name", "kind", "amount", "on_date", "reason", "status",
					"sales_order", "created_by", "approved_by", "reversal_reason"],
			order_by="on_date desc, creation desc",
			limit_page_length=1000,
		)
	]


# --------------------------------------------------------------------------
# The statement
# --------------------------------------------------------------------------


def statement(from_date: str | None = None, to_date: str | None = None) -> dict:
	"""Per worker, what the period adds up to."""
	_ensure(READERS, "Ведомость видят начальник производства, администратор и бухгалтерия.")
	company = current_company()
	start, end = _period(from_date, to_date)
	rules = bonus_rules(company)
	rows: dict[str, dict] = {}

	def row(employee: str, name: str | None = None) -> dict:
		if employee not in rows:
			rows[employee] = {
				"employee": employee,
				"employee_name": name or frappe.db.get_value("User", employee, "full_name") or employee,
				"piece": 0.0,
				"pending": 0.0,
				"daily_bonus": 0.0,
				"monthly_bonus": 0.0,
				"bonus": 0.0,
				"fine": 0.0,
				"advance": 0.0,
				"bonus_days": 0,
				"bonus_months": 0,
			}
		return rows[employee]

	for r in _piece_entries(company, start, end):
		target = row(r.employee, r.employee_name)
		if r.status in COUNTED:
			target["piece"] += flt(r.amount)
		elif r.status == "Pending Approval":
			target["pending"] += flt(r.amount)

	for employee, (days, months) in _bonuses(company, start, end, rules).items():
		target = row(employee)
		target["bonus_days"], target["bonus_months"] = len(days), len(months)
		target["daily_bonus"] = len(days) * rules["daily_bonus"]
		target["monthly_bonus"] = len(months) * rules["monthly_bonus"]

	for a in frappe.get_all(
		DOCTYPE,
		filters={"company": company, "status": "Approved", "on_date": ["between", [start, end]]},
		fields=["employee", "employee_name", "kind", "amount"],
	):
		key = {ADVANCE: "advance", FINE: "fine", BONUS: "bonus"}[a.kind]
		row(a.employee, a.employee_name)[key] += flt(a.amount)

	paid = _paid_within(company, start, end)
	for employee in paid:
		row(employee)

	result = []
	for r in sorted(rows.values(), key=lambda x: x["employee_name"]):
		for key in ("piece", "pending", "daily_bonus", "monthly_bonus", "bonus", "fine", "advance"):
			r[key] = round(r[key], 2)
		r["to_pay"] = round(r["piece"] + r["daily_bonus"] + r["monthly_bonus"] + r["bonus"] - r["fine"] - r["advance"], 2)
		r["paid"] = round(paid.get(r["employee"], 0.0), 2)
		r["left"] = round(r["to_pay"] - r["paid"], 2)
		result.append(r)
	return {
		"from_date": str(start),
		"to_date": str(end),
		"rules": rules,
		"rows": result,
		"total_to_pay": round(sum(r["to_pay"] for r in result), 2),
		"total_paid": round(sum(r["paid"] for r in result), 2),
		"total_left": round(sum(r["left"] for r in result), 2),
		"can_mark_paid": bool(PAYERS.intersection(frappe.get_roles())),
	}


def statement_csv(from_date: str | None = None, to_date: str | None = None) -> str:
	"""The statement as CSV for accounting — `;`-separated, as Excel in Kazakhstan opens it."""
	data = statement(from_date, to_date)
	buffer = io.StringIO()
	writer = csv.writer(buffer, delimiter=";")
	writer.writerow(
		["Сотрудник", "Сдельно", "Премия дня", "Премия месяца", "Премия", "Штраф", "Аванс", "К выплате", "Выплачено",
		 "Остаток", "Не утверждено"]
	)
	for r in data["rows"]:
		writer.writerow(
			[r["employee_name"], r["piece"], r["daily_bonus"], r["monthly_bonus"], r["bonus"], r["fine"],
			 r["advance"], r["to_pay"], r["paid"], r["left"], r["pending"]]
		)
	writer.writerow(["Итого", "", "", "", "", "", "", data["total_to_pay"], data["total_paid"], data["total_left"], ""])
	audit.record_audit(
		action="payroll.statement_exported",
		entity_type="Company",
		entity_id=current_company(),
		diff={"from_date": data["from_date"], "to_date": data["to_date"], "rows": len(data["rows"])},
	)
	return buffer.getvalue()


# --------------------------------------------------------------------------
# «Выплачено»
# --------------------------------------------------------------------------


def mark_paid(employee: str, from_date: str, to_date: str, note: str | None = None) -> dict:
	"""Pay a worker's period out: what is left of their «к выплате» becomes a
	`Pay Payout`, and the period's approved accruals become «Paid».

	One period per payout and no overlaps: a sheet paid for October cannot be
	paid again for 15 September – 15 October. The same period marked again pays
	only what was approved since.
	"""
	_ensure(PAYERS, "Выплату отмечает бухгалтер, начальник производства или администратор.")
	company = current_company()
	if not from_date or not to_date:
		frappe.throw("Укажите период выплаты.")
	start, end = _period(from_date, to_date)
	if end > getdate(nowdate()):
		frappe.throw("Период ещё не закончился — за текущие дни платят авансом.")
	if employee == frappe.session.user:
		frappe.throw("Свою выплату отмечает другой человек.", frappe.PermissionError)
	_ensure_worker(employee, company)
	# Two people marking the same sheet at once: the second waits here and
	# then sees the first one's payout.
	frappe.db.sql("SELECT name FROM `tabUser` WHERE name = %s FOR UPDATE", employee)

	same = 0.0
	for p in frappe.get_all(
		PAYOUT,
		filters={"company": company, "employee": employee, "from_date": ["<=", end], "to_date": [">=", start]},
		fields=["name", "from_date", "to_date", "amount"],
	):
		if getdate(p.from_date) != start or getdate(p.to_date) != end:
			frappe.throw(f"Пересекается с выплатой {p.name} за {p.from_date} – {p.to_date}.")
		same += flt(p.amount)

	waiting_work = len(_piece_entries(company, start, end, employee=employee, statuses=["Pending Approval"]))
	waiting_adj = frappe.db.count(
		DOCTYPE,
		{"company": company, "employee": employee, "status": "Pending Approval", "on_date": ["between", [start, end]]},
	)
	if waiting_work or waiting_adj:
		frappe.throw(
			f"Сначала утвердите или отклоните то, что ждёт решения: начислений — {waiting_work}, "
			f"авансов, штрафов и премий — {waiting_adj}."
		)

	row = next((r for r in statement(str(start), str(end))["rows"] if r["employee"] == employee), None)
	approved = frappe.get_all(
		"Piece Work Entry",
		filters={
			"company": company,
			"employee": employee,
			"status": "Approved",
			"reversed_entry": ["is", "not set"],
			"creation": ["between", [f"{start} 00:00:00", f"{end} 23:59:59.999999"]],
		},
		pluck="name",
	)
	left = round(flt(row["to_pay"]) - same, 2) if row else 0.0
	if left < 0:
		frappe.throw(
			f"К выплате {left:g} ₸: удержано больше, чем заработано. Перенесите долг штрафом в следующий период."
		)
	if left == 0 and not approved:
		frappe.throw("За этот период выплачивать нечего.")

	from korkem_manufacturing.services import piece_work

	for name in approved:
		piece_work.mark_paid(name, actor=frappe.session.user)
	doc = frappe.get_doc(
		{
			"doctype": PAYOUT,
			"company": company,
			"employee": employee,
			"employee_name": frappe.db.get_value("User", employee, "full_name") or employee,
			"from_date": str(start),
			"to_date": str(end),
			"amount": left,
			"piece": flt(row["piece"]) if row else 0,
			"bonuses": flt(row["daily_bonus"] + row["monthly_bonus"] + row["bonus"]) if row else 0,
			"fine": flt(row["fine"]) if row else 0,
			"advance": flt(row["advance"]) if row else 0,
			"entries": len(approved),
			"paid_by": frappe.session.user,
			"paid_at": now_datetime(),
			"note": (note or "").strip()[:500] or None,
		}
	)
	doc.insert(ignore_permissions=True)
	audit.record_audit(
		action="payroll.paid_out",
		entity_type=PAYOUT,
		entity_id=doc.name,
		diff={"employee": employee, "from_date": str(start), "to_date": str(end), "amount": left, "entries": len(approved)},
	)
	return _payout(doc)


def payouts(from_date: str | None = None, to_date: str | None = None) -> list[dict]:
	"""Payouts whose period touches the given one."""
	_ensure(READERS, "Ведомость видят начальник производства, администратор и бухгалтерия.")
	start, end = _period(from_date, to_date)
	return [
		_payout(r)
		for r in frappe.get_all(
			PAYOUT,
			filters={"company": current_company(), "from_date": ["<=", end], "to_date": [">=", start]},
			fields=["name", "employee", "employee_name", "from_date", "to_date", "amount", "entries", "paid_by",
					"paid_at", "note"],
			order_by="paid_at desc",
			limit_page_length=1000,
		)
	]


def _paid_within(company: str, start: date, end: date) -> dict[str, float]:
	"""Per worker, what was paid out for periods inside [start, end]."""
	paid: dict[str, float] = {}
	for p in frappe.get_all(
		PAYOUT,
		filters={"company": company, "from_date": [">=", start], "to_date": ["<=", end]},
		fields=["employee", "amount"],
	):
		paid[p.employee] = paid.get(p.employee, 0.0) + flt(p.amount)
	return paid


def _ensure_open(employee: str, day: date, company: str) -> None:
	"""An advance, fine or bonus dated in a paid-out period would change a sum
	already handed over: it goes into the next period instead."""
	paid = frappe.db.get_value(
		PAYOUT,
		{"company": company, "employee": employee, "from_date": ["<=", day], "to_date": [">=", day]},
		["name", "from_date", "to_date"],
		as_dict=True,
	)
	if paid:
		frappe.throw(
			f"Период {paid.from_date} – {paid.to_date} уже выплачен ({paid.name}). Внесите в следующий период."
		)


def _payout(r) -> dict:
	return {
		"payout": r.name,
		"employee": r.employee,
		"employee_name": r.employee_name or r.employee,
		"from_date": str(r.from_date),
		"to_date": str(r.to_date),
		"amount": flt(r.amount),
		"entries": int(r.entries or 0),
		"paid_by": r.paid_by,
		"paid_at": str(r.paid_at) if r.paid_at else None,
		"note": r.note,
	}


# --------------------------------------------------------------------------
# Bonuses
# --------------------------------------------------------------------------


def bonus_rules(company: str | None = None) -> dict:
	company = company or current_company()
	row = frappe.db.get_value(
		"Piece Work Rules",
		company,
		["daily_bonus_threshold", "daily_bonus", "monthly_bonus_threshold", "monthly_bonus"],
		as_dict=True,
	) or frappe._dict()
	return {
		"daily_bonus_threshold": flt(row.daily_bonus_threshold),
		"daily_bonus": flt(row.daily_bonus),
		"monthly_bonus_threshold": flt(row.monthly_bonus_threshold),
		"monthly_bonus": flt(row.monthly_bonus),
	}


def my_progress() -> dict:
	"""The signed-in worker's way to today's and this month's bonus."""
	if not is_staff():
		frappe.throw("Прогресс видят сотрудники.", frappe.PermissionError)
	company = current_company()
	rules = bonus_rules(company)
	today = getdate(nowdate())
	month_start = get_first_day(today)
	by_day = _earned_by_day(company, month_start, today, employee=frappe.session.user, include_pending=True)
	day_total = by_day.get(today, 0.0)
	month_total = sum(by_day.values())

	def part(total: float, threshold: float, bonus: float) -> dict | None:
		if not threshold:
			return None
		return {
			"earned": round(total, 2),
			"threshold": threshold,
			"bonus": bonus,
			"left": round(max(0.0, threshold - total), 2),
			"reached": total >= threshold,
		}

	return {
		"today": part(day_total, rules["daily_bonus_threshold"], rules["daily_bonus"]),
		"month": part(month_total, rules["monthly_bonus_threshold"], rules["monthly_bonus"]),
		# Counted with work still waiting for approval, and said so: the
		# bonus itself is paid on approved work only.
		"includes_pending": True,
	}


def _bonuses(company: str, start: date, end: date, rules: dict) -> dict[str, tuple[set, set]]:
	"""Per worker, the days and whole months in the period that reach a threshold."""
	result: dict[str, tuple[set, set]] = {}
	if not rules["daily_bonus_threshold"] and not rules["monthly_bonus_threshold"]:
		return result
	earned = _earned_by_day(company, get_first_day(start), get_last_day(end))
	for employee, days in earned.items():
		bonus_days = {
			d for d, total in days.items()
			if start <= d <= end and rules["daily_bonus_threshold"] and total >= rules["daily_bonus_threshold"]
		}
		months: dict[date, float] = {}
		for d, total in days.items():
			months[get_first_day(d)] = months.get(get_first_day(d), 0.0) + total
		# A month earns its bonus in the statement that covers all of it, so
		# two statements over halves of a month never pay it twice.
		bonus_months = {
			m for m, total in months.items()
			if rules["monthly_bonus_threshold"]
			and total >= rules["monthly_bonus_threshold"]
			and start <= m and get_last_day(m) <= end
		}
		if bonus_days or bonus_months:
			result[employee] = (bonus_days, bonus_months)
	return result


def _earned_by_day(company: str, start: date, end: date, employee: str | None = None, include_pending: bool = False):
	"""Piece pay per worker per day (or per day, for one worker)."""
	statuses = list(COUNTED) + (["Pending Approval"] if include_pending else [])
	result: dict = {}
	for r in _piece_entries(company, start, end, employee=employee, statuses=statuses):
		day = getdate(r.creation)
		if employee:
			result[day] = result.get(day, 0.0) + flt(r.amount)
		else:
			result.setdefault(r.employee, {})
			result[r.employee][day] = result[r.employee].get(day, 0.0) + flt(r.amount)
	return result


def _piece_entries(company: str, start: date, end: date, employee: str | None = None, statuses=None):
	filters = {
		"company": company,
		"creation": ["between", [f"{start} 00:00:00", f"{end} 23:59:59.999999"]],
		# A reversal row is bookkeeping; the original it reverses is «Reversed».
		"reversed_entry": ["is", "not set"],
		"status": ["in", list(statuses or (*COUNTED, "Pending Approval"))],
	}
	if employee:
		filters["employee"] = employee
	return frappe.get_all(
		"Piece Work Entry",
		filters=filters,
		fields=["employee", "employee_name", "amount", "status", "creation"],
		limit_page_length=0,
	)


def workers() -> list[dict]:
	"""Who works here, by name only — for a crew or an adjustment.

	Any member of staff may ask: a cutter naming the crew that made a facade
	needs the names of the people beside them, and nothing more. No roles, no
	contacts, no pay.
	"""
	if not is_staff():
		frappe.throw("Список видят сотрудники.", frappe.PermissionError)
	company = current_company()
	members = _members(company)
	people = []
	for u in frappe.get_all(
		"User",
		filters={"enabled": 1, "user_type": "System User", "name": ["in", list(members) or [""]]},
		fields=["name", "full_name"],
		order_by="full_name asc",
		limit_page_length=0,
	):
		if is_staff(u.name):
			people.append({"user": u.name, "name": u.full_name or u.name})
	return people


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------


def _period(from_date, to_date) -> tuple[date, date]:
	end = getdate(to_date) if to_date else getdate(nowdate())
	start = getdate(from_date) if from_date else get_first_day(end)
	if start > end:
		frappe.throw("Начало периода позже конца.")
	if (end - start).days > MAX_DAYS:
		frappe.throw(f"Период — не длиннее {MAX_DAYS} дней.")
	return start, end


def _ensure_worker(employee: str, company: str) -> None:
	if (
		not frappe.db.exists("User", {"name": employee, "enabled": 1})
		or not is_staff(employee)
		or employee not in _members(company)
	):
		frappe.throw("Такого сотрудника нет.", frappe.DoesNotExistError)


def _members(company: str) -> set[str]:
	"""Who belongs to the company: ERPNext's own User Permission on Company —
	the binding `scope.current_company` reads and onboarding creates."""
	return set(
		frappe.get_all("User Permission", filters={"allow": "Company", "for_value": company}, pluck="user")
	)


def _own(name: str):
	if not frappe.db.exists(DOCTYPE, name):
		frappe.throw("Такой записи нет.", frappe.DoesNotExistError)
	doc = frappe.get_doc(DOCTYPE, name)
	if doc.company != current_company():
		frappe.throw("Такой записи нет.", frappe.DoesNotExistError)
	return doc


def _adjustment(r) -> dict:
	return {
		"adjustment": r.name,
		"employee": r.employee,
		"employee_name": r.employee_name or r.employee,
		"kind": r.kind,
		"amount": flt(r.amount),
		"on_date": str(r.on_date),
		"reason": r.reason,
		"status": r.status,
		"sales_order": r.sales_order,
		"created_by": r.get("created_by"),
		"approved_by": r.get("approved_by"),
		"reversal_reason": r.get("reversal_reason"),
	}
