# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Starting production: the domain service every client calls.

Moved out of `korkem_ai/tools/production.py` **unchanged**. Nothing here was
ever about an assistant — it is what the factory does when somebody says start,
and the button on a desktop, the shop-floor terminal, a Telegram reply and the
model must all reach the same one (ADR-0003, ADR-0007).

## What is deliberately *not* here

**No permission check and no confirmation.** Those belong to the API layer that
publishes this service (`korkem_manufacturing/api/production.py`), because they
are questions about a *caller*, and this layer answers questions about the
*business*. Calling this function directly from a script bypasses them, which is
correct: a migration or a fixture is not a person.

**No notification import.** Starting production should tell somebody, and the
code that tells them lives in `korkem_ai`. A domain that imports its own client
stops being a domain, so this emits a named event through
`korkem_manufacturing.domain_events` and never learns who listens.

## Two rules the move preserves, because both are load-bearing

**Readiness is re-checked here, at execution.** Between a model proposing a
start and a person agreeing to it, the board this job needs may have gone to
another job. The check is the same reading `production_control` reports, so the
tool that says "can start" and the service that starts cannot disagree.

**Readiness is physical, not procurement.** A purchase order for the board does
not let anybody cut it, which is why the guard reads `not_on_the_shelf` and not
`shortages`.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, nowdate

from korkem_manufacturing import domain_events
from korkem_manufacturing.services.scope import current_company, ensure_company, scoped
from korkem_manufacturing.services.warehouse import material_shortage

#: Business events this service announces. Subscribers register against these
#: names in their own `hooks.py`; nothing here knows who they are.
PRODUCTION_STARTED = "production.started"
MATERIAL_SHORT = "production.material_short"


#: Work Order states that still represent a live job.
LIVE_WORK = ("Draft", "Not Started", "In Process", "Stock Reserved", "Stock Partially Reserved")

#: An operation is done, running, or waiting — ERPNext's own three.
DONE = "Completed"
RUNNING = "Work in Progress"


def work_order_stages(work_order: str) -> dict:
	"""Where a job has got to, from its own operations.

	`current` is the first operation not finished, `next` the one after it —
	both read from `Work Order Operation`, never inferred from progress
	percentages.
	"""
	rows = frappe.get_all(
		"Work Order Operation",
		filters={"parent": work_order},
		fields=[
			"operation",
			"workstation",
			"status",
			"completed_qty",
			"process_loss_qty",
			"time_in_mins",
			"sequence_id",
		],
		order_by="sequence_id asc",
	)
	if not rows:
		return {"operations": [], "current_operation": None, "next_operation": None}

	unfinished = [row for row in rows if row["status"] != DONE]
	current = next((row for row in unfinished if row["status"] == RUNNING), None) or (
		unfinished[0] if unfinished else None
	)
	following = None
	if current:
		after = [row for row in rows if row["sequence_id"] > current["sequence_id"]]
		following = after[0] if after else None

	return {
		"operations": [
			{
				"operation": row["operation"],
				"workstation": row["workstation"],
				"status": row["status"],
				"completed_qty": flt(row["completed_qty"]),
				"scrap_qty": flt(row["process_loss_qty"]),
				"planned_minutes": flt(row["time_in_mins"]),
				"sequence": row["sequence_id"],
			}
			for row in rows
		],
		"current_operation": current["operation"] if current else None,
		"current_workstation": current["workstation"] if current else None,
		"next_operation": following["operation"] if following else None,
	}


def _live_work_orders(sales_order: str) -> list[dict]:
	return frappe.get_list(
		"Work Order",
		filters=scoped({"sales_order": sales_order, "docstatus": ["<", 2]}),
		fields=[
			"name",
			"production_item",
			"qty",
			"produced_qty",
			"material_transferred_for_manufacturing",
			"status",
			"docstatus",
			"bom_no",
		],
		order_by="creation asc",
	)


def _live_job_name(sales_order: str) -> str | None:
	"""The one running job for this order, or nothing.

	Used only to attach a notification to a job when there is exactly one — with
	two, naming either would be the silent choice this codebase refuses
	everywhere else, and the order-level message still reaches the customer.
	"""
	live = _live_work_orders(sales_order)
	return live[0]["name"] if len(live) == 1 else None


def _awaiting_material(job: dict) -> float:
	"""Units of this job whose material has not been moved into WIP yet.

	ERPNext counts both halves for us: `qty` is what the job is for and
	`material_transferred_for_manufacturing` is how many units' worth has been
	transferred so far. The difference is what still has to go across, and it
	is *not* the same as what is left to build — a job can have material
	sitting in work-in-progress for units nobody has assembled yet.
	"""
	return round(flt(job["qty"]) - flt(job["material_transferred_for_manufacturing"]), 3)


def _planned_qty(orders: list[dict]) -> float:
	return sum(flt(row["qty"]) for row in orders if row["status"] not in ("Cancelled", "Closed"))


def start_production(sales_order: str, item_code: str | None = None):
	"""Put an order into production: plan the work if needed, then move material.

	Everything is re-read here rather than taken from the proposal. A start is
	a stock movement; between the model suggesting one and a person agreeing,
	the board it needs may have gone to another job.
	"""
	from erpnext.manufacturing.doctype.work_order.mapper import make_stock_entry

	if not frappe.db.exists("Sales Order", sales_order):
		frappe.throw(f"Sales order {sales_order} not found.")
	ensure_company("Sales Order", sales_order)

	order = frappe.get_doc("Sales Order", sales_order)
	order.check_permission("read")
	if order.docstatus != 1:
		frappe.throw(f"{sales_order} is not submitted, so it cannot be produced.")

	lines = [row for row in order.items if not item_code or row.item_code == item_code]
	if not lines:
		frappe.throw(f"{sales_order} has no line for {item_code}.")
	line = lines[0]

	# Readiness, re-checked from the shelf rather than from the proposal — and
	# from the same reading `production_control` reports, so the tool that says
	# "can start" and the tool that starts cannot disagree.
	blocking = material_shortage(sales_order)["not_on_the_shelf"]
	if blocking:
		# Somebody is waiting on this. Emitting the event here rather than in the
		# caller keeps the tool's own knowledge — which job, which material — in
		# the one place that has it, and the notification layer decides who hears.
		domain_events.emit(
			MATERIAL_SHORT,
			work_order=_live_job_name(sales_order),
			blocking=blocking,
			sales_order=sales_order,
		)
		return {
			"status": "blocked",
			"sales_order": sales_order,
			"item_code": line.item_code,
			"blocking_materials": blocking,
			"message": (
				"Not enough material on the shelf: "
				+ ", ".join(
					f"{m['item_code']} short {m['physical_shortage_qty']} {m['uom']}"
					for m in blocking
				)
			),
		}

	existing = _live_work_orders(sales_order)
	outstanding = round(flt(line.qty) - _planned_qty(existing), 3)

	created = None
	if outstanding > 0:
		bom = frappe.db.get_value(
			"BOM", {"item": line.item_code, "is_active": 1, "is_default": 1, "company": current_company()}, "name"
		)
		if not bom:
			frappe.throw(f"No active BOM for {line.item_code}, so production cannot be planned.")

		if not frappe.has_permission("Work Order", "submit"):
			frappe.throw(
				"You can plan production but not submit a work order, and an "
				"unsubmitted one never reaches the floor."
			)

		job = frappe.new_doc("Work Order")
		job.update(
			{
				"production_item": line.item_code,
				"bom_no": bom,
				"company": current_company(),
				"qty": outstanding,
				"sales_order": sales_order,
				"sales_order_item": line.name,
				"wip_warehouse": frappe.db.get_value(
					"Warehouse", {"company": current_company(), "warehouse_name": "Work In Progress"}, "name"
				),
				"fg_warehouse": line.warehouse,

				"planned_start_date": nowdate(),
			}
		)
		# Operations do not arrive on their own — the desk form asks for them
		# and `insert` does not. Without this the job has no stages.
		job.set_work_order_operations()
		job.insert()
		job.submit()
		created = job.name
		existing = _live_work_orders(sales_order)

	startable = [row for row in existing if row["status"] in ("Not Started", "Draft")]
	running = [row for row in existing if row["status"] == "In Process"]

	# A job that is already running can still be waiting for material, and this
	# is the ordinary case rather than an edge one: a batch is transferred,
	# built, and consumed, and the next batch needs its own transfer. Before
	# the demo factory manufactured for real, no job ever reached that state,
	# so "already running" was indistinguishable from "nothing to do" — and a
	# part-built order could not be finished through the assistant at all.
	topping_up = [row for row in running if _awaiting_material(row) > 0]

	if startable:
		job_name = startable[0]["name"]
		moving = flt(startable[0]["qty"])
		topped_up = False
	elif topping_up:
		job_name = topping_up[0]["name"]
		moving = _awaiting_material(topping_up[0])
		topped_up = True
	else:
		return {
			"status": "already_started" if running else "nothing_to_start",
			"sales_order": sales_order,
			"work_orders": existing,
			"message": (
				"Production is already running for this order and every unit's "
				"material is already in work in progress."
				if running
				else "There is nothing left to start on this order."
			),
		}

	if not frappe.has_permission("Stock Entry", "submit"):
		frappe.throw(
			"You can prepare a material transfer but not submit one, and an "
			"unsubmitted transfer moves nothing."
		)

	# ERPNext's own mapper: it picks the required items, quantities and
	# warehouses from the work order.
	transfer = frappe.get_doc(
		make_stock_entry(job_name, "Material Transfer for Manufacture", moving)
	)
	transfer.insert()
	transfer.submit()

	# Read back what ERPNext now says, rather than reporting what was intended.
	job = frappe.get_doc("Work Order", job_name)
	stages = work_order_stages(job_name)
	domain_events.emit(PRODUCTION_STARTED, work_order=job.name)
	return {
		"status": "started",
		"sales_order": sales_order,
		"work_order": job.name,
		"work_order_created": created,
		"item_code": job.production_item,
		"qty": flt(job.qty),
		"produced_qty": flt(job.produced_qty),
		"remaining_qty": round(flt(job.qty) - flt(job.produced_qty), 3),
		"work_order_status": job.status,
		# True when this moved the *next* batch into an already-running job
		# rather than starting a fresh one. Reported so the answer can say
		# "материал для оставшихся 4 подан" instead of "производство запущено",
		# which would be wrong — it started some time ago.
		"topped_up": topped_up,
		"transferred_for_qty": moving,
		"material_transfer": transfer.name,
		"transferred": [
			{"item_code": row.item_code, "qty": flt(row.qty), "uom": row.uom, "to_warehouse": row.t_warehouse}
			for row in transfer.items
		],
		"current_operation": stages["current_operation"],
		"current_workstation": stages["current_workstation"],
		"next_operation": stages["next_operation"],
	}
