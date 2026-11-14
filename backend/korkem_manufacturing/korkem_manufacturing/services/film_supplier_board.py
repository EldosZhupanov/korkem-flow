# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The suppliers' board (owner, 12.11.2026: «какая фирма лучше покупается»).

Each source of film on one line, the best seller first: how many metres of
its film were sold this month (or in all), what that brought, how much of it
lies on the shelf, what is on its way, how long it takes to bring a roll
against what it promised — and what to do about it: which of its films ran
low and are to be ordered, which lie on the shelf unmoved. And the money
side of it (owner, 14.11.2026): what we owe it for film taken on credit,
how many of its last rolls came on time, and whether its price moved.

**Whose metres a sale is.** A film bought from two sources is shared between
them by what each brought: 60 m from one and 40 m from the other make a
sale of 10 m six metres of the first and four of the second. The shelf is
shared the same way. A film nobody is named for is in the totals and in
nobody's line.

Nothing is stored: every number is counted from the receipts and the sales.
"""

from __future__ import annotations

import json

import frappe
from frappe.utils import date_diff, flt, getdate, nowdate

from korkem_manufacturing.services import film_cash, film_dept, material_stock, price_visibility
from korkem_manufacturing.services.film_team import IDLE_DAYS
from korkem_manufacturing.services.scope import current_company

#: How many of a source's last rolls say how long it takes.
LEAD_ROLLS = 10


def board(period: str | None = None) -> dict:
	"""Every source with what its film sold; the best seller first."""
	material_stock._ensure_staff()
	company = current_company()
	money = price_visibility.can_see_prices()
	all_time = str(period or "month").strip() == "all"
	since = None if all_time else getdate(nowdate()).replace(day=1)

	films = {f["item"]: f for f in film_dept.stock()["films"]}
	known = set(frappe.get_all(
		"Item", filters={"korkem_material_company": company, "korkem_material_kind": material_stock.FILM},
		pluck="name", limit_page_length=0,
	))
	brought = _brought(company, known)
	sold = _sold(company, known, since)
	coming = _coming(company)
	lead = _lead(company)
	idle = _idle(company, films, brought)
	owed = _owed(company) if money else {}
	prices = _price_change(company, known) if money else {}

	rows: dict[str, dict] = {}
	for s in frappe.get_all(
		"Supplier", filters={"disabled": 0},
		fields=["name", "supplier_name", "korkem_src_city", "korkem_src_contact", "korkem_src_phone",
				"korkem_src_whatsapp"],
		order_by="supplier_name asc", limit_page_length=500,
	):
		rows[s.name] = {
			"supplier": s.name,
			"name": s.supplier_name or s.name,
			"city": s.korkem_src_city or None,
			"contact": s.korkem_src_contact or None,
			"phone": s.korkem_src_phone or None,
			"whatsapp": s.korkem_src_whatsapp or None,
			"sold_m": 0.0,
			"amount": 0.0,
			"on_hand_m": 0.0,
			"coming": coming.get(s.name),
			**{"lead_days": None, "promised_days": None, "late_days": None, "on_time": None, "rolls": 0,
			   **lead.get(s.name, {})},
			# Film taken on credit and not paid for yet — for who sees money.
			"owed": owed.get(s.name, {}).get("amount") if money else None,
			"owed_count": owed.get(s.name, {}).get("count", 0),
			# Its last price for a metre against the one before, in percent.
			"price_change": prices.get(s.name),
			"reorder": [],
			"idle": idle.get(s.name),
		}

	# A film's metres, shared by what each source brought of it.
	for item, by_source in brought.items():
		whole = sum(by_source.values())
		if whole <= 0:
			continue
		out = sold.get(item, {"metres": 0.0, "amount": 0.0})
		shelf = flt((films.get(item) or {}).get("on_hand"))
		for supplier, metres in by_source.items():
			row = rows.get(supplier)
			if not row:
				continue
			part = metres / whole
			row["sold_m"] += out["metres"] * part
			row["amount"] += out["amount"] * part
			row["on_hand_m"] += shelf * part

	# What ran low, by whom it is ordered from.
	for f in films.values():
		order = f.get("reorder")
		row = rows.get(order["supplier"]) if order and order.get("supplier") else None
		if row:
			row["reorder"].append({
				"item": f["item"],
				"title": _title(f),
				"metres": order["metres"],
				"free": round(flt(f.get("free")), 2),
				"price_m": order.get("price_m") if money else None,
			})

	sold_m = sum(r["metres"] for r in sold.values())
	result = list(rows.values())
	for r in result:
		r["share"] = round(100 * r["sold_m"] / sold_m, 1) if sold_m else 0.0
		r["sold_m"] = round(r["sold_m"], 2)
		r["on_hand_m"] = round(r["on_hand_m"], 2)
		r["amount"] = round(r["amount"], 2) if money else None
		r["reorder"].sort(key=lambda o: o["title"].casefold())
	result.sort(key=lambda r: (-r["sold_m"], -r["on_hand_m"], r["name"].casefold()))
	return {
		"period": "all" if all_time else "month",
		"since": str(since) if since else None,
		"sold_m": round(sold_m, 2),
		"amount": round(sum(r["amount"] for r in sold.values()), 2) if money else None,
		"on_hand_m": round(sum(flt(f.get("on_hand")) for f in films.values()), 2),
		"coming_m": round(sum(c["metres"] for c in coming.values()), 2),
		"coming_count": sum(c["count"] for c in coming.values()),
		"reorder_films": sum(len(r["reorder"]) for r in result),
		"reorder_suppliers": sum(1 for r in result if r["reorder"]),
		"owed": round(sum(o["amount"] for o in owed.values()), 2) if money else None,
		"owed_suppliers": len(owed),
		"idle_days": IDLE_DAYS,
		"suppliers": result,
	}


def _title(f: dict) -> str:
	return f.get("label") or f"{f.get('maker') or ''} · {f.get('colour') or ''}".strip(" ·")


def _brought(company: str, known: set[str]) -> dict[str, dict[str, float]]:
	"""Film → source → the metres it brought, in all."""
	out: dict[str, dict[str, float]] = {}
	for r in frappe.db.sql(
		"""select d.item_code, e.korkem_supplier, sum(d.qty) as metres
		from `tabStock Entry Detail` d join `tabStock Entry` e on e.name = d.parent
		where e.company = %s and e.docstatus = 1 and e.korkem_material_receipt = 1
			and e.korkem_supplier is not null and e.korkem_supplier != ''
		group by d.item_code, e.korkem_supplier""",
		(company,), as_dict=True,
	):
		if r.item_code in known and flt(r.metres) > 0:
			out.setdefault(r.item_code, {})[r.korkem_supplier] = flt(r.metres)
	return out


def _sold(company: str, known: set[str], since) -> dict[str, dict]:
	"""Film → the metres sold to customers and what they were charged."""
	out: dict[str, dict] = {}
	for r in frappe.db.sql(
		"""select d.item_code, sum(d.qty) as metres, sum(d.qty * ifnull(d.korkem_film_price_m, 0)) as amount
		from `tabStock Entry Detail` d join `tabStock Entry` e on e.name = d.parent
		where e.company = %s and e.docstatus = 1 and e.korkem_film_kind = %s and e.posting_date >= %s
		group by d.item_code""",
		(company, film_dept.SALE, str(since or "2000-01-01")), as_dict=True,
	):
		if r.item_code in known:
			out[r.item_code] = {"metres": flt(r.metres), "amount": flt(r.amount)}
	return out


def _coming(company: str) -> dict[str, dict]:
	"""Source → what is on its way: the metres, how many rolls, the nearest day."""
	today = getdate(nowdate())
	out: dict[str, dict] = {}
	for e in frappe.get_all(
		"Stock Entry",
		filters={"company": company, "docstatus": 0, "korkem_material_receipt": 1,
				 "korkem_film_due": ["is", "set"], "korkem_supplier": ["is", "set"]},
		fields=["name", "korkem_film_due", "korkem_supplier"],
		order_by="korkem_film_due asc", limit_page_length=500,
	):
		metres = flt(frappe.db.get_value("Stock Entry Detail", {"parent": e.name}, "qty"))
		row = out.setdefault(e.korkem_supplier, {"metres": 0.0, "count": 0, "due": str(e.korkem_film_due),
												  "late_days": 0})
		row["metres"] += metres
		row["count"] += 1
		row["late_days"] = max(row["late_days"], date_diff(today, e.korkem_film_due), 0)
	return out


def _lead(company: str) -> dict[str, dict]:
	"""Source → how long a roll took against what was promised, over its
	last rolls that were ordered ahead. The promise is the day first named:
	a date moved because the source was late does not excuse it."""
	entries = frappe.get_all(
		"Stock Entry",
		filters={"company": company, "docstatus": 1, "korkem_material_receipt": 1,
				 "korkem_film_due": ["is", "set"], "korkem_supplier": ["is", "set"]},
		fields=["name", "creation", "posting_date", "korkem_film_due", "korkem_supplier"],
		order_by="posting_date desc, creation desc", limit_page_length=2000,
	)
	first: dict[str, str] = {}
	if entries:
		for a in frappe.get_all(
			"Domain Audit Event",
			filters={"company": company, "action": "film.rescheduled",
					 "entity_id": ["in", [e.name for e in entries]]},
			fields=["entity_id", "diff_json"], order_by="creation asc", limit_page_length=0,
		):
			try:
				was = (json.loads(a.diff_json or "{}") or {}).get("from")
			except ValueError:
				was = None
			if was and a.entity_id not in first:
				first[a.entity_id] = was
	took: dict[str, list[tuple[int, int]]] = {}
	for e in entries:
		rolls = took.setdefault(e.korkem_supplier, [])
		if len(rolls) >= LEAD_ROLLS:
			continue
		ordered = getdate(e.creation)
		days = date_diff(e.posting_date, ordered)
		promised = date_diff(first.get(e.name) or e.korkem_film_due, ordered)
		if days >= 0 and promised >= 0:
			rolls.append((days, promised))
	out = {}
	for supplier, rolls in took.items():
		if not rolls:
			continue
		days = sum(r[0] for r in rolls) / len(rolls)
		promised = sum(r[1] for r in rolls) / len(rolls)
		out[supplier] = {
			"lead_days": round(days),
			"promised_days": round(promised),
			"late_days": max(round(days) - round(promised), 0),
			# «Вовремя 9 из 10»: the rolls that took no longer than promised.
			"on_time": sum(1 for took_days, promised_days in rolls if took_days <= promised_days),
			"rolls": len(rolls),
		}
	return out


def _owed(company: str) -> dict[str, dict]:
	"""Source → what we owe it for film taken on credit, and for how many rolls."""
	out: dict[str, dict] = {}
	for row in film_cash._suppliers_owed(company):
		mine = out.setdefault(row["supplier_id"], {"amount": 0.0, "count": 0})
		mine["amount"] = round(mine["amount"] + flt(row["amount"]), 2)
		mine["count"] += 1
	return out


def _price_change(company: str, known: set[str]) -> dict[str, float]:
	"""Source → how its price for a metre moved, in percent: each film's last
	receipt against the one before it, averaged over its films. A film it
	brought once says nothing."""
	last_two: dict[tuple[str, str], list[float]] = {}
	for r in frappe.db.sql(
		"""select d.item_code, e.korkem_supplier, d.basic_rate
		from `tabStock Entry Detail` d join `tabStock Entry` e on e.name = d.parent
		where e.company = %s and e.docstatus = 1 and e.korkem_material_receipt = 1
			and e.korkem_supplier is not null and e.korkem_supplier != '' and d.basic_rate > 0
		order by e.posting_date desc, e.creation desc""",
		(company,), as_dict=True,
	):
		if r.item_code not in known:
			continue
		rates = last_two.setdefault((r.korkem_supplier, r.item_code), [])
		if len(rates) < 2:
			rates.append(flt(r.basic_rate))
	moved: dict[str, list[float]] = {}
	for (supplier, _item), rates in last_two.items():
		if len(rates) == 2 and rates[1] > 0:
			moved.setdefault(supplier, []).append((rates[0] - rates[1]) / rates[1] * 100)
	return {supplier: round(sum(m) / len(m), 1) for supplier, m in moved.items()}


def _idle(company: str, films: dict[str, dict], brought: dict[str, dict[str, float]]) -> dict[str, dict]:
	"""Source → its films that lie on the shelf unmoved: how many, how many
	metres. A film of two sources is the one's that brought most of it."""
	since = getdate(nowdate()).toordinal() - IDLE_DAYS
	moved = {
		r.item_code: r.last_out or r.first_in
		for r in frappe.db.sql(
			"""select d.item_code,
				max(case when d.s_warehouse is not null and d.s_warehouse != '' then e.posting_date end) as last_out,
				min(case when d.t_warehouse is not null and d.t_warehouse != '' then e.posting_date end) as first_in
			from `tabStock Entry Detail` d join `tabStock Entry` e on e.name = d.parent
			where e.company = %s and e.docstatus = 1
			group by d.item_code""",
			(company,), as_dict=True,
		)
	}
	out: dict[str, dict] = {}
	for item, f in films.items():
		by_source = brought.get(item)
		when = moved.get(item)
		if flt(f.get("on_hand")) <= 0 or not by_source or not when or getdate(when).toordinal() > since:
			continue
		supplier = max(by_source, key=lambda s: (by_source[s], s))
		row = out.setdefault(supplier, {"films": 0, "metres": 0.0})
		row["films"] += 1
		row["metres"] = round(row["metres"] + flt(f["on_hand"]), 2)
	return out
