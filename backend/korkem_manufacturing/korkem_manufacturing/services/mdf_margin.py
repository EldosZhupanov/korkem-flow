# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Маржа по заказу МДФ — what an order earned (owner, 14.11.2026: «дашборд
цеха → маржа по заказу»).

    margin = the order's total − (material + work)

**Material.** What was written off for the order — ERPNext's own Material
Issue, at its own valuation: what the shelf really cost. An order nothing was
written off for yet is *estimated*: its need (`facade_materials.need`) at
each material's current valuation, MDF pro rata by area rather than in whole
sheets — a small order does not cost a whole sheet, the rest of it goes to the
next one. An estimate is marked as one; a material with no price at all is
named in `missing`, and counted as nothing.

**Work.** Piece work booked to the order (`piece_work`), reversals included,
so a cancelled accrual nets to nothing.

**Not counted**, and the screen says so: paint, glue, power, delivery —
nobody records them per order. The margin is therefore an upper bound.

A rework or a warranty job has no price: its «margin» is what the mistake
cost, which is the point of showing it.

Margins are the owner's and sales' reading, never the floor's: the money
switch that shows a floor worker a client's price does not open this.
"""

from __future__ import annotations

from collections import defaultdict

import frappe
from frappe.utils import flt, getdate

from korkem_manufacturing.services import facade_materials, facade_prices, mdf_orders
from korkem_manufacturing.services.scope import ensure_company

#: Lowest-margin orders the summary names.
LOWEST = 5
#: A finished order's cost hardly moves; the summary keeps it this long.
CACHE_SECONDS = 6 * 3600
_CACHE = "korkem_mdf_margin"


def of_order(order: str) -> dict:
	"""The order's margin, with what it is made of."""
	facade_prices.ensure_editor()
	ensure_company("Sales Order", order)
	doc = mdf_orders._order(order)
	return _margin(doc.name, flt(doc.grand_total))


def _margin(order: str, revenue: float) -> dict:
	rows, estimate, missing = _written_off(order)
	if not rows:
		rows, missing = _estimated(order)
		estimate = bool(rows)
	material = round(sum(r["cost"] for r in rows), 2)
	work = _work([order]).get(order, 0.0)
	cost = round(material + work, 2)
	margin = round(revenue - cost, 2)
	return {
		"order": order,
		"revenue": round(revenue, 2),
		"material": material,
		"material_rows": rows,
		"estimate": estimate,
		"missing": missing,
		"work": work,
		"cost": cost,
		"margin": margin,
		"share": round(margin / revenue, 3) if revenue > 0 else None,
	}


# --------------------------------------------------------------------------
# Material
# --------------------------------------------------------------------------


def _written_off(order: str) -> tuple[list[dict], bool, list[str]]:
	lines = frappe.db.sql(
		"""select d.item_code, d.item_name, d.stock_uom as uom, d.transfer_qty as qty, d.valuation_rate as price, d.amount
		from `tabStock Entry Detail` d join `tabStock Entry` e on e.name = d.parent
		where e.korkem_sales_order = %s and e.docstatus = 1 and e.purpose = 'Material Issue'""",
		order,
		as_dict=True,
	)
	rows: dict[str, dict] = {}
	for line in lines:
		row = rows.setdefault(line.item_code, {"item": line.item_code, "title": line.item_name, "unit": line.uom,
											   "qty": 0.0, "price": flt(line.price), "cost": 0.0})
		row["qty"] = round(row["qty"] + flt(line.qty), 3)
		row["cost"] = round(row["cost"] + flt(line.amount), 2)
	return list(rows.values()), False, []


def _estimated(order: str) -> tuple[list[dict], list[str]]:
	need = facade_materials.need(order)
	rules = need["norms"]
	sheet_m2 = flt(rules["sheet_length_mm"]) * flt(rules["sheet_width_mm"]) / 1_000_000
	rows, missing = [], []
	for m in need["materials"]:
		if not m["item"] or m["needed"] is None:
			continue
		unit = (m["unit"] or "").strip().lower()
		qty = m["area_m2"] / sheet_m2 if unit in facade_materials.SHEET_UNITS and sheet_m2 else m["needed"]
		price = unit_cost(m["item"])
		if price is None:
			missing.append(m["title"] or m["item"])
		rows.append({"item": m["item"], "title": m["title"], "unit": m["unit"], "qty": round(flt(qty), 3),
					 "price": price, "cost": round(flt(qty) * flt(price), 2)})
	return rows, missing


def unit_cost(item: str) -> float | None:
	"""What one unit of the material costs now: the stock's average valuation,
	else the last movement's. None when it was never valued."""
	held = frappe.db.sql(
		"""select sum(actual_qty * valuation_rate), sum(actual_qty) from `tabBin`
		where item_code = %s and actual_qty > 0""",
		item,
	)
	value, qty = held[0] if held else (None, None)
	if flt(qty) > 0 and flt(value) > 0:
		return round(flt(value) / flt(qty), 4)
	last = frappe.db.get_value(
		"Stock Ledger Entry",
		{"item_code": item, "is_cancelled": 0, "valuation_rate": [">", 0]},
		"valuation_rate",
		order_by="posting_date desc, posting_time desc, creation desc",
	)
	return round(flt(last), 4) if last else None


# --------------------------------------------------------------------------
# Work
# --------------------------------------------------------------------------


def _work(orders: list[str]) -> dict[str, float]:
	if not orders:
		return {}
	rows = frappe.db.sql(
		"""select sales_order, sum(amount) from `tabPiece Work Entry`
		where sales_order in %(orders)s group by sales_order""",
		{"orders": tuple(orders)},
	)
	return {order: round(flt(amount), 2) for order, amount in rows}


# --------------------------------------------------------------------------
# The period, for «Итоги МДФ»
# --------------------------------------------------------------------------


def period(rows: list, start, end) -> dict:
	"""Orders handed over in the period: what they brought, what they cost,
	and the five that earned least."""
	done = [r for r in rows if r.get("korkem_handed_over_on")
			and start <= getdate(r.korkem_handed_over_on) <= end]
	cache = frappe.cache()
	margins = []
	for r in done:
		key = f"{_CACHE}:{r.name}:{r.get('modified')}:{flt(r.grand_total)}"
		m = cache.get_value(key)
		if m is None:
			m = _margin(r.name, flt(r.grand_total))
			cache.set_value(key, m, expires_in_sec=CACHE_SECONDS)
		margins.append((r, m))
	revenue = round(sum(m["revenue"] for _, m in margins), 2)
	cost = round(sum(m["cost"] for _, m in margins), 2)
	by_kind: dict[str, float] = defaultdict(float)
	for _, m in margins:
		by_kind["material"] += m["material"]
		by_kind["work"] += m["work"]
	lowest = sorted(margins, key=lambda rm: (rm[1]["share"] if rm[1]["share"] is not None else -1, rm[1]["margin"]))
	return {
		"orders": len(margins),
		"revenue": revenue,
		"material": round(by_kind["material"], 2),
		"work": round(by_kind["work"], 2),
		"cost": cost,
		"margin": round(revenue - cost, 2),
		"share": round((revenue - cost) / revenue, 3) if revenue > 0 else None,
		"estimated": sum(1 for _, m in margins if m["estimate"]),
		"missing": sum(1 for _, m in margins if m["missing"]),
		"lowest": [
			{"name": r.name, "customer_name": r.customer_name, "revenue": m["revenue"], "margin": m["margin"],
			 "share": m["share"]}
			for r, m in lowest[:LOWEST]
		],
	}
