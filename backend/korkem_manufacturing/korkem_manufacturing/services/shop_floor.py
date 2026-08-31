# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The shop floor: finishing a stage, and everything that decides what that means.

Moved out of `korkem_ai/tools/production.py` **unchanged**, the second action
of Horizon 1. Like the first, nothing here was ever about an assistant — it is
what happens when somebody at a workstation says the stage is done, and the
terminal, the desktop, a Telegram reply and the model must all reach the same
one (ADR-0003, ADR-0007).

## The arithmetic ERPNext owns, and we must not duplicate

A `Job Card` carries three quantities and ERPNext enforces their relation on
save:

    total_completed_qty + process_loss_qty + pending_qty == for_quantity

`total_completed_qty` is **good** output, with process loss already excluded.
So scrap is not a second tally kept beside ERPNext's — it *is* the card's
`process_loss_qty`. Reporting the good figure alone would let two spoiled
panels quietly become finished goods.

The card is submitted **only when nothing is pending**: "сделали 4, одну в
брак" on a card for ten leaves five still to attempt, and a submitted card
cannot be returned to. Everything is written through ERPNext's own
`Job Card.complete_job_card`, which is what the desk button calls — including
its quality-inspection gate.

## Why this drags twelve helpers with it

Deciding *which* card a person means, whether a piece is at the rework bench,
what the upstream stage actually produced and whether the bench is free are all
one question with one answer. `shop_floor` and `start_operation` ask it too and
still live in the tool layer, so `tools/production.py` re-exports these names
until those actions migrate — one definition, reached from two places, rather
than a copy that can drift.

Unlike `start_production`, nothing here announces a business event: the
notifications for process loss and quality live elsewhere, keyed off documents
rather than off this call.
"""

from __future__ import annotations

import frappe
from frappe.utils import add_to_date, flt, get_datetime, now_datetime

from korkem_manufacturing.services.scope import ensure_company, scoped

#: An operation is done, running, or waiting — ERPNext's own three.
DONE = "Completed"
RUNNING = "Work in Progress"


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
