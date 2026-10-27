# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The shop floor's list of facades to make, and where each one stands.

Read from the order lines `facade_order` writes: size, area, milling, finish
and options, as fields. **No money** — not even redacted: the list is built
from a fixed set of fields that has no price in it, so it cannot leak one
whatever the price switch says.

Status lives on the order line (`korkem_facade_status`). Moving a facade is a
production report, so it is allowed to the same roles that book a stage
(`MAY_REPORT`) and is audited like one.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt

from korkem_manufacturing.services import audit
from korkem_manufacturing.services.scope import ensure_company, scoped

QUEUED, IN_WORK, DONE = "В очереди", "В работе", "Готово"
STATUSES = (QUEUED, IN_WORK, DONE)
MAY_REPORT = frozenset({"Manufacturing Manager", "Manufacturing User", "System Manager"})
OPEN_ORDER = {"docstatus": 1, "status": ["not in", ["Closed", "Completed", "Cancelled", "On Hold"]]}
LINE_FIELDS = (
	"name", "parent", "idx", "qty", "korkem_width_mm", "korkem_height_mm", "korkem_area_m2",
	"korkem_milling", "korkem_finish", "korkem_double_sided", "korkem_customer_material",
	"korkem_facade_status", "korkem_thickness_mm", "korkem_decor_top", "korkem_decor_bottom",
	"korkem_edge_profile", "korkem_color_group",
)
MAX_LIMIT = 200


def jobs(status: str | None = None, limit: int = 100) -> dict:
	"""Facade lines of this company's open orders, soonest due first."""
	if status and status not in STATUSES:
		frappe.throw(f"Статус должен быть одним из: {', '.join(STATUSES)}.")
	limit = max(1, min(int(limit or 100), MAX_LIMIT))

	# Permission-aware and company-scoped: who may read which order is
	# decided once, by Frappe, here.
	orders = {
		row["name"]: row
		for row in frappe.get_list(
			"Sales Order",
			filters=scoped(dict(OPEN_ORDER)),
			fields=["name", "customer", "delivery_date", "korkem_urgent"],
			limit_page_length=0,
		)
	}
	if not orders:
		return {"jobs": [], "total": 0}

	filters = {
		"parent": ["in", list(orders)],
		"parenttype": "Sales Order",
		"korkem_width_mm": [">", 0],
	}
	if status:
		filters["korkem_facade_status"] = status
	# get_all, with the parent set already restricted above: the fields read
	# are a fixed, money-free list, so nothing here depends on field levels.
	lines = frappe.get_all("Sales Order Item", filters=filters, fields=list(LINE_FIELDS), limit_page_length=0)
	# Urgent orders head the queue (KORKEM brief, «Срочный заказ»); within
	# each group, soonest due first.
	lines.sort(
		key=lambda r: (
			not orders[r["parent"]].get("korkem_urgent"),
			str(orders[r["parent"]].get("delivery_date") or "9999"),
			r["parent"],
			r["idx"],
		)
	)
	return {
		"jobs": [_job(line, orders[line["parent"]]) for line in lines[:limit]],
		"total": len(lines),
	}


def set_status(line: str, status: str) -> dict:
	"""Move one facade line along: queued → in work → done (or back)."""
	if not MAY_REPORT.intersection(frappe.get_roles()):
		frappe.throw("Статус фасада меняет производство.", frappe.PermissionError)
	if status not in STATUSES:
		frappe.throw(f"Статус должен быть одним из: {', '.join(STATUSES)}.")

	row = frappe.db.get_value(
		"Sales Order Item", {"name": line, "parenttype": "Sales Order"}, ["parent", "korkem_width_mm", "korkem_facade_status"], as_dict=True
	)
	if not row or not row.korkem_width_mm:
		frappe.throw("Такого фасада нет.", frappe.DoesNotExistError)
	# Another company's order reads exactly like a missing one.
	ensure_company("Sales Order", row.parent)
	if frappe.db.get_value("Sales Order", row.parent, "docstatus") != 1:
		frappe.throw("Заказ ещё не подтверждён или отменён.")

	before = row.korkem_facade_status or QUEUED
	if before != status:
		frappe.db.set_value("Sales Order Item", line, "korkem_facade_status", status)
		# Pay follows the facade: finished pays, taken back from finished
		# reverses the unpaid accrual. See services/piece_rates.py.
		from korkem_manufacturing.services import piece_rates

		if status == DONE:
			piece_rates.accrue_facade(line, row.parent)
		elif before == DONE:
			piece_rates.withdraw_facade(line)
		audit.record_audit(
			action="manufacturing.facade_status",
			entity_type="Sales Order",
			entity_id=row.parent,
			diff={"line": line, "before": before, "after": status},
		)
	return {"line": line, "sales_order": row.parent, "status": status, "changed": before != status}


def _job(line: dict, order: dict) -> dict:
	return {
		"line": line["name"],
		"sales_order": line["parent"],
		"customer": order.get("customer"),
		"due_on": str(order["delivery_date"]) if order.get("delivery_date") else None,
		"urgent": bool(order.get("korkem_urgent")),
		"width_mm": line["korkem_width_mm"],
		"height_mm": line["korkem_height_mm"],
		"qty": int(flt(line["qty"])),
		"area_m2": flt(line["korkem_area_m2"]),
		"milling": line["korkem_milling"],
		"finish": line["korkem_finish"],
		"double_sided": bool(line["korkem_double_sided"]),
		"customer_material": bool(line["korkem_customer_material"]),
		"status": line["korkem_facade_status"] or QUEUED,
		"thickness_mm": line["korkem_thickness_mm"] or None,
		"decor_top": line["korkem_decor_top"],
		"decor_bottom": line["korkem_decor_bottom"],
		"edge_profile": line["korkem_edge_profile"],
		"color_group": line["korkem_color_group"],
	}
