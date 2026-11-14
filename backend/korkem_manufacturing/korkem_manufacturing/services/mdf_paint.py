# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Отдел краски — the paint department's board (owner, 14.11.2026).

What the painter needs in front of him, and nothing else:

- **by colour** — the orders waiting to be painted now, grouped by the paint
  colour of their painted positions, the biggest batch first. One colour
  mixed once and one gun cleaned once for three orders is the saving; the
  manager sees which colour to mix next;
- **drying** — what was put to dry and when it will be dry (`dry_hours`
  after it went in, the factory's own figure); a facade handled wet comes
  back for a second coat;
- **coming** — the m² still on its way to the paint, so the painter knows
  what tomorrow holds;
- **popular** — the colours painted most over the last 90 days, to keep
  in stock.

An order waits at paint when «краска» is the first of its stages not
ticked. «Покрасил — сушится» (`start_drying`) stamps the time; ticking the
stage «краска» (`mdf_orders.set_stage`) when it is dry takes it off the board.
"""

from __future__ import annotations

from collections import defaultdict
from decimal import Decimal

import frappe
from frappe.utils import add_days, add_to_date, cint, flt, get_datetime, now_datetime, nowdate

from korkem_manufacturing.services import audit, directions, facade_order, facade_prices, mdf_orders, mdf_tags
from korkem_manufacturing.services.scope import current_company

PAINT = "paint"
DRYING = "korkem_paint_drying_since"
DEFAULT_DRY_HOURS = 24
MAX_DRY_HOURS = 168
POPULAR_DAYS = 90
POPULAR_TOP = 8
_DRY_KEY = "korkem_paint_dry_hours"
#: A position with no colour named still has to be painted.
NO_COLOUR = "—"


def dry_hours(company: str | None = None) -> int:
	value = cint(frappe.db.get_default(f"{_DRY_KEY}:{company or current_company()}"))
	return value if 0 < value <= MAX_DRY_HOURS else DEFAULT_DRY_HOURS


def set_dry_hours(hours) -> dict:
	"""How long a coat dries here, in hours (1–168)."""
	facade_prices.ensure_editor()
	value = cint(hours)
	if not 0 < value <= MAX_DRY_HOURS:
		frappe.throw(f"Сушка — от 1 до {MAX_DRY_HOURS} часов.")
	company = current_company()
	frappe.db.set_default(f"{_DRY_KEY}:{company}", str(value))
	audit.record_audit(action="mdf.paint_dry_hours", entity_type="Company", entity_id=company,
					   diff={"hours": value})
	return {"dry_hours": value}


def board() -> dict:
	facade_prices.ensure_editor()
	company = current_company()
	hours = dry_hours(company)
	now = now_datetime()
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "korkem_ready_on": ["is", "not set"], "korkem_handed_over_on": ["is", "not set"],
				 "korkem_hold_reason": ["is", "not set"]},
		fields=["name", "customer_name", "delivery_date", "korkem_finish", "korkem_extra_stages",
				"korkem_coatings", "korkem_tags", DRYING, *mdf_orders.STAGES.values()],
		order_by="delivery_date asc, name asc",
		limit_page_length=1000,
	)
	painting = [r for r in rows if PAINT in mdf_orders.stages_of(r) and not r.get(mdf_orders.STAGES[PAINT])]
	colours = _colours([r.name for r in painting])
	by_colour: dict[str, dict] = {}
	drying, coming = [], Decimal(0)
	for r in painting:
		needed = mdf_orders.stages_of(r)
		first = next(s for s in needed if not r.get(mdf_orders.STAGES[s]))
		own = colours.get(r.name, {})
		area = sum(own.values(), Decimal(0))
		if r.get(DRYING):
			since = get_datetime(r.get(DRYING))
			dry_at = add_to_date(since, hours=hours)
			drying.append({"name": r.name, "customer_name": r.customer_name, "since": str(since),
						   "dry_at": str(dry_at), "dry": dry_at <= now,
						   "minutes_left": max(0, int((dry_at - now).total_seconds() // 60)),
						   "colours": sorted(own), "area_m2": float(area)})
			continue
		if first != PAINT:
			coming += area
			continue
		for colour, m2 in own.items():
			group = by_colour.setdefault(colour, {"colour": colour, "area_m2": Decimal(0), "orders": []})
			group["area_m2"] += m2
			group["orders"].append({"name": r.name, "customer_name": r.customer_name,
									"delivery_date": str(r.delivery_date), "area_m2": float(m2),
									"overdue": mdf_orders._overdue(r),
									"urgent": "urgent" in mdf_tags.parse(r.korkem_tags)})
	groups = sorted(by_colour.values(), key=lambda g: (-g["area_m2"], g["colour"]))
	drying.sort(key=lambda d: d["dry_at"])
	return {
		"dry_hours": hours,
		"by_colour": [{**g, "area_m2": float(g["area_m2"])} for g in groups],
		"waiting_m2": float(sum((g["area_m2"] for g in groups), Decimal(0))),
		"drying": drying,
		"coming_m2": float(coming),
		"popular": popular(company),
	}


def _colours(orders: list[str]) -> dict[str, dict[str, Decimal]]:
	"""m² by paint colour, per order — its painted positions only."""
	if not orders:
		return {}
	heads = {r.name: r.korkem_finish for r in frappe.get_all(
		"Sales Order", filters={"name": ["in", orders]}, fields=["name", "korkem_finish"])}
	result: dict[str, dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
	for line in frappe.get_all(
		"Sales Order Item",
		filters={"parent": ["in", orders], "item_code": facade_order.FACADE_ITEM},
		fields=["parent", "korkem_decor_top", "korkem_line_coating", "korkem_finish", "korkem_area_m2"],
		limit_page_length=0,
	):
		coating = line.korkem_line_coating or mdf_orders.coating_of(line.korkem_finish or heads.get(line.parent))
		if coating != PAINT:
			continue
		colour = (line.korkem_decor_top or "").strip() or NO_COLOUR
		result[line.parent][colour] += Decimal(str(flt(line.korkem_area_m2)))
	return {order: dict(c) for order, c in result.items()}


def popular(company: str | None = None) -> list[dict]:
	"""The colours painted most, by m², over the last 90 days of orders."""
	company = company or current_company()
	names = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "transaction_date": [">=", add_days(nowdate(), -POPULAR_DAYS)]},
		pluck="name",
		limit_page_length=0,
	)
	totals: dict[str, Decimal] = defaultdict(Decimal)
	orders: dict[str, int] = defaultdict(int)
	for colours in _colours(names).values():
		for colour, m2 in colours.items():
			totals[colour] += m2
			orders[colour] += 1
	top = sorted(totals.items(), key=lambda kv: -kv[1])[:POPULAR_TOP]
	return [{"colour": c, "area_m2": float(m2), "orders": orders[c]} for c, m2 in top]


def start_drying(order: str) -> dict:
	"""«Покрасил — сушится»: the time the coat went on."""
	facade_prices.ensure_editor()
	doc = mdf_orders._accepted(order)
	if doc.korkem_handed_over_on:
		frappe.throw("Заказ уже выдан.")
	if PAINT not in mdf_orders.stages_of(doc):
		frappe.throw("У этого заказа нет покраски.")
	if doc.get(mdf_orders.STAGES[PAINT]):
		frappe.throw("Покраска уже отмечена.")
	doc.db_set(DRYING, now_datetime(), update_modified=True)
	audit.record_audit(action="mdf.paint_drying", entity_type="Sales Order", entity_id=doc.name,
					   diff={"drying": True})
	return board()


def stop_drying(order: str) -> dict:
	"""Put to dry by mistake — back to waiting."""
	facade_prices.ensure_editor()
	doc = mdf_orders._accepted(order)
	doc.db_set(DRYING, None, update_modified=True)
	audit.record_audit(action="mdf.paint_drying", entity_type="Sales Order", entity_id=doc.name,
					   diff={"drying": False})
	return board()
