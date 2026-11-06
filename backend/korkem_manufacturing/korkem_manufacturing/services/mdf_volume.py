# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Объём работ» — OnayBaza's «Жұмыс көлемі»: who did how many m² at which stage.

A stage ticked with a worker (`mdf_orders.set_stage(..., worker=)`) counts the
order's m² to that worker, on the day it was ticked. A stage ticked without
one is counted as «не указано», so the shop's total still adds up and the
manager sees what is missing.

This is the volume, not the pay: piece rates and approval stay with
`piece_work` and the owner.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import flt, getdate, nowdate

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


def volume(since: str | None = None, until: str | None = None) -> dict:
	"""m² and orders per worker and stage, for stages ticked in [since, until]."""
	facade_prices.ensure_editor()
	company = current_company()
	since_d, until_d = _period(since, until)
	done: list[tuple[str, str, str | None]] = []  # (order, stage, worker)
	for stage, field in mdf_orders.STAGES.items():
		by = mdf_orders.STAGE_BY[stage]
		for row in frappe.get_all(
			"Sales Order",
			filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
					 field: ["between", [since_d, until_d]]},
			fields=["name", by],
			limit_page_length=0,
		):
			done.append((row.name, stage, row.get(by)))

	names = sorted({order for order, _, _ in done})
	areas: dict[str, Decimal] = {}
	if names:
		for r in frappe.get_all("Sales Order Item",
								filters={"parent": ["in", names], "item_code": facade_order.FACADE_ITEM},
								fields=["parent", "korkem_area_m2"], limit_page_length=0):
			areas[r.parent] = areas.get(r.parent, Decimal(0)) + Decimal(str(flt(r.korkem_area_m2)))
	people = {}
	ids = sorted({w for _, _, w in done if w})
	if ids:
		people = dict(frappe.get_all("Employee", filters={"name": ["in", ids]}, fields=["name", "employee_name"],
									 as_list=True))

	by_worker: dict[str, dict] = {}
	by_stage = {s: {"stage": s, "orders": 0, "area_m2": Decimal(0)} for s in mdf_orders.STAGES}
	for order, stage, worker in done:
		area = areas.get(order, Decimal(0))
		key = worker or ""
		w = by_worker.setdefault(key, {"worker": worker, "worker_name": people.get(worker) if worker else None,
									   "orders": 0, "area_m2": Decimal(0),
									   "stages": {s: Decimal(0) for s in mdf_orders.STAGES}})
		w["orders"] += 1
		w["area_m2"] += area
		w["stages"][stage] += area
		by_stage[stage]["orders"] += 1
		by_stage[stage]["area_m2"] += area

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
	}
