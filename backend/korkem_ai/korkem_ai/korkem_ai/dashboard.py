# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The mobile home screen, as one request.

A dashboard is six or seven counts. Asking for them one HTTP call at a time is
six or seven round trips over a factory Wi-Fi that is frequently poor -- the
latency, not the query cost, is what makes it slow. This assembles them
in-process and answers once.

Two rules shape everything here.

**Permissions are not bypassed.** Every count goes through
`frappe.client.get_count`, which routes to `reportview.get_count` and therefore
applies the same permission query conditions as the list views. That matters
concretely on this site: Frappe CRM restricts `CRM Deal` and `CRM Lead` to the
owner and assignees, so a sales rep's dashboard must show *their* pipeline, not
the company's. Counting with `frappe.db.count` would have silently leaked it.

**A metric the caller may not see is `None`, never `0`.** "No deals" and "not
allowed to know" are different facts, and a tile reading a confident zero when
the truth is "no access" is worse than one reading a dash.
"""

import frappe
from frappe.utils import now_datetime

OPEN_TASK_STATUSES = ("Backlog", "Todo", "In Progress")
CLOSED_DEAL_STATUSES = ("Won", "Lost")

ATTENTION_LIMIT = 5


@frappe.whitelist()
def get_summary() -> dict:
	"""Counts and a short attention list for the signed-in user."""
	user = frappe.session.user
	now = now_datetime()

	return {
		"user": user,
		"generated_at": str(now),
		"metrics": {
			"open_deals": _count(
				"CRM Deal",
				[["status", "not in", list(CLOSED_DEAL_STATUSES)]],
			),
			"open_leads": _count("CRM Lead", []),
			"my_open_tasks": _count(
				"CRM Task",
				[
					["status", "in", list(OPEN_TASK_STATUSES)],
					["assigned_to", "=", user],
				],
			),
			"overdue_tasks": _count(
				"CRM Task",
				[
					["status", "in", list(OPEN_TASK_STATUSES)],
					["due_date", "<", now],
				],
			),
			"pending_actions": _count("Pending Action", [["status", "=", "Pending"]]),
			"work_orders_in_progress": _count(
				"Work Order",
				[["status", "=", "In Process"]],
			),
		},
		"attention": _attention(user, now),
	}


def _count(doctype: str, filters: list) -> int | None:
	"""A permission-aware count, or None when the caller may not look.

	`frappe.client.get_count` is reused rather than reimplemented so this cannot
	drift from what the list screens themselves report.
	"""
	if not frappe.db.exists("DocType", doctype):
		# An app the site does not have installed is not an error here; the
		# tile simply has nothing to show.
		return None

	try:
		return frappe.client.get_count(doctype, filters=filters)
	except frappe.PermissionError:
		_discard_permission_message()
		return None


def _discard_permission_message():
	"""Drop the "Insufficient Permission" note Frappe queued on the way out.

	A refused count is an expected outcome here, not a failure -- the response is
	still a 200. Left in place, the message rides along in `_server_messages`,
	and any competent client (ours included) parses that field and shows it to
	the user as an error over a request that actually succeeded.
	"""
	frappe.clear_last_message()


def _attention(user: str, now) -> list[dict]:
	"""What the user should look at first: decisions, then overdue work.

	Pending Actions outrank overdue tasks because they block an AI agent that is
	waiting on a human -- nothing else in the system moves until one is resolved.
	"""
	items: list[dict] = []

	for action in _safe_list(
		"Pending Action",
		filters={"status": "Pending"},
		fields=["name", "agent_skill", "entity_type", "entity_name", "expires_at"],
		order_by="creation asc",
		limit=ATTENTION_LIMIT,
	):
		items.append(
			{
				"kind": "pending_action",
				"name": str(action.name),
				"title": action.agent_skill or "Pending action",
				"subtitle": f"{action.entity_type or ''} {action.entity_name or ''}".strip(),
				"due": str(action.expires_at) if action.expires_at else None,
			}
		)

	remaining = ATTENTION_LIMIT - len(items)
	if remaining <= 0:
		return items

	for task in _safe_list(
		"CRM Task",
		filters={
			"status": ["in", list(OPEN_TASK_STATUSES)],
			"due_date": ["<", now],
		},
		fields=["name", "title", "due_date", "reference_docname"],
		order_by="due_date asc",
		limit=remaining,
	):
		items.append(
			{
				"kind": "overdue_task",
				"name": str(task.name),
				"title": task.title,
				"subtitle": task.reference_docname or "",
				"due": str(task.due_date) if task.due_date else None,
			}
		)

	return items


def _safe_list(doctype: str, **kwargs) -> list:
	"""`frappe.get_list` -- which applies permissions, unlike `frappe.get_all`.

	The distinction is easy to get wrong and expensive here: `get_all` would
	hand a sales rep every other rep's overdue work.
	"""
	if not frappe.db.exists("DocType", doctype):
		return []

	try:
		return frappe.get_list(doctype, **kwargs)
	except frappe.PermissionError:
		_discard_permission_message()
		return []
