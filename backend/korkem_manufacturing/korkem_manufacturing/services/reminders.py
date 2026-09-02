# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Remember the follow-up the factory owner did not have time to remember.

This is deliberately a clock and a set of database predicates, not an agent.
It must work with no model configured.  Delivery is also deliberately absent
from this domain service: it emits the same domain events as production does,
and the already-existing notification app decides how the owner is reached.

Idempotency lives in ``Notification Delivery.event_key``.  Each event below is
identified by its kind, recipient and subject document, so re-running this job
finds the same unique row.  A task that is both overdue and unassigned is
collapsed into one event with two reasons before it is emitted; the owner must
not receive two reminders about the same task in one tick either.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing import domain_events

STALE_CAPTURE = "reminder.capture_stale"
MEASUREMENT_TASK = "reminder.measurement_task"


def run() -> dict:
	"""Find forgotten stage-one work and emit one reminder per subject."""
	now = frappe.utils.now_datetime()
	stale = _stale_captures(now)
	tasks = _measurement_tasks_needing_attention(now)

	for row in stale:
		domain_events.emit(STALE_CAPTURE, capture=row.name, company=row.company)

	for row in tasks.values():
		domain_events.emit(
			MEASUREMENT_TASK,
			task=row["name"],
			capture=row["capture"],
			company=row["company"],
			overdue=row["overdue"],
			unassigned=row["unassigned"],
		)

	return {
		"stale_captures": len(stale),
		"overdue_tasks": sum(bool(row["overdue"]) for row in tasks.values()),
		"unassigned_tasks": sum(bool(row["unassigned"]) for row in tasks.values()),
		"subjects": len(stale) + len(tasks),
	}


def _stale_captures(now) -> list[frappe._dict]:
	return frappe.get_all(
		"Capture",
		filters={
			"task": ["is", "not set"],
			"status": ["in", ["Recorded", "Understood"]],
			"creation": ["<", frappe.utils.add_to_date(now, hours=-24)],
		},
		fields=["name", "company"],
		limit_page_length=0,
	)


def _measurement_tasks_needing_attention(now) -> dict[str, dict]:
	"""Return Capture follow-ups, merging every reason by CRM Task.

	CRM Task has no task-type field.  The factual discriminator available at
	this stage is its polymorphic reference to Capture: these are precisely the
	stage-one follow-ups created from what the owner said.  Production tasks and
	other CRM tasks are therefore not guessed to be measurements.
	"""
	tasks: dict[str, dict] = {}

	for row in _task_rows({"due_date": ["<", now]}):
		_task_reason(tasks, row, overdue=True)
	for row in _task_rows({"assigned_to": ["is", "not set"]}):
		_task_reason(tasks, row, unassigned=True)

	return tasks


def _task_rows(extra_filters: dict) -> list[frappe._dict]:
	return frappe.get_all(
		"CRM Task",
		filters={
			"reference_doctype": "Capture",
			"status": ["!=", "Done"],
			**extra_filters,
		},
		fields=["name", "reference_docname"],
		# A default 20-row page would starve every later item forever: the same
		# first 20 are found next hour and then deduplicated by delivery keys.
		limit_page_length=0,
	)


def _task_reason(tasks: dict[str, dict], row, **reason: bool) -> None:
	capture = frappe.db.get_value(
		"Capture", row.reference_docname, ["name", "company"], as_dict=True
	)
	if not capture:
		# A broken dynamic link has no company and therefore no safe owner.  It is
		# not broadened to a role broadcast; repair of the task is a data issue.
		return
	key = str(row.name)
	item = tasks.setdefault(
		key,
		{
			"name": row.name,
			"capture": capture.name,
			"company": capture.company,
			"overdue": False,
			"unassigned": False,
		},
	)
	item.update(reason)
