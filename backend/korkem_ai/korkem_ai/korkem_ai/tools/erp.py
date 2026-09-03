# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Sales, manufacturing and stock — the tools a production question needs.

## Reusing ERPNext instead of recomputing it

Two things here would be easy to write badly and are simply read instead:

* **BOM explosion.** ERPNext maintains `BOM Explosion Item` — the full
  multi-level expansion of a BOM, kept in step with it. Walking `BOM Item`
  recursively would duplicate that and drift from it the first time somebody
  nests an assembly.
* **Availability.** `Bin.projected_qty` is stock *minus what production has
  already reserved, plus what is on order*. It is the number that answers "can
  we start", and it is why the readiness tool does not do arithmetic on
  `actual_qty` and get a confidently wrong answer for an order that is already
  half committed to another job.

## Reads only

Everything in this module is `Risk.READ`. Production writes — creating a work
order, raising a material request — are a separate decision with a separate
blast radius, and they belong behind the confirmation flow rather than beside a
search.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register
from korkem_ai.korkem_ai.tools import paging, scope
from korkem_ai.korkem_ai.tools.scope import ensure_company, scoped

MAX_LIMIT = 50


def _limit(value: int | None) -> int:
	return min(int(value or 20), MAX_LIMIT)


# --------------------------------------------------------------------------
# Sales
# --------------------------------------------------------------------------


def search_sales_orders(
	customer: str | None = None,
	status: str | None = None,
	limit: int | None = None,
):
	filters = {"docstatus": 1}
	# A customer searching their orders searches only their own. The `like` a
	# staff user gets is a convenience; for a customer it would be a way to
	# fish, so the pinned name is matched exactly.
	pinned = scope.customer_scope()
	if pinned:
		filters["customer"] = pinned
	elif customer:
		filters["customer"] = ["like", f"%{customer}%"]
	if status:
		filters["status"] = status

	rows = frappe.get_list(
		"Sales Order",
		filters=scoped(filters),
		fields=[
			"name",
			"customer",
			"transaction_date",
			"delivery_date",
			"status",
			"grand_total",
			"currency",
			"per_delivered",
		],
		limit=_limit(limit),
		order_by="transaction_date desc",
	)
	return {"sales_orders": rows, **paging.page(rows, "Sales Order", scoped(filters))}


#: Sales Order statuses that are no longer live work.
#:
#: One definition, imported by everything that asks "what is active". The
#: production overview and the factory shortage must agree on which orders
#: exist, or the same floor produces two different answers.
CLOSED_STATUSES = ("Completed", "Closed", "Cancelled")


def active_sales_orders(limit: int | None = None) -> list[dict]:
	"""Submitted orders that still represent work.

	`get_list`, not `get_all`: this applies the permission query conditions, so
	a user restricted to one company sees one company's orders.
	"""
	return frappe.get_list(
		"Sales Order",
		filters={"docstatus": 1, "status": ["not in", CLOSED_STATUSES]},
		fields=["name", "customer", "status", "delivery_date", "company", "per_delivered"],
		order_by="delivery_date asc",
		limit_page_length=limit or 0,
	)


#: Sales Order statuses that are no longer live work.
#:
#: One definition, imported by everything that asks "what is active". The
#: production overview and the factory shortage must agree on which orders
#: exist, or the same floor produces two different answers.
CLOSED_STATUSES = ("Completed", "Closed", "Cancelled")


def active_sales_orders(limit: int | None = None) -> list[dict]:
	"""Submitted orders that still represent work, for this company only."""
	return frappe.get_list(
		"Sales Order",
		filters=scoped({"docstatus": 1, "status": ["not in", CLOSED_STATUSES]}),
		fields=["name", "customer", "status", "delivery_date", "company", "per_delivered"],
		order_by="delivery_date asc",
		limit_page_length=limit or 0,
	)


def get_sales_order(name: str):
	"""One order and what it is for.

	Draft orders are included deliberately — "why has this not started?" is a
	real question, and the answer is sometimes "nobody submitted it".
	"""
	if not frappe.has_permission("Sales Order", "read") or not frappe.db.exists(
		"Sales Order", name
	):
		frappe.throw(f"Sales Order '{name}' was not found.")

	ensure_company("Sales Order", name)
	order = frappe.get_doc("Sales Order", name)
	return {
		"name": order.name,
		"customer": order.customer,
		"status": order.status,
		"submitted": order.docstatus == 1,
		"transaction_date": str(order.transaction_date),
		"delivery_date": str(order.delivery_date) if order.delivery_date else None,
		"currency": order.currency,
		"grand_total": order.grand_total,
		"per_delivered": order.per_delivered,
		"items": [
			{
				"item_code": row.item_code,
				"item_name": row.item_name,
				"qty": row.qty,
				"uom": row.uom,
				"delivery_date": str(row.delivery_date) if row.delivery_date else None,
				"warehouse": row.warehouse,
			}
			for row in order.items
		],
	}


# --------------------------------------------------------------------------
# Manufacturing
# --------------------------------------------------------------------------


def get_bom_materials(item_code: str, qty: float | None = None):
	"""What building `qty` of something actually consumes.

	Reads the *exploded* bill, so a cabinet made of a sub-assembly reports the
	board and the hinges rather than the sub-assembly.
	"""
	bom = frappe.db.get_value(
		"BOM",
		{"item": item_code, "is_active": 1, "is_default": 1, "docstatus": 1},
		["name", "quantity"],
		as_dict=True,
	) or frappe.db.get_value(
		"BOM",
		{"item": item_code, "is_active": 1, "docstatus": 1},
		["name", "quantity"],
		as_dict=True,
	)
	if not bom:
		return {"item_code": item_code, "bom": None, "materials": []}

	wanted = float(qty or bom.quantity or 1)
	# A BOM may be written for a batch — "per 10 cabinets" — so the ratio, not
	# the raw quantity, is what scales.
	factor = wanted / float(bom.quantity or 1)

	rows = frappe.get_all(
		"BOM Explosion Item",
		filters={"parent": bom.name},
		fields=["item_code", "item_name", "stock_qty", "stock_uom"],
	)
	return {
		"item_code": item_code,
		"bom": bom.name,
		"for_qty": wanted,
		"materials": [
			{
				"item_code": row["item_code"],
				"item_name": row["item_name"],
				"required_qty": round(row["stock_qty"] * factor, 3),
				"uom": row["stock_uom"],
			}
			for row in rows
		],
	}


def search_work_orders(
	sales_order: str | None = None,
	item_code: str | None = None,
	status: str | None = None,
	limit: int | None = None,
):
	filters = {}
	if sales_order:
		filters["sales_order"] = sales_order
	if item_code:
		filters["production_item"] = item_code
	if status:
		filters["status"] = status

	rows = frappe.get_list(
		"Work Order",
		filters=scoped(filters),
		fields=[
			"name",
			"production_item",
			"bom_no",
			"qty",
			"produced_qty",
			"status",
			"sales_order",
			"planned_start_date",
		],
		limit=_limit(limit),
		order_by="modified desc",
	)
	for row in rows:
		row["remaining_qty"] = round((row["qty"] or 0) - (row["produced_qty"] or 0), 3)
	return {"work_orders": rows, **paging.page(rows, "Work Order", scoped(filters))}


# --------------------------------------------------------------------------
# Stock
# --------------------------------------------------------------------------


def get_stock(item_codes: list | None = None, warehouse: str | None = None):
	"""On hand, reserved, and what is actually free.

	`projected_qty` is the one that matters: stock already committed to another
	work order is not available for this one, and `actual_qty` alone would say
	it is.
	"""
	filters = {}
	if item_codes:
		filters["item_code"] = ["in", list(item_codes)]
	if warehouse:
		filters["warehouse"] = warehouse

	rows = frappe.get_list(
		"Bin",
		filters=scoped(filters),
		fields=[
			"item_code",
			"warehouse",
			"actual_qty",
			"reserved_qty",
			"ordered_qty",
			"projected_qty",
			"stock_uom",
		],
		limit=MAX_LIMIT,
	)
	return {"stock": rows, **paging.page(rows, "Bin", scoped(filters))}


# --------------------------------------------------------------------------
# Analytics
# --------------------------------------------------------------------------


# `production_readiness` has been removed.
#
# It keyed stock by item across every warehouse, so the moment production put
# material into work-in-progress the WIP row — quantity zero — overwrote the
# store's, and it reported everything as missing. That stayed invisible for as
# long as nothing ever moved to WIP, which is to say until production actually
# ran.
#
# Its question is answered by `manufacturing.production_control(sales_order=…)`,
# whose numbers come from ERPNext's own planning engine and are warehouse-aware.


# --------------------------------------------------------------------------
# Registration
# --------------------------------------------------------------------------

register(
	ToolSpec(
		name="sales.search_sales_orders",
		description=(
			"Find submitted sales orders, optionally by customer name or status "
			"(To Deliver and Bill, To Deliver, To Bill, Completed, Closed)."
		),
		input_schema={
			"type": "object",
			"properties": {
				"customer": {"type": "string"},
				"status": {"type": "string"},
				"limit": {"type": "integer"},
			},
		},
		risk=Risk.READ,
		handler=search_sales_orders,
		doctypes=("Sales Order",),
		audit_category="sales",
	)
)

register(
	ToolSpec(
		name="sales.get_sales_order",
		description="One sales order with the items on it, by id, e.g. SAL-ORD-2026-00001.",
		input_schema={
			"type": "object",
			"properties": {"name": {"type": "string"}},
			"required": ["name"],
		},
		risk=Risk.READ,
		handler=get_sales_order,
		doctypes=("Sales Order",),
		audit_category="sales",
	)
)

register(
	ToolSpec(
		name="manufacturing.get_bom_materials",
		description=(
			"The raw materials needed to build a quantity of an item, from its "
			"active BOM, fully exploded through sub-assemblies."
		),
		input_schema={
			"type": "object",
			"properties": {
				"item_code": {"type": "string"},
				"qty": {"type": "number", "description": "How many to build."},
			},
			"required": ["item_code"],
		},
		risk=Risk.READ,
		handler=get_bom_materials,
		doctypes=("BOM",),
		audit_category="manufacturing",
	)
)

register(
	ToolSpec(
		name="manufacturing.search_work_orders",
		description=(
			"Work orders on the shop floor, optionally for a sales order, an item "
			"or a status (Not Started, In Process, Completed, Stopped)."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {"type": "string"},
				"item_code": {"type": "string"},
				"status": {"type": "string"},
				"limit": {"type": "integer"},
			},
		},
		risk=Risk.READ,
		handler=search_work_orders,
		doctypes=("Work Order",),
		audit_category="manufacturing",
	)
)

register(
	ToolSpec(
		name="inventory.get_stock",
		description=(
			"Stock for items: on hand, reserved for production, on order, and "
			"projected. Use projected_qty to judge what is actually free."
		),
		input_schema={
			"type": "object",
			"properties": {
				"item_codes": {"type": "array", "items": {"type": "string"}},
				"warehouse": {"type": "string"},
			},
		},
		risk=Risk.READ,
		handler=get_stock,
		doctypes=("Bin",),
		audit_category="inventory",
	)
)
