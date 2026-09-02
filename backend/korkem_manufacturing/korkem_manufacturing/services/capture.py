# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Catching what somebody said before it can be forgotten.

The product's sharpest problem statement came from an interview, not from us:

    the customer calls · the owner is standing at the CNC machine · he writes
    the size on a notepad · he keeps working · in the evening he is supposed to
    move it into a spreadsheet · sometimes he forgets · the task never reaches
    the measurer · the order is late

Nothing in that chain is a production problem. The loss happens between hearing
and recording, and it happens because his hands are busy. His own words for what
he wants: *a digital administrator I can tell everything by voice.*

So this service does two things, and the second is the one a notepad cannot do:

1. **Record what was said, immediately**, whatever state the rest of the world
   is in — no model, no network, no decision about what kind of thing it is.
2. **Hand the follow-up to a person, with a date.** A notepad remembers; it does
   not assign. The order was late because nobody was told, not because nobody
   wrote it down.

Everything else about a capture — turning it into a lead, a quotation, an
order — happens later, by people who are not holding a workpiece.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped

# ADR-0023: a task attaches to any doctype through Frappe's native polymorphic
# reference pair, so a CRM Task can point at a Capture with no schema change.
# The same mechanism already carries tasks on Work Orders.
TASK_DOCTYPE = "CRM Task"

UNDERSTOOD_FIELDS = (
	"customer_hint",
	"product_hint",
	"material_hint",
	"size_hint",
	"due_hint",
	"next_action_hint",
)


def record(
	*,
	text: str,
	spoken_at: str | None = None,
	source: str = "Voice",
	understood: dict | None = None,
	assign_to: str | None = None,
	due_on: str | None = None,
) -> dict:
	"""Store one utterance, and optionally hand its follow-up to somebody.

	`understood` is whatever the model managed to pull out of the sentence, and
	it is **optional on purpose**. With no model configured, or with the model
	unreachable, the sentence is still recorded verbatim and still becomes
	somebody's task. That is rule R7 where it matters most: the feature that
	replaces the notepad cannot be the feature that needs a working LLM.
	"""
	text = (text or "").strip()
	if not text:
		frappe.throw("A capture with nothing said is not a capture.")

	capture = frappe.get_doc(
		{
			"doctype": "Capture",
			"spoken_text": text,
			"spoken_at": spoken_at or frappe.utils.now_datetime(),
			"company": _company(),
			"source": source if source in ("Voice", "Text", "Channel") else "Text",
			"status": "Understood" if understood else "Recorded",
			**_understood_fields(understood),
		}
	)
	capture.insert()

	task = None
	if assign_to:
		task = _hand_over(capture, assign_to, due_on)

	return {
		"capture": capture.name,
		"status": capture.status,
		"task": task,
		"assigned_to": assign_to if task else None,
		"understood": {
			field: capture.get(field) for field in UNDERSTOOD_FIELDS if capture.get(field)
		},
	}


def stats(days: int = 30) -> dict:
	"""The four numbers that answer "can I not hire an administrator".

	An administrator's job, as this owner describes it, is to catch what was
	said and make sure somebody acts on it. So the honest measure is not usage
	but outcome: how much was caught, how much was handed to a person, how much
	turned into work, and how much went stale.

	`stale` is the number that matters, because it is the one the notepad was
	losing. A capture nobody was told about, still sitting there after a day, is
	the same failure as a forgotten note — just visible.
	"""
	days = max(1, min(int(days or 30), 365))
	since = frappe.utils.add_days(frappe.utils.nowdate(), -days)
	base = scoped({"creation": [">=", since]})

	caught = _count(base)
	handed_over = _count({**base, "task": ["is", "set"]})
	converted = _count({**base, "status": "Converted"})
	dismissed = _count({**base, "status": "Dismissed"})

	stale = _count(
		{
			**base,
			"task": ["is", "not set"],
			"status": ["in", ["Recorded", "Understood"]],
			"creation": ["<", frappe.utils.add_to_date(frappe.utils.now_datetime(), hours=-24)],
		}
	)

	return {
		"days": days,
		"caught": caught,
		"handed_over": handed_over,
		"converted": converted,
		"dismissed": dismissed,
		"stale": stale,
	}


def _count(filters: dict) -> int:
	# Permission-aware, and counted the way `api.queries._total` does — never
	# through `frappe.client.get_count`, which drags the request's own arguments
	# into the query.
	return len(
		frappe.get_list("Capture", filters=filters, pluck="name", limit_page_length=0)
	)


def _company() -> str:
	company = scoped().get("company")
	if not company:
		frappe.throw("No company in scope; a capture must belong to one.")
	return company


def _understood_fields(understood: dict | None) -> dict:
	if not understood:
		return {}
	return {
		field: understood.get(field)
		for field in UNDERSTOOD_FIELDS
		if understood.get(field)
	}


def _hand_over(capture, assign_to: str, due_on: str | None) -> str:
	"""Create the follow-up task, pointed back at what was said.

	The title carries the sentence rather than a reference number: the person
	opening their tasks needs to know what this is about without a second tap,
	and "Capture a3f9c1" tells them nothing.
	"""
	title = capture.spoken_text.strip().replace("\n", " ")
	task = frappe.get_doc(
		{
			"doctype": TASK_DOCTYPE,
			"title": title[:140],
			"description": capture.spoken_text,
			"assigned_to": assign_to,
			"status": "Todo",
			"due_date": due_on or capture.due_hint,
			"reference_doctype": "Capture",
			"reference_docname": capture.name,
		}
	)
	task.insert()

	capture.db_set("task", str(task.name), update_modified=False)
	return str(task.name)
