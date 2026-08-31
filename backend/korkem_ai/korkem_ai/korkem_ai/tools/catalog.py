# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The read tools, and nothing else yet.

Every doctype and every fieldname below was read off the running site with
`frappe.get_meta`, not taken from memory or from a plan document. That matters
more here than anywhere: a tool that queries a field which does not exist fails
at the moment a user is watching, and a tool that queries the *wrong* field
succeeds and lies.

Facts this catalogue is built on, all verified:

* `CRM Task.name` is an **integer** — its `autoname` is `autoincrement`. Typing
  a task id as a string is a real bug on this backend, not a hypothetical.
* `CRM Task.status` is one of Backlog / Todo / In Progress / Done / Canceled,
  and `priority` is Low / Medium / High.
* `CRM Deal.status` and `CRM Lead.status` are **Links**, not Selects, so their
  allowed values live in a doctype rather than in an enum here.
* The customer-shaped doctype in Frappe CRM is `CRM Organization`. There is no
  `Customer` doctype in the CRM app; ERPNext's `Customer` is a different thing
  and is not what the deals point at.
* `Work Order` carries `originating_deal`, a custom field added by
  `korkem_manufacturing`, which is how a work order is traced back to a sale.

Writes are deliberately absent. They arrive with the confirmation flow, not
before it — a write tool that exists before there is anything to stop it being
called unattended is exactly the risk ADR-0015 is about.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai.tools import registry
from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register

#: Hard ceiling on rows returned to a model, whatever it asks for.
#:
#: Two reasons, and cost is the lesser one. A thousand-row JSON blob is mostly
#: tokens the model cannot use, and burying the three rows that matter in a
#: list of a thousand measurably degrades the answer. Ask a narrower question.
MAX_LIMIT = 50
DEFAULT_LIMIT = 20

_LIMIT_SCHEMA = {
	"type": "integer",
	"minimum": 1,
	"maximum": MAX_LIMIT,
	"description": f"How many rows to return (default {DEFAULT_LIMIT}, max {MAX_LIMIT}).",
}


def _limit(value: int | None) -> int:
	if not value:
		return DEFAULT_LIMIT
	return max(1, min(int(value), MAX_LIMIT))


def _like(term: str) -> str:
	return f"%{term.strip()}%"


# --------------------------------------------------------------------------
# CRM
# --------------------------------------------------------------------------


def search_deals(status: str | None = None, search: str | None = None, limit: int | None = None):
	filters = {}
	if status:
		filters["status"] = status
	if search:
		filters["organization"] = ["like", _like(search)]

	rows = frappe.get_list(
		"CRM Deal",
		filters=filters,
		fields=[
			"name",
			"organization",
			"status",
			"deal_owner",
			"expected_deal_value",
			"expected_closure_date",
			"modified",
		],
		limit=_limit(limit),
		order_by="modified desc",
	)
	return {"deals": rows, "count": len(rows)}


def get_deal(name: str):
	deal = frappe.get_doc("CRM Deal", name)
	deal.check_permission("read")
	return {
		"name": deal.name,
		"organization": deal.organization,
		"status": deal.status,
		"deal_owner": deal.deal_owner,
		"expected_deal_value": deal.expected_deal_value,
		"expected_closure_date": deal.expected_closure_date,
		"probability": deal.probability,
		"next_step": deal.next_step,
		"modified": deal.modified,
	}


def search_organizations(search: str | None = None, limit: int | None = None):
	"""Organizations are what this CRM calls customers."""
	filters = {}
	if search:
		filters["organization_name"] = ["like", _like(search)]

	rows = frappe.get_list(
		"CRM Organization",
		filters=filters,
		fields=["name", "organization_name", "industry", "territory", "website", "modified"],
		limit=_limit(limit),
		order_by="modified desc",
	)
	return {"organizations": rows, "count": len(rows)}


def search_leads(status: str | None = None, search: str | None = None, limit: int | None = None):
	filters = {}
	if status:
		filters["status"] = status
	if search:
		filters["lead_name"] = ["like", _like(search)]

	rows = frappe.get_list(
		"CRM Lead",
		filters=filters,
		fields=["name", "lead_name", "organization", "status", "lead_owner", "modified"],
		limit=_limit(limit),
		order_by="modified desc",
	)
	return {"leads": rows, "count": len(rows)}


# --------------------------------------------------------------------------
# Tasks
# --------------------------------------------------------------------------

OPEN_TASK_STATUSES = ("Backlog", "Todo", "In Progress")


def list_tasks(
	status: str | None = None,
	overdue: bool | None = None,
	assigned_to_me: bool | None = None,
	limit: int | None = None,
):
	filters = {}
	if status:
		filters["status"] = status
	elif overdue:
		# "Overdue" means past due and not finished. Without this, a task
		# completed last month still matches "due before today" and the answer
		# is confidently wrong.
		filters["status"] = ["in", OPEN_TASK_STATUSES]

	if overdue:
		filters["due_date"] = ["<", frappe.utils.now_datetime()]

	if assigned_to_me:
		filters["assigned_to"] = frappe.session.user

	rows = frappe.get_list(
		"CRM Task",
		filters=filters,
		fields=[
			"name",
			"title",
			"status",
			"priority",
			"due_date",
			"assigned_to",
			"reference_doctype",
			"reference_docname",
		],
		limit=_limit(limit),
		order_by="due_date asc",
	)
	# `name` is an integer here; it is stringified on the way out so the model
	# echoes back something that round-trips through JSON unchanged.
	for row in rows:
		row["name"] = str(row["name"])
	return {"tasks": rows, "count": len(rows)}


# --------------------------------------------------------------------------
# Production
# --------------------------------------------------------------------------


def list_work_orders(status: str | None = None, limit: int | None = None):
	filters = {}
	if status:
		filters["status"] = status

	rows = frappe.get_list(
		"Work Order",
		filters=filters,
		fields=[
			"name",
			"production_item",
			"item_name",
			"status",
			"qty",
			"produced_qty",
			"planned_end_date",
			"originating_deal",
		],
		limit=_limit(limit),
		order_by="planned_end_date asc",
	)
	return {"work_orders": rows, "count": len(rows)}


# --------------------------------------------------------------------------
# Session
# --------------------------------------------------------------------------


def current_user():
	"""Who the assistant is acting as.

	Not vanity: "my tasks" and "my deals" are meaningless without it, and it is
	the one piece of context the model cannot look up any other way.
	"""
	user = frappe.get_doc("User", frappe.session.user)
	return {
		"user": user.name,
		"full_name": user.full_name,
		"roles": sorted(frappe.get_roles(user.name)),
	}


# --------------------------------------------------------------------------
# Registration
# --------------------------------------------------------------------------

register(
	ToolSpec(
		name="crm.search_deals",
		description=(
			"Search deals in the CRM. Returns the caller's own deals only — "
			"this CRM restricts deals to their owner and assignees."
		),
		input_schema={
			"type": "object",
			"properties": {
				"status": {"type": "string", "description": "Exact deal status, e.g. 'Open'."},
				"search": {"type": "string", "description": "Match on organization name."},
				"limit": _LIMIT_SCHEMA,
			},
		},
		risk=Risk.READ,
		handler=search_deals,
		doctypes=("CRM Deal",),
	)
)

register(
	ToolSpec(
		name="crm.get_deal",
		description="Read one deal by its id, e.g. CRM-DEAL-2026-00001.",
		input_schema={
			"type": "object",
			"properties": {"name": {"type": "string"}},
			"required": ["name"],
		},
		risk=Risk.READ,
		handler=get_deal,
		doctypes=("CRM Deal",),
	)
)

register(
	ToolSpec(
		name="crm.search_organizations",
		description="Search customer organizations by name.",
		input_schema={
			"type": "object",
			"properties": {"search": {"type": "string"}, "limit": _LIMIT_SCHEMA},
		},
		risk=Risk.READ,
		handler=search_organizations,
		doctypes=("CRM Organization",),
	)
)

register(
	ToolSpec(
		name="crm.search_leads",
		description="Search leads in the CRM.",
		input_schema={
			"type": "object",
			"properties": {
				"status": {"type": "string"},
				"search": {"type": "string", "description": "Match on lead name."},
				"limit": _LIMIT_SCHEMA,
			},
		},
		risk=Risk.READ,
		handler=search_leads,
		doctypes=("CRM Lead",),
	)
)

register(
	ToolSpec(
		name="tasks.list",
		description=(
			"List CRM tasks. Use overdue=true for tasks past their due date that "
			"are not finished, and assigned_to_me=true for the caller's own."
		),
		input_schema={
			"type": "object",
			"properties": {
				"status": {
					"type": "string",
					"enum": ["Backlog", "Todo", "In Progress", "Done", "Canceled"],
				},
				"overdue": {"type": "boolean"},
				"assigned_to_me": {"type": "boolean"},
				"limit": _LIMIT_SCHEMA,
			},
		},
		risk=Risk.READ,
		handler=list_tasks,
		doctypes=("CRM Task",),
	)
)

# `production.list_work_orders` is deliberately **not registered**.
#
# It and `manufacturing.search_work_orders` read the same doctype and answer the
# same business question, and offering both to a model is not redundancy but
# confusion: in a live run Gemini called each of them once in a single turn,
# spending a round trip to learn nothing new. The canonical tool is
# `manufacturing.search_work_orders`, which filters by sales order and item and
# returns `remaining_qty`.
#
# The function below stays: `production_readiness` calls it directly in Python,
# and the mobile client still maps the old name to a progress label so
# transcripts recorded before this change keep reading correctly.

register(
	ToolSpec(
		name="profile.current_user",
		description="Who the assistant is acting as, and which roles they hold.",
		input_schema={"type": "object", "properties": {}},
		risk=Risk.READ,
		handler=current_user,
		doctypes=(),
	)
)


# --------------------------------------------------------------------------
# Writes
# --------------------------------------------------------------------------
#
# The first tool that changes anything. Everything above this line is a read
# that runs unattended; this one stops the turn and waits for a person.
#
# Its shape is dictated by the real `CRM Lead` doctype, read from
# `frappe.get_meta` rather than assumed: `first_name` and `status` are the only
# required fields, `status` is a **Link** to `CRM Lead Status` (not a Select),
# `organization` is a plain **Data** field (not a link to an organisation
# record), and the name comes from a naming series.

#: Statuses a model may open a *new* lead in.
#:
#: Narrower than the doctype allows, deliberately. `Converted` and `Junk` are
#: outcomes of a sales process, not opening states, and an assistant that
#: opened a lead as "Converted" would corrupt every funnel report in the
#: product. The link table stays the authority; this only limits the choice.
NEW_LEAD_STATUSES = ("New Lead", "Contacted", "Nurture", "Qualified")

DEFAULT_LEAD_STATUS = "New Lead"


def create_lead(
	first_name: str,
	last_name: str | None = None,
	organization: str | None = None,
	email: str | None = None,
	mobile_no: str | None = None,
	job_title: str | None = None,
	source: str | None = None,
	status: str | None = None,
):
	"""Create one CRM Lead.

	Never reached directly from the agent loop: this is `Risk.WRITE`, so the
	loop stops and the call is written down as a Pending Action first. It runs
	only from `PendingAction.approve()`, with the arguments a human saw.

	`frappe.get_doc(...).insert()` rather than a direct insert, so the CRM's own
	validation, naming series and permission checks all apply — the assistant
	gets no privileged path into the database that a person does not have.
	"""
	status = status or DEFAULT_LEAD_STATUS
	if status not in NEW_LEAD_STATUSES:
		frappe.throw(
			f"'{status}' is not a status a new lead may open in. "
			f"Choose one of: {', '.join(NEW_LEAD_STATUSES)}.",
			exc=registry.ToolError,
		)

	# Link targets are checked against the real tables rather than trusted, so a
	# hallucinated source becomes a sentence the model can act on instead of a
	# Frappe LinkValidationError it cannot.
	if source and not frappe.db.exists("CRM Lead Source", source):
		frappe.throw(f"Unknown lead source '{source}'.", exc=registry.ToolError)

	if not frappe.db.exists("CRM Lead Status", status):
		frappe.throw(f"Unknown lead status '{status}'.", exc=registry.ToolError)

	lead = frappe.get_doc(
		{
			"doctype": "CRM Lead",
			"first_name": first_name.strip(),
			"last_name": (last_name or "").strip() or None,
			"organization": (organization or "").strip() or None,
			"email": (email or "").strip() or None,
			"mobile_no": (mobile_no or "").strip() or None,
			"job_title": (job_title or "").strip() or None,
			"source": source,
			"status": status,
			# Whoever asked owns what they created. Leaving this to Frappe's
			# default would hand the lead to somebody who is not the person who
			# will be chased about it.
			"lead_owner": frappe.session.user,
		}
	)
	lead.insert()

	return {
		"lead_id": lead.name,
		"lead_name": lead.lead_name,
		"organization": lead.organization,
		"status": lead.status,
		"lead_owner": lead.lead_owner,
	}


register(
	ToolSpec(
		name="crm.create_lead",
		description=(
			"Create a new lead in the CRM. Requires the person's first name. "
			"Ask the user for anything you do not know rather than inventing it — "
			"an invented phone number is worse than a missing one. "
			"The user must confirm before this runs."
		),
		input_schema={
			"type": "object",
			"properties": {
				"first_name": {"type": "string", "description": "Given name. Required."},
				"last_name": {"type": "string"},
				"organization": {"type": "string", "description": "Company name, free text."},
				"email": {"type": "string"},
				"mobile_no": {"type": "string"},
				"job_title": {"type": "string"},
				"source": {
					"type": "string",
					"description": "How the lead arrived, e.g. Referral, Website, Cold Call.",
				},
				"status": {
					"type": "string",
					"enum": list(NEW_LEAD_STATUSES),
					"description": f"Opening status. Defaults to {DEFAULT_LEAD_STATUS}.",
				},
			},
			"required": ["first_name"],
		},
		risk=Risk.WRITE,
		handler=create_lead,
		doctypes=("CRM Lead",),
		audit_category="crm",
	)
)


#: Doctypes a task may be attached to.
#:
#: `reference_doctype` is a Link to **DocType** — unrestricted, it would let the
#: assistant attach a task to anything on the site, including `User` or a
#: settings singleton. Restricting it to the records the assistant can already
#: read keeps the blast radius equal to what it can see, rather than equal to
#: what Frappe has.
TASK_REFERENCE_DOCTYPES = ("CRM Deal", "CRM Lead", "CRM Organization")

TASK_STATUSES = ("Backlog", "Todo", "In Progress", "Done", "Canceled")
TASK_PRIORITIES = ("Low", "Medium", "High")
DEFAULT_TASK_STATUS = "Backlog"


def search_users(search: str | None = None, limit: int | None = None):
	"""Find a colleague to assign work to.

	Exists because assignment is by user *id* and people are named by their
	name: "создай задачу Айдосу" cannot become `assigned_to` without a lookup,
	and a model guessing an email address would silently assign the work to
	nobody.

	`frappe.get_list` applies User's own permissions, so this shows the same
	people the caller could find in the CRM — it is not a directory dump.
	"""
	filters = {"enabled": 1, "user_type": "System User"}
	if search:
		filters["full_name"] = ["like", _like(search)]

	rows = frappe.get_list(
		"User",
		filters=filters,
		fields=["name", "full_name"],
		limit=_limit(limit),
		order_by="full_name asc",
	)
	return {"users": rows, "count": len(rows)}


register(
	ToolSpec(
		name="crm.search_users",
		description=(
			"Find colleagues by name, to get the user id needed to assign a task. "
			"Use this before assigning work to somebody named in the request."
		),
		input_schema={
			"type": "object",
			"properties": {
				"search": {"type": "string", "description": "Part of a person's name."},
				"limit": {"type": "integer"},
			},
		},
		risk=Risk.READ,
		handler=search_users,
		doctypes=("User",),
		audit_category="crm",
	)
)


def create_task(
	title: str,
	description: str | None = None,
	status: str | None = None,
	priority: str | None = None,
	assigned_to: str | None = None,
	due_date: str | None = None,
	reference_doctype: str | None = None,
	reference_docname: str | None = None,
):
	"""Create one CRM Task.

	`Risk.WRITE`, so this never runs from the agent loop directly — the call is
	written down as a Pending Action and executed from there, with the arguments
	a human saw.

	The field names are the doctype's own and differ from the obvious guesses:
	the subject is `title`, and the link target is `reference_docname` (not
	`reference_name`). `CRM Task` also names itself with an autoincrementing
	**integer**, which is why the returned id is not a string.
	"""
	status = status or DEFAULT_TASK_STATUS
	if status not in TASK_STATUSES:
		frappe.throw(
			f"'{status}' is not a task status. Choose one of: {', '.join(TASK_STATUSES)}.",
			exc=registry.ToolError,
		)
	if priority and priority not in TASK_PRIORITIES:
		frappe.throw(
			f"'{priority}' is not a priority. Choose one of: {', '.join(TASK_PRIORITIES)}.",
			exc=registry.ToolError,
		)

	if assigned_to and not frappe.db.exists(
		"User", {"name": assigned_to, "enabled": 1}
	):
		# Named rather than silently dropped: a task assigned to nobody looks
		# assigned, and the person who asked would never learn otherwise.
		frappe.throw(
			f"'{assigned_to}' is not an active user. Use crm.search_users to find the id.",
			exc=registry.ToolError,
		)

	reference_doctype, reference_docname = _validated_reference(
		reference_doctype, reference_docname
	)

	if due_date:
		try:
			due_date = frappe.utils.get_datetime(due_date)
		except Exception:
			frappe.throw(
				f"'{due_date}' is not a date and time this system understands.",
				exc=registry.ToolError,
			)

	task = frappe.get_doc(
		{
			"doctype": "CRM Task",
			"title": title.strip(),
			"description": (description or "").strip() or None,
			"status": status,
			"priority": priority,
			"assigned_to": assigned_to,
			"due_date": due_date,
			"reference_doctype": reference_doctype,
			"reference_docname": reference_docname,
		}
	)
	task.insert()

	return {
		"task_id": task.name,
		"title": task.title,
		"status": task.status,
		"priority": task.priority,
		"assigned_to": task.assigned_to,
		"due_date": str(task.due_date) if task.due_date else None,
		"reference_doctype": task.reference_doctype,
		"reference_docname": task.reference_docname,
	}


def _validated_reference(doctype: str | None, docname: str | None):
	"""Check a task's link target before it is written.

	Three separate refusals, because they are three different mistakes:

	1. **Half a reference.** A doctype with no name, or the reverse, produces a
	   task pointing at nothing.
	2. **A doctype outside the allowlist.** See `TASK_REFERENCE_DOCTYPES`.
	3. **A record the caller cannot read.** Checked with `has_permission`
	   *before* `exists`, so answering "no such deal" for a deal that does exist
	   but belongs to someone else cannot be used to enumerate other people's
	   records. Both cases give the same message.
	"""
	if not doctype and not docname:
		return None, None

	if bool(doctype) != bool(docname):
		frappe.throw(
			"A reference needs both reference_doctype and reference_docname.",
			exc=registry.ToolError,
		)

	if doctype not in TASK_REFERENCE_DOCTYPES:
		frappe.throw(
			f"A task cannot be attached to {doctype}. "
			f"Allowed: {', '.join(TASK_REFERENCE_DOCTYPES)}.",
			exc=registry.ToolError,
		)

	if not frappe.has_permission(doctype, "read") or not frappe.db.exists(
		doctype, docname
	):
		frappe.throw(
			f"{doctype} '{docname}' was not found.", exc=registry.ToolError
		)

	return doctype, docname


register(
	ToolSpec(
		name="crm.create_task",
		description=(
			"Create a task in the CRM, optionally assigned to a colleague, with a "
			"due date, and attached to a deal, lead or organization. Requires a "
			"title. Look up the assignee with crm.search_users first — assignment "
			"is by user id, not by name. The user must confirm before this runs."
		),
		input_schema={
			"type": "object",
			"properties": {
				"title": {"type": "string", "description": "What needs doing. Required."},
				"description": {"type": "string"},
				"status": {"type": "string", "enum": list(TASK_STATUSES)},
				"priority": {"type": "string", "enum": list(TASK_PRIORITIES)},
				"assigned_to": {
					"type": "string",
					"description": "User id (an email address), from crm.search_users.",
				},
				"due_date": {
					"type": "string",
					"description": "When it is due, as YYYY-MM-DD HH:MM:SS.",
				},
				"reference_doctype": {
					"type": "string",
					"enum": list(TASK_REFERENCE_DOCTYPES),
					"description": "What the task is about, if anything.",
				},
				"reference_docname": {
					"type": "string",
					"description": "The id of that record, e.g. CRM-DEAL-2026-00001.",
				},
			},
			"required": ["title"],
		},
		risk=Risk.WRITE,
		handler=create_task,
		doctypes=("CRM Task",),
		audit_category="crm",
	)
)


# Sales, manufacturing and stock. Imported here so the catalogue stays the one
# place tools are registered — the agent loop imports this module and gets all
# of them, rather than each caller remembering a list.
from korkem_ai.korkem_ai.tools import erp  # noqa: E402,F401  (import registers)
from korkem_ai.korkem_ai.tools import procurement  # noqa: E402,F401  (import registers)
from korkem_ai.korkem_ai.tools import control  # noqa: E402,F401  (import registers)
from korkem_ai.korkem_ai.tools import buying  # noqa: E402,F401  (import registers)
from korkem_ai.korkem_ai.tools import production  # noqa: E402,F401  (import registers)
from korkem_ai.korkem_ai.tools import capacity  # noqa: E402,F401  (import registers)
from korkem_ai.korkem_ai.tools import delivery  # noqa: E402,F401  (import registers)
from korkem_ai.korkem_ai.tools import timeline  # noqa: E402,F401  (import registers)
from korkem_ai.korkem_ai.tools import orders  # noqa: E402,F401  (import registers)
from korkem_ai.korkem_ai.tools import dispatch  # noqa: E402,F401  (import registers)
