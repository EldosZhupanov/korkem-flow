# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Когда будет готово» at the order's taking (owner, 25.11.2026): a date
from the shop's load, not a guess.

The shop has lanes — film goes through the press, enamel through the paint
booth, a raw facade through neither. For each lane the order goes through:

- **what is ahead of it**: the m² of every order taken and not yet ready
  (on hold — not counted), in that lane;
- **the pace**: the m² that lane made ready over the last four weeks, per
  working day;
- **the days**: (ahead + this order) ÷ pace, at least the lane's own least
  (paint dries; film waits for its glue), in working days — Monday to
  Saturday.

The order is ready when its slowest lane is. A lane that made fewer than
`MIN_DONE` orders in the four weeks has no pace worth the name: its least
days are given, and the answer says it is a rough one.

Three queries, whatever the size of the queue.
"""

from __future__ import annotations

import math
from decimal import Decimal

import frappe
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_manufacturing.services import directions, facade_order, facade_prices, mdf_orders
from korkem_manufacturing.services.scope import current_company

#: The days the pace is taken over.
WINDOW_DAYS = 28
#: Orders a lane must have made ready in the window for its pace to count.
MIN_DONE = 3
#: The least working days in each lane, however empty the shop.
LEAST_DAYS = {"pvc": 3, "paint": 6, "raw": 2}
LANES = tuple(LEAST_DAYS)
#: Sunday is the shop's day off.
_DAY_OFF = 6


def lanes_of(row) -> list[str]:
	"""The lanes an order goes through, by its stages: the press, the
	paint booth — or neither."""
	stages = mdf_orders.stages_of(row)
	out = [lane for lane, stage in (("pvc", "vacuum"), ("paint", "paint")) if stage in stages]
	return out or ["raw"]


def estimate(areas: dict | str | None, order: str | None = None) -> dict:
	"""The ready date for an order of [areas] — m² by lane, {"pvc": 2.4} —
	from what is in the shop now and how fast it goes. [order] — the
	order itself, not to be counted ahead of itself."""
	facade_prices.ensure_editor()
	wanted = _areas(areas)
	if not wanted:
		frappe.throw("Добавьте в заказ фасады — тогда видно, когда он будет готов.")
	company = current_company()
	today = getdate(nowdate())
	ahead = _in_work(company, order)
	pace = _pace(company, today)
	lanes, days = [], 0
	for lane, area in wanted.items():
		done = pace[lane]
		known = done["orders"] >= MIN_DONE and done["per_day"] > 0
		need = math.ceil((ahead[lane] + area) / done["per_day"]) if known else 0
		lane_days = max(LEAST_DAYS[lane], need)
		days = max(days, lane_days)
		lanes.append({"lane": lane, "area_m2": flt(area, 2), "ahead_m2": flt(ahead[lane], 2),
					  "pace_m2": flt(done["per_day"], 1), "days": lane_days, "known": known})
	return {"ready_on": str(working_days_from(today, days)), "days": days, "lanes": lanes,
			"known": all(x["known"] for x in lanes)}


def working_days_from(start, days: int):
	"""The day [days] working days after [start]; Sundays are not counted."""
	day, left = getdate(start), days
	while left > 0:
		day = add_days(day, 1)
		if day.weekday() != _DAY_OFF:
			left -= 1
	if day.weekday() == _DAY_OFF:
		day = add_days(day, 1)
	return getdate(day)


def _areas(raw) -> dict[str, Decimal]:
	values = frappe.parse_json(raw) if isinstance(raw, str) else (raw or {})
	if not isinstance(values, dict):
		frappe.throw("Площади — по покрытиям: {\"pvc\": 2.4}.")
	out = {}
	for lane, m2 in values.items():
		if lane in LANES and flt(m2) > 0:
			out[lane] = Decimal(str(flt(m2)))
	return out


def _in_work(company: str, order: str | None) -> dict[str, Decimal]:
	"""The m² taken and not yet ready, by lane; on hold — not counted."""
	filters = {"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
			   "korkem_ready_on": ["is", "not set"], "korkem_handed_over_on": ["is", "not set"],
			   "korkem_hold_reason": ["is", "not set"]}
	if order:
		filters["name"] = ["!=", order]
	rows = frappe.get_all("Sales Order", filters=filters, fields=_FIELDS, limit_page_length=0)
	return _by_lane(rows)


def _pace(company: str, today) -> dict[str, dict]:
	"""What each lane made ready over the window: orders and m² a working day."""
	since = add_days(today, -WINDOW_DAYS)
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "korkem_ready_on": ["between", [since, add_days(today, -1)]]},
		fields=_FIELDS, limit_page_length=0,
	)
	area = _by_lane(rows)
	orders = dict.fromkeys(LANES, 0)
	for r in rows:
		for lane in lanes_of(r):
			orders[lane] += 1
	working = sum(1 for i in range(1, WINDOW_DAYS + 1) if add_days(today, -i).weekday() != _DAY_OFF)
	return {lane: {"orders": orders[lane], "per_day": area[lane] / working} for lane in LANES}


_FIELDS = ["name", "korkem_finish", "korkem_extra_stages", "korkem_coatings", "korkem_tags"]


def _by_lane(rows) -> dict[str, Decimal]:
	out = dict.fromkeys(LANES, Decimal(0))
	if not rows:
		return out
	areas: dict[str, Decimal] = {}
	for item in frappe.get_all(
		"Sales Order Item",
		filters={"parent": ["in", [r.name for r in rows]], "item_code": facade_order.FACADE_ITEM},
		fields=["parent", "korkem_area_m2"], limit_page_length=0,
	):
		areas[item.parent] = areas.get(item.parent, Decimal(0)) + Decimal(str(flt(item.korkem_area_m2)))
	for r in rows:
		for lane in lanes_of(r):
			out[lane] += areas.get(r.name, Decimal(0))
	return out


# --------------------------------------------------------------------------
# «Срок» at the order's taking (owner, 27.11.2026): the month by load, the
# earliest day and a safe one, and the film the order waits for
# --------------------------------------------------------------------------

#: How far ahead the month's load is shown, days.
LOAD_DAYS = 45
#: A day's reserve for scrap and a redo: «надёжно» is «впритык» and this.
SAFE_DAYS = 1
#: Film metres a m² of facades takes on the press, roughly — to tell «есть»
#: from «мало» before the layout is made.
FILM_M_PER_M2 = 1.2


def due_options(areas: dict | str | None, order: str | None = None, films=None) -> dict:
	"""For the order form's «Срок»: the earliest day the shop makes it, a
	safe day after it, each day's m² already due against the shop's pace —
	and, for a film not on the shelf, when it can come and the days counted
	from then."""
	company = current_company()
	today = getdate(nowdate())
	wanted = _areas(areas)
	if wanted:
		base = estimate(areas, order)
	else:
		# No sizes yet (owner, 27.11.2026): the month's load is still worth
		# seeing; the date is the lanes' least days, said to be rough.
		facade_prices.ensure_editor()
		raw = frappe.parse_json(areas) if isinstance(areas, str) else (areas or {})
		lanes = [lane for lane in (raw if isinstance(raw, dict) else {}) if lane in LANES] or ["pvc"]
		days = max(LEAST_DAYS[lane] for lane in lanes)
		base = {"ready_on": str(working_days_from(today, days)), "known": False}
	films = frappe.parse_json(films) if isinstance(films, str) else (films or [])
	# {decor: m²} — each film's own area; a bare list takes the PVC total.
	if not isinstance(films, dict):
		films = {f: wanted.get("pvc", 0) for f in films}
	film_rows, film_ready = [], None
	for decor, area in list(films.items())[:10]:
		decor = str(decor or "").strip()
		if not decor:
			continue
		row = _film(decor, company, max(0.0, flt(area)))
		film_rows.append(row)
		if row["short"]:
			# Not on the shelf: the press waits for it — known or not.
			comes = getdate(row["comes_on"]) if row["comes_on"] else None
			if comes and (film_ready is None or comes > film_ready):
				film_ready = comes
	earliest = getdate(base["ready_on"])
	if film_ready:
		earliest = max(earliest, working_days_from(film_ready, LEAST_DAYS["pvc"]))
	safe = working_days_from(earliest, SAFE_DAYS)
	pace = _pace(company, today)
	capacity = sum(float(p["per_day"]) for p in pace.values() if p["orders"] >= MIN_DONE)
	return {
		"earliest": str(earliest),
		"safe": str(safe),
		"known": base["known"] and not any(f["short"] and not f["comes_on"] for f in film_rows),
		"films": film_rows,
		"capacity_m2": round(capacity, 1) if capacity else None,
		"days": _due_by_day(company, today, order),
	}


def _film(decor: str, company: str, area: float) -> dict:
	"""On the shelf, enough for the order — or when it can come."""
	from korkem_manufacturing.services import film_sourcing, film_sources, material_stock

	from korkem_manufacturing.services import film_catalog

	item = frappe.db.get_value(
		"Item", {"korkem_material_company": company, "korkem_material_kind": material_stock.FILM,
				 **film_catalog.named(decor), "disabled": 0}, ["name", "korkem_manufacturer"], as_dict=True)
	if not item:
		return {"decor": decor, "free_m": None, "short": False, "comes_on": None, "supplier": None}
	on_hand = material_stock._stock([item.name], company).get(item.name, (0.0, 0.0))[0]
	free = max(0.0, on_hand - material_stock._reserved([item.name], company).get(item.name, 0.0))
	short = free < area * FILM_M_PER_M2
	comes_on, supplier = None, None
	if short:
		from korkem_manufacturing.services import film_supplier_board

		# What a source took of late, not what it promises (owner, 27.11.2026).
		took = film_supplier_board._lead(company)
		for source in film_sources.by_maker().get(item.korkem_manufacturer, []):
			card = film_sourcing._source_card(source)
			days = film_sourcing._days(card.get("lead"))
			actual = (took.get(source) or {}).get("lead_days")
			if actual is not None:
				days = max(days or 0, actual)
			if days is None:
				continue
			when = add_days(nowdate(), days)
			if comes_on is None or getdate(when) < getdate(comes_on):
				comes_on, supplier = str(getdate(when)), card["name"]
	return {"decor": decor, "free_m": round(free, 1), "short": short, "comes_on": comes_on, "supplier": supplier}


def _due_by_day(company: str, today, order: str | None) -> list[dict]:
	"""The m² of the open orders due each day, from today, for `LOAD_DAYS`."""
	until = add_days(today, LOAD_DAYS)
	filters = {"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
			   "korkem_handed_over_on": ["is", "not set"], "delivery_date": ["between", [today, until]]}
	if order:
		filters["name"] = ["!=", order]
	rows = frappe.get_all("Sales Order", filters=filters, fields=["name", "delivery_date"], limit_page_length=0)
	areas: dict[str, float] = {}
	for item in frappe.get_all(
		"Sales Order Item",
		filters={"parent": ["in", [r.name for r in rows] or [""]], "item_code": facade_order.FACADE_ITEM},
		fields=["parent", "korkem_area_m2"], limit_page_length=0,
	):
		areas[item.parent] = areas.get(item.parent, 0.0) + flt(item.korkem_area_m2)
	by_day: dict[str, dict] = {}
	for r in rows:
		day = by_day.setdefault(str(getdate(r.delivery_date)), {"date": str(getdate(r.delivery_date)), "m2": 0.0,
																 "orders": 0})
		day["m2"] += areas.get(r.name, 0.0)
		day["orders"] += 1
	return [{**d, "m2": round(d["m2"], 2)} for d in sorted(by_day.values(), key=lambda d: d["date"])]
