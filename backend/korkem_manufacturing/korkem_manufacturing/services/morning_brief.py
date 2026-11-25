# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Утренняя сводка» — the owner's morning in one message (owner,
25.11.2026): what to hand over today, what is due today and is not ready,
what is late, who owes the most, what the orders lack — film and paint —
and what it is time to order.

It is the morning list «Пора заказать» (`reorder_watch`) grown up: the same
switch («утром»), the same hour, the same one message a day to the owner's
Telegram or WhatsApp; the list of what to order is now its last part.
Nothing in it changes anything — it is read, and the work is done where it
always was.

A part with nothing in it is left out; a morning with nothing at all says
nothing — an empty «всё хорошо» every day teaches people not to read it.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import date_diff, flt, getdate, nowdate

from korkem_manufacturing.services import cnc_orders, directions, mdf_orders, search_text

#: Orders named in a part, the rest counted.
SHOWN = 5
#: Customers named among those who owe.
DEBTORS = 3
_FIELDS = ["name", "docstatus", "customer", "customer_name", "transaction_date", "delivery_date", "grand_total",
		   "advance_paid", "korkem_tags", "korkem_direction", "korkem_ready_on", "korkem_handed_over_on",
		   "korkem_hold_reason", "korkem_cnc_started_on", "korkem_finish", "korkem_extra_stages",
		   "korkem_coatings", *mdf_orders.STAGES.values()]


def collect(company: str, day=None, *, staff: bool = True) -> dict:
	"""The morning's parts for one company. [staff] — the stock parts too
	(the film and paint the orders lack, what to order)."""
	today = getdate(day or nowdate())
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "docstatus": 1,
				 "korkem_direction": ["in", [directions.FACADES, directions.CNC]]},
		fields=_FIELDS, order_by="delivery_date asc, transaction_date asc", limit_page_length=0,
	)
	ready, due_today, late = [], [], []
	owed: dict[str, dict] = {}
	for r in rows:
		cnc = r.korkem_direction == directions.CNC
		debt = (cnc_orders._debt if cnc else mdf_orders._debt)(r)
		if debt > 0:
			taken = r.korkem_handed_over_on or r.transaction_date
			who = owed.setdefault(r.customer, {"customer": r.customer, "name": r.customer_name or r.customer,
											   "debt": Decimal(0), "days": 0})
			who["debt"] += debt
			who["days"] = max(who["days"], max(0, date_diff(today, taken)) if taken else 0)
		if r.korkem_handed_over_on:
			continue
		status = (cnc_orders.status_of if cnc else mdf_orders.status_of)(r)
		row = {"order": r.name, "number": search_text.number_in(r.name), "customer": r.customer_name,
			   "debt": float(debt)}
		if status == "ready":
			ready.append(row)
		elif not cnc and status in ("accepted", "in_shop") and r.delivery_date:
			days = date_diff(today, r.delivery_date)
			if days > 0:
				late.append({**row, "days": days})
			elif days == 0:
				due_today.append(row)
	late.sort(key=lambda x: -x["days"])
	debtors = sorted(owed.values(), key=lambda x: -x["debt"])
	out = {
		"day": str(today),
		"ready": ready,
		"due_today": due_today,
		"late": late,
		"owed": float(sum((d["debt"] for d in debtors), Decimal(0))),
		"debtors": [{**d, "debt": float(d["debt"])} for d in debtors[:DEBTORS]],
		"film": [],
		"paint": [],
		"reorder": None,
	}
	if staff:
		out.update(_stock(company))
	return out


def _stock(company: str) -> dict:
	"""What the orders lack and what to order; a part that fails is left
	out — the rest of the morning still goes."""
	from korkem_manufacturing.services import film_shortage, paint_stock, reorder_watch

	out = {}
	try:
		out["film"] = [{"title": f["title"], "short": f["to_buy"], "unit": f["unit"], "orders": f["orders"]}
					   for f in film_shortage.count(company)["by_film"] if f["to_buy"] > 0]
	except Exception:
		frappe.log_error(title="morning_brief.film", message=frappe.get_traceback(with_context=True))
	try:
		stock = paint_stock.stock()
		out["paint"] = [{"title": c["colour"], "short": c["short_kg"]} for c in stock["queue"] if c["short_kg"] > 0]
		out["paint"] += [{"title": m["name"], "short": m["short_kg"]} for m in stock["materials"] if m["short_kg"] > 0]
	except Exception:
		frappe.log_error(title="morning_brief.paint", message=frappe.get_traceback(with_context=True))
	try:
		out["reorder"] = reorder_watch.report()
	except Exception:
		frappe.log_error(title="morning_brief.reorder", message=frappe.get_traceback(with_context=True))
	return out


def text(b: dict, company: str) -> str | None:
	"""The message; None when the morning has nothing to say."""
	from korkem_manufacturing.services import reorder_watch

	order_lines = reorder_watch.lines(b["reorder"]) if b.get("reorder") else []
	if not (b["ready"] or b["due_today"] or b["late"] or b["debtors"] or b["film"] or b["paint"] or order_lines):
		return None
	name = frappe.db.get_value("Company", company, "company_name") or company
	lines = [f"Доброе утро! Сводка на {getdate(b['day']).strftime('%d.%m')} — {name}"]
	if b["ready"]:
		lines += ["", f"Готово, можно выдавать: {len(b['ready'])}"]
		lines += [f"  · {_no(x)} {x['customer']}" + (f" — долг {_money(x['debt'])}" if x["debt"] > 0 else "")
				  for x in b["ready"][:SHOWN]]
		lines += _more(b["ready"])
	if b["due_today"]:
		lines += ["", f"Срок сегодня, ещё не готово: {len(b['due_today'])}"]
		lines += [f"  · {_no(x)} {x['customer']}" for x in b["due_today"][:SHOWN]]
		lines += _more(b["due_today"])
	if b["late"]:
		lines += ["", f"Опаздывают: {len(b['late'])}"]
		lines += [f"  · {_no(x)} {x['customer']} — на {x['days']} дн." for x in b["late"][:SHOWN]]
		lines += _more(b["late"])
	if b["debtors"]:
		lines += ["", f"Клиенты должны: {_money(b['owed'])}. Больше всех:"]
		lines += [f"  · {d['name']} — {_money(d['debt'])}" + (f", {d['days']} дн." if d["days"] else "")
				  for d in b["debtors"]]
	if b["film"] or b["paint"]:
		lines += ["", "Не хватает на заказы:"]
		lines += [f"  · плёнка {f['title']} — {_num(f['short'])} {f['unit']} ({f['orders']} зак.)"
				  for f in b["film"][:SHOWN]]
		lines += [f"  · краска {p['title']} — {_num(p['short'])} кг" for p in b["paint"][:SHOWN]]
	if order_lines:
		lines += ["", "Пора заказать:", *order_lines]
	return "\n".join(lines)


def _no(x: dict) -> str:
	return f"№ {x['number'] or x['order']}"


def _more(items: list) -> list[str]:
	return [f"  … и ещё {len(items) - SHOWN}"] if len(items) > SHOWN else []


def _money(value) -> str:
	return f"{flt(value):,.0f} ₸".replace(",", " ")


def _num(value) -> str:
	return f"{flt(value):g}".replace(".", ",")
