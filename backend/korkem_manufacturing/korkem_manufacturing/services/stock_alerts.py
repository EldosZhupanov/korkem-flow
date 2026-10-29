# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Мало листов»: tell the owner before the shop stands waiting for MDF.

The owner's words (29.10.2026): «когда заканчивается мдф система должна
предупреждать… чтобы мы не делали ожидание мдф листов в цеху».

**A minimum per material** (`Item.korkem_min_stock`), set by whoever keeps the
warehouse: «МДФ 16 мм — 10 листов», «Плёнка Графит — 30 м». Zero means no
warning for that material.

**What is compared is what is free**, not what is on the shelf: fifteen
sheets of which twelve are promised to orders in the queue are three sheets,
and three is what the next order will find. Free is the store's own figure
(`material_stock`: ERPNext's quantity on hand minus active reservations).

**When.** Hourly, from the scheduler, and at once after anything that takes
material away — a facade order's reservation or its write-off — so the
warning arrives when the sheets go, not up to an hour later.

**Said once a day per material.** The event carries the date, and delivery is
idempotent on it (`Notification Delivery.event_key`): an hourly run does not
repeat a morning's warning, and the next morning, if nothing was bought, it is
said again.

The domain only emits `stock.low`; korkem_ai decides who hears it and how
(domain_events, ADR-0003).
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, nowdate

from korkem_manufacturing import domain_events
from korkem_manufacturing.services import material_stock

LOW = "stock.low"
FIELD = "korkem_min_stock"


def low(company: str, items: list[str] | None = None) -> list[dict]:
	"""Materials of this company whose free quantity is below their minimum."""
	filters = {"korkem_material_company": company, "disabled": 0, FIELD: [">", 0]}
	if items:
		filters["name"] = ["in", items]
	rows = frappe.get_all(
		"Item", filters=filters, fields=["name", "item_name", "stock_uom", FIELD], limit_page_length=1000
	)
	if not rows:
		return []
	names = [r.name for r in rows]
	stock = material_stock._stock(names, company)
	held = material_stock._reserved(names, company)
	result = []
	for r in rows:
		on_hand = stock.get(r.name, (0.0, 0.0))[0]
		reserved = held.get(r.name, 0.0)
		free = round(on_hand - reserved, 3)
		minimum = flt(r.get(FIELD))
		if free < minimum:
			result.append(
				{
					"item": r.name,
					"title": r.item_name,
					"unit": r.stock_uom,
					"on_hand": on_hand,
					"reserved": reserved,
					"free": free,
					"minimum": minimum,
				}
			)
	return result


def check(company: str, items: list[str] | None = None) -> int:
	"""Emit one `stock.low` per material below its minimum. Never raises."""
	try:
		rows = low(company, items)
	except Exception:
		frappe.log_error(title="stock_alerts.check", message=frappe.get_traceback(with_context=True))
		return 0
	day = nowdate()
	for row in rows:
		domain_events.emit(LOW, company=company, day=day, **row)
	return len(rows)


def run() -> dict:
	"""Hourly: every company that keeps materials."""
	companies = frappe.get_all(
		"Item",
		filters={FIELD: [">", 0], "disabled": 0},
		pluck="korkem_material_company",
		distinct=True,
	)
	return {company: check(company) for company in companies if company}
