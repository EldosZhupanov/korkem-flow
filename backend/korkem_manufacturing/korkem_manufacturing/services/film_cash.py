# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The film department's own cash book (owner, 11.11.2026: «оплаты за такси и
логистику… должны чисто лежать в отделе плёнки»).

In: what customers paid for film, by the day it was paid and how — cash,
Kaspi, a transfer, a card. Out: what bringing film cost when the
department's cash paid it, money given back to an employee who paid out of
his pocket, and what was paid to a carrier later. The balance is in less out.

Three lists stay open until settled: what is owed back to employees, what
is owed to carriers, and film taken from a supplier on credit. Paying a
supplier says where the money came from (owner, 14.11.2026): out of the
department's own money — then it is out of this book, by the way it went —
or from elsewhere, the owner's or the MDF side's, and the book is not
touched. Logistics is shown apart, for the owner's eye; the
team's bonus does not count it (owner, 11.11.2026).

The MDF cash book is not touched: the two departments keep their own money.
"""

from __future__ import annotations

import frappe
from frappe.utils import add_days, flt, get_fullname, getdate, nowdate

from korkem_manufacturing.services import audit, material_stock
from korkem_manufacturing.services.film_dept import (
	METHODS,
	PAYER_CASH,
	PAYER_EMPLOYEE,
	PAYER_SUPPLIER,
	PAYER_UNPAID,
	SALE,
	_payments,
)
from korkem_manufacturing.services.scope import current_company

#: A period longer than this is a report, not a cash book.
MAX_DAYS = 366

_FIELDS = [
	"name", "creation", "posting_date", "docstatus", "korkem_supplier", "korkem_delivery_transport",
	"korkem_delivery_cost", "korkem_delivery_payer", "korkem_delivery_paid_by", "korkem_delivery_method",
	"korkem_delivery_settled_on", "korkem_delivery_settled_method", "korkem_film_due",
	"korkem_delivery_driver", "korkem_delivery_phone",
]


def _period(since: str | None, until: str | None) -> tuple:
	until_d = getdate(until or nowdate())
	since_d = getdate(since or until_d)
	if since_d > until_d:
		frappe.throw("Начало периода позже конца.")
	if (until_d - since_d).days >= MAX_DAYS:
		frappe.throw("Период — не больше года.")
	return since_d, until_d


def _way(method: str | None, bank: str | None) -> str:
	"""«Наличные», «Перевод · Kaspi» — how the money moved."""
	return " · ".join(x for x in (method or "Наличные", bank) if x)


def _deliveries(company: str) -> list[dict]:
	"""Film receipts that cost something to bring: posted, or on their way
	(paid when ordered). A receipt made again right counts once — the
	cancelled one is left out."""
	rows = frappe.get_all(
		"Stock Entry",
		filters={"company": company, "korkem_material_receipt": 1, "docstatus": ["in", [0, 1]],
				 "korkem_delivery_payer": ["is", "set"]},
		fields=_FIELDS,
		limit_page_length=0,
	)
	# An unposted one is on its way, or was struck off after it was paid for:
	# the money went either way.
	return rows


def _metres(entry: str) -> float:
	return flt(frappe.db.get_value("Stock Entry Detail", {"parent": entry}, "qty"))


def book(since: str | None = None, until: str | None = None, compare: bool = True) -> dict:
	"""The department's money in and out over a period, and what is owed.

	`days` — in and out day by day, every day of the period, for the chart;
	`previous` — the period of the same length just before, to say whether
	this one is better (owner, 14.11.2026: a chart on every department).
	"""
	material_stock._ensure_editor()
	company = current_company()
	start, end = _period(since, until)
	ins: dict[str, float] = {}
	moves: list[dict] = []
	sales = set()
	for s in frappe.get_all(
		"Stock Entry",
		filters={"company": company, "docstatus": 1, "korkem_film_kind": SALE},
		fields=["name", "posting_date", "korkem_film_payments", "korkem_film_paid", "korkem_film_pay_method",
				"korkem_film_pay_bank", "korkem_film_customer", "creation"],
		limit_page_length=0,
	):
		for p in _payments(s):
			on = getdate(p.get("date") or s.posting_date)
			if start <= on <= end and flt(p.get("amount")) > 0:
				way = _way(p.get("method"), p.get("bank"))
				ins[way] = ins.get(way, 0.0) + flt(p.get("amount"))
				sales.add(s.name)
				# Each payment its own line (owner, 12.11.2026).
				moves.append({
					"date": str(on), "in": True, "amount": flt(p.get("amount")), "way": way,
					"what": frappe.db.get_value("Customer", s.korkem_film_customer, "customer_name")
					or s.korkem_film_customer, "entry": s.name,
					"at": str(s.creation)[11:16] if str(on) == str(getdate(s.creation)) else None,
				})
	outs: list[dict] = []
	logistics, logistics_m = 0.0, 0.0
	for d in _deliveries(company):
		cost = flt(d.korkem_delivery_cost)
		paid_on = getdate(d.creation)
		label = d.korkem_delivery_transport or "Доставка"
		if start <= paid_on <= end and d.korkem_delivery_payer != PAYER_SUPPLIER:
			logistics += cost
			logistics_m += _metres(d.name)
		if d.korkem_delivery_payer == PAYER_CASH and start <= paid_on <= end and cost:
			outs.append({"date": str(paid_on), "what": label, "amount": cost, "way": d.korkem_delivery_method,
						 "receipt": d.name})
		settled = getdate(d.korkem_delivery_settled_on) if d.korkem_delivery_settled_on else None
		if settled and start <= settled <= end and cost:
			who = (get_fullname(d.korkem_delivery_paid_by) if d.korkem_delivery_payer == PAYER_EMPLOYEE
				   else d.korkem_delivery_transport)
			outs.append({
				"date": str(settled),
				"what": f"Вернули: {who}" if d.korkem_delivery_payer == PAYER_EMPLOYEE else f"Перевозчику: {who}",
				"amount": cost, "way": d.korkem_delivery_settled_method, "receipt": d.name,
			})
	outs.extend(_supplier_payments(company, start, end))
	outs.sort(key=lambda o: (o["date"], o["receipt"]))
	for o in outs:
		moves.append({"date": o["date"], "in": False, "amount": o["amount"], "way": o.get("way") or "Наличные",
					  "what": o["what"], "entry": o["receipt"], "at": None})
	moves.sort(key=lambda m: (m["date"], m["at"] or ""), reverse=True)
	# Where the money is: cash in the drawer, each bank apart — in less out
	# by the way it went (owner, 12.11.2026).
	where: dict[str, float] = {}
	for way, amount in ins.items():
		where[way] = where.get(way, 0.0) + amount
	for o in outs:
		way = _way(o.get("way"), None)
		where[way] = where.get(way, 0.0) - o["amount"]
	total_in = round(sum(ins.values()), 2)
	total_out = round(sum(o["amount"] for o in outs), 2)
	daily: dict[str, list[float]] = {}
	for m in moves:
		row = daily.setdefault(m["date"], [0.0, 0.0])
		row[0 if m["in"] else 1] += m["amount"]
	days = []
	day = start
	while day <= end:
		got, spent = daily.get(str(day), (0.0, 0.0))
		days.append({"date": str(day), "in": round(got, 2), "out": round(spent, 2)})
		day = add_days(day, 1)
	previous = None
	if compare:
		length = (end - start).days + 1
		before = book(str(add_days(start, -length)), str(add_days(start, -1)), compare=False)
		previous = {k: before[k] for k in ("since", "until", "in_total", "out_total", "balance")}
	return {
		"since": str(start),
		"until": str(end),
		"in": [{"way": k, "amount": round(v, 2)} for k, v in sorted(ins.items(), key=lambda kv: -kv[1])],
		"in_total": total_in,
		"out": outs,
		"out_total": total_out,
		"balance": round(total_in - total_out, 2),
		"sales": len(sales),
		"spent": len(outs),
		"where": [{"way": k, "amount": round(v, 2)} for k, v in sorted(where.items(), key=lambda kv: -kv[1])],
		"moves": moves[:200],
		"days": days,
		"previous": previous,
		# A day's close, when the period is one day (owner, 12.11.2026).
		"closed": closed(str(start), company) if start == end else None,
		# For the owner's eye only — the bonus does not count it.
		"logistics": round(logistics, 2),
		"logistics_per_m": round(logistics / logistics_m, 2) if logistics_m else None,
		"owed": owed(company),
	}


def owed(company: str | None = None) -> dict:
	"""What is still to be paid: back to employees, and to carriers."""
	employees, carriers = [], []
	for d in _deliveries(company or current_company()):
		if d.korkem_delivery_settled_on or not flt(d.korkem_delivery_cost):
			continue
		row = {
			"receipt": d.name,
			"date": str(getdate(d.creation)),
			"amount": flt(d.korkem_delivery_cost),
			"transport": d.korkem_delivery_transport,
			# How to reach the carrier who is owed (owner, 12.11.2026).
			"driver": d.korkem_delivery_driver,
			"phone": d.korkem_delivery_phone,
			"supplier": frappe.db.get_value("Supplier", d.korkem_supplier, "supplier_name") or d.korkem_supplier,
		}
		if d.korkem_delivery_payer == PAYER_EMPLOYEE:
			employees.append({**row, "user": d.korkem_delivery_paid_by,
							  "name": get_fullname(d.korkem_delivery_paid_by) or d.korkem_delivery_paid_by})
		elif d.korkem_delivery_payer == PAYER_UNPAID:
			carriers.append(row)
	return {"employees": employees, "carriers": carriers, "suppliers": _suppliers_owed(company or current_company())}


def _suppliers_owed(company: str) -> list[dict]:
	"""Film taken on credit and not paid for yet, oldest first. A roll still
	on its way counts — it was bought; one struck off as not coming does not."""
	out = []
	for e in frappe.get_all(
		"Stock Entry",
		filters={"company": company, "korkem_material_receipt": 1, "docstatus": ["in", [0, 1]],
				 "korkem_supplier_owed": 1, "korkem_supplier_paid_on": ["is", "not set"]},
		fields=["name", "creation", "docstatus", "korkem_film_due", "korkem_supplier"],
		order_by="creation asc",
		limit_page_length=0,
	):
		if e.docstatus == 0 and not e.korkem_film_due:
			continue
		line = frappe.db.get_value("Stock Entry Detail", {"parent": e.name}, ["item_code", "qty", "basic_rate"],
								   as_dict=True)
		if not line:
			continue
		out.append({
			"receipt": e.name,
			"date": str(getdate(e.creation)),
			"amount": round(flt(line.qty) * flt(line.basic_rate), 2),
			"metres": flt(line.qty),
			"film": frappe.db.get_value("Item", line.item_code, "item_name") or line.item_code,
			"supplier": frappe.db.get_value("Supplier", e.korkem_supplier, "supplier_name") or e.korkem_supplier,
			"coming": e.docstatus == 0,
		})
	return out


#: Paid out of the film department's own money, or from elsewhere.
FROM_DEPT, FROM_ELSEWHERE = "dept", "elsewhere"


def _supplier_payments(company: str, start, end) -> list[dict]:
	"""Suppliers paid out of the department's own money within the period."""
	out = []
	for e in frappe.get_all(
		"Stock Entry",
		filters={"company": company, "korkem_material_receipt": 1, "korkem_supplier_owed": 1,
				 # A receipt made again right is paid once: the struck one is out.
				 "docstatus": ["in", [0, 1]], "korkem_supplier_paid_from": FROM_DEPT, "korkem_supplier_paid_on": ["between", [start, end]]},
		fields=["name", "korkem_supplier", "korkem_supplier_paid_on", "korkem_supplier_paid_method"],
		limit_page_length=0,
	):
		line = frappe.db.get_value("Stock Entry Detail", {"parent": e.name}, ["qty", "basic_rate"], as_dict=True)
		if not line:
			continue
		who = frappe.db.get_value("Supplier", e.korkem_supplier, "supplier_name") or e.korkem_supplier
		out.append({
			"date": str(getdate(e.korkem_supplier_paid_on)), "what": f"Поставщику: {who}",
			"amount": round(flt(line.qty) * flt(line.basic_rate), 2), "way": e.korkem_supplier_paid_method,
			"receipt": e.name,
		})
	return out


def pay_supplier(receipt: str, method: str | None = None, source: str | None = None) -> dict:
	"""Film taken on credit is paid for — today; `source` says from where:
	`dept`, the department's own money (out of this book), or `elsewhere`."""
	material_stock._ensure_editor()
	row = frappe.db.get_value(
		"Stock Entry", receipt,
		["company", "korkem_material_receipt", "docstatus", "korkem_supplier_owed", "korkem_supplier_paid_on"],
		as_dict=True,
	)
	if (not row or row.company != current_company() or not row.korkem_material_receipt
			or not row.korkem_supplier_owed or row.docstatus == 2):
		frappe.throw("Такого долга поставщику нет.", frappe.DoesNotExistError)
	if row.korkem_supplier_paid_on:
		frappe.throw("Уже оплатили.")
	how = (method or "").strip() or METHODS[0]
	if how not in METHODS:
		frappe.throw("Как платили — наличные, перевод или карта.")
	source = (source or "").strip() or FROM_DEPT
	if source not in (FROM_DEPT, FROM_ELSEWHERE):
		frappe.throw("Откуда деньги — из кассы плёнки или не из неё.")
	frappe.db.set_value("Stock Entry", receipt, {
		"korkem_supplier_paid_on": nowdate(), "korkem_supplier_paid_method": how,
		"korkem_supplier_paid_from": source,
	}, update_modified=False)
	line = frappe.db.get_value("Stock Entry Detail", {"parent": receipt}, ["qty", "basic_rate"], as_dict=True) or {}
	audit.record_audit(action="film.supplier_paid", entity_type="Stock Entry", entity_id=receipt,
					   diff={"amount": round(flt(line.get("qty")) * flt(line.get("basic_rate")), 2), "method": how,
						 "source": source})
	return {"receipt": receipt, "paid_on": nowdate(), "method": how, "source": source}


def settle(receipt: str, method: str | None = None) -> dict:
	"""Given back to the employee, or paid to the carrier — from the
	department's cash, today."""
	material_stock._ensure_editor()
	row = frappe.db.get_value(
		"Stock Entry", receipt,
		["company", "korkem_material_receipt", "korkem_delivery_payer", "korkem_delivery_settled_on",
		 "korkem_delivery_cost"],
		as_dict=True,
	)
	if (not row or row.company != current_company() or not row.korkem_material_receipt
			or row.korkem_delivery_payer not in (PAYER_EMPLOYEE, PAYER_UNPAID)):
		frappe.throw("Такого долга за доставку нет.", frappe.DoesNotExistError)
	if row.korkem_delivery_settled_on:
		frappe.throw("Уже рассчитались.")
	how = (method or "").strip() or METHODS[0]
	if how not in METHODS:
		frappe.throw("Как платили — наличные, перевод или карта.")
	frappe.db.set_value("Stock Entry", receipt, {
		"korkem_delivery_settled_on": nowdate(), "korkem_delivery_settled_method": how,
	}, update_modified=False)
	audit.record_audit(action="film.delivery_settled", entity_type="Stock Entry", entity_id=receipt,
					   diff={"amount": flt(row.korkem_delivery_cost), "payer": row.korkem_delivery_payer, "method": how})
	return {"receipt": receipt, "settled_on": nowdate(), "method": how}


# --------------------------------------------------------------------------
# «Закрыть день» (owner, 12.11.2026): the cash counted in the evening against
# what the book says should be there; a gap is said with why, for the owner.
# --------------------------------------------------------------------------

_CLOSE = "korkem_film_cash_close"


def _expected_cash(day) -> float:
	book_day = book(str(day), str(day), compare=False)
	return next((w["amount"] for w in book_day["where"] if w["way"] == METHODS[0]), 0.0)


def closed(day: str | None = None, company: str | None = None) -> dict | None:
	raw = frappe.db.get_default(f"{_CLOSE}:{company or current_company()}:{getdate(day or nowdate())}")
	if not raw:
		return None
	try:
		return frappe.parse_json(raw)
	except ValueError:
		return None


def close_day(counted, reason: str | None = None, day: str | None = None) -> dict:
	"""The cash in the drawer is counted: what is there, against what should be."""
	material_stock._ensure_editor()
	company = current_company()
	on = getdate(day or nowdate())
	if on > getdate(nowdate()):
		frappe.throw("Закрыть можно только сегодняшний или прошедший день.")
	counted = flt(counted)
	if counted < 0:
		frappe.throw("Сколько насчитали — число от нуля.")
	expected = round(_expected_cash(on), 2)
	gap = round(counted - expected, 2)
	reason = " ".join(str(reason or "").split())[:200]
	if abs(gap) >= 1 and not reason:
		frappe.throw(f"Не сходится на {gap:+,.0f} ₸ — скажите почему.".replace(",", " "))
	row = {"day": str(on), "expected": expected, "counted": counted, "gap": gap, "reason": reason or None,
		   "by": get_fullname(frappe.session.user), "at": str(frappe.utils.now_datetime())[:16]}
	frappe.db.set_default(f"{_CLOSE}:{company}:{on}", frappe.as_json(row))
	audit.record_audit(action="film.cash_closed", entity_type="Company", entity_id=company, diff=row)
	return row
