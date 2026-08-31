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


# The shop floor moved to the domain in Horizon 1's second action. Imported
# back rather than duplicated: `shop_floor` and `start_operation` below, plus
# `control.py`, still reach these names through this module, and one definition
# reached from two places cannot drift the way a copy can.
from korkem_manufacturing.services.shop_floor import (  # noqa: F401
	CARD_DONE,
	CORRECTIVE_OPERATION,
	_bench_free_from,
	_card_quantities,
	_cards_for,
	_catch_up_card,
	_corrective_card,
	_current_card,
	_held_before,
	_hold_cards,
	_inspection_state,
	_open_rework,
	_resolve_card,
	_split_off_hold,
	_upstream_good,
	complete_operation,
)


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
		handler=_api().complete_operation,
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
