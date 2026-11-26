# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Объём работ» — OnayBaza's «Жұмыс көлемі»: who did how many m² at which stage.

A stage ticked with a worker (`mdf_orders.set_stage(..., worker=)`) counts the
order's m² to that worker, on the day it was ticked. A stage ticked without
one is counted as «не указано», so the shop's total still adds up and the
manager sees what is missing.

This is the volume, not the pay: piece rates and approval stay with
`piece_work` and the owner.

It is also the shop's dashboard (owner, 14.11.2026): `days` — m² done day by
day; `previous_m2` — the period of the same length before, to compare with;
`queue` — what waits at each stage now, the longest where the shop jams.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_manufacturing.services import directions, facade_order, facade_prices, mdf_orders
from korkem_manufacturing.services.scope import current_company

MAX_DAYS = 366


def workers() -> list[dict]:
	facade_prices.ensure_editor()
	return frappe.get_all(
		"Employee",
		filters={"company": current_company(), "status": "Active"},
		fields=["name as employee", "employee_name", "designation"],
		order_by="employee_name asc",
		limit_page_length=500,
	)


def _period(since: str | None, until: str | None) -> tuple:
	until_d = getdate(until or nowdate())
	since_d = getdate(since or until_d.replace(day=1))
	if since_d > until_d:
		frappe.throw("Начало периода позже конца.")
	if (until_d - since_d).days >= MAX_DAYS:
		frappe.throw("Период — не больше года.")
	return since_d, until_d


def _ticked(company: str, since_d, until_d) -> list[tuple[str, str, str | None, str]]:
	"""(order, stage, worker, day) for every stage ticked in the period."""
	done = []
	for stage, field in mdf_orders.STAGES.items():
		by = mdf_orders.STAGE_BY[stage]
		for row in frappe.get_all(
			"Sales Order",
			filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
					 field: ["between", [since_d, until_d]]},
			fields=["name", by, field],
			limit_page_length=0,
		):
			done.append((row.name, stage, row.get(by), str(getdate(row.get(field)))))
	return done


def _ticked_people(company: str, since_d, until_d) -> list[tuple[str, str, str | None, str, Decimal]]:
	"""(order, stage, worker, day, share) — every ticked stage once per person
	who did it, with his part of it (owner, 26.11.2026: «2 или 3 вакуумщика
	делают вместе, и система делит»). One person: share 1. A stage's own
	total is `_ticked`'s, counted once."""
	from korkem_manufacturing.services import stage_crew

	ticks = _ticked(company, since_d, until_d)
	crews = stage_crew.of_orders({t[0] for t in ticks}, "by")
	out = []
	for order, stage, worker, day in ticks:
		crew = crews.get((order, stage))
		if crew:
			out.extend((order, stage, who, day, Decimal(str(share)) / 100) for who, share in crew)
		else:
			out.append((order, stage, worker, day, Decimal(1)))
	return out


def _areas(names) -> dict[str, Decimal]:
	areas: dict[str, Decimal] = {}
	if names:
		for r in frappe.get_all("Sales Order Item",
								filters={"parent": ["in", sorted(names)], "item_code": facade_order.FACADE_ITEM},
								fields=["parent", "korkem_area_m2"], limit_page_length=0):
			areas[r.parent] = areas.get(r.parent, Decimal(0)) + Decimal(str(flt(r.korkem_area_m2)))
	return areas


def volume(since: str | None = None, until: str | None = None) -> dict:
	"""m² and orders per worker and stage, for stages ticked in [since, until]."""
	facade_prices.ensure_editor()
	company = current_company()
	since_d, until_d = _period(since, until)
	ticked = _ticked(company, since_d, until_d)
	# Each person his part of a stage done by several; the stage once.
	done = [(order, stage, worker, share) for order, stage, worker, _, share in _ticked_people(company, since_d, until_d)]

	names = sorted({order for order, *_ in ticked})
	areas = _areas(names)
	people = {}
	ids = sorted({w for _, _, w, _ in done if w})
	if ids:
		people = dict(frappe.get_all("Employee", filters={"name": ["in", ids]}, fields=["name", "employee_name"],
									 as_list=True))

	by_worker: dict[str, dict] = {}
	by_stage = {s: {"stage": s, "orders": 0, "area_m2": Decimal(0)} for s in mdf_orders.STAGES}
	for order, stage, worker, share in done:
		area = areas.get(order, Decimal(0)) * share
		key = worker or ""
		w = by_worker.setdefault(key, {"worker": worker, "worker_name": people.get(worker) if worker else None,
									   "orders": 0, "area_m2": Decimal(0),
									   "stages": {s: Decimal(0) for s in mdf_orders.STAGES}})
		w["orders"] += 1
		w["area_m2"] += area
		w["stages"][stage] += area
	for order, stage, _, _ in ticked:
		by_stage[stage]["orders"] += 1
		by_stage[stage]["area_m2"] += areas.get(order, Decimal(0))

	rows = sorted(by_worker.values(), key=lambda w: (w["worker"] is None, -w["area_m2"]))
	return {
		"since": str(since_d),
		"until": str(until_d),
		"workers": [
			{**w, "area_m2": flt(w["area_m2"], 2), "stages": {s: flt(v, 2) for s, v in w["stages"].items() if v}}
			for w in rows
		],
		"stages": [{**b, "area_m2": flt(b["area_m2"], 2)} for b in by_stage.values() if b["orders"]],
		"unassigned_m2": flt(by_worker.get("", {}).get("area_m2", 0), 2),
		"days": _days(ticked, areas, since_d, until_d),
		"previous_m2": _previous(company, since_d, until_d),
		"queue": _queue(),
	}


def _days(ticked, areas, since_d, until_d) -> list[dict]:
	"""m² done each day of the period — a month each over more than 62 days."""
	monthly = (until_d - since_d).days > 62
	by: dict[str, Decimal] = {}
	for order, _, _, day in ticked:
		key = day[:7] if monthly else day
		by[key] = by.get(key, Decimal(0)) + areas.get(order, Decimal(0))
	out = []
	day = since_d
	while day <= until_d:
		key = str(day)[:7] if monthly else str(day)
		if not out or out[-1]["date"] != key:
			out.append({"date": key, "area_m2": flt(by.get(key, 0), 2)})
		day = getdate(add_days(day, 1))
	return out


def _previous(company: str, since_d, until_d) -> float:
	"""m² done in the period of the same length just before."""
	length = (until_d - since_d).days + 1
	ticked = _ticked(company, getdate(add_days(since_d, -length)), getdate(add_days(since_d, -1)))
	areas = _areas({order for order, *_ in ticked})
	return flt(sum((areas.get(order, Decimal(0)) for order, *_ in ticked), Decimal(0)), 2)


def _queue() -> list[dict]:
	"""What waits at each stage now, as «Жоспар» counts it."""
	return [{"stage": s["stage"], "orders": len(s["orders"]), "area_m2": flt(s["area_m2"], 2)}
			for s in mdf_orders.plan()["stages"] if s["orders"]]
