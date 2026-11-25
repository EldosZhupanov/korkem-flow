# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Куда идут деньги» — the shop's month in management-accounting terms
(owner, 25.11.2026: «нам надо видеть траекторию, картину — куда деньги
идут и тратятся»).

**What came in.** The orders the shop made ready in the month — facades and
CNC — at their totals, and the m² of facades among them. That is the month's
work, whatever was paid when; the cash book (`mdf_cash`) answers the other
question. Film the film department sold is its own business and not here.

**Where it went**, by cost group and cost item (`cost_items`):

- **raw material** — MDF, film, paint, glue taken off the shelf in the month
  (Material Issue at the ledger's valuation; the film department's own sales
  are left out);
- **piece-work pay** — the piece-work book's entries of the month, approved
  or paid (a reversal nets its entry out);
- **bills** — the month's bills (`cost_bills`);
- **consumables** — what was taken off their shelf (`consumables`);
- **urgent expenses** — approved in the month, on their cost item, else by
  their own category.

**What it means.** The cost of one m²; the overheads per m² (everything but
raw material and piece work) that each order's margin now carries
(`overhead_rate`); costs split into **fixed** and **variable**, and from
them the **break-even point** — the m² a month at which the shop covers
everything and earns nothing:

    break-even m² = fixed ÷ (revenue per m² − variable per m²)

**Plan against fact.** An item over its monthly limit, an item at more than
half again its last three months' average, and a bill not entered by the
5th — each is said, here and in the morning brief.
"""

from __future__ import annotations

from collections import defaultdict

import frappe
from frappe.utils import add_months, flt, get_last_day, getdate, nowdate

from korkem_manufacturing.services import cost_bills, cost_items, directions, facade_order, material_stock
from korkem_manufacturing.services.scope import current_company

RAW_KINDS = (material_stock.MDF, material_stock.FILM, material_stock.PAINT, material_stock.GLUE)
#: Months the «usual» of an item is taken over.
HISTORY = 3
#: More than this times its usual, and an item is said to have jumped.
JUMP = 1.5
#: A jump smaller than this, ₸, is not worth a line.
JUMP_FLOOR = 5000
#: A bill not entered by this day of the next month is said to be missing.
BILL_DAY = 5
PIECE = "piece"
RATE_KEY = "korkem:overhead_rate:{company}"


def month(value: str | None = None) -> dict:
	cost_items.ensure_owner()
	company = current_company()
	cost_items.seed(company)
	first = cost_bills.month_of(value)
	last = get_last_day(first)
	made = _made(company, first, last)
	costs = _costs(company, first, last)
	history = [_costs(company, add_months(first, -i), get_last_day(add_months(first, -i)))
			   for i in range(1, HISTORY + 1)]
	items = {r.name: r for r in frappe.get_all(
		cost_items.DOCTYPE, filters={"company": company},
		fields=["name", "title", "cost_group", "mode", "behaviour", "area", "monthly_limit", "archived",
				"merged_into"], limit_page_length=0)}

	rows = []
	for key, amount in costs["items"].items():
		usual = _usual([h["items"].get(key, 0.0) for h in history])
		rows.append(_item_row(key, amount, usual, items, costs))
	# A bill item nothing was spent on yet this month still has its line.
	for r in items.values():
		if r.mode == "bill" and not r.archived and not r.merged_into and r.name not in costs["items"]:
			rows.append(_item_row(r.name, 0.0, _usual([h["items"].get(r.name, 0.0) for h in history]), items, costs))
	rows.sort(key=lambda x: -x["amount"])

	revenue, m2 = made["revenue"], made["m2"]
	total = sum(x["amount"] for x in rows)
	groups: dict[str, float] = defaultdict(float)
	areas: dict[str, float] = defaultdict(float)
	fixed = variable = overhead = 0.0
	for x in rows:
		groups[x["group"]] += x["amount"]
		if x["area"]:
			areas[x["area"]] += x["amount"]
		if x["behaviour"] == "fixed":
			fixed += x["amount"]
		else:
			variable += x["amount"]
		if x["key"] not in (cost_items.RAW, PIECE):
			overhead += x["amount"]
	order = {g: i for i, g in enumerate(cost_items.GROUPS)}
	group_rows = sorted(
		({"group": g, "amount": round(a, 2), "share": _share(a, revenue)} for g, a in groups.items() if a),
		key=lambda g: (-g["amount"], order.get(g["group"], 99)))
	per_m2 = (revenue - variable) / m2 if m2 else 0.0
	return {
		"month": str(first),
		"revenue": round(revenue, 2),
		"orders": made["orders"],
		"m2": round(m2, 2),
		"costs": round(total, 2),
		"profit": round(revenue - total, 2),
		"profit_share": _share(revenue - total, revenue),
		"groups": group_rows,
		"items": rows,
		"areas": sorted(({"area": a, "amount": round(v, 2)} for a, v in areas.items() if v),
						key=lambda a: -a["amount"]),
		"cost_per_m2": round(total / m2, 0) if m2 else None,
		"overhead": round(overhead, 2),
		"overhead_per_m2": round(overhead / m2, 0) if m2 else None,
		"fixed": round(fixed, 2),
		"variable": round(variable, 2),
		"break_even_m2": round(fixed / per_m2, 0) if per_m2 > 0 else None,
		"alerts": _alerts(rows, company, first),
	}


def overhead_rate(company: str | None = None) -> float | None:
	"""Overheads per m² of the last full month — what each order's margin
	carries beyond its own material and work. None while not known."""
	company = company or current_company()
	key = RATE_KEY.format(company=company)
	cached = frappe.cache().get_value(key)
	if cached is not None:
		return cached or None
	first = add_months(cost_bills.month_of(), -1)
	last = get_last_day(first)
	made = _made(company, first, last)
	costs = _costs(company, first, last)
	over = sum(a for k, a in costs["items"].items() if k not in (cost_items.RAW, PIECE))
	rate = round(over / made["m2"], 2) if made["m2"] and over else 0.0
	frappe.cache().set_value(key, rate, expires_in_sec=6 * 3600)
	return rate or None


def alerts(company: str) -> list[dict]:
	"""This month's plan-against-fact lines, for the morning brief."""
	first = cost_bills.month_of()
	costs = _costs(company, first, get_last_day(first))
	history = [_costs(company, add_months(first, -i), get_last_day(add_months(first, -i)))
			   for i in range(1, HISTORY + 1)]
	items = {r.name: r for r in frappe.get_all(
		cost_items.DOCTYPE, filters={"company": company},
		fields=["name", "title", "cost_group", "mode", "behaviour", "area", "monthly_limit", "archived",
				"merged_into"], limit_page_length=0)}
	rows = [_item_row(k, a, _usual([h["items"].get(k, 0.0) for h in history]), items, costs)
			for k, a in costs["items"].items()]
	# Only what is over: a missing bill is the month-end's business.
	return [a for a in _alerts(rows, company, first) if a["kind"] != "unfilled"]


def _item_row(key: str, amount: float, usual: float, items: dict, costs: dict) -> dict:
	if key == cost_items.RAW:
		return {"key": key, "item": None, "title": cost_items.RAW, "group": cost_items.RAW, "area": None,
				"behaviour": "variable", "amount": round(amount, 2), "usual": round(usual, 2), "limit": 0.0,
				"used": None}
	if key == PIECE:
		return {"key": key, "item": None, "title": "Сдельная оплата", "group": cost_items.PAY, "area": None,
				"behaviour": "variable", "amount": round(amount, 2), "usual": round(usual, 2), "limit": 0.0,
				"used": None}
	if key.startswith("category:"):
		group = cost_items.group_of_expense(None, key.split(":", 1)[1])
		return {"key": key, "item": None, "title": key.split(":", 1)[1], "group": group, "area": None,
				"behaviour": "variable", "amount": round(amount, 2), "usual": round(usual, 2), "limit": 0.0,
				"used": None}
	r = items.get(key)
	return {"key": key, "item": key, "title": r.title if r else key, "group": r.cost_group if r else cost_items.OTHER,
			"area": r.area if r else None, "behaviour": r.behaviour if r else "variable",
			"amount": round(amount, 2), "usual": round(usual, 2), "limit": flt(r.monthly_limit) if r else 0.0,
			"used": costs["used"].get(key)}


def _alerts(rows: list[dict], company: str, first) -> list[dict]:
	out = []
	for x in rows:
		if x["limit"] and x["amount"] > x["limit"]:
			out.append({"kind": "limit", "title": x["title"], "amount": x["amount"], "limit": x["limit"],
						"over": round((x["amount"] - x["limit"]) / x["limit"] * 100)})
		elif x["usual"] and x["amount"] > x["usual"] * JUMP and x["amount"] - x["usual"] >= JUMP_FLOOR:
			out.append({"kind": "jump", "title": x["title"], "amount": x["amount"], "usual": x["usual"],
						"times": round(x["amount"] / x["usual"], 1)})
	today = getdate(nowdate())
	month_over = get_last_day(first) < today
	if month_over and (today.day >= BILL_DAY or cost_bills.month_of(str(today)) > add_months(first, 1)):
		for x in rows:
			if x["item"] and not x["amount"] and _is_bill(x["item"]):
				out.append({"kind": "unfilled", "title": x["title"]})
	return out


def _is_bill(item: str) -> bool:
	return frappe.db.get_value(cost_items.DOCTYPE, item, "mode") == "bill"


def _made(company: str, first, last) -> dict:
	"""The orders made ready in the month: their totals and the facades' m²."""
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "docstatus": 1, "korkem_ready_on": ["between", [first, last]],
				 "korkem_direction": ["in", [directions.FACADES, directions.CNC]]},
		fields=["name", "grand_total", "korkem_direction"], limit_page_length=0,
	)
	facades = [r.name for r in rows if r.korkem_direction == directions.FACADES]
	m2 = 0.0
	if facades:
		m2 = flt(frappe.db.sql(
			"""select sum(korkem_area_m2) from `tabSales Order Item` where parent in %(orders)s and item_code = %(item)s""",
			{"orders": tuple(facades), "item": facade_order.FACADE_ITEM})[0][0])
	return {"orders": len(rows), "revenue": sum(flt(r.grand_total) for r in rows), "m2": m2}


def _costs(company: str, first, last) -> dict:
	"""The month's costs by key: a cost item's name, «Сырьё», the piece
	work, or an urgent expense's own category («category:Ремонт»)."""
	items: dict[str, float] = defaultdict(float)
	raw = frappe.db.sql(
		"""
		select sum(d.amount)
		from `tabStock Entry Detail` d
		join `tabStock Entry` e on e.name = d.parent
		join `tabItem` i on i.name = d.item_code
		where e.docstatus = 1 and e.purpose = 'Material Issue' and e.company = %(company)s
		  and e.posting_date between %(first)s and %(last)s
		  and i.korkem_material_kind in %(kinds)s and ifnull(e.korkem_film_kind, '') = ''
		""",
		{"company": company, "first": first, "last": last, "kinds": RAW_KINDS},
	)[0][0]
	if flt(raw):
		items[cost_items.RAW] += flt(raw)
	piece = frappe.db.sql(
		"""
		select sum(amount) from `tabPiece Work Entry`
		where company = %(company)s and status != 'Pending Approval' and date(creation) between %(first)s and %(last)s
		""",
		{"company": company, "first": first, "last": last},
	)[0][0]
	if flt(piece):
		items[PIECE] += flt(piece)
	used: dict[str, float] = {}
	for b in frappe.get_all("Cost Bill", filters={"company": company, "month": first},
							fields=["cost_item", "amount", "meter_from", "meter_to"], limit_page_length=0):
		items[_root(b.cost_item)] += flt(b.amount)
		if b.meter_to and b.meter_from not in (None, ""):
			used[_root(b.cost_item)] = round(flt(b.meter_to) - flt(b.meter_from), 2)
	from korkem_manufacturing.services import consumables, urgent_expenses

	for key, amount in consumables.spent(company, first, last).items():
		items[_root(key)] += amount
	for e in frappe.get_all(
		urgent_expenses.DOCTYPE,
		filters={"company": company, "status": urgent_expenses.APPROVED,
				 "decided_at": ["between", [f"{first} 00:00:00", f"{last} 23:59:59.999999"]]},
		fields=["amount", "category", "cost_item"], limit_page_length=0,
	):
		items[_root(e.cost_item) if e.cost_item else f"category:{e.category or 'Другое'}"] += flt(e.amount)
	return {"items": {k: v for k, v in items.items() if v}, "used": used}


def _root(name: str) -> str:
	"""A merged item's money is its target's."""
	seen = 0
	while name and seen < 10:
		nxt = frappe.db.get_value(cost_items.DOCTYPE, name, "merged_into")
		if not nxt:
			return name
		name, seen = nxt, seen + 1
	return name


def _usual(values: list[float]) -> float:
	spent = [v for v in values if v]
	return sum(spent) / len(spent) if spent else 0.0


def _share(part: float, whole: float) -> float | None:
	return round(part / whole * 100, 1) if whole else None

