# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Piece-rate pay, wired to what the shop floor actually books.

`services/piece_work.py` keeps the ledger (entries, approval, reversal). This
module decides **what goes into it**, and the rule is that a worker never types
an amount or a quantity for pay:

- **A finished stage** (`complete_operation`) accrues the pieces ERPNext just
  booked as good on that job card, at the operation's rate.
- **A finished facade** (`facade_jobs.set_status` → «Готово») accrues its m²
  (or pieces) at the rate for «Фасад».

Both are idempotent, so a retried request or a double tap pays once. That, and
quantities taken from the booking rather than from the person being paid, is
the protection against padding («приписки»). Every entry starts as «Pending
Approval»; a production manager approves it, and nobody approves their own.

**Overtime and weekends** are decided by the clock and the company's own
`Piece Work Rules` — never claimed by the worker. Unset coefficients mean
ordinary pay, not a guess.

Rates and rules: administrator and production manager (`EDITORS`).
"""

from __future__ import annotations

from datetime import datetime

import frappe
from frappe.utils import flt, get_datetime, get_time, now_datetime

from korkem_manufacturing.services import audit, piece_work
from korkem_manufacturing.services.scope import current_company

EDITORS = frozenset({"System Manager", "Manufacturing Manager"})
APPROVERS = EDITORS
FACADE_OPERATION = "Фасад"
NORMAL, OVERTIME, WEEKEND = "Обычная", "Сверхурочно", "Выходной"
PER_PART, PER_M2 = "KZT_PER_PART", "KZT_PER_M2"
BONUS_FIELDS = ("daily_bonus_threshold", "daily_bonus", "monthly_bonus_threshold", "monthly_bonus")
#: A facade can be made by a crew; more than this is a typo, not a crew.
MAX_CREW = 5


def _ensure(roles: frozenset, message: str) -> None:
	if not roles.intersection(frappe.get_roles()):
		frappe.throw(message, frappe.PermissionError)


# --------------------------------------------------------------------------
# Rates and rules — the administrator's settings
# --------------------------------------------------------------------------


def rates() -> dict:
	company = current_company()
	rows = frappe.get_all(
		"Piece Rate",
		filters={"company": company},
		fields=["operation", "rate_type", "rate", "enabled"],
		order_by="operation asc",
	)
	return {
		"rates": [
			{"operation": r.operation, "rate_type": r.rate_type, "rate": flt(r.rate), "enabled": bool(r.enabled)}
			for r in rows
		],
		"rules": rules(company),
		"can_edit": bool(EDITORS.intersection(frappe.get_roles())),
	}


def set_rate(operation: str, rate_type: str, rate, enabled=True) -> dict:
	_ensure(EDITORS, "Тарифы задаёт администратор или начальник производства.")
	company = current_company()
	operation = (operation or "").strip()
	if rate_type not in (PER_PART, PER_M2):
		frappe.throw("Тариф — за штуку или за м².")
	enabled = bool(int(enabled)) if isinstance(enabled, str) else bool(enabled)
	name = frappe.db.get_value("Piece Rate", {"company": company, "operation": operation}, "name")
	doc = frappe.get_doc("Piece Rate", name) if name else frappe.new_doc("Piece Rate")
	before = {"rate_type": doc.rate_type, "rate": flt(doc.rate), "enabled": bool(doc.enabled)} if name else None
	doc.update({"company": company, "operation": operation, "rate_type": rate_type, "rate": flt(rate), "enabled": 1 if enabled else 0})
	doc.save()
	audit.record_audit(
		action="payroll.piece_rate_set",
		entity_type="Piece Rate",
		entity_id=doc.name,
		diff={"operation": operation, "before": before, "after": {"rate_type": rate_type, "rate": flt(rate), "enabled": enabled}},
	)
	return rates()


def rules(company: str | None = None) -> dict:
	company = company or current_company()
	row = frappe.db.get_value(
		"Piece Work Rules",
		company,
		["shift_end", "overtime_factor", "weekend_factor", "saturday_is_weekend", "sunday_is_weekend", *BONUS_FIELDS],
		as_dict=True,
	) or frappe._dict(sunday_is_weekend=1)
	return {
		"shift_end": str(row.shift_end) if row.shift_end else None,
		"overtime_factor": flt(row.overtime_factor) or None,
		"weekend_factor": flt(row.weekend_factor) or None,
		"saturday_is_weekend": bool(row.saturday_is_weekend),
		"sunday_is_weekend": bool(row.sunday_is_weekend),
		# Threshold bonuses (services/payroll.py). Empty means none.
		**{field: flt(row.get(field)) or None for field in BONUS_FIELDS},
	}


def save_rules(**values) -> dict:
	_ensure(EDITORS, "Коэффициенты задаёт администратор или начальник производства.")
	company = current_company()
	allowed = {"shift_end", "overtime_factor", "weekend_factor", "saturday_is_weekend", "sunday_is_weekend", *BONUS_FIELDS}
	doc = (
		frappe.get_doc("Piece Work Rules", company)
		if frappe.db.exists("Piece Work Rules", company)
		else frappe.new_doc("Piece Work Rules")
	)
	before = rules(company)
	doc.company = company
	for key, value in values.items():
		if key in allowed:
			doc.set(key, value if value not in ("", None) else None)
	doc.save()
	audit.record_audit(
		action="payroll.piece_rules_set", entity_type="Piece Work Rules", entity_id=company,
		diff={"before": before, "after": rules(company)},
	)
	return rates()


def shift_of(moment: datetime, company: str) -> tuple[str, float]:
	"""Which shift `moment` falls in, and the coefficient the rules give it."""
	r = rules(company)
	weekday = moment.weekday()  # Monday 0 … Sunday 6
	off = (weekday == 5 and r["saturday_is_weekend"]) or (weekday == 6 and r["sunday_is_weekend"])
	if off and r["weekend_factor"]:
		return WEEKEND, r["weekend_factor"]
	if r["shift_end"] and r["overtime_factor"] and moment.time() > get_time(r["shift_end"]):
		return OVERTIME, r["overtime_factor"]
	return NORMAL, 1.0


# --------------------------------------------------------------------------
# Accrual — called by the shop floor, never by the person being paid
# --------------------------------------------------------------------------


def _rate(company: str, operation: str):
	return frappe.db.get_value(
		"Piece Rate", {"company": company, "operation": operation, "enabled": 1}, ["rate_type", "rate"], as_dict=True
	)


def accrue_stage(result: dict, moment: datetime | None = None, crew=None):
	"""Pay for the pieces a finished stage just booked as good. No rate, no entry.

	`crew`, as for a facade: the people who did the stage together; the booked
	pieces are split between them by share or by each one's own count.
	"""
	booked = flt(result.get("booked_now"))
	if booked <= 0 or result.get("status") not in ("completed", "partially_completed"):
		return None
	company = current_company()
	rate = _rate(company, result.get("operation") or "")
	if not rate or rate.rate_type != PER_PART:
		return None
	members = _crew(crew, company)
	kind, factor = shift_of(moment or now_datetime(), company)
	# The card's own running total after this booking: the same booking
	# replayed lands on the same key; the next real booking does not.
	key = f"stage:{result.get('job_card')}:{flt(result.get('good_qty'))}"
	return _pay(
		members,
		booked,
		key,
		company=company,
		operation=result["operation"],
		rate_type=PER_PART,
		unit="pcs",
		rate=flt(rate.rate),
		job_card=result.get("job_card"),
		work_order=result.get("work_order"),
		factor=factor,
		shift_kind=kind,
	)


def _pay(members: list[tuple[str, float]], quantity: float, key: str, **entry):
	"""One entry per member, for their share of `quantity`; one entry alone
	keeps the plain key, so a single worker's accrual reads as it always did."""
	crew = len(members) > 1
	entries = [
		piece_work.record_piece_work(
			employee=user,
			employee_name=frappe.db.get_value("User", user, "full_name"),
			quantity=round(quantity * share / 100, 4),
			idempotency_key=key + (f":{user}" if crew else ""),
			notes=f"Бригада: доля {round(share, 2):g}%" if crew else None,
			**entry,
		)
		for user, share in members
	]
	return entries[0] if len(entries) == 1 else entries


def accrue_facade(line: str, sales_order: str, moment: datetime | None = None, crew=None):
	"""Pay for a facade line marked «Готово» — to the person who marked it, or
	split across the crew that made it.

	`crew` is 2–5 people, each with a share in % (summing to 100), or each
	with their own quantity — m² or pieces, summing to the line's — or with
	neither, for equal shares. Each member gets their share of the quantity, at the rate, as
	their own entry; each entry is approved on its own. Who was in the crew is
	the floor's report, checked like any other: by the approver.
	"""
	company = current_company()
	rate = _rate(company, FACADE_OPERATION)
	if not rate:
		return None
	row = frappe.db.get_value("Sales Order Item", line, ["qty", "korkem_area_m2"], as_dict=True)
	quantity, unit = (flt(row.korkem_area_m2), "m2") if rate.rate_type == PER_M2 else (flt(row.qty), "pcs")
	if quantity <= 0:
		return None
	members = _crew(crew, company, quantity)
	kind, factor = shift_of(moment or now_datetime(), company)
	# A line can go back to «В работе» and be finished again — by somebody
	# else, perhaps. Each finish is its own key; going back reverses the last.
	finish = _finishes(line) + 1
	return _pay(
		members,
		quantity,
		f"facade:{line}:{finish}",
		company=company,
		operation=FACADE_OPERATION,
		rate_type=rate.rate_type,
		unit=unit,
		rate=flt(rate.rate),
		sales_order=sales_order,
		factor=factor,
		shift_kind=kind,
	)


def facade_quantity(line: str) -> float | None:
	"""What a finished facade line pays for: its m² or its pieces, by the rate."""
	rate = _rate(current_company(), FACADE_OPERATION)
	if not rate:
		return None
	row = frappe.db.get_value("Sales Order Item", line, ["qty", "korkem_area_m2"], as_dict=True)
	return flt(row.korkem_area_m2) if rate.rate_type == PER_M2 else flt(row.qty)


def _finishes(line: str) -> int:
	"""How many times the line has been finished: the highest finish number used."""
	numbers = [
		int(key.split(":")[2])
		for key in frappe.get_all(
			"Piece Work Entry", filters={"idempotency_key": ["like", f"facade:{line}:%"]}, pluck="idempotency_key"
		)
		if key and key.count(":") >= 2 and key.split(":")[2].isdigit()
	]
	return max(numbers, default=0)


def check_crew(crew, total: float | None = None) -> list[tuple[str, float]]:
	"""Refuse a crew that cannot be paid — before anything is written."""
	return _crew(crew, current_company(), total)


def _crew(crew, company: str, total: float | None = None) -> list[tuple[str, float]]:
	"""(user, share %) pairs; the marker alone, at 100%, when no crew is named.

	Each member brings a share in %, or their own quantity (`qty`: m² or
	pieces), or nothing — all the same way. Quantities become shares of their
	sum, which must be `total` when the total is known.
	"""
	if crew in (None, "", []):
		return [(frappe.session.user, 100.0)]
	if isinstance(crew, str):
		crew = frappe.parse_json(crew)
	if not isinstance(crew, list) or not 1 <= len(crew) <= MAX_CREW:
		frappe.throw(f"Бригада — от 1 до {MAX_CREW} человек.")
	members, shares, quantities = [], [], []
	for item in crew:
		item = item if isinstance(item, dict) else {"user": item}
		user = item.get("user")
		if not user or not frappe.db.exists("User", {"name": user, "enabled": 1}) or not _works_here(user, company):
			frappe.throw("В бригаде указан человек, которого здесь нет.", frappe.DoesNotExistError)
		members.append(user)
		shares.append(_number(item.get("share")))
		quantities.append(_number(item.get("qty")))
	if len(set(members)) != len(members):
		frappe.throw("Один человек указан в бригаде дважды.")
	given_share = [s for s in shares if s is not None]
	given_qty = [q for q in quantities if q is not None]
	if given_share and given_qty:
		frappe.throw("Делите бригаду одним способом: в процентах или по количеству.")
	if not given_share and not given_qty:
		return [(u, 100.0 / len(members)) for u in members]
	given = given_share or given_qty
	if len(given) != len(members):
		frappe.throw("Укажите доли всем в бригаде — или никому, тогда поровну.")
	if any(v <= 0 for v in given):
		frappe.throw("Доля каждого в бригаде — больше нуля.")
	if given_share:
		if abs(sum(given) - 100) > 0.01:
			frappe.throw("Доли бригады в сумме — 100%.")
		return list(zip(members, given))
	done = sum(given)
	if total is not None and abs(done - flt(total)) > 0.01:
		frappe.throw(f"Бригада указала {done:g}, а сделано {flt(total):g}. Количества должны сойтись.")
	return [(u, q * 100.0 / done) for u, q in zip(members, given)]


def _number(value) -> float | None:
	if value in (None, ""):
		return None
	try:
		return float(value)
	except (TypeError, ValueError):
		frappe.throw(f"Доля бригады — число, а не {value!r}.")


def _works_here(user: str, company: str) -> bool:
	"""A member of staff bound to this company (User Permission on Company)."""
	from korkem_manufacturing.services.identity import is_staff

	return is_staff(user) and frappe.db.exists(
		"User Permission", {"user": user, "allow": "Company", "for_value": company}
	)


def withdraw_facade(line: str) -> None:
	"""A facade taken back from «Готово»: its unpaid accrual is reversed."""
	entries = frappe.get_all(
		"Piece Work Entry",
		filters={
			"idempotency_key": ["like", f"facade:{line}:%"],
			"status": ["in", ["Pending Approval", "Approved"]],
			"reversed_entry": ["is", "not set"],
		},
		pluck="name",
	)
	for name in entries:
		piece_work.reverse_piece_work(name, reason="Фасад возвращён из «Готово»")


# --------------------------------------------------------------------------
# Approval and the worker's own view
# --------------------------------------------------------------------------


def pending() -> list[dict]:
	_ensure(APPROVERS, "Начисления утверждает начальник производства.")
	return [
		_entry(r)
		for r in frappe.get_all(
			"Piece Work Entry",
			filters={"company": current_company(), "status": "Pending Approval", "reversed_entry": ["is", "not set"]},
			fields=_FIELDS,
			order_by="creation asc",
			limit_page_length=500,
		)
	]


def approve(entry: str) -> dict:
	_ensure(APPROVERS, "Начисления утверждает начальник производства.")
	employee = frappe.db.get_value("Piece Work Entry", entry, "employee")
	if employee == frappe.session.user:
		frappe.throw("Своё начисление утверждает другой человек.", frappe.PermissionError)
	doc = piece_work.approve_piece_work(entry, approved_by=frappe.session.user)
	return {"entry": doc.name, "status": doc.status}


def reject(entry: str, reason: str) -> dict:
	_ensure(APPROVERS, "Начисления утверждает начальник производства.")
	reason = (reason or "").strip()
	if not reason:
		frappe.throw("Укажите причину — работник увидит её.")
	piece_work.reverse_piece_work(entry, reason=reason, actor=frappe.session.user)
	return {"entry": entry, "status": "Reversed"}


def my_work(days: int = 31) -> dict:
	"""The signed-in worker's own entries and totals. Their own pay is theirs to see."""
	days = max(1, min(int(days or 31), 366))
	since = frappe.utils.add_days(now_datetime(), -days)
	rows = frappe.get_all(
		"Piece Work Entry",
		filters={"employee": frappe.session.user, "company": current_company(), "creation": [">=", since]},
		fields=_FIELDS,
		order_by="creation desc",
		limit_page_length=500,
	)
	totals = {"pending": 0.0, "approved": 0.0, "paid": 0.0}
	for r in rows:
		key = {"Pending Approval": "pending", "Approved": "approved", "Paid": "paid"}.get(r.status)
		if key and not r.reversed_entry:
			totals[key] += flt(r.amount)
	return {"entries": [_entry(r) for r in rows], "totals": {k: round(v, 2) for k, v in totals.items()}, "days": days}


_FIELDS = [
	"name", "employee", "employee_name", "operation", "quantity", "unit", "rate", "factor",
	"shift_kind", "amount", "status", "creation", "sales_order", "job_card", "reversed_entry", "reversal_reason",
]


def _entry(r) -> dict:
	return {
		"entry": r.name,
		"employee": r.employee,
		"employee_name": r.employee_name or r.employee,
		"operation": r.operation,
		"quantity": flt(r.quantity),
		"unit": r.unit,
		"rate": flt(r.rate),
		"factor": flt(r.factor) or 1.0,
		"shift": r.shift_kind or NORMAL,
		"amount": flt(r.amount),
		"status": r.status,
		"reason": r.reversal_reason,
		"is_reversal": bool(r.reversed_entry),
		"at": str(get_datetime(r.creation)),
		"sales_order": r.sales_order,
		"job_card": r.job_card,
	}
