# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Shortage → purchase request: the first production write.

## What is reused, and the one place it could not be

ERPNext already owns the hard half of this. `get_items_for_material_requests`
is the engine behind Production Plan: it explodes multi-level BOMs, resolves
purchase UOM and conversion factors, aggregates `Bin` across child warehouses,
applies minimum order quantities and rounds whole-number UOMs. None of that is
reimplemented here — writing a second BOM walker or a second availability
calculation would guarantee the two disagree eventually, and the ERP would be
right.

**What could not be taken from it is its `quantity` field**, and the reason is
worth stating because it is not obvious. That engine is written for a
Production Plan, where the plan's own demand is *not yet* reserved anywhere. A
Sales Order that already has a Work Order is the opposite situation: the Work
Order has already reserved the requirement, and `Bin.projected_qty` already has
it subtracted. Measured on the seeded order, which needs 42 sheets against 38
in stock with a Work Order for all ten cabinets:

    ignore_existing_ordered_qty = 0  ->  ДСП 42, Кромка 180, Петля 40
    ignore_existing_ordered_qty = 1  ->  ДСП 42, Кромка 120, Петля 28

The true answer is 4, 0, 0. The first mode asks for the entire requirement
again; the second subtracts availability from a requirement that is already
inside that availability, so it orders 120 metres of edge banding on top of the
180 already reserved. Both would have someone buy material they own.

So the requirement, the bin figures and the units come from ERPNext, and the
subtraction is done here — once, explicitly, against the reservation ERPNext
itself records:

    shortage = max(0, (required - already_reserved_for_this_order) - projected)

With a Work Order the requirement is already reserved, the first bracket is
zero, and the shortage is whatever `projected_qty` has gone negative by. With
no Work Order nothing is reserved, the bracket is the full requirement, and it
is compared against stock. One formula, both situations, no double count.

## Requirement means *remaining* requirement

`required` above is the requirement that is still outstanding, not the one the
order started with. The distinction is invisible until something is genuinely
manufactured, and then it is the whole answer.

The engine is asked for the full order — ten cabinets, 42 sheets — because that
is what the order is for. But six of those cabinets consuming 25.2 sheets does
not mean the shop must buy 25.2 more; it means only four cabinets are left to
build and only 16.8 sheets are still needed. `_reserved_for` already nets
`consumed_qty` out of its side of the subtraction, so leaving it in on the
requirement side counts every produced unit twice — once as material that has
left the bin, once as material still to buy.

Measured on the seeded order before this was corrected: producing six cabinets
for real turned a four-sheet shortage into 29.2, and 48 metres of edge banding
appeared out of nothing. Physical truth throughout: 16.8 needed, 12.8 on the
shelf, short 4. So `consumed_qty` is subtracted from the requirement too, and
both sides of the comparison mean the same thing.

## Why the model's numbers are not trusted

`create_material_request` recomputes the shortage server-side and refuses to
order more than it finds. A language model that has just been told "не хватает
4 листов" will usually ask for 4, but "usually" is not a control: the argument
that reaches ERPNext is checked against the database, not against what the
model was told a moment ago.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, getdate, nowdate

from korkem_ai.korkem_ai.tools.erp import active_sales_orders
from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register
from korkem_ai.korkem_ai.tools.scope import current_company, ensure_company

#: What a Material Request may be raised for. ERPNext's own field allows more
#: (`Material Issue`, `Subcontracting`), but issuing stock and subcontracting
#: have consequences an assistant should not reach for unprompted. Widening
#: this is a deliberate decision, which is what an allowlist is for.
PURPOSES = ("Purchase", "Material Transfer", "Manufacture")

#: A Material Request still in play. Anything else — Cancelled, Stopped,
#: Received — no longer covers a shortage, so it must not suppress a new one.
OPEN_STATUSES = ("Draft", "Pending", "Partially Ordered", "Ordered")

#: Rounding slack when comparing a requested quantity against the computed
#: shortage. Quantities are floats through UOM conversion, and refusing 4.0000001
#: sheets would be pedantry rather than a control.
TOLERANCE = 0.001


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


#: How many orders one factory-wide pass will explode.
MAX_ORDERS = 20


def _severity(shortage: float, blocked: int, days_until: int | None, overdue: bool) -> str:
	"""How loudly this material should be shouting.

	Data only — how short, how many orders it stops, how soon they are due, and
	whether any of them is already late. No judgement the database cannot back.
	"""
	if shortage <= 0:
		return "none"
	if overdue or (days_until is not None and days_until <= 3):
		return "critical"
	if blocked >= 3 or (days_until is not None and days_until <= 7):
		return "high"
	if days_until is None:
		# Short, and nothing says when it is wanted. Real, but not urgent on
		# any evidence — which is different from urgent and different from fine.
		return "low"
	return "medium"


def factory_shortage(within_days: int | None = None, limit: int | None = None):
	"""What the whole shop is short of, not one order.

	## Why per-order shortages cannot simply be added

	`projected_qty` is **one pool**, shared by every order. Two orders each
	needing 30 sheets against 40 in stock each look fine on their own — 30 is
	less than 40 — and the factory is 20 short. Summing per-order answers gives
	zero. Subtracting availability once per order gives a different wrong
	number in the other direction.

	So demand is aggregated first and availability subtracted **once**:

	    unreserved_demand = Σ max(0, required_i − reserved_i)
	    shortage          = max(0, unreserved_demand − projected_qty)

	With a single order this reduces exactly to the per-order formula, which is
	what keeps this tool and `material_shortage` from ever disagreeing about
	the same material.

	`required_i` is the **remaining** requirement of order *i*, net of what its
	production has already consumed — the same correction `material_shortage`
	applies, and for the same reason. `total_required` below therefore reads
	"what the shop still has to find", not "what its orders originally called
	for".
	"""
	today = getdate(nowdate())
	cap = min(int(limit or MAX_ORDERS), MAX_ORDERS)

	orders = active_sales_orders(limit=cap + 1)
	truncated = len(orders) > cap
	orders = orders[:cap]

	# Keyed by item *and* warehouse: the same board in two stores is two
	# availabilities, and adding them would claim stock that cannot be moved.
	pooled: dict[tuple, dict] = {}

	for header in orders:
		order = frappe.get_doc("Sales Order", header["name"])
		warehouse = _raw_material_warehouse(order)
		reserved = _reserved_for(order.name)
		consumed = _consumed_for(order.name)
		due = getdate(header["delivery_date"]) if header["delivery_date"] else None
		overdue = bool(due and due < today and flt(header["per_delivered"]) < 100)

		for row in _requirements(order, warehouse):
			key = (row["item_code"], row.get("warehouse"))
			# Remaining requirement, exactly as in `material_shortage` — the two
			# tools must never disagree about the same board.
			required = max(
				0.0,
				flt(row.get("required_bom_qty")) - flt(consumed.get(row["item_code"], 0)),
			)
			held = flt(reserved.get(row["item_code"], 0))

			entry = pooled.setdefault(
				key,
				{
					"item_code": row["item_code"],
					"item_name": row.get("item_name"),
					"uom": row.get("stock_uom"),
					"warehouse": row.get("warehouse"),
					# Availability is a property of the bin, not of the order,
					# so it is read once and never accumulated.
					"available_qty": round(flt(row.get("actual_qty")), 3),
					"projected_qty": round(flt(row.get("projected_qty")), 3),
					"ordered_qty": round(flt(row.get("ordered_qty")), 3),
					"total_required": 0.0,
					"_unreserved": 0.0,
					"orders": [],
				},
			)
			entry["total_required"] += required
			entry["_unreserved"] += max(0.0, required - held)
			entry["orders"].append(
				{
					"sales_order": order.name,
					"customer": header["customer"],
					"required_qty": round(required, 3),
					"delivery_date": str(due) if due else None,
					"days_to_delivery": (due - today).days if due else None,
					"overdue": overdue,
				}
			)

	items = []
	for entry in pooled.values():
		orders_for_item = entry.pop("orders")
		unreserved = entry.pop("_unreserved")
		shortage = round(max(0.0, unreserved - entry["projected_qty"]), 3)

		# Two different gaps, and collapsing them is the mistake this whole
		# slice exists to avoid.
		#
		# `shortage_qty` answers "do we need to buy more" and counts what is
		# already requested and on order — raise a purchase request and it goes
		# to zero, which is right, because raising a second one would buy the
		# board twice.
		#
		# `physical_shortage_qty` answers "can the floor cut this today" and
		# counts only what is on the shelf. Ordering material does not put it
		# there. A shop told it has board because somebody bought board finds
		# out at the saw.
		physical = round(max(0.0, entry["total_required"] - entry["available_qty"]), 3)
		if shortage <= 0 and physical <= 0:
			continue

		dated = [o for o in orders_for_item if o["days_to_delivery"] is not None]
		soonest = min(dated, key=lambda o: o["days_to_delivery"]) if dated else None
		lead_time = frappe.db.get_value("Item", entry["item_code"], "lead_time_days")

		items.append(
			{
				**entry,
				"total_required": round(entry["total_required"], 3),
				"shortage_qty": shortage,
				"physical_shortage_qty": physical,
				# On a submitted purchase order and not here yet. Never part of
				# `available_qty`.
				"on_order_qty": round(flt(entry["ordered_qty"]), 3),
				"orders_blocked": sorted(
					orders_for_item,
					key=lambda o: (o["days_to_delivery"] is None, o["days_to_delivery"]),
				),
				"blocked_order_count": len(orders_for_item),
				"earliest_required_date": soonest["delivery_date"] if soonest else None,
				"days_until_required": soonest["days_to_delivery"] if soonest else None,
				# Reported only when the item actually carries one. A default
				# would be a delivery promise nobody made.
				"lead_time_days": int(lead_time) if lead_time else None,
				"severity": _severity(
					shortage,
					len(orders_for_item),
					soonest["days_to_delivery"] if soonest else None,
					any(o["overdue"] for o in orders_for_item),
				),
			}
		)

	if within_days is not None:
		# The horizon is applied here, not by the model: comparing dates is
		# exactly the arithmetic a language model should never be trusted with.
		horizon = int(within_days)
		items = [
			item
			for item in items
			if item["days_until_required"] is not None and item["days_until_required"] <= horizon
		]

	rank = {"critical": 0, "high": 1, "medium": 2, "low": 3, "none": 4}
	items.sort(key=lambda i: (rank.get(i["severity"], 9), i["days_until_required"] is None, i["days_until_required"] or 0))

	return {
		"as_of": str(today),
		"within_days": within_days,
		"summary": {
			"items_short": len([i for i in items if i["shortage_qty"] > 0]),
			"items_physically_short": len([i for i in items if i["physical_shortage_qty"] > 0]),
			"critical_items": len([i for i in items if i["severity"] == "critical"]),
			"orders_affected": len({o["sales_order"] for i in items for o in i["orders_blocked"]}),
			"orders_examined": len(orders),
			"truncated": truncated,
		},
		"items": items,
	}


# --------------------------------------------------------------------------
# Raising the request
# --------------------------------------------------------------------------


def _open_requests(sales_order: str | None, item_codes: list[str]) -> dict[str, list[str]]:
	"""Requests already raised for these materials.

	Scoped to one order when buying for one order, and to the item alone when
	buying for the factory — because an open request for board covers the board,
	whichever order prompted it.
	"""
	filters = {"item_code": ["in", item_codes], "docstatus": ["<", 2]}
	if sales_order:
		filters["sales_order"] = sales_order
	rows = frappe.get_all("Material Request Item", filters=filters, fields=["parent", "item_code"])
	if not rows:
		return {}

	live = set(
		frappe.get_all(
			"Material Request",
			filters={
				"name": ["in", list({row.parent for row in rows})],
				"status": ["in", OPEN_STATUSES],
				"docstatus": ["<", 2],
			},
			pluck="name",
		)
	)

	found: dict[str, list[str]] = {}
	for row in rows:
		if row.parent in live:
			found.setdefault(row.item_code, []).append(row.parent)
	return found


def _checked_line(line: dict) -> dict:
	"""One requested line, checked for existence and sanity.

	Every rejection here is a rejection of something a model asked for. None of
	these are theoretical: an argument list is the one part of a turn that is
	written by the model rather than by a person, and it arrives with exactly
	the authority of the user it runs as.

	The warehouse is *not* resolved here. It is a property of the shortage, and
	a line that is no longer short is dropped before it needs one — checking
	first meant a request for material somebody else had already bought failed
	with "no warehouse could be resolved" instead of "nothing is short".
	"""
	item_code = line.get("item_code")
	if not frappe.db.exists("Item", item_code):
		frappe.throw(f"Item {item_code} does not exist.")

	qty = flt(line.get("qty"))
	if qty <= 0:
		frappe.throw(f"Quantity for {item_code} must be greater than zero.")

	return {"item_code": item_code, "qty": qty, "warehouse": line.get("warehouse")}


def _checked_warehouse(line: dict) -> dict:
	"""Where this line's material will land, validated."""
	target = line.get("warehouse")
	item_code = line["item_code"]

	if not target:
		frappe.throw(f"No warehouse given for {item_code}, and none could be resolved.")
	if not frappe.db.exists("Warehouse", target):
		frappe.throw(f"Warehouse {target} does not exist.")
	if frappe.db.get_value("Warehouse", target, "is_group"):
		# ERPNext refuses this too, later and less clearly. A group warehouse
		# holds nothing; material received into one has nowhere to land.
		frappe.throw(f"Warehouse {target} is a group and cannot receive material.")
	if not frappe.has_permission("Warehouse", "read", doc=target):
		raise frappe.PermissionError

	return line


def _clamped_to_shortage(line: dict, shortage: dict[str, dict]) -> dict | None:
	"""The step that makes the model's arithmetic irrelevant.

	The shortage is recomputed from the database inside this call, and the
	requested quantity is trimmed down to it. Never up: asking for less than is
	missing is a legitimate partial order, asking for more is not a decision the
	model gets to make.

	Trimming rather than refusing matters for a reason that only shows up in
	use. A proposal is confirmed seconds or minutes after it is made, and stock
	moves in between. If four sheets were missing when the model proposed and
	two are missing now, refusing the whole request leaves the user with nothing
	and a puzzle; ordering two is what they actually wanted. The same mechanism
	handles a model that invents four hundred — the database decides, either way.

	Returns `None` when nothing is missing any more, which the caller reads as
	"this line has become unnecessary" rather than as a failure.
	"""
	found = shortage.get(line["item_code"])
	if not found or found["shortage_qty"] <= TOLERANCE:
		return None

	wanted = min(line["qty"], found["shortage_qty"])
	return {
		**line,
		"qty": round(wanted, 3),
		"requested_qty": line["qty"],
		"adjusted": wanted < line["qty"] - TOLERANCE,
		"warehouse": line["warehouse"] or found["warehouse"],
		"uom": found["uom"],
		"stock_uom": found["uom"],
		"conversion_factor": 1.0,
		"needed_by": found.get("earliest_required_date"),
		"blocking_orders": found.get("blocking_orders") or [],
	}


def _shortage_for(sales_order: str | None) -> tuple[dict, dict, str | None]:
	"""The live shortage, per-order or factory-wide, in one shape.

	Both callers need the same three things — what is short, where it lands, and
	which company to bill — so the two readings are normalised here rather than
	branched over three times further down.
	"""
	if sales_order:
		order = _order(sales_order)
		analysis = material_shortage(sales_order)
		shortage = {
			row["item_code"]: {
				**row,
				"earliest_required_date": str(order.delivery_date) if order.delivery_date else None,
				"blocking_orders": [order.name],
			}
			for row in analysis["shortages"]
		}
		warehouses = {row["item_code"]: row.get("warehouse") for row in analysis["items"]}
		return shortage, warehouses, order.company

	analysis = factory_shortage()
	shortage = {
		row["item_code"]: {
			**row,
			"blocking_orders": [o["sales_order"] for o in row["orders_blocked"]],
		}
		for row in analysis["items"]
	}
	warehouses = {row["item_code"]: row.get("warehouse") for row in analysis["items"]}
	company = current_company()
	return shortage, warehouses, company


def create_material_request(
	items: list,
	sales_order: str | None = None,
	purpose: str | None = None,
	schedule_date: str | None = None,
	allow_duplicate: bool | None = None,
):
	"""Raise one Material Request for material that is short.

	Two shapes, one document. Given a `sales_order` the quantities are checked
	against that order's shortage; without one they are checked against the
	whole factory's, which is what "buy everything we are missing" means.

	Submitted rather than left in Draft: a draft does not update `indented_qty`,
	so it neither reaches purchasing nor prevents the same shortage being
	requested again tomorrow. A request nobody can see is not a business action.
	"""
	purpose = purpose or "Purchase"
	if purpose not in PURPOSES:
		frappe.throw(f"Purpose must be one of: {', '.join(PURPOSES)}.")

	if not items:
		frappe.throw("No items were given to request.")

	shortage, warehouses, company = _shortage_for(sales_order)

	lines = [_checked_line(dict(line)) for line in items]

	# Duplicates are looked for *before* the shortage is consulted, and the
	# order matters. Submitting a request raises `indented_qty`, which lifts
	# `projected_qty`, which closes the shortage — so by the time a second
	# identical request arrives there is nothing short any more, and the
	# shortage check would report "this item is not short". True, and useless:
	# what the user needs to hear is that they already asked for it.
	duplicates = {} if allow_duplicate else _open_requests(sales_order, [ln["item_code"] for ln in lines])
	if duplicates:
		# Reported rather than silently merged or silently duplicated. Buying
		# the same material twice is a real cost, and so is not buying it at
		# all because something quietly decided a request already covered it.
		return {
			"status": "duplicate",
			"sales_order": sales_order,
			"existing": [
				{"item_code": item, "material_requests": names}
				for item, names in sorted(duplicates.items())
			],
		}

	clamped = [_clamped_to_shortage(line, shortage) for line in lines]
	wanted = [line for line in clamped if line]

	# Warehouses resolved only for the lines that survived. Falling order of
	# authority: what the model was told, then what the shortage resolved.
	for line in wanted:
		line["warehouse"] = line["warehouse"] or warehouses.get(line["item_code"])
		_checked_warehouse(line)

	if not wanted:
		# Everything asked for has since been covered. Not an error, and not a
		# document either: an empty purchase request is noise in somebody's
		# approval queue.
		return {
			"status": "not_needed",
			"sales_order": sales_order,
			"message": "Nothing is short any more — no purchase request was created.",
			"items": [line["item_code"] for line in lines],
		}

	# Asked before anything is written, not discovered at the end. `insert()`
	# needs `create` and `submit()` needs `submit`, and ERPNext lets an
	# administrator grant one without the other. Finding out afterwards leaves
	# a draft nobody asked for and nobody will action — visible in the list,
	# invisible to purchasing, and indistinguishable from one a person started
	# and abandoned.
	if not frappe.has_permission("Material Request", "submit"):
		frappe.throw(
			"You can create a material request but not submit one, and an "
			"unsubmitted request never reaches purchasing. Ask someone with "
			"submit rights to raise it."
		)

	request = frappe.new_doc("Material Request")
	request.update(
		{
			"company": company,
			"material_request_type": purpose,
			"transaction_date": nowdate(),
		}
	)

	for line in wanted:
		# The date the material is actually wanted, taken from the delivery
		# dates of the orders it blocks. The old `today + 7` was a promise
		# nobody made; `Item.lead_time_days` is reported by the read tool but
		# is not used to invent one either, because it is unset on every item
		# on this bench and a default would be the same fiction.
		# The date the material is wanted, never earlier than today. An overdue
		# order wanted its board last week, and ERPNext rightly refuses a
		# request dated before it was raised ("Required By cannot be before
		# Transaction Date"). Being already late is real and is reported in the
		# shortage; it cannot be fixed by back-dating a purchase.
		due = schedule_date or line.get("needed_by") or nowdate()
		if getdate(due) < getdate(nowdate()):
			due = nowdate()
		request.append(
			"items",
			{
				"item_code": line["item_code"],
				"qty": line["qty"],
				"uom": line["uom"],
				"stock_uom": line["stock_uom"],
				"conversion_factor": line["conversion_factor"],
				"warehouse": line["warehouse"],
				"schedule_date": due,
				# Cited when the material is for one order. Left empty when it
				# serves several — naming one of five would be a tidier lie.
				"sales_order": sales_order,
			},
		)

	request.schedule_date = min(row.schedule_date for row in request.items)
	request.insert()
	request.submit()

	return {
		"status": "created",
		"material_request": request.name,
		"sales_order": sales_order,
		"purpose": purpose,
		"schedule_date": str(request.schedule_date),
		"items": [
			{
				"item_code": line["item_code"],
				"qty": line["qty"],
				"uom": line["uom"],
				"warehouse": line["warehouse"],
				"needed_by": line.get("needed_by"),
				"blocking_orders": line.get("blocking_orders") or [],
				# Surfaced so the model tells the user the number changed rather
				# than quietly reporting a figure they did not ask for.
				"requested_qty": line.get("requested_qty"),
				"adjusted": bool(line.get("adjusted")),
			}
			for line in wanted
		],
		"skipped": [line["item_code"] for line, kept in zip(lines, clamped, strict=True) if not kept],
	}


# --------------------------------------------------------------------------
# Registration
# --------------------------------------------------------------------------

register(
	ToolSpec(
		name="inventory.factory_shortage",
		description=(
			"What the whole factory is short of, across every active order. Use "
			"this for «что не хватает на складе», «какие материалы нужно купить», "
			"«какой материал самый критичный» or «какие заказы блокируются из-за "
			"материалов». For one specific order use inventory.material_shortage "
			"instead. Every quantity, severity and date here is computed from the "
			"database — report them as given and do not add, compare or re-derive "
			"any of them."
		),
		input_schema={
			"type": "object",
			"properties": {
				"within_days": {
					"type": "integer",
					"minimum": 1,
					"maximum": 365,
					"description": (
						"Only material needed within this many days. Use 7 for "
						"«на этой неделе». Omit for everything."
					),
				},
				"limit": {
					"type": "integer",
					"minimum": 1,
					"maximum": MAX_ORDERS,
					"description": f"How many orders to examine, at most {MAX_ORDERS}.",
				},
			},
			"required": [],
		},
		handler=factory_shortage,
		risk=Risk.READ,
		doctypes=("Sales Order", "BOM", "Bin", "Work Order", "Production Plan"),
		audit_category="inventory",
		timeout=60,
	)
)

register(
	ToolSpec(
		name="inventory.material_shortage",
		description=(
			"What one named sales order is short of. Returns every material that "
			"order needs with required, available, reserved and short quantities. "
			"Use inventory.factory_shortage instead when the question is about the "
			"warehouse or the factory rather than a specific order. Use these "
			"numbers rather than your own arithmetic."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {"type": "string", "description": "Sales Order name, e.g. SAL-ORD-2026-00001"},
			},
			"required": ["sales_order"],
		},
		handler=material_shortage,
		risk=Risk.READ,
		# `Production Plan` is here because ERPNext's requirement engine calls
		# `has_permission("Production Plan", "read", throw=True)` on the way in,
		# even though this tool never creates a plan. Leaving it undeclared
		# meant the tool was offered to a user who could not run it, and the
		# failure arrived as a bare "you do not have permission to do that"
		# naming nothing. `Work Order` likewise: reservations are read from it.
		doctypes=("Sales Order", "BOM", "Bin", "Work Order", "Production Plan"),
		audit_category="inventory",
	)
)

register(
	ToolSpec(
		name="inventory.create_material_request",
		description=(
			"Raise one purchase request for material that is short. Pass "
			"sales_order to buy for one order, or omit it to buy everything the "
			"factory is missing in a single request. Ask "
			"inventory.material_shortage or inventory.factory_shortage first and "
			"pass the quantities it reported. Requires the user to confirm before "
			"anything is created."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {
					"type": "string",
					"description": (
						"The order the material is for. Omit for a factory-wide "
						"request covering several orders."
					),
				},
				"purpose": {
					"type": "string",
					"enum": list(PURPOSES),
					"description": "Why the material is needed. Defaults to Purchase.",
				},
				"items": {
					"type": "array",
					"description": "The materials to request",
					"items": {
						"type": "object",
						"properties": {
							"item_code": {"type": "string"},
							"qty": {"type": "number", "description": "In the item's stock UOM"},
							"warehouse": {"type": "string", "description": "Receiving warehouse"},
						},
						"required": ["item_code", "qty"],
					},
				},
				"schedule_date": {"type": "string", "description": "Required-by date, YYYY-MM-DD"},
				"allow_duplicate": {
					"type": "boolean",
					"description": "Only set this after the user has been shown an existing request and asked for another anyway.",
				},
			},
			"required": ["items"],
		},
		handler=create_material_request,
		risk=Risk.WRITE,
		doctypes=("Material Request",),
		audit_category="inventory",
	)
)
