# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Starting production — the first thing the assistant does on the shop floor.

Everything before this could describe the factory. This changes it: material
leaves the store, a work order begins, and the floor has something to cut.

## What "start production" means in ERPNext

Two steps, both ERPNext's own:

1. A **Work Order** must exist for the quantity still to build. If the order has
   none — nobody has planned it yet — one is created from the item's default
   BOM, which is also what gives it its seven operations.
2. Material moves to work-in-progress through a **Stock Entry** of purpose
   *Material Transfer for Manufacture*, built by
   `work_order/mapper.py:make_stock_entry`. That entry is what takes the work
   order from Not Started to In Process.

Neither is reimplemented, and stock is never written directly. A hand-moved
`Bin` would leave the ledger disagreeing with the shelf, and ERPNext's own
status transitions would stop matching what the floor sees.

## What is checked before anything moves

Material readiness is **physical**, not procurement: a purchase order for the
board does not let anybody cut it. So the check is the same one
`production_control` reports — what is on the shelf, against what this build
needs — and it is re-run at execution rather than trusted from the proposal.
Between a model suggesting a start and a person agreeing to it, somebody else
may have consumed the same board.
"""

from __future__ import annotations

import frappe
from frappe.utils import add_to_date, flt, get_datetime, now_datetime, nowdate

from korkem_ai.korkem_ai.notifications import events
from korkem_manufacturing.services.production import (
	_awaiting_material,
	_live_job_name,
	_live_work_orders,
	_planned_qty,
	work_order_stages,
)
from korkem_ai.korkem_ai.tools.procurement import material_shortage
from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register
from korkem_ai.korkem_ai.tools.scope import current_company, ensure_company, scoped

#: Work Order states that still represent a live job.

def _api():
	"""The published endpoint this tool is an alias for.

	Imported lazily: `korkem_manufacturing.api.production` imports the domain,
	which imports nothing from here, but a module-level import would still make
	tool registration depend on app load order for no gain.
	"""
	from korkem_manufacturing.api import production

	return production


LIVE_WORK = ("Draft", "Not Started", "In Process", "Stock Reserved", "Stock Partially Reserved")

#: An operation is done, running, or waiting — ERPNext's own three.
DONE = "Completed"
RUNNING = "Work in Progress"


def _the_only_job(sales_order: str, verb: str) -> str:
	"""The one work order on this order, or a question naming all of them.

	Never the first by creation date. An order with two jobs on it is a
	question, not a default: acting on the wrong one touches the wrong
	material and the wrong customer's job, and both are real movements that
	somebody then has to reverse.
	"""
	ensure_company("Sales Order", sales_order)
	jobs = frappe.get_list(
		"Work Order",
		filters=scoped({"sales_order": sales_order, "docstatus": 1}),
		fields=["name", "production_item", "sales_order", "qty", "produced_qty", "status"],
		order_by="creation asc",
	)
	if not jobs:
		frappe.throw(f"{sales_order} has no work order, so nothing is being made for it.")

	unfinished = [job for job in jobs if flt(job["qty"]) - flt(job["produced_qty"]) > 0]
	candidates = unfinished or jobs
	if len(candidates) > 1:
		frappe.throw(
			f"{sales_order} has {len(candidates)} work orders that could be {verb}. "
			"Say which one:\n"
			+ "\n".join(
				f"  {job['name']} — {job['production_item']}, "
				f"{flt(job['produced_qty'])} of {flt(job['qty'])} made, "
				f"{round(flt(job['qty']) - flt(job['produced_qty']), 3)} left, {job['status']}"
				for job in candidates
			)
		)
	return candidates[0]["name"]


# --------------------------------------------------------------------------
# The shop floor
# --------------------------------------------------------------------------

#: Job Card states that mean the job is finished with.
CARD_DONE = ("Completed", "Cancelled")


def _cards_for(work_orders: list[str]) -> list[dict]:
	if not work_orders:
		return []
	return frappe.get_list(
		"Job Card",
		filters=scoped({"work_order": ["in", work_orders], "docstatus": ["<", 2]}),
		fields=[
			"name",
			"work_order",
			"operation",
			"workstation",
			"status",
			"for_quantity",
			"total_completed_qty",
			# ERPNext's own scrap accounting. `process_loss_qty` is what was
			# started and did not survive the operation; `pending_qty` is what
			# has not been attempted yet. The card's own invariant is
			# completed + loss + pending == for_quantity, and it is enforced on
			# save — so these three are not ours to compute, only to report.
			"process_loss_qty",
			"pending_qty",
			"quality_inspection",
			"sequence_id",
			"operation_id",
			"actual_start_date",
			"actual_end_date",
			"docstatus",
		],
		order_by="sequence_id asc, creation asc",
		limit_page_length=0,
	)


def _upstream_good(work_order: str, sequence_id) -> float | None:
	"""How many units the stages before this one actually passed on.

	ERPNext refuses an operation that completes more than a previous one did
	(`Job Card.validate_previous_operation`) — cut four good panels and only
	four can be edge-banded. So the fifth unit of a card for five is not
	"pending", it is a unit that no longer exists, and leaving it pending would
	keep the card open for work nobody can do.

	The loss is therefore carried forward, and ERPNext expects exactly that: a
	Manufacture entry takes the **maximum** process loss across the operations,
	not the sum (`Stock Entry.set_process_loss_qty`), because a unit lost at the
	saw is the same unit missing at every bench after it. Declaring it again
	downstream does not lose it twice.
	"""
	if not sequence_id:
		return None
	rows = frappe.get_all(
		"Work Order Operation",
		filters={"parent": work_order, "docstatus": 1, "sequence_id": ["<", sequence_id]},
		pluck="completed_qty",
	)
	return min(flt(qty) for qty in rows) if rows else None


def _bench_free_from(card_doc):
	"""When this workstation was last free, so a synthetic log does not overlap.

	ERPNext refuses two job cards whose time logs overlap on one workstation,
	which is right — a bench does one job at a time. So a card being closed
	without ever having been started begins where the previous job on that
	bench ended, rather than at some invented hour that runs straight through
	its neighbours.
	"""
	latest = frappe.db.sql(
		"""
		select max(log.to_time)
		from `tabJob Card Time Log` log
		join `tabJob Card` card on card.name = log.parent
		where card.workstation = %s and card.docstatus < 2 and card.name != %s
		""",
		(card_doc.workstation, card_doc.name),
	)[0][0]
	fallback = add_to_date(now_datetime(), minutes=-1)
	if not latest:
		return fallback
	return max(get_datetime(latest), fallback) if get_datetime(latest) < now_datetime() else fallback


#: The shop's rework operation. Marked `is_corrective_operation` in ERPNext, so
#: its job cards carry cost of poor quality and never production quantity.
CORRECTIVE_OPERATION = "Исправление брака"


def _corrective_card(work_order: str, for_job_card: str | None = None) -> dict | None:
	"""The open rework card on this job, if one is waiting.

	Corrective job cards are ERPNext's own record of rework: `is_corrective_job_card`,
	linked back to the card whose units failed. They contribute
	`corrective_operation_cost` to the work order and **never** production
	quantity — `Job Card.update_work_order` returns early for them. Getting a
	unit back into good output is done on the original card, not this one.
	"""
	filters = {
		"work_order": work_order,
		"is_corrective_job_card": 1,
		"docstatus": 0,
	}
	if for_job_card:
		filters["for_job_card"] = for_job_card
	rows = frappe.get_list(
		"Job Card",
		filters=scoped(filters),
		fields=["name", "operation", "for_operation", "for_job_card", "for_quantity", "workstation"],
		order_by="creation asc",
	)
	return rows[0] if rows else None


def _hold_cards(work_order: str, operation: str | None = None) -> list[dict]:
	"""Cards holding pieces that are out of the line but not lost.

	A hold card is a draft, non-corrective card that some corrective card points
	at through `for_job_card` — ERPNext's own link, and the only thing that
	distinguishes a piece waiting on a rework verdict from a card opened to
	catch a recovered piece up with the rest.

	The distinction matters downstream. A piece at the rework bench is not scrap
	and must not be carried forward as loss — it may yet come back.
	"""
	sent = {
		row["for_job_card"]
		for row in frappe.get_list(
			"Job Card",
			filters=scoped({"work_order": work_order, "is_corrective_job_card": 1}),
			fields=["for_job_card"],
		)
		if row["for_job_card"]
	}
	if not sent:
		return []

	filters = {"work_order": work_order, "is_corrective_job_card": 0, "docstatus": 0}
	if operation:
		filters["operation"] = operation
	drafts = frappe.get_list(
		"Job Card",
		filters=scoped(filters),
		fields=["name", "operation", "operation_id", "for_quantity", "sequence_id"],
		order_by="sequence_id asc, creation asc",
	)
	return [row for row in drafts if row["name"] in sent]


def _held_before(work_order: str, sequence_id) -> float:
	"""Pieces held for rework at or before this point in the routing.

	Sequence comes from the work order's own operations rather than the card's
	`sequence_id` — that field is not carried onto a card created by copying
	another, so a hold card looked like it belonged nowhere and the piece it was
	holding was written off downstream as lost.
	"""
	if not sequence_id:
		return 0.0
	order = {
		row["operation"]: row["sequence_id"]
		for row in frappe.get_all(
			"Work Order Operation",
			filters={"parent": work_order},
			fields=["operation", "sequence_id"],
		)
	}
	return sum(
		flt(row["for_quantity"])
		for row in _hold_cards(work_order)
		if flt(order.get(row["operation"], 0)) < flt(sequence_id)
		and order.get(row["operation"]) is not None
	)


def _split_off_hold(card_doc, qty: float) -> str:
	"""Put `qty` pieces on a card of their own, so the rest can move on.

	This is the whole of Phase 25. Holding a piece by leaving its card open
	stopped the line, and the reason is exact: an unsubmitted job card
	contributes nothing to `Work Order Operation.completed_qty`, which is what
	`Job Card.validate_previous_operation` reads. Four finished pieces looked
	like none, and the next operation refused to start.

	ERPNext already allows several cards per operation — `get_current_operation_data`
	sums across them — so the good pieces get a card that submits and the held
	piece gets one that waits. `validate_job_card_qty` sums `for_quantity` over
	the same operation, so the original is resized first; together they still
	come to what the operation is for.
	"""
	hold = frappe.copy_doc(card_doc)
	# `copy_doc` carries the source's `docstatus`, and by this point the source
	# has been submitted — so inserting the copy ran submit validation on a card
	# with nothing on it yet and threw "Time logs are required" against a card
	# nobody had heard of. The hold card is a draft; it is submitted later by
	# whatever the rework result turns out to be.
	hold.docstatus = 0
	hold.amended_from = None
	hold.set("time_logs", [])
	hold.set("employee", [])
	hold.for_quantity = qty
	hold.total_completed_qty = 0
	hold.process_loss_qty = 0
	hold.pending_qty = qty
	hold.status = "Open"
	hold.insert()
	# No time log yet, deliberately. One was added here while the real cause of
	# "Time logs are required" was still unknown; with the docstatus corrected
	# it is not needed, and an open-ended log on a card that may sit for days
	# collides with every other job on that workstation. The log is opened when
	# the rework result is booked.
	return hold.name


def _catch_up_card(work_order: str, operation: str, cards: list[dict]) -> dict | None:
	"""A card for pieces that reached this stage after it had closed.

	A recovered piece rejoins the line at the stage it left, and the stages
	after it have already finished on the pieces that were never damaged. Their
	cards are submitted and cannot be added to, so the piece needs a card of its
	own — which is the same thing ERPNext does when an operation is run in
	batches.

	Only ever for quantity that has genuinely arrived: what the stage before
	this one has completed, less what this one already has.
	"""
	row = frappe.db.get_value(
		"Work Order Operation",
		{"parent": work_order, "operation": operation},
		["name", "completed_qty", "process_loss_qty", "sequence_id"],
		as_dict=True,
	)
	if not row:
		return None
	settled = flt(row["completed_qty"]) + flt(row["process_loss_qty"])
	upstream = _upstream_good(work_order, row["sequence_id"])
	if upstream is None:
		upstream = flt(frappe.db.get_value("Work Order", work_order, "qty"))
	outstanding = round(min(upstream, flt(frappe.db.get_value("Work Order", work_order, "qty"))) - settled, 3)
	if outstanding <= 0:
		return None

	template = frappe.get_doc("Job Card", cards[-1]["name"])
	catch_up = frappe.copy_doc(template)
	# Same reason as in `_split_off_hold`: the template is a submitted card.
	catch_up.docstatus = 0
	catch_up.amended_from = None
	catch_up.set("time_logs", [])
	catch_up.set("employee", [])
	catch_up.for_quantity = outstanding
	catch_up.total_completed_qty = 0
	catch_up.process_loss_qty = 0
	catch_up.pending_qty = outstanding
	catch_up.status = "Open"
	catch_up.insert()
	return next(
		(row for row in _cards_for([work_order]) if row["name"] == catch_up.name), None
	)


def _open_rework(card_doc, qty: float) -> str:
	"""Send `qty` units of this card to the rework bench.

	ERPNext's `make_corrective_job_card` builds it. Two fields have to be
	corrected after the mapper runs, and both are measured rather than guessed:

	* `operation_id` is copied from the source card, and `validate_job_card_qty`
	  sums `for_quantity` across every card sharing it — so the rework card is
	  counted against the operation it is fixing and ERPNext refuses it with
	  "Qty To Manufacture in the job card cannot be greater than...". A
	  corrective card is not that operation, so it carries no operation row.
	* `for_quantity` is copied whole, and only the failed units are being
	  reworked.
	"""
	from erpnext.manufacturing.doctype.job_card.mapper import make_corrective_job_card

	if not frappe.db.exists("Operation", CORRECTIVE_OPERATION):
		frappe.throw(
			f"This factory has no '{CORRECTIVE_OPERATION}' operation, so there is "
			"nowhere to send rework."
		)

	doc = frappe.get_doc(
		make_corrective_job_card(card_doc.name, CORRECTIVE_OPERATION, card_doc.operation)
	)
	doc.operation_id = None
	doc.for_quantity = qty
	doc.insert()
	return doc.name


def _card_quantities(card: dict) -> dict:
	"""The three numbers a floor cares about, named as a person would name them.

	`total_completed_qty` is *good* output — ERPNext already excludes process
	loss from it — so reporting it as "completed" without saying what happened
	to the rest is how scrap turns into finished goods in somebody's head.
	"""
	good = flt(card["total_completed_qty"])
	scrap = flt(card["process_loss_qty"])
	return {
		"for_quantity": flt(card["for_quantity"]),
		"good_qty": good,
		"scrap_qty": scrap,
		"pending_qty": round(flt(card["for_quantity"]) - good - scrap, 3),
	}


def _inspection_state(card: dict) -> dict:
	"""Whether this operation is inspected, and how it went.

	Required only when the bill of materials asks for inspection *and* the
	operation does — ERPNext's own rule, in `Job Card.validate_inspection`. Most
	operations are not inspected and pretending otherwise would put a gate in
	front of every cut.
	"""
	required = bool(
		card.get("operation_id")
		and frappe.db.get_value("Work Order Operation", card["operation_id"], "quality_inspection_required")
		and frappe.db.get_value(
			"BOM", frappe.db.get_value("Job Card", card["name"], "bom_no"), "inspection_required"
		)
	)
	status = None
	if card.get("quality_inspection"):
		status = frappe.db.get_value("Quality Inspection", card["quality_inspection"], "status")
	return {
		"inspection_required": required,
		"quality_inspection": card.get("quality_inspection"),
		"inspection_status": status,
	}


def _current_card(work_order: str) -> dict | None:
	"""The card the floor is on: the one running, else the first not finished.

	Sequence comes from the routing, so "next" is the routing's next and not a
	guess from how much has been done.
	"""
	cards = [card for card in _cards_for([work_order]) if card["status"] not in CARD_DONE]
	if not cards:
		return None
	running = [card for card in cards if card["status"] == "Work In Progress"]
	return (running or cards)[0]


def shop_floor(work_order: str | None = None, workstation: str | None = None):
	"""What every station is doing, from Job Cards.

	Job Cards are ERPNext's record of an operation actually happening — they are
	created when a Work Order is submitted, so nothing here creates one. Progress
	is `total_completed_qty` against `for_quantity`, both ERPNext's own running
	totals rather than a second tally kept beside them.
	"""
	if work_order:
		ensure_company("Work Order", work_order)
		jobs = [work_order]
	else:
		jobs = frappe.get_list(
			"Work Order",
			filters=scoped({"docstatus": 1, "status": ["in", ("Not Started", "In Process")]}),
			pluck="name",
			limit_page_length=0,
		)

	cards = [
		card
		for card in _cards_for(jobs)
		if not workstation or card["workstation"] == workstation
	]

	stations: dict[str, dict] = {}
	for card in cards:
		entry = stations.setdefault(
			card["workstation"], {"workstation": card["workstation"], "running": [], "queued": []}
		)
		row = {
			"job_card": card["name"],
			"work_order": card["work_order"],
			"operation": card["operation"],
			"status": card["status"],
			**_card_quantities(card),
			# Kept for callers written before scrap existed. It is the *good*
			# figure, which is what it always was.
			"completed_qty": flt(card["total_completed_qty"]),
			"remaining_qty": round(
				flt(card["for_quantity"])
				- flt(card["total_completed_qty"])
				- flt(card["process_loss_qty"]),
				3,
			),
			"sequence": card["sequence_id"],
			"started_at": str(card["actual_start_date"]) if card["actual_start_date"] else None,
			**_inspection_state(card),
		}
		if card["status"] == "Work In Progress":
			entry["running"].append(row)
		elif card["status"] not in CARD_DONE:
			entry["queued"].append(row)

	return {
		"as_of": nowdate(),
		"summary": {
			"operations_running": sum(len(s["running"]) for s in stations.values()),
			"operations_waiting": sum(len(s["queued"]) for s in stations.values()),
			"workstations_busy": len([s for s in stations.values() if s["running"]]),
		},
		"workstations": sorted(stations.values(), key=lambda s: s["workstation"]),
	}


def _resolve_card(work_order: str | None, sales_order: str | None, operation: str | None):
	"""Which card the user means.

	A person says «раскрой закончен», not a card number. So the order is found
	first, then the operation by name, and failing that whatever the floor is
	currently on.
	"""
	if not (work_order or sales_order):
		frappe.throw("Name an order or a work order.")

	if not work_order:
		ensure_company("Sales Order", sales_order)
		jobs = frappe.get_list(
			"Work Order",
			filters=scoped({"sales_order": sales_order, "docstatus": 1}),
			fields=["name", "production_item", "qty", "produced_qty", "status"],
			order_by="creation asc",
		)
		if not jobs:
			frappe.throw(f"{sales_order} has no work order, so nothing is being made for it yet.")
		open_jobs = [row for row in jobs if row["status"] not in ("Completed", "Stopped", "Closed")]
		candidates = open_jobs or jobs
		if len(candidates) > 1:
			# Never the newest, never the first. Booking an operation against
			# the wrong job records work on a customer's order that nobody did.
			frappe.throw(
				f"{sales_order} has {len(candidates)} work orders on the floor. "
				"Say which one:\n"
				+ "\n".join(
					f"  {row['name']} — {row['production_item']}, "
					f"{flt(row['produced_qty'])} of {flt(row['qty'])} made, {row['status']}"
					for row in candidates
				)
			)
		work_order = candidates[0]["name"]

	ensure_company("Work Order", work_order)

	if operation:
		matching = [
			card
			for card in _cards_for([work_order])
			if card["operation"].casefold() == operation.casefold()
		]
		# An operation can have more than one card once a stage has been split
		# for rework: the good pieces went out on a submitted card and the held
		# piece waits on a draft one. The unfinished card is the one anybody
		# naming the operation means.
		open_matching = [card for card in matching if card["docstatus"] == 0]
		if open_matching:
			matching = open_matching
		elif matching:
			# Every card for this stage is closed. If more pieces have since
			# reached it — a rework came back — it needs a fresh one.
			caught_up = _catch_up_card(work_order, matching[0]["operation"], matching)
			if caught_up:
				return work_order, caught_up
		if not matching:
			known = ", ".join(sorted({c["operation"] for c in _cards_for([work_order])}))
			frappe.throw(f"{work_order} has no operation '{operation}'. It has: {known}.")
		return work_order, matching[0]

	card = _current_card(work_order)
	if not card:
		frappe.throw(f"Every operation on {work_order} is already finished.")
	return work_order, card


def start_operation(
	operation: str | None = None,
	sales_order: str | None = None,
	work_order: str | None = None,
):
	"""Mark an operation as under way — «начали кромление».

	Recorded as a Job Card time log, which is what moves the card to Work In
	Progress and what a shop floor is actually paid against. Nothing is invented
	beside it.
	"""
	work_order, card = _resolve_card(work_order, sales_order, operation)

	if card["docstatus"] == 1 or card["status"] == "Completed":
		return {
			"status": "already_complete",
			"job_card": card["name"],
			"operation": card["operation"],
			"message": f"{card['operation']} is already finished.",
		}
	if card["status"] == "Work In Progress":
		# Not an error, and not a second time log either — two open logs would
		# double the hours this operation is costed at.
		return {
			"status": "already_running",
			"job_card": card["name"],
			"operation": card["operation"],
			"workstation": card["workstation"],
			"message": f"{card['operation']} is already under way.",
		}

	doc = frappe.get_doc("Job Card", card["name"])
	doc.check_permission("write")
	doc.append("time_logs", {"from_time": now_datetime()})
	doc.save()

	doc.reload()
	return {
		"status": "started",
		"job_card": doc.name,
		"work_order": work_order,
		"operation": doc.operation,
		"workstation": doc.workstation,
		"job_card_status": doc.status,
		"for_quantity": flt(doc.for_quantity),
		"completed_qty": flt(doc.total_completed_qty),
		"started_at": str(doc.time_logs[-1].from_time),
	}


def complete_operation(
	operation: str | None = None,
	sales_order: str | None = None,
	work_order: str | None = None,
	qty: float | None = None,
	scrap_qty: float | None = None,
	rework_qty: float | None = None,
):
	"""Finish an operation — «раскрой закончен», «сделали 4, 1 в брак».

	Submitting the Job Card is what updates the Work Order Operation's completed
	quantity and status, and therefore what makes the next operation the current
	one. That update is ERPNext's, not ours.

	## Good, scrapped and not yet attempted

	A card carries three quantities and ERPNext enforces the relation between
	them on save:

	    total_completed_qty + process_loss_qty + pending_qty == for_quantity

	`total_completed_qty` is **good** output; process loss is already excluded
	from it. So `scrap_qty` here is not a second tally kept beside ERPNext's —
	it is the card's `process_loss_qty`, and `pending_qty` is whatever the
	arithmetic leaves. Reporting the good figure alone would let two scrapped
	panels quietly become finished goods.

	The card is **submitted only when nothing is pending**. "Сделали 4, 1 в брак"
	on a card for 10 leaves 5 to attempt, and a submitted card cannot be
	returned to; the rest is booked by calling this again.

	Written through ERPNext's own `Job Card.complete_job_card`, which is what
	the desk button calls — including its quality-inspection gate.
	"""
	work_order, card = _resolve_card(work_order, sales_order, operation)

	if card["docstatus"] == 1 or card["status"] == "Completed":
		# Saying it twice must not book the hours or the quantity twice.
		return {
			"status": "already_complete",
			"job_card": card["name"],
			"operation": card["operation"],
			**_card_quantities(card),
			"message": f"{card['operation']} was already finished.",
		}

	doc = frappe.get_doc("Job Card", card["name"])
	doc.check_permission("submit")

	# Sending a piece back to the bench for another attempt. The stage was
	# already split, so there is nothing to complete and nothing to split
	# again — only a fresh corrective card against the card still holding it.
	on_hold = any(row["name"] == doc.name for row in _hold_cards(work_order, doc.operation))
	if on_hold and not flt(rework_qty or 0):
		# The fate of a piece at the rework bench belongs to the rework result,
		# not to an ordinary "стадия закончена". Without this, saying the stage
		# was finished books the held piece as good output and a defective
		# cabinet walks back into the batch with nobody having repaired it.
		frappe.throw(
			f"{doc.operation}: {flt(doc.for_quantity)} шт. на исправлении. "
			"Скажите, чем закончилось исправление, прежде чем закрывать этап."
		)
	if on_hold and flt(rework_qty or 0) > 0:
		if _corrective_card(work_order, doc.name):
			return {
				"status": "already_in_rework",
				"job_card": doc.name,
				"work_order": work_order,
				"operation": doc.operation,
				"message": f"{doc.operation}: деталь уже на исправлении.",
			}
		again = _open_rework(doc, min(flt(rework_qty), flt(doc.for_quantity)))
		return {
			"status": "sent_to_rework",
			"job_card": doc.name,
			"work_order": work_order,
			"operation": doc.operation,
			"rework_job_card": again,
			"sent_to_rework": min(flt(rework_qty), flt(doc.for_quantity)),
			"message": f"{doc.operation}: деталь снова отправлена на исправление.",
		}

	booked = flt(doc.total_completed_qty)
	scrapped_before = flt(doc.process_loss_qty)
	room = round(flt(doc.for_quantity) - booked - scrapped_before, 3)
	if room <= 0:
		return {
			"status": "already_complete",
			"job_card": doc.name,
			"operation": doc.operation,
			**_card_quantities(card),
			"message": f"Every unit on {doc.operation} is already accounted for.",
		}

	scrap = flt(scrap_qty) if scrap_qty else 0.0
	if scrap < 0:
		frappe.throw("Scrap quantity cannot be negative.")
	rework = flt(rework_qty) if rework_qty else 0.0
	if rework < 0:
		frappe.throw("Rework quantity cannot be negative.")
	if rework and scrap and rework + scrap > room:
		frappe.throw(
			f"{doc.operation} has {room} pieces left to account for, and "
			f"{scrap} scrapped plus {rework} for rework is more than that."
		)
	# Units held for rework stay **pending** rather than becoming loss. A
	# scrapped unit is gone; one on its way to the rework bench is not, and
	# ERPNext's own card arithmetic already has a place for it. Booking it as
	# process loss would be a decision nobody has taken yet — and process loss
	# on a submitted card cannot be taken back.
	if rework > room - scrap:
		rework = round(max(0.0, room - scrap), 3)

	# What the user says was finished, or everything still unaccounted for —
	# capped at what the stages before this one actually passed on, with the
	# shortfall carried forward as this stage's loss. See `_upstream_good`.
	carried = 0.0
	resized = False
	if qty is None:
		available = round(room - scrap - rework, 3)
		upstream = _upstream_good(work_order, doc.sequence_id)
		if upstream is not None:
			reachable = round(max(0.0, upstream - booked), 3)
			if reachable < available:
				shortfall = round(available - reachable, 3)
				# Pieces the stages before this one are still holding for rework
				# are not lost, and booking them as this stage's process loss
				# would write off something that may yet come back. They are
				# simply not here: the card is resized to what arrived, and the
				# held piece gets a card of its own if and when it is recovered.
				held = min(shortfall, _held_before(work_order, doc.sequence_id))
				carried = round(shortfall - held, 3)
				available = reachable
				if held > 0:
					doc.for_quantity = round(flt(doc.for_quantity) - held, 3)
					resized = True
		asked = available
		scrap = round(scrap + carried, 3)
	else:
		asked = flt(qty)
	if asked < 0:
		frappe.throw("Quantity cannot be negative.")
	if asked + scrap <= 0:
		frappe.throw("Quantity must be greater than zero.")

	# Never more than the card was opened for. ERPNext would refuse the save
	# anyway; trimming here means "сделали 400" on a card for 10 books 10.
	if asked + scrap + rework > room:
		asked = round(max(0.0, room - scrap - rework), 3)
	adjusted = asked != (flt(qty) if qty is not None else asked)

	# The quality gate, checked before anything is written.
	#
	# ERPNext throws this on *submit*, by which point `complete_job_card` has
	# already saved the quantities and closed the time log — so the card is left
	# booked but unsubmitted, and the next attempt reports it as finished. Same
	# shape as the orphaned draft in Phase 12: the check has to happen before
	# the write, not during it.
	#
	# Only the unconditional case is pre-empted. A *rejected* or unsubmitted
	# inspection is governed by `Stock Settings`, which may say warn rather than
	# stop, and second-guessing that would be our rule instead of the ERP's.
	state = _inspection_state(card)
	if state["inspection_required"] and not state["quality_inspection"]:
		frappe.throw(
			f"{doc.operation} is an inspected stage and has no quality result yet. "
			"Record whether it passed before closing it."
		)

	open_log = next((row for row in doc.time_logs if not row.to_time and row.from_time), None)
	if open_log is None:
		# Finished without anyone having said it started — normal on a floor
		# where the card is only touched once. ERPNext's own completion path
		# closes an open log rather than creating one, so there has to be one.
		#
		# It starts where the last job on that workstation ended. An hour-wide
		# window used to be invented instead, and three of these operations
		# share the paint-and-assembly bench: completing them in one sitting
		# produced overlapping time logs and ERPNext refused the card. Jobs on
		# one machine run one after another, so that is what is recorded.
		doc.append("time_logs", {"from_time": _bench_free_from(doc)})
		doc.save()
		doc.reload()

	# Pieces going to the rework bench move to a card of their own, and this one
	# is resized to the pieces that are actually finished. Otherwise the whole
	# stage waits on one damaged panel — see `_split_off_hold`.
	hold_card = None
	rework_card = None
	if rework > 0:
		doc.for_quantity = round(flt(doc.for_quantity) - rework, 3)
		resized = True

	if resized:
		doc.save()
		doc.reload()

	pending = round(flt(doc.for_quantity) - booked - asked - scrapped_before - scrap, 3)
	# ERPNext's own entry point — the one the desk button calls. It validates
	# the quantities, writes `process_loss_qty`, and on submit runs the
	# quality-inspection gate and pushes everything to the Work Order Operation.
	doc.complete_job_card(
		qty=asked,
		pending_qty=max(0.0, pending),
		process_loss_qty=scrapped_before + scrap,
		end_time=now_datetime(),
		auto_submit=pending <= 0,
	)

	if rework > 0:
		hold_card = _split_off_hold(doc, rework)
		rework_card = _open_rework(frappe.get_doc("Job Card", hold_card), rework)

	# Read back what ERPNext now says rather than what was intended.
	doc.reload()
	fresh = next((c for c in _cards_for([work_order]) if c["name"] == doc.name), None) or card
	following = _current_card(work_order)
	job = frappe.get_doc("Work Order", work_order)
	return {
		"status": "completed" if doc.docstatus == 1 else "partially_completed",
		"job_card": doc.name,
		"work_order": work_order,
		"operation": doc.operation,
		"workstation": doc.workstation,
		**_card_quantities(fresh),
		"booked_now": asked,
		"scrapped_now": scrap,
		"sent_to_rework": rework,
		"held_job_card": hold_card,
		"rework_job_card": rework_card,
		# Units this stage could not work on because an earlier one lost them.
		# Reported apart from what was spoiled here, so a report of scrap at the
		# saw does not read as scrap at the paint booth as well.
		"carried_forward_loss": carried,
		"adjusted": adjusted,
		"job_card_status": doc.status,
		"work_order_status": job.status,
		"produced_qty": flt(job.produced_qty),
		# Scrap at the work-order level, summed by ERPNext from its operations.
		"work_order_scrap_qty": flt(job.process_loss_qty),
		**_inspection_state(fresh),
		"next_operation": following["operation"] if following else None,
		"next_workstation": following["workstation"] if following else None,
	}


def _floor_verdict(work_order: str) -> str | None:
	"""The ОТК verdict on this job — "Accepted", "Rejected", or nothing yet.

	Recorded against a Job Card by `record_inspection`. Read as a *status*
	rather than as a document, because the document cannot be reused: ERPNext
	re-points a Quality Inspection at whatever transaction links it, so
	attaching the ОТК inspection to a Manufacture entry moves it off the job
	card and the next release finds nothing. One inspection belongs to one
	document.
	"""
	cards = [card["name"] for card in _cards_for([work_order])]
	if not cards:
		return None
	rows = frappe.get_all(
		"Quality Inspection",
		filters={"reference_type": "Job Card", "reference_name": ["in", cards], "docstatus": 1},
		fields=["status"],
		order_by="creation desc",
	)
	return rows[0]["status"] if rows else None


def _carry_verdict(entry, verdict: str) -> None:
	"""Record the floor's verdict against the goods this entry receives.

	ERPNext asks a Manufacture entry for an inspection of its finished item
	whenever the bill of materials is marked for inspection, and it must be a
	document of that entry's own. So the ОТК result is written onto one — the
	same verdict, applied to the batch being received.

	Nothing is decided here. The status is whatever a person recorded at ОТК; a
	rejection is written as a rejection, and ERPNext then refuses the entry
	under `Stock Settings`. What this must never do is upgrade a rejection into
	something the shelf will accept.
	"""
	verdicts = {}
	for row in entry.items:
		if not row.is_finished_item or row.quality_inspection:
			continue
		doc = frappe.get_doc(
			{
				"doctype": "Quality Inspection",
				"inspection_type": "In Process",
				"reference_type": "Stock Entry",
				"reference_name": entry.name,
				"item_code": row.item_code,
				"sample_size": flt(row.qty),
				"inspected_by": frappe.session.user,
				"status": verdict,
				"remarks": f"ОТК: {verdict}",
				"company": current_company(),
			}
		)
		doc.insert()
		doc.submit()
		verdicts[row.idx] = doc.name

	if not verdicts:
		return
	# Submitting an inspection writes back to the entry, so the copy in hand is
	# a version behind and saving it would raise a timestamp mismatch.
	entry.reload()
	for row in entry.items:
		if row.idx in verdicts:
			row.quality_inspection = verdicts[row.idx]
	entry.save()


def _inspection_demanded(work_order: str) -> bool:
	"""Whether ERPNext will ask the Manufacture entry for an inspection.

	`BOM.inspection_required` is the switch, and it governs the finished-item
	row of the stock entry — `QualityInspectionService.validate_inspection`
	throws on submit without one. Read from the ERP rather than assumed, so a
	product whose bill of materials is not inspected is not gated.
	"""
	bom = frappe.db.get_value("Work Order", work_order, "bom_no")
	return bool(bom and frappe.db.get_value("BOM", bom, "inspection_required"))


def stop_production(
	action: str = "stop",
	sales_order: str | None = None,
	work_order: str | None = None,
	reason: str | None = None,
):
	"""Halt or restart a job — «останови производство», «возобнови заказ».

	A shop needs this more often than it would like: a customer postpones, a
	board turns out to be the wrong colour, a machine goes down. Until now a job
	could only ever go forwards, so a cancelled order kept asking for material
	in the shortage report and kept taking a slot in the capacity queue for as
	long as it existed.

	`Work Order.stop_unstop` is ERPNext's own, the method the desk's Stop button
	calls. Its `update_planned_qty` is what releases the material the job had
	reserved — which is the point: stopped work should stop competing for board
	that another order can use.

	Nothing is un-made. Stopping does not touch what has already been produced,
	consumed or transferred; it stops the job going any further.
	"""
	from erpnext.manufacturing.doctype.work_order.work_order import stop_unstop

	intent = (action or "").strip().casefold()
	# Resuming is checked first: "возобнови" and "останови" share no stem, but
	# "не останавливай" contains one of them, and of the two ways to be wrong
	# only stopping a running job interrupts a floor.
	resuming = any(
		word in intent
		for word in ("возобнов", "продолж", "resume", "unstop", "restart", "снова", "запусти")
	)
	stopping = any(
		word in intent for word in ("останов", "приостанов", "стоп", "stop", "pause", "halt")
	)
	if resuming:
		wanted = "Resumed"
	elif stopping:
		wanted = "Stopped"
	else:
		frappe.throw("Say whether the job should be stopped or resumed.")

	if not (sales_order or work_order):
		frappe.throw("Name an order or a work order.")
	if not work_order:
		work_order = _the_only_job(sales_order, "stopped" if wanted == "Stopped" else "resumed")

	ensure_company("Work Order", work_order)
	job = frappe.get_doc("Work Order", work_order)
	job.check_permission("write")

	if sales_order and job.sales_order and job.sales_order != sales_order:
		frappe.throw(
			f"{work_order} belongs to {job.sales_order}, not {sales_order}. "
			"Say which order you mean."
		)
	if job.docstatus != 1:
		frappe.throw(f"{work_order} is not submitted, so there is nothing running to stop.")
	if job.status == "Closed":
		frappe.throw(f"{work_order} is closed, and a closed job cannot be stopped or reopened.")

	already = (wanted == "Stopped" and job.status == "Stopped") or (
		wanted == "Resumed" and job.status != "Stopped"
	)
	if already:
		# Saying it twice must not move stock or reservations twice.
		return {
			"status": "already_stopped" if wanted == "Stopped" else "already_running",
			"work_order": work_order,
			"sales_order": job.sales_order,
			"item_code": job.production_item,
			"work_order_status": job.status,
			"message": (
				f"{work_order} is already stopped."
				if wanted == "Stopped"
				else f"{work_order} is not stopped — it is {job.status}."
			),
		}

	reserved_before = _reserved_for_job(job)
	stop_unstop(work_order, wanted)

	job.reload()
	events.production_stopped(work_order, resumed=wanted != "Stopped", reason=reason)
	return {
		"status": "stopped" if wanted == "Stopped" else "resumed",
		"work_order": work_order,
		"sales_order": job.sales_order,
		"item_code": job.production_item,
		"qty": flt(job.qty),
		"produced_qty": flt(job.produced_qty),
		"remaining_qty": round(flt(job.qty) - flt(job.produced_qty) - flt(job.process_loss_qty), 3),
		"work_order_status": job.status,
		"reason": reason,
		# What the floor gets back, or gives up. ERPNext's own reservation,
		# read either side of the call rather than predicted.
		"material_reserved_before": reserved_before,
		"material_reserved_now": _reserved_for_job(job),
		"message": (
			f"{work_order} остановлен. Материал больше не зарезервирован за ним."
			if wanted == "Stopped"
			else f"{work_order} снова в работе."
		),
	}


def _reserved_for_job(job) -> list[dict]:
	"""What this job is currently holding in the store, per ERPNext's own Bin.

	One query, not one per row: a job with seven materials would otherwise make
	seven round trips to answer a question nobody asked in that shape.
	"""
	items = [row.item_code for row in job.required_items]
	if not items or not job.source_warehouse:
		return []
	bins = {
		row["item_code"]: flt(row["reserved_qty_for_production"])
		for row in frappe.get_all(
			"Bin",
			filters={"item_code": ["in", items], "warehouse": job.source_warehouse},
			fields=["item_code", "reserved_qty_for_production"],
		)
	}
	return [
		{"item_code": code, "reserved_qty": bins.get(code, 0.0)}
		for code in items
		if bins.get(code)
	]


def complete_rework(
	result: str = "fixed",
	operation: str | None = None,
	sales_order: str | None = None,
	work_order: str | None = None,
	qty: float | None = None,
):
	"""Close a rework — «исправление завершено», «не удалось исправить».

	The unit went to the rework bench as `pending` on the original card rather
	than as loss, precisely so that this call can decide which it becomes. Two
	documents move:

	1. The **corrective job card** is completed and submitted. That is ERPNext's
	   record of the rework itself — its time lands on the work order as
	   `corrective_operation_cost`, the cost of poor quality, and it carries no
	   production quantity by design.
	2. The **original card** books the held units: as good output if the rework
	   worked, as process loss if it did not.

	So a recovered unit reaches finished goods through exactly the path every
	other unit does, and a failed rework is scrap — recorded once, on the card
	whose operation lost it.
	"""
	verdict = (result or "").strip().casefold()
	# Negation is checked first and separately. "не исправили" contains
	# "исправили", so a plain membership test on the positive words reads a
	# failure as a success — and that failure would put a broken cabinet on the
	# shelf. Of the two ways to be wrong here, only one is dangerous.
	# Three outcomes, and the order of these checks is the whole safety of it.
	# "не исправили" contains "исправили", so a positive match must never be
	# tried first — a failed rework read as a success puts a broken cabinet on
	# the shelf.
	#
	# Failing is not the same as writing off. A piece that could not be fixed
	# this time is still at the bench and can be tried again; only "в брак"
	# ends it, and that is irreversible once the card submits.
	written_off = any(word in verdict for word in ("брак", "списать", "scrap", "write off"))
	failed = any(
		word in verdict
		for word in ("не ", "fail", "не удалось", "не получилось", "нельзя", "unsuccessful")
	)
	fixed = any(
		word in verdict
		for word in ("fixed", "repaired", "исправ", "починил", "готово", "успешно", "ok")
	)
	if written_off:
		outcome = "scrapped"
	elif failed:
		outcome = "unresolved"
	elif fixed:
		outcome = "recovered"
	else:
		frappe.throw(
			"Say whether the rework succeeded, failed, or the piece is scrap."
		)
	recovered = outcome == "recovered"

	if not (sales_order or work_order):
		frappe.throw("Name an order or a work order.")
	if not work_order:
		work_order, _card = _resolve_card(work_order, sales_order, None)
	ensure_company("Work Order", work_order)

	# The verdict is about the *piece*, which lives on the holding card. The
	# corrective card is about one *attempt* at fixing it, and it is submitted
	# the moment that attempt is recorded — so after a failed try there is no
	# open one, and looking for it first made "списать в брак" answer that
	# nothing was at the bench while the piece sat there untouched.
	holds = _hold_cards(work_order, operation)
	if not holds:
		return {
			"status": "nothing_in_rework",
			"work_order": work_order,
			"operation": operation,
			"message": (
				f"Nothing is at the rework bench for {operation} on this job."
				if operation
				else "No piece is at the rework bench for this job."
			),
		}

	origin = frappe.get_doc("Job Card", holds[0]["name"])
	rework = _corrective_card(work_order, origin.name)
	origin.check_permission("submit")
	held = flt(origin.for_quantity) - flt(origin.total_completed_qty) - flt(origin.process_loss_qty)
	moving = min(flt(qty), held) if qty else held
	if moving <= 0:
		return {
			"status": "nothing_in_rework",
			"work_order": work_order,
			"job_card": origin.name,
			"message": f"{origin.operation} has nothing waiting on a rework result.",
		}

	# 1. The attempt, if one is open. Writing a piece off does not require
	#    another go at fixing it first.
	card = None
	if rework:
		card = frappe.get_doc("Job Card", rework["name"])
		card.check_permission("submit")
		if not card.time_logs or all(row.to_time for row in card.time_logs):
			card.append("time_logs", {"from_time": _bench_free_from(card)})
			card.save()
			card.reload()
		card.complete_job_card(
			qty=flt(card.for_quantity),
			pending_qty=0,
			process_loss_qty=0,
			end_time=now_datetime(),
			auto_submit=True,
		)

	# 2. What the held pieces became.
	#
	# An unresolved attempt writes nothing to the holding card: the pieces stay
	# exactly where they were, and another rework can be opened for them. Only
	# a recovery or a write-off settles the card, and once it submits neither
	# can be undone.
	origin.reload()
	operation_name = origin.operation
	if recovered:
		if not origin.time_logs or all(row.to_time for row in origin.time_logs):
			origin.append("time_logs", {"from_time": _bench_free_from(origin)})
			origin.save()
			origin.reload()
		remaining = round(held - moving, 3)
		origin.complete_job_card(
			qty=moving,
			pending_qty=max(0.0, remaining),
			process_loss_qty=flt(origin.process_loss_qty),
			end_time=now_datetime(),
			auto_submit=remaining <= 0,
		)
		origin.reload()
	elif outcome == "scrapped":
		# The holding card is removed rather than submitted as pure loss.
		#
		# ERPNext derives process loss in `Job Card.set_process_loss` and only
		# when the card completed something: a card that produced nothing has
		# its loss reset to zero, and then completed + loss + pending no longer
		# equals what it was opened for, so it cannot be submitted at all. A
		# card that is entirely loss has no expression in that model.
		#
		# So the piece simply never arrives. The stage stays at the pieces that
		# passed, and the stages after it carry the missing one forward as their
		# loss — which is Phase 23's mechanism, already proven, and collapses
		# under the maximum ERPNext takes across operations.
		frappe.delete_doc("Job Card", origin.name, force=1, ignore_permissions=True)
	# Reported at the stage, not at the card. A stage split for rework has two
	# cards, and "сколько годных на раскрое" means the operation's total — the
	# figure ERPNext itself rolls up and the one every downstream check reads.
	stage = frappe.db.get_value(
		"Work Order Operation",
		{"parent": work_order, "operation": operation_name},
		["completed_qty", "process_loss_qty"],
		as_dict=True,
	) or {}
	job = frappe.get_doc("Work Order", work_order)
	return {
		"status": outcome,
		"work_order": work_order,
		"operation": operation_name,
		"job_card": origin.name,
		"rework_job_card": card.name if card else None,
		"reworked_qty": moving,
		"for_quantity": flt(job.qty),
		"good_qty": flt(stage.get("completed_qty")),
		"scrap_qty": flt(stage.get("process_loss_qty")),
		"pending_qty": round(
			flt(job.qty) - flt(stage.get("completed_qty")) - flt(stage.get("process_loss_qty")), 3
		),
		"job_card_status": origin.status if outcome != "scrapped" else "Cancelled",
		"work_order_status": job.status,
		"produced_qty": flt(job.produced_qty),
		"rework_cost": flt(job.corrective_operation_cost),
		"can_try_again": outcome == "unresolved",
		"message": {
			"recovered": f"{operation_name}: {moving} исправлено и возвращено в годные.",
			"unresolved": (
				f"{operation_name}: {moving} исправить не удалось. "
				"Деталь осталась в браке — можно попробовать ещё раз или списать."
			),
			"scrapped": f"{operation_name}: {moving} списано в брак.",
		}[outcome],
	}


def record_inspection(
	result: str,
	operation: str | None = None,
	sales_order: str | None = None,
	work_order: str | None = None,
	remarks: str | None = None,
):
	"""Record the ОТК verdict on an operation — «ОТК принял», «ОТК забраковал».

	A separate confirmed step rather than an argument on completion, because it
	is a separate decision made by a different person, and because ERPNext keeps
	it as its own document with its own submit.

	The inspection is only meaningful where ERPNext asks for one: the bill of
	materials must have `inspection_required` and the operation
	`quality_inspection_required`. Recording one anywhere else would put a
	quality gate in front of every cut, which is not what the ERP models and not
	what a shop does.

	Nothing about the *quantities* is decided here. A failed inspection does not
	silently become scrap — ERPNext's `Stock Settings` decides whether a
	rejected inspection stops the job card or warns, and that setting is
	reported back rather than second-guessed. What a failure must never do is
	pass unnoticed into finished goods, and the card's own gate is what prevents
	that.
	"""
	verdict = (result or "").strip().casefold()
	if verdict in ("accepted", "pass", "passed", "принято", "принят", "годно", "ok"):
		status = "Accepted"
	elif verdict in ("rejected", "fail", "failed", "брак", "забраковано", "забракован"):
		status = "Rejected"
	else:
		frappe.throw("Say whether the inspection passed or failed.")

	work_order, card = _resolve_card(work_order, sales_order, operation)
	state = _inspection_state(card)
	if not state["inspection_required"]:
		return {
			"status": "not_required",
			"job_card": card["name"],
			"operation": card["operation"],
			"work_order": work_order,
			"message": (
				f"{card['operation']} is not an inspected operation on this order, "
				"so there is no inspection to record."
			),
		}
	if state["quality_inspection"]:
		return {
			"status": "already_inspected",
			"job_card": card["name"],
			"operation": card["operation"],
			"quality_inspection": state["quality_inspection"],
			"inspection_status": state["inspection_status"],
			"message": (
				f"{card['operation']} was already inspected — "
				f"{state['inspection_status']}."
			),
		}

	doc = frappe.get_doc("Job Card", card["name"])
	doc.check_permission("write")
	if doc.docstatus == 1:
		frappe.throw(
			f"{card['operation']} is already submitted, and an inspection after the "
			"fact would change nothing on it."
		)

	if not frappe.has_permission("Quality Inspection", "submit"):
		frappe.throw(
			"You can prepare an inspection but not submit one, and an unsubmitted "
			"inspection does not count."
		)

	inspection = frappe.get_doc(
		{
			"doctype": "Quality Inspection",
			"inspection_type": "In Process",
			"reference_type": "Job Card",
			"reference_name": doc.name,
			"item_code": doc.production_item,
			"sample_size": flt(doc.for_quantity),
			"quality_inspection_template": doc.quality_inspection_template,
			"inspected_by": frappe.session.user,
			"status": status,
			"remarks": remarks,
			"company": current_company(),
		}
	)
	inspection.insert()
	inspection.submit()

	# The link is what `Job Card.validate_inspection` reads on submit. Reloaded
	# first: a failed completion attempt just before this leaves the in-memory
	# copy behind the database, and saving it raises "modified after you have
	# opened it" — which reads like a concurrency problem and is really a stale
	# read in the same request.
	doc.reload()
	doc.quality_inspection = inspection.name
	doc.save()

	rejected_action = frappe.db.get_single_value(
		"Stock Settings", "action_if_quality_inspection_is_rejected"
	)
	return {
		"status": "recorded",
		"job_card": doc.name,
		"work_order": work_order,
		"operation": doc.operation,
		"quality_inspection": inspection.name,
		"inspection_status": inspection.status,
		"item_code": doc.production_item,
		# What ERPNext will do with a rejection when the card is submitted. Its
		# setting, reported — not a rule invented here.
		"rejection_blocks_completion": status == "Rejected" and rejected_action == "Stop",
		"message": (
			f"{doc.operation}: инспекция {inspection.name} — {inspection.status}."
		),
	}


# --------------------------------------------------------------------------
# Closing production
# --------------------------------------------------------------------------


def complete_production(
	sales_order: str | None = None,
	work_order: str | None = None,
	qty: float | None = None,
):
	"""Release finished goods — «производство закончено, выпусти товар».

	The boundary that matters. A completed job card records that an operation
	*happened*; it puts nothing on a shelf. Only a **Manufacture** stock entry
	consumes the raw material out of work-in-progress and receives the finished
	units into finished goods, and until it runs there is nothing to deliver.

	ERPNext's own `make_stock_entry(work_order, "Manufacture", qty)` builds it:
	it drains WIP per the bill of materials, receives the product into the work
	order's finished-goods warehouse, carries the routing's operating cost, and
	its submit is what moves `produced_qty`. None of that is reimplemented.
	"""
	from erpnext.manufacturing.doctype.work_order.mapper import make_stock_entry

	if not (sales_order or work_order):
		frappe.throw("Name an order or a work order.")

	if not work_order:
		work_order = _the_only_job(sales_order, "released")

	ensure_company("Work Order", work_order)
	job = frappe.get_doc("Work Order", work_order)
	job.check_permission("read")

	# A model that names both must name them consistently. Two customers order
	# the same product here, so "выпусти Тумбу Караганда" is genuinely
	# ambiguous — and releasing against the wrong job would consume another
	# order's material.
	if sales_order and job.sales_order and job.sales_order != sales_order:
		frappe.throw(
			f"{work_order} belongs to {job.sales_order}, not {sales_order}. "
			"Say which order you mean."
		)

	if job.docstatus != 1:
		frappe.throw(f"{work_order} is not submitted, so nothing can be released against it.")
	if job.status in ("Stopped", "Closed", "Cancelled"):
		frappe.throw(f"{work_order} is {job.status}.")

	# Scrapped units are gone, not outstanding. A job for ten that made eight
	# and lost two is finished, and asking for two more would consume material
	# for cabinets nobody is going to build. `process_loss_qty` is ERPNext's own
	# roll-up from the operations, and its status logic uses the same sum.
	scrapped = flt(job.process_loss_qty)
	# Pieces still at the rework bench are neither good nor lost, and they are
	# certainly not on a shelf. Releasing the batch while one is being fixed
	# would receive it as finished goods on the strength of a repair nobody has
	# reported yet.
	held_for_rework = sum(flt(row["for_quantity"]) for row in _hold_cards(work_order))
	remaining = round(flt(job.qty) - flt(job.produced_qty) - scrapped - held_for_rework, 3)
	if remaining <= 0:
		# Everything planned has already been released. Not an error, and not a
		# second stock entry either — that would put units on the shelf that
		# were never built.
		return {
			"status": "already_complete",
			"work_order": work_order,
			"item_code": job.production_item,
			"qty": flt(job.qty),
			"produced_qty": flt(job.produced_qty),
			"scrap_qty": scrapped,
			"held_for_rework": held_for_rework,
			"message": (
				f"All {flt(job.qty)} units are accounted for: "
				f"{flt(job.produced_qty)} made"
				+ (f", {scrapped} scrapped." if scrapped else ".")
			),
		}

	wanted = flt(qty) if qty else remaining
	if wanted <= 0:
		frappe.throw("Quantity must be greater than zero.")

	stages = work_order_stages(work_order)
	# `fg_completed_qty` is the batch that was *started*, not the good units
	# that came out of it. ERPNext deducts the operations' process loss from it
	# to arrive at what is received (`Stock Entry.set_process_loss_qty` takes
	# the maximum across the operations), so releasing the good figure has the
	# loss taken off twice: five started with one spoiled, asked for as four,
	# put three on the shelf. Measured on the device, and it is the one number
	# in this phase that a person would never think to check.
	#
	# So whatever is asked for, the loss the floor has already recorded is added
	# back before the entry is built.
	unaccounted = max(
		0.0,
		max(
			[flt(row["scrap_qty"]) for row in stages["operations"]] or [0.0],
		)
		- scrapped,
	)
	releasing = round(min(wanted + unaccounted, remaining), 3)
	adjusted = releasing - unaccounted < wanted - 0.001

	if not frappe.has_permission("Stock Entry", "submit"):
		frappe.throw(
			"You can prepare a manufacturing entry but not submit one, and an "
			"unsubmitted entry moves no stock."
		)

	entry = frappe.get_doc(make_stock_entry(work_order, "Manufacture", releasing))
	entry.posting_date = nowdate()

	# Goods this shop inspects cannot be received without the verdict.
	#
	# ERPNext gates the finished-item row of a Manufacture entry whenever the
	# bill of materials asks for inspection, and it is the same check the ОТК
	# operation runs — so the verdict recorded there is carried onto the row
	# rather than a fresh inspection being conjured at the moment of release.
	# That is what stops rejected work becoming finished goods: there is no
	# accepted inspection to carry, and the entry does not submit.
	verdict = _floor_verdict(work_order) if _inspection_demanded(work_order) else None
	if _inspection_demanded(work_order) and not verdict:
		frappe.throw(
			f"{job.production_item} is inspected before it goes to finished goods, "
			f"and {work_order} has no quality result on record. "
			"Record whether it passed first."
		)

	entry.insert()
	if verdict:
		_carry_verdict(entry, verdict)
	entry.submit()

	# Read back what ERPNext now says rather than what was intended.
	job.reload()
	events.production_completed(work_order)
	return {
		"status": "released",
		"work_order": work_order,
		"sales_order": job.sales_order,
		"item_code": job.production_item,
		"stock_entry": entry.name,
		"released_qty": releasing,
		"requested_qty": wanted,
		"adjusted": adjusted,
		"qty": flt(job.qty),
		"produced_qty": flt(job.produced_qty),
		"scrap_qty": flt(job.process_loss_qty),
		"held_for_rework": held_for_rework,
		"remaining_qty": round(
			flt(job.qty) - flt(job.produced_qty) - flt(job.process_loss_qty) - held_for_rework, 3
		),
		"work_order_status": job.status,
		"finished_goods_warehouse": job.fg_warehouse,
		"consumed": [
			{"item_code": row.item_code, "qty": flt(row.qty), "uom": row.uom, "from_warehouse": row.s_warehouse}
			for row in entry.items
			if row.s_warehouse
		],
		# Reported, not enforced: ERPNext permits a Manufacture entry whatever
		# the job cards say, and inventing a block on top of it would be our
		# rule rather than the ERP's. The floor's own state is shown so a
		# person can judge.
		"current_operation": stages["current_operation"],
		"operations_outstanding": len(
			[row for row in stages["operations"] if row["status"] != "Completed"]
		),
	}


register(
	ToolSpec(
		name="manufacturing.start_production",
		description=(
			"Put a sales order into production: plan the work order if there is "
			"none, then move the material into work-in-progress. Use when the "
			"user says «запусти производство», «начни делать», and also «подай "
			"материал» or «продолжи производство» for a job that is already "
			"running but has consumed what was transferred to it — the next "
			"batch needs its own material before it can be built. Refuses if the "
			"material is not physically on the shelf — ordered is not received. "
			"Requires confirmation before anything moves."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {"type": "string", "description": "The order to start producing"},
				"item_code": {
					"type": "string",
					"description": "Only when the order has several products and the user named one.",
				},
			},
			"required": ["sales_order"],
		},
		handler=_api().start_production,
		risk=Risk.WRITE,
		doctypes=("Work Order", "Stock Entry"),
		audit_category="manufacturing",
		timeout=60,
	)
)


register(
	ToolSpec(
		name="manufacturing.shop_floor",
		description=(
			"What every workstation is doing right now: which operation is "
			"running, what is queued behind it, and how much of each is done. "
			"Use for «что сейчас на станке», «сколько сделано», «что сейчас "
			"выполняется». Report its numbers as given."
		),
		input_schema={
			"type": "object",
			"properties": {
				"work_order": {"type": "string", "description": "Narrow to one job."},
				"workstation": {"type": "string", "description": "Narrow to one station."},
			},
			"required": [],
		},
		handler=shop_floor,
		risk=Risk.READ,
		doctypes=("Job Card", "Work Order"),
		audit_category="manufacturing",
	)
)

register(
	ToolSpec(
		name="manufacturing.start_operation",
		description=(
			"Record that a production stage has begun — «начали кромление», "
			"«запустили раскрой». Name the operation and the order; the job card "
			"is found from them. Requires confirmation."
		),
		input_schema={
			"type": "object",
			"properties": {
				"operation": {
					"type": "string",
					"description": "The stage, e.g. Раскрой. Omit for whichever is current.",
				},
				"sales_order": {"type": "string", "description": "The customer order it belongs to"},
				"work_order": {"type": "string", "description": "Or the work order directly"},
			},
			"required": [],
		},
		handler=start_operation,
		risk=Risk.WRITE,
		doctypes=("Job Card",),
		audit_category="manufacturing",
	)
)

register(
	ToolSpec(
		name="manufacturing.complete_operation",
		description=(
			"Record that a production stage is finished — «раскрой закончен», "
			"«кромление готово», «сделали 4, одну в брак». Pass qty only if the "
			"user said how many were good; otherwise everything still "
			"outstanding is taken. Pass scrap_qty when the user says pieces were "
			"spoiled, rejected or written off — never fold them into qty. The "
			"stage stays open until every piece is accounted for, so a partial "
			"run can be finished later. Requires confirmation."
		),
		input_schema={
			"type": "object",
			"properties": {
				"operation": {
					"type": "string",
					"description": "The stage that finished. Omit for whichever is current.",
				},
				"sales_order": {"type": "string", "description": "The customer order it belongs to"},
				"work_order": {"type": "string", "description": "Or the work order directly"},
				"qty": {
					"type": "number",
					"description": "How many pieces came out good, if the user said.",
				},
				"scrap_qty": {
					"type": "number",
					"description": (
						"How many were spoiled beyond saving — «в брак», «списали». "
						"Counted apart from qty and never as finished goods."
					),
				},
				"rework_qty": {
					"type": "number",
					"description": (
						"How many are to be fixed rather than written off — «на "
						"переделку», «на исправление», «можно исправить». They are "
						"held, not lost, until manufacturing.complete_rework says "
						"which they became."
					),
				},
			},
			"required": [],
		},
		handler=complete_operation,
		risk=Risk.WRITE,
		doctypes=("Job Card",),
		audit_category="manufacturing",
		timeout=60,
	)
)

register(
	ToolSpec(
		name="manufacturing.stop_production",
		description=(
			"Halt a job or put it back to work — «останови производство», "
			"«приостанови заказ», «возобнови производство», «продолжай этот "
			"заказ». Stopping frees the material the job had reserved so other "
			"orders can use it; nothing already made or consumed is undone. "
			"Requires confirmation."
		),
		input_schema={
			"type": "object",
			"properties": {
				"action": {
					"type": "string",
					"description": "«останови» to halt the job, «возобнови» to put it back to work.",
				},
				"sales_order": {"type": "string", "description": "The customer order it belongs to"},
				"work_order": {"type": "string", "description": "Or the work order directly"},
				"reason": {
					"type": "string",
					"description": "Why, if the user said — «клиент перенёс», «сломался станок».",
				},
			},
			"required": ["action"],
		},
		handler=stop_production,
		risk=Risk.WRITE,
		doctypes=("Work Order",),
		audit_category="manufacturing",
		timeout=60,
	)
)

register(
	ToolSpec(
		name="manufacturing.complete_rework",
		description=(
			"Close a rework that was sent with complete_operation — «исправление "
			"завершено», «починили», «не удалось исправить, в брак». Records the "
			"rework effort and returns the piece to good output, or writes it off "
			"if it could not be saved. Requires confirmation."
		),
		input_schema={
			"type": "object",
			"properties": {
				"result": {
					"type": "string",
					"description": (
						"How it ended: «исправлено» if the piece was saved, «не "
						"удалось» if this attempt failed and it can be tried "
						"again, «в брак» to write it off for good."
					),
				},
				"operation": {
					"type": "string",
					"description": (
						"Which stage's rework, e.g. Раскрой. Omit unless more "
						"than one stage is holding a piece."
					),
				},
				"sales_order": {"type": "string", "description": "The customer order it belongs to"},
				"work_order": {"type": "string", "description": "Or the work order directly"},
				"qty": {
					"type": "number",
					"description": "How many of the held pieces this result covers, if fewer than all.",
				},
			},
			"required": ["result"],
		},
		handler=complete_rework,
		risk=Risk.WRITE,
		doctypes=("Job Card", "Work Order"),
		audit_category="manufacturing",
		timeout=60,
	)
)

register(
	ToolSpec(
		name="manufacturing.record_inspection",
		description=(
			"Record the quality-control verdict on a production stage — «ОТК "
			"принял», «ОТК забраковал», «контроль пройден». Only stages the bill "
			"of materials marks for inspection have one; for the rest this "
			"reports that none is needed. Requires confirmation."
		),
		input_schema={
			"type": "object",
			"properties": {
				"result": {
					"type": "string",
					"description": "Whether it passed or failed — «принято» or «брак».",
				},
				"operation": {
					"type": "string",
					"description": "The stage inspected. Omit for whichever is current.",
				},
				"sales_order": {"type": "string", "description": "The customer order it belongs to"},
				"work_order": {"type": "string", "description": "Or the work order directly"},
				"remarks": {"type": "string", "description": "What the inspector noted, if anything."},
			},
			"required": ["result"],
		},
		handler=record_inspection,
		risk=Risk.WRITE,
		doctypes=("Quality Inspection", "Job Card"),
		audit_category="manufacturing",
		timeout=60,
	)
)


register(
	ToolSpec(
		name="manufacturing.complete_production",
		description=(
			"Release finished goods from a work order — «производство закончено», "
			"«выпусти готовую продукцию», «мы изготовили 5 штук». This is what "
			"consumes the raw material and puts finished units on the shelf; "
			"completing an operation does not. Pass qty only if the user said how "
			"many. Requires confirmation."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {"type": "string", "description": "The customer order being made"},
				"work_order": {"type": "string", "description": "Or the work order directly"},
				"qty": {
					"type": "number",
					"description": "How many units were finished, if the user said.",
				},
			},
			"required": [],
		},
		handler=complete_production,
		risk=Risk.WRITE,
		doctypes=("Stock Entry", "Work Order"),
		audit_category="manufacturing",
		timeout=60,
	)
)
