# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""An instruction from somebody who decides to somebody who does.

## Why this exists at all, when ERPNext has Job Cards

A Job Card is the *work*: which operation, on which work order, how many pieces.
This is the *asking*: who was told, through which chat app, whether they picked
up the phone, and whether they said yes. ERPNext has no document for that, and
inventing fields on Job Card to hold it would put an assistant's messaging state
inside a production record that a foreman reads.

So this row records the conversation around the work, and points at the work
rather than describing it. `produced_qty` is still ERPNext's and always will be:
nothing here counts anything.

## The states are deliberately few

Draft → Sent → Acknowledged → In Progress → Completed, with Rejected and
Cancelled as the two ways out. Every transition is caused by something that
actually happened — a message going out, a person answering it, a production
tool running — and none of them is a timer. There is no workflow engine here
and there should not be one.
"""

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import now_datetime

DRAFT = "Draft"
SENT = "Sent"
ACKNOWLEDGED = "Acknowledged"
REJECTED = "Rejected"
IN_PROGRESS = "In Progress"
COMPLETED = "Completed"
CANCELLED = "Cancelled"
CLARIFICATION = "Clarification Requested"
EXPIRED = "Expired"

#: Statuses from which an employee may still accept or refuse. Once a person has
#: answered, answering again changes nothing — the same rule `Pending Action`
#: applies to a confirmation, for the same reason.
#:
#: `Clarification Requested` is open, and that is the point of it: asking a
#: question does not settle anything, so the job is still waiting for a real
#: answer and can still get one.
OPEN = (DRAFT, SENT, CLARIFICATION)


class WorkInstruction(Document):
	def validate(self):
		if not self.company:
			frappe.throw("A work instruction needs a company.")

		# Cross-company dispatch is the failure this class of document invites:
		# an administrator of one company naming an order or a job of another.
		# Checked here as well as in the tool, because a row is reachable from
		# the desk too.
		for doctype, name in (("Sales Order", self.sales_order), ("Work Order", self.work_order)):
			if not name:
				continue
			company = frappe.db.get_value(doctype, name, "company")
			if company and company != self.company:
				frappe.throw(f"{doctype} {name} not found.")

	def mark_sent(self, channel: str | None = None, identity: str | None = None):
		self.db_set(
			{
				"status": SENT,
				"sent_at": now_datetime(),
				"channel": channel or self.channel,
				"channel_identity": identity or self.channel_identity,
			},
			notify=False,
		)

	def ask(self, question: str | None = None) -> bool:
		"""The employee wants to know more. Settles nothing, on purpose.

		Recorded as its own status so a dispatch board can show the difference
		between "nobody has answered" and "somebody answered with a question" —
		which are different problems for whoever is waiting.
		"""
		return self._answer(CLARIFICATION, "sent_at", question, keep_open=True)

	def acknowledge(self, response: str | None = None) -> bool:
		"""The employee accepts. Returns False if somebody already answered.

		A single conditional UPDATE decides, not a read followed by a write: a
		double-tapped button and a re-delivered webhook both produce two
		acknowledgements arriving together, and the second must change nothing.
		"""
		return self._answer(ACKNOWLEDGED, "acknowledged_at", response)

	def refuse(self, response: str | None = None) -> bool:
		"""The employee refuses, with their reason recorded as they wrote it."""
		return self._answer(REJECTED, "rejected_at", response)

	def _answer(self, status: str, stamp: str, response: str | None, keep_open: bool = False) -> bool:
		frappe.db.sql(
			f"""
			UPDATE `tabWork Instruction`
			   SET status = %(status)s, `{stamp}` = %(now)s, response = %(response)s
			 WHERE name = %(name)s AND status IN %(open)s
			""",
			{
				"status": status,
				"now": now_datetime(),
				"response": (response or "")[:500] or None,
				"name": self.name,
				"open": OPEN,
			},
		)
		claimed = frappe.db._cursor.rowcount == 1
		if claimed:
			self.reload()
		# A question can be asked more than once, so it is not a claim at all —
		# it reports success either way, while accepting and refusing stay
		# exactly-once.
		return True if keep_open else claimed


def notify_owner(doc, text: str) -> dict:
	"""Send what the employee said back to whoever gave the instruction.

	The point of a dispatch record is that somebody is waiting on the answer, and
	an answer that stops at the database is the same as no answer.

	This used to reach for a channel adapter itself. It now emits a business
	event and the notification service decides how to reach that person — which
	is what stops "how do I message somebody" from being answered twice, and what
	makes an undeliverable answer retryable instead of lost.
	"""
	from korkem_ai.korkem_ai.notifications import events

	created = events.instruction_answered(doc, text)
	return {"delivered": bool(created), "deliveries": created}


def latest_for(user: str) -> dict | None:
	"""The last thing this person was asked to do, answered or not.

	Exists so that a second «принял» is told *"уже принято"* rather than
	*"нечего подтверждать"* — the same answer a second press of the same button
	gets, which is what makes the two indistinguishable to whoever is holding
	the phone.
	"""
	rows = frappe.get_all(
		"Work Instruction",
		filters={"employee_user": user},
		fields=["name", "status"],
		order_by="creation desc",
		limit=1,
	)
	return rows[0] if rows else None


def open_for(user: str) -> list[dict]:
	"""Instructions this person has been sent and has not answered."""
	return frappe.get_all(
		"Work Instruction",
		filters={"employee_user": user, "status": ["in", OPEN]},
		fields=["name", "instruction", "sales_order", "work_order", "due_date", "status"],
		order_by="creation asc",
	)
