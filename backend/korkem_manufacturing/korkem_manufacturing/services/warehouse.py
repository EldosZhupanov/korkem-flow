# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""What an order still needs before the floor can cut it.

Moved verbatim out of `korkem_ai/tools/procurement.py`. Nothing about this
computation was ever about an assistant: it is the factory's own answer to
"can this be built today", and the button, the Telegram bot and the model all
need the same one. While it lived in the AI app, `start_production` could not
leave that app either, because it re-checks readiness from here at execution.

Two rules survive the move unchanged, and both matter more than they look:

**Requirement is what is *left* to build**, not what the order started as.
Consumed material is subtracted, otherwise a finished work order restores its
whole requirement to the shopping list the moment it completes.

**Two shortages are kept apart.** `shortage_qty` answers "must we buy more" and
closes when a request is raised. `physical_shortage_qty` answers "can the floor
cut this today" and closes only when the material lands on the shelf. Ordered is
not received, and a start that trusted the first number would move stock that is
not there.

Everything numeric comes from ERPNext's own Production Plan engine, which is why
multi-level BOMs, UOM conversion and warehouse aggregation are not this module's
problem.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt

from korkem_manufacturing.services.scope import ensure_company

# --------------------------------------------------------------------------
# Reading the shortage
# --------------------------------------------------------------------------



def _order(sales_order: str):
	"""The order, as this user. `get_doc` applies permissions."""
	if not frappe.db.exists("Sales Order", sales_order):
		frappe.throw(f"Sales order {sales_order} not found.")
	ensure_company("Sales Order", sales_order)
	order = frappe.get_doc("Sales Order", sales_order)
	order.check_permission("read")
	return order


def _raw_material_warehouse(order) -> str | None:
	"""Where this order's raw material is actually drawn from.

	Taken from the Work Orders that already exist for the order rather than
	guessed: they record the source warehouse the factory really uses. With no
	Work Order yet, ERPNext resolves each item's own default instead.
	"""
	rows = frappe.get_all(
		"Work Order",
		filters={"sales_order": order.name, "docstatus": ["<", 2]},
		pluck="name",
	)
	if not rows:
		return None
	warehouses = frappe.get_all(
		"Work Order Item",
		filters={"parent": ["in", rows], "source_warehouse": ["is", "set"]},
		pluck="source_warehouse",
	)
	return warehouses[0] if warehouses else None


def _reserved_for(order_name: str) -> dict[str, float]:
	"""How much of each material this order's own Work Orders already hold.

	This is the quantity `Bin.projected_qty` has already subtracted, and
	subtracting it a second time is exactly the double count this module
	exists to avoid. Consumed material is excluded — it has left the bin, so it
	is no longer reserved against it.
	"""
	orders = frappe.get_all(
		"Work Order",
		filters={
			"sales_order": order_name,
			"docstatus": 1,
			"status": ["not in", ("Completed", "Stopped", "Closed")],
		},
		pluck="name",
	)
	if not orders:
		return {}

	held: dict[str, float] = {}
	for row in frappe.get_all(
		"Work Order Item",
		filters={"parent": ["in", orders]},
		fields=["item_code", "required_qty", "consumed_qty"],
	):
		outstanding = flt(row.required_qty) - flt(row.consumed_qty)
		if outstanding > 0:
			held[row.item_code] = held.get(row.item_code, 0.0) + outstanding
	return held


def _consumed_for(order_name: str) -> dict[str, float]:
	"""How much of each material this order's production has already eaten.

	Counted across **every** submitted work order for the order, whatever its
	status — unlike `_reserved_for`, which deliberately looks only at the live
	ones. A finished work order reserves nothing and has consumed everything,
	and dropping it here would restore its whole requirement to the shopping
	list the moment it completed.
	"""
	orders = frappe.get_all(
		"Work Order",
		filters={"sales_order": order_name, "docstatus": 1},
		pluck="name",
	)
	if not orders:
		return {}

	used: dict[str, float] = {}
	for row in frappe.get_all(
		"Work Order Item",
		filters={"parent": ["in", orders]},
		fields=["item_code", "consumed_qty"],
	):
		if flt(row.consumed_qty) > 0:
			used[row.item_code] = used.get(row.item_code, 0.0) + flt(row.consumed_qty)
	return used


def _requirements(order, warehouse: str | None) -> list[dict]:
	"""ERPNext's own raw-material requirement for this order.

	Delegates to the Production Plan engine, which is why multi-level BOMs,
	UOM conversion and warehouse aggregation are not this module's problem.
	"""
	from erpnext.manufacturing.doctype.production_plan.services.material_request import (
		get_items_for_material_requests,
	)

	lines = []
	for item in order.items:
		bom = frappe.db.get_value(
			"BOM", {"item": item.item_code, "is_active": 1, "is_default": 1}, "name"
		)
		if not bom:
			continue
		lines.append(
			{
				"item_code": item.item_code,
				"sales_order": order.name,
				"sales_order_item": item.name,
				"bom_no": bom,
				"planned_qty": flt(item.qty),
				"warehouse": warehouse or item.warehouse,
				"include_exploded_items": 1,
			}
		)

	if not lines:
		return []

	plan = {
		"company": order.company,
		"for_warehouse": warehouse,
		"po_items": lines,
		"include_non_stock_items": 0,
		"include_subcontracted_items": 1,
		# Ask for the untouched requirement. The availability subtraction is
		# done below, against this order's own reservations — see the module
		# docstring for why the engine's own answer cannot be used here.
		"ignore_existing_ordered_qty": 0,
		"sub_assembly_items": [],
	}
	return get_items_for_material_requests(plan)


def material_shortage(sales_order: str):
	"""What must be bought before this order can be built.

	Machine-readable on purpose: every quantity here is a number the model
	turns into a sentence, never a sentence the model has to parse back into a
	number.
	"""
	order = _order(sales_order)
	warehouse = _raw_material_warehouse(order)
	reserved = _reserved_for(order.name)
	consumed = _consumed_for(order.name)

	items = []
	for row in _requirements(order, warehouse):
		ordered_requirement = flt(row.get("required_bom_qty"))
		used = flt(consumed.get(row["item_code"], 0))
		# What is still needed to finish the order — see the module docstring.
		# Everything below compares against this, never against the quantity
		# the order started life with.
		required = max(0.0, ordered_requirement - used)
		held = flt(reserved.get(row["item_code"], 0))
		projected = flt(row.get("projected_qty"))

		# The requirement not already reserved out of the bin, compared against
		# what the bin projects. Both terms come from ERPNext.
		unreserved = max(0.0, required - held)
		shortage = round(max(0.0, unreserved - projected), 3)
		# The same two questions the factory-wide tool keeps apart, per order.
		# `shortage_qty` is "do we need to buy more" and closes the moment a
		# request is raised; `physical_shortage_qty` is "can the floor cut this
		# today" and only closes when the material actually lands.
		physical = round(max(0.0, required - flt(row.get("actual_qty"))), 3)

		items.append(
			{
				"item_code": row["item_code"],
				"item_name": row.get("item_name"),
				# What the whole order takes, what production has already eaten,
				# and what is left to find. Reported apart so "нужно ещё" and
				# "нужно всего" can never be read as the same number.
				"required_qty": round(ordered_requirement, 3),
				"consumed_qty": round(used, 3),
				"remaining_required_qty": round(required, 3),
				"reserved_qty": round(held, 3),
				"available_qty": round(flt(row.get("actual_qty")), 3),
				"projected_qty": round(projected, 3),
				"ordered_qty": round(flt(row.get("ordered_qty")), 3),
				"shortage_qty": shortage,
				"physical_shortage_qty": physical,
				"uom": row.get("stock_uom"),
				"warehouse": row.get("warehouse"),
			}
		)

	short = [item for item in items if item["shortage_qty"] > 0]
	return {
		"sales_order": order.name,
		"customer": order.customer,
		"company": order.company,
		"items": items,
		"shortages": short,
		"has_shortage": bool(short),
		"not_on_the_shelf": [item for item in items if item["physical_shortage_qty"] > 0],
	}
