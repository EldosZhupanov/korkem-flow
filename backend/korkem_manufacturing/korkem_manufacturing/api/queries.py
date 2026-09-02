# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Permission-aware, company-scoped reads for KORKEM clients."""

from __future__ import annotations

import frappe
from frappe.utils import flt

from korkem_manufacturing.services.scope import scoped

SALES_ORDER_FIELDS = (
	"name",
	"customer",
	"status",
	"transaction_date",
	"delivery_date",
	"grand_total",
	"per_delivered",
)
WORK_ORDER_FIELDS = (
	"name",
	"production_item",
	"item_name",
	"qty",
	"produced_qty",
	"status",
	"planned_end_date",
	"actual_end_date",
	"sales_order",
	"bom_no",
)
WORK_ORDER_OPERATION_FIELDS = (
	"name",
	"operation",
	"workstation",
	"status",
	"completed_qty",
	"process_loss_qty",
	"time_in_mins",
	"sequence_id",
)
BIN_FIELDS = (
	"item_code",
	"warehouse",
	"actual_qty",
	"reserved_qty",
	"projected_qty",
	"stock_uom",
)
DELIVERY_NOTE_FIELDS = (
	"name",
	"posting_date",
	"status",
	"grand_total",
)
DELIVERY_NOTE_ITEM_FIELDS = (
	"parent",
	"item_code",
	"item_name",
	"qty",
	"uom",
)
PURCHASE_ORDER_FIELDS = (
	"name",
	"supplier",
	"transaction_date",
	"schedule_date",
	"status",
	"per_received",
	"grand_total",
)
MATERIAL_REQUEST_FIELDS = (
	"name",
	"transaction_date",
	"schedule_date",
	"status",
	"per_ordered",
)
MAX_LIMIT = 100


@frappe.whitelist()
def sales_orders(
	status: str | None = None,
	search: str | None = None,
	limit: int = 20,
	offset: int = 0,
) -> dict:
	"""Return the session company's sales orders visible to the caller.

	Readiness is deliberately absent. Computing it through
	``material_shortage`` for every row would load each order's work orders,
	materials and Production Plan requirements, turning one list request into a
	heavy N+1 query. The start mutation remains the authoritative readiness
	check.
	"""
	limit = min(_page_integer(limit, "limit"), MAX_LIMIT)
	offset = _page_integer(offset, "offset")
	status = _text(status, "status")
	search = _text(search, "search")

	filters = scoped()
	if status:
		filters["status"] = status

	query = {
		"filters": filters,
		"fields": list(SALES_ORDER_FIELDS),
		"order_by": "transaction_date desc, name desc",
		"limit_start": offset,
		"limit_page_length": limit,
	}
	if search:
		pattern = f"%{search}%"
		query["or_filters"] = [
			["Sales Order", "name", "like", pattern],
			["Sales Order", "customer", "like", pattern],
		]

	orders = frappe.get_list("Sales Order", **query)

	return {
		"orders": orders,
		"total": _total("Sales Order", filters, query.get("or_filters")),
		"limit": limit,
		"offset": offset,
	}


@frappe.whitelist()
def work_orders(
	status: str | None = None,
	search: str | None = None,
	limit: int = 20,
	offset: int = 0,
) -> dict:
	"""Return permission-visible work orders from the session's company."""
	limit = min(_page_integer(limit, "limit"), MAX_LIMIT)
	offset = _page_integer(offset, "offset")
	status = _text(status, "status")
	search = _text(search, "search")

	filters = scoped()
	if status:
		filters["status"] = status

	or_filters = None
	if search:
		pattern = f"%{search}%"
		or_filters = [
			["Work Order", "name", "like", pattern],
			["Work Order", "production_item", "like", pattern],
			["Work Order", "item_name", "like", pattern],
			["Work Order", "sales_order", "like", pattern],
		]

	rows = frappe.get_list(
		"Work Order",
		filters=filters,
		or_filters=or_filters,
		fields=list(WORK_ORDER_FIELDS),
		order_by="planned_end_date asc, name asc",
		limit_start=offset,
		limit_page_length=limit,
	)
	return {
		"orders": [_work_order(row) for row in rows],
		"total": _total("Work Order", filters, or_filters),
		"limit": limit,
		"offset": offset,
	}


@frappe.whitelist()
def operations(work_order: str, limit: int = 20, offset: int = 0) -> dict:
	"""Return one visible work order's operations in routing order.

	``Work Order Operation`` is a child table and has no company field of its
	own. Scope therefore belongs on the permission-aware parent lookup; only a
	parent visible in the session company may unlock its children.
	"""
	limit = min(_page_integer(limit, "limit"), MAX_LIMIT)
	offset = _page_integer(offset, "offset")
	work_order = _text(work_order, "work_order")
	if not work_order:
		frappe.throw("work_order must be text.")

	visible = frappe.get_list(
		"Work Order",
		filters=scoped({"name": work_order}),
		pluck="name",
		limit_start=0,
		limit_page_length=1,
	)
	if not visible:
		return {"operations": [], "total": 0, "limit": limit, "offset": offset}

	filters = {"parent": work_order, "parenttype": "Work Order"}
	rows = frappe.get_list(
		"Work Order Operation",
		filters=filters,
		fields=list(WORK_ORDER_OPERATION_FIELDS),
		order_by="sequence_id asc, idx asc",
		limit_start=offset,
		limit_page_length=limit,
	)
	return {
		"operations": [_operation(row) for row in rows],
		"total": _total("Work Order Operation", filters),
		"limit": limit,
		"offset": offset,
	}


@frappe.whitelist()
def stock(
	warehouse: str | None = None,
	search: str | None = None,
	limit: int = 50,
	offset: int = 0,
) -> dict:
	"""Return bins in warehouses belonging to the session's company."""
	limit = min(_page_integer(limit, "limit"), MAX_LIMIT)
	offset = _page_integer(offset, "offset")
	warehouse = _text(warehouse, "warehouse")
	search = _text(search, "search")

	warehouse_filters = scoped({"is_group": 0})
	if warehouse:
		warehouse_filters["name"] = warehouse
	warehouses = frappe.get_list(
		"Warehouse",
		filters=warehouse_filters,
		pluck="name",
		limit_page_length=0,
	)
	if not warehouses:
		return {"items": [], "total": 0, "limit": limit, "offset": offset}

	filters = {"warehouse": ["in", warehouses]}
	item_rows = None
	if search:
		pattern = f"%{search}%"
		item_rows = frappe.get_list(
			"Item",
			or_filters=[
				["Item", "name", "like", pattern],
				["Item", "item_name", "like", pattern],
			],
			fields=["name", "item_name"],
			limit_page_length=0,
		)
		item_codes = [row["name"] for row in item_rows]
		if not item_codes:
			return {"items": [], "total": 0, "limit": limit, "offset": offset}
		filters["item_code"] = ["in", item_codes]

	rows = frappe.get_list(
		"Bin",
		filters=filters,
		fields=list(BIN_FIELDS),
		order_by="item_code asc, warehouse asc",
		limit_start=offset,
		limit_page_length=limit,
	)
	if item_rows is None and rows:
		item_rows = frappe.get_list(
			"Item",
			filters={"name": ["in", [row["item_code"] for row in rows]]},
			fields=["name", "item_name"],
			limit_page_length=0,
		)
	item_names = {row["name"]: row.get("item_name") or None for row in item_rows or []}

	return {
		"items": [_stock_item(row, item_names) for row in rows],
		"total": _total("Bin", filters),
		"limit": limit,
		"offset": offset,
	}


@frappe.whitelist()
def deliveries(sales_order: str, limit: int = 20, offset: int = 0) -> dict:
	"""Return submitted, permission-visible deliveries for one sales order."""
	limit = min(_page_integer(limit, "limit"), MAX_LIMIT)
	offset = _page_integer(offset, "offset")
	sales_order = _text(sales_order, "sales_order")
	if not sales_order:
		frappe.throw("sales_order must be text.")

	# ERPNext records the Sales Order link on Delivery Note Item, not reliably
	# on the delivery header. This is one set query, not a per-delivery lookup.
	delivery_names = frappe.get_list(
		"Delivery Note Item",
		filters={"against_sales_order": sales_order, "parenttype": "Delivery Note"},
		# `parent` is not decoration. Frappe permission-checks a child table
		# through its parent doctype, and without this it has nothing to check
		# against — so the query comes back **empty instead of refused**, which
		# reads as "this order has no deliveries" for an order that has one.
		parent_doctype="Delivery Note",
		pluck="parent",
		limit_page_length=0,
	)
	if not delivery_names:
		return {"deliveries": [], "total": 0, "limit": limit, "offset": offset}

	filters = scoped({"docstatus": 1, "name": ["in", delivery_names]})
	rows = frappe.get_list(
		"Delivery Note",
		filters=filters,
		fields=list(DELIVERY_NOTE_FIELDS),
		order_by="posting_date desc, name desc",
		limit_start=offset,
		limit_page_length=limit,
	)
	items = frappe.get_list(
		"Delivery Note Item",
		filters={"parent": ["in", [row["name"] for row in rows]], "parenttype": "Delivery Note"},
		parent_doctype="Delivery Note",
		fields=list(DELIVERY_NOTE_ITEM_FIELDS),
		order_by="parent asc, idx asc",
		limit_page_length=0,
	) if rows else []
	items_by_delivery: dict[str, list[dict]] = {}
	for item in items:
		items_by_delivery.setdefault(item["parent"], []).append(_delivery_item(item))

	return {
		"deliveries": [_delivery(row, items_by_delivery.get(row["name"], [])) for row in rows],
		"total": _total("Delivery Note", filters),
		"limit": limit,
		"offset": offset,
	}


def _total(doctype: str, filters: dict, or_filters: list | None = None) -> int:
	"""How many rows the caller could page through, counted their way.

	Both branches go through a permission-aware path. `frappe.db.count` would
	not, and a total that includes rows the caller cannot open is worse than no
	total at all.

	Two branches because `frappe.client.get_count` has no `or_filters`, and a
	search that counted without its own filter would say "3 of 143" — a number
	that is wrong in the one place a person is most likely to read it. When a
	search is on, the count comes from the same list query with the page
	removed, which is bounded by what actually matched.
	"""
	# Deliberately not `frappe.client.get_count`. That helper stuffs its
	# arguments into `frappe.form_dict` and then calls a desk view that reads
	# the *whole* form_dict back — so when it is called from inside a
	# whitelisted endpoint, the endpoint's own HTTP arguments come along. A
	# request to `station_queue?workstation=Edge 1` reached the database layer
	# as an unexpected `workstation` keyword and raised TypeError. Nothing in a
	# unit test with a mocked client can see this: it needs a real request.
	return len(
		frappe.get_list(
			doctype,
			filters=filters,
			or_filters=or_filters or None,
			pluck="name",
			limit_page_length=0,
		)
	)


def _work_order(row) -> dict:
	return {
		"name": row["name"],
		"production_item": row.get("production_item") or None,
		"item_name": row.get("item_name") or None,
		"qty": flt(row.get("qty")),
		"produced_qty": flt(row.get("produced_qty")),
		"status": row["status"],
		"planned_end_date": _iso(row.get("planned_end_date")),
		"actual_end_date": _iso(row.get("actual_end_date")),
		"sales_order": row.get("sales_order") or None,
		"bom_no": row.get("bom_no") or None,
	}


def _operation(row) -> dict:
	return {
		"name": row["name"],
		"operation": row.get("operation") or None,
		"workstation": row.get("workstation") or None,
		"status": row.get("status") or None,
		"completed_qty": flt(row.get("completed_qty")),
		"scrap_qty": flt(row.get("process_loss_qty")),
		"planned_minutes": flt(row.get("time_in_mins")),
		"sequence": row.get("sequence_id"),
	}


def _stock_item(row, item_names: dict[str, str | None]) -> dict:
	return {
		"item_code": row["item_code"],
		"item_name": item_names.get(row["item_code"]),
		"warehouse": row["warehouse"],
		"actual_qty": flt(row.get("actual_qty")),
		"reserved_qty": flt(row.get("reserved_qty")),
		"projected_qty": flt(row.get("projected_qty")),
		"stock_uom": row.get("stock_uom") or None,
	}


def _delivery(row, items: list[dict]) -> dict:
	return {
		"name": row["name"],
		"posting_date": _iso(row.get("posting_date")),
		"status": row.get("status") or None,
		"grand_total": flt(row.get("grand_total")),
		"items": items,
	}


def _delivery_item(row) -> dict:
	return {
		"item_code": row.get("item_code") or None,
		"item_name": row.get("item_name") or None,
		"qty": flt(row.get("qty")),
		"uom": row.get("uom") or None,
	}


def _iso(value) -> str | None:
	if value in (None, ""):
		return None
	if hasattr(value, "isoformat"):
		return value.isoformat()
	return str(value)


def _page_integer(value, field: str) -> int:
	"""A non-negative page number, accepting the string shape HTTP sends."""
	if isinstance(value, int) and not isinstance(value, bool):
		number = value
	elif isinstance(value, str) and value.strip().isdecimal():
		number = int(value.strip())
	else:
		frappe.throw(f"{field} must be a non-negative integer.")
	if number < 0:
		frappe.throw(f"{field} must be a non-negative integer.")
	return number


def _text(value, field: str) -> str | None:
	if value is None:
		return None
	if not isinstance(value, str):
		frappe.throw(f"{field} must be text.")
	return value.strip() or None


@frappe.whitelist()
def receivable_purchase_orders(limit: int = 20, offset: int = 0) -> dict:
	"""Purchase orders a warehouse worker could still receive against.

	This exists so nobody has to type ``PUR-ORD-2026-00001`` from memory. A
	document id typed by hand is a receipt booked against the wrong order as
	soon as somebody transposes two digits, and the warehouse is the last place
	that mistake gets noticed.

	The filters mirror what ``services.purchasing.receive_purchase_order``
	refuses, so the list cannot offer a row the action would then reject:
	submitted, not Closed/Cancelled/On Hold, and not already fully received.
	"""
	limit = min(_page_integer(limit, "limit"), MAX_LIMIT)
	offset = _page_integer(offset, "offset")

	filters = scoped(
		{
			"docstatus": 1,
			"status": ["not in", ["Closed", "Cancelled", "On Hold"]],
			"per_received": ["<", 100],
		}
	)
	rows = frappe.get_list(
		"Purchase Order",
		filters=filters,
		fields=list(PURCHASE_ORDER_FIELDS),
		order_by="schedule_date asc, name asc",
		limit_start=offset,
		limit_page_length=limit,
	)
	return {
		"orders": [_purchase_order(row) for row in rows],
		"total": _total("Purchase Order", filters),
		"limit": limit,
		"offset": offset,
	}


@frappe.whitelist()
def orderable_material_requests(limit: int = 20, offset: int = 0) -> dict:
	"""Material requests a purchase order could still be raised against.

	Same reason as :func:`receivable_purchase_orders`, and the same rule: the
	filters mirror the refusals in ``services.purchasing.create_purchase_order``
	— submitted, of type Purchase, not Stopped/Cancelled, not fully ordered —
	so the list never offers work the action will decline.
	"""
	limit = min(_page_integer(limit, "limit"), MAX_LIMIT)
	offset = _page_integer(offset, "offset")

	filters = scoped(
		{
			"docstatus": 1,
			"material_request_type": "Purchase",
			"status": ["not in", ["Stopped", "Cancelled"]],
			"per_ordered": ["<", 100],
		}
	)
	rows = frappe.get_list(
		"Material Request",
		filters=filters,
		fields=list(MATERIAL_REQUEST_FIELDS),
		order_by="schedule_date asc, name asc",
		limit_start=offset,
		limit_page_length=limit,
	)
	return {
		"requests": [_material_request(row) for row in rows],
		"total": _total("Material Request", filters),
		"limit": limit,
		"offset": offset,
	}


def _purchase_order(row) -> dict:
	return {
		"name": row["name"],
		"supplier": row.get("supplier") or None,
		"ordered_on": _iso(row.get("transaction_date")),
		"expected_on": _iso(row.get("schedule_date")),
		"status": row.get("status") or None,
		"received_percent": flt(row.get("per_received")),
		"total": flt(row.get("grand_total")),
	}


def _material_request(row) -> dict:
	return {
		"name": row["name"],
		"requested_on": _iso(row.get("transaction_date")),
		"needed_on": _iso(row.get("schedule_date")),
		"status": row.get("status") or None,
		"ordered_percent": flt(row.get("per_ordered")),
	}


@frappe.whitelist()
def workstations(limit: int = 50, offset: int = 0) -> dict:
	"""Workstations that currently have unfinished work waiting.

	Not every workstation ERPNext knows about — only the ones a person could
	walk up to and find something to do. A shop-floor list of empty stations is
	a list nobody reads.
	"""
	limit = min(_page_integer(limit, "limit"), MAX_LIMIT)
	offset = _page_integer(offset, "offset")

	parents = _open_work_order_names()
	if not parents:
		return {"workstations": [], "total": 0, "limit": limit, "offset": offset}

	# Counted in Python rather than with a GROUP BY. Frappe 17 refuses a SQL
	# function written as a string in `fields`, and its dict form does not
	# survive the permission-aware path here. The set being counted is the open
	# operations of visible work orders, which is bounded by the shop floor
	# itself — not by the size of the database.
	rows = frappe.get_list(
		"Work Order Operation",
		filters={
			"parent": ["in", parents],
			"parenttype": "Work Order",
			"status": ["!=", "Completed"],
			"workstation": ["is", "set"],
		},
		pluck="workstation",
		limit_page_length=0,
	)
	waiting: dict[str, int] = {}
	for station in rows:
		waiting[station] = waiting.get(station, 0) + 1
	names = [{"name": k, "waiting": v} for k, v in sorted(waiting.items())]
	return {
		"workstations": names[offset : offset + limit],
		"total": len(names),
		"limit": limit,
		"offset": offset,
	}


@frappe.whitelist()
def station_queue(workstation: str, limit: int = 20, offset: int = 0) -> dict:
	"""Unfinished operations waiting at one workstation, soonest first.

	The shop-floor question is "what do I do next", and it is asked at a
	machine, not at a work order. So this crosses work orders and orders by when
	the job is due rather than by which order it belongs to.

	Scope rides on the parent, as it must: ``Work Order Operation`` is a child
	table with no company of its own, so only operations belonging to a work
	order visible in the session company are ever listed.
	"""
	limit = min(_page_integer(limit, "limit"), MAX_LIMIT)
	offset = _page_integer(offset, "offset")
	workstation = _text(workstation, "workstation")
	if not workstation:
		frappe.throw("workstation must be text.")

	parents = _open_work_order_names()
	if not parents:
		return {"operations": [], "total": 0, "limit": limit, "offset": offset}

	filters = {
		"parent": ["in", parents],
		"parenttype": "Work Order",
		"workstation": workstation,
		"status": ["!=", "Completed"],
	}
	rows = frappe.get_list(
		"Work Order Operation",
		filters=filters,
		fields=[*WORK_ORDER_OPERATION_FIELDS, "parent"],
		order_by="planned_start_time asc, sequence_id asc, idx asc",
		limit_start=offset,
		limit_page_length=limit,
	)
	orders = {
		row["name"]: row
		for row in frappe.get_list(
			"Work Order",
			filters={"name": ["in", [r["parent"] for r in rows]]},
			fields=["name", "production_item", "item_name", "qty", "planned_end_date"],
			limit_page_length=0,
		)
	} if rows else {}

	return {
		"operations": [_queued_operation(row, orders.get(row["parent"], {})) for row in rows],
		"total": _total("Work Order Operation", filters),
		"limit": limit,
		"offset": offset,
	}


def _open_work_order_names() -> list[str]:
	"""Work orders the session may see and that are not finished with.

	One permission-aware query, reused by both shop-floor lists, so scope is
	decided in exactly one place rather than repeated per caller.
	"""
	return frappe.get_list(
		"Work Order",
		filters=scoped({"docstatus": 1, "status": ["not in", ["Completed", "Stopped", "Closed"]]}),
		pluck="name",
		limit_page_length=0,
	)


def _queued_operation(row, order) -> dict:
	return {
		"name": row["name"],
		"work_order": row["parent"],
		"operation": row.get("operation") or None,
		"status": row.get("status") or None,
		"completed_qty": flt(row.get("completed_qty")),
		"planned_minutes": flt(row.get("time_in_mins")),
		"sequence": row.get("sequence_id"),
		"item": order.get("production_item") or None,
		"item_name": order.get("item_name") or None,
		"order_qty": flt(order.get("qty")),
		"due_on": _iso(order.get("planned_end_date")),
	}
