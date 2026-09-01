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
	if or_filters:
		return len(
			frappe.get_list(
				doctype,
				filters=filters,
				or_filters=or_filters,
				pluck="name",
				limit_page_length=0,
			)
		)
	return frappe.client.get_count(doctype, filters=filters)


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
