# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document
from frappe.utils import now_datetime

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401 - catalog registers tools


class PendingAction(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		action_class: DF.Data | None
		action_data: DF.JSON | None
		agent_skill: DF.Data | None
		conversation: DF.Link | None
		display_data: DF.JSON | None
		entity_name: DF.DynamicLink | None
		entity_type: DF.Link | None
		expires_at: DF.Datetime | None
		resolved_at: DF.Datetime | None
		resolved_by: DF.Link | None
		result_data: DF.JSON | None
		error: DF.SmallText | None
		executed_at: DF.Datetime | None
		model: DF.Data | None
		provider: DF.Data | None
		provider_meta: DF.SmallText | None
		status: DF.Literal["Pending", "Approved", "Rejected", "Expired"]
		tool: DF.Data | None
		turn_id: DF.Data | None
	# end: auto-generated types

	def validate(self):
		# One of the two shapes, never neither: a proposal that names no way to
		# carry itself out is a row that can only ever fail at approval time.
		if not self.tool and not self.action_class:
			frappe.throw("A Pending Action needs either a tool or an action_class")

		if self.is_new() and not self.expires_at:
			# Default validity window for a proposal: 24 hours. Per ADR-0015 there is no
			# auto-approval tier -- this only bounds how long a proposal waits before it is
			# considered stale and swept up by expire_stale_pending_actions().
			self.expires_at = frappe.utils.add_to_date(now_datetime(), hours=24)

	def is_expired(self) -> bool:
		return bool(self.expires_at) and now_datetime() > frappe.utils.get_datetime(self.expires_at)

	def claim(self) -> bool:
		"""Take exclusive ownership of this proposal, atomically.

		Returns True if *this* caller moved it out of `Pending`, False if
		somebody already had.

		A plain `if self.status != "Pending": throw` is check-then-act: two
		confirmations arriving together both read `Pending`, both proceed, and
		the write runs twice. That is not hypothetical for an assistant — a
		double-tap, a retried request after a timeout, or a client that resends
		on reconnect all produce exactly this.

		So the transition is done as a single conditional UPDATE and the
		*database* decides who won. `rowcount` is the answer: one row means we
		claimed it, zero means the state was no longer `Pending` when the
		statement ran.
		"""
		frappe.db.sql(
			"""
			UPDATE `tabPending Action`
			   SET status = 'Approved', resolved_by = %(user)s, resolved_at = %(now)s
			 WHERE name = %(name)s AND status = 'Pending'
			""",
			{"name": self.name, "user": frappe.session.user, "now": now_datetime()},
		)
		claimed = frappe.db._cursor.rowcount == 1
		if claimed:
			self.reload()
		return claimed

	@frappe.whitelist()
	def approve(self):
		"""Approve this proposal and carry out exactly what it recorded.

		"Exactly what it recorded" is the whole point. The tool name and its
		arguments were written down when the model proposed them and are read
		back from this row — the model is never asked again, so it cannot
		propose one thing, be approved, and then do another. That is why the
		AI confirmation flow persists here instead of replaying a turn.

		Per domain_model.md invariant 9, a target entity's existence is
		re-validated here, at approval time -- not just at proposal time -- so a
		stale proposal whose target has since been deleted cannot silently
		"succeed" against nothing. A creating tool has no target yet, so the
		check applies only when one was named.
		"""
		if self.status != "Pending":
			frappe.throw(f"Pending Action {self.name} is not Pending (status: {self.status})")

		if self.is_expired():
			self.status = "Expired"
			self.save(ignore_permissions=True)
			frappe.throw(f"Pending Action {self.name} has expired and can no longer be approved")

		if self.entity_type and self.entity_name and not frappe.db.exists(
			self.entity_type, self.entity_name
		):
			frappe.throw(
				f"Re-validation failed: {self.entity_type} {self.entity_name} no longer exists"
			)

		# Claimed *before* the work, not after. Marking it approved afterwards
		# would leave a window in which a second confirmation sees `Pending` and
		# runs the write again — the whole point of the guard.
		if not self.claim():
			frappe.throw(f"Pending Action {self.name} was already resolved")

		try:
			result = self._execute()
		except Exception as exc:
			# The row stays `Approved` — a human did approve it — but records
			# that carrying it out failed. Rolling the status back would invite
			# a retry that re-runs a write which may well have partly happened.
			self.db_set(
				{"error": str(exc)[:500], "executed_at": now_datetime()},
				notify=False,
				commit=False,
			)
			raise

		# A tool reports failure as *data*, not by raising — the registry does
		# that on purpose so one bad call cannot kill a turn. That means a
		# failure arrives here looking like a normal return, and recording it as
		# a clean success would leave an audit row saying "Approved" with no
		# hint that nothing happened.
		failed = isinstance(result, dict) and result.get("ok") is False
		self.db_set(
			{
				"result_data": frappe.as_json(_to_json_safe(result)),
				"executed_at": now_datetime(),
				"error": (result.get("error", {}).get("message") if failed else None),
			},
			notify=False,
			commit=False,
		)
		self.reload()
		return result

	def _execute(self):
		"""Run the recorded work — a registered tool, or a legacy action path.

		The two are kept apart deliberately. `action_class` is a dotted path fed
		to `frappe.get_attr`, which is fine for proposals this app writes itself
		but would be an arbitrary-call surface if a model could choose it. A
		model-proposed action therefore goes through the registry, which accepts
		only registered names and validates arguments against a schema.
		"""
		arguments = frappe.parse_json(self.action_data) or {}

		if self.tool:
			return registry.execute(self.tool, arguments)

		return frappe.get_attr(self.action_class)(**arguments)

	@frappe.whitelist()
	def reject(self, reason: str | None = None):
		if self.status != "Pending":
			frappe.throw(f"Pending Action {self.name} is not Pending (status: {self.status})")

		self.status = "Rejected"
		self.resolved_by = frappe.session.user
		self.resolved_at = now_datetime()
		if reason:
			self.result_data = {"reason": reason}
		self.save(ignore_permissions=True)


def _to_json_safe(value):
	"""Reduce an action function's return value to something the JSON field can store."""
	if value is None or isinstance(value, (str, int, float, bool, list, dict)):
		return value
	if isinstance(value, Document):
		return {"doctype": value.doctype, "name": value.name}
	return str(value)


def expire_stale_pending_actions():
	"""Scheduled task (see hooks.py scheduler_events): mark overdue proposals Expired.

	This is the System-only ExpirePendingAction command from the Command Catalogue --
	no user or agent invokes it directly.
	"""
	stale = frappe.get_all(
		"Pending Action",
		filters={"status": "Pending", "expires_at": ["<", now_datetime()]},
		pluck="name",
	)
	for name in stale:
		doc = frappe.get_doc("Pending Action", name)
		doc.status = "Expired"
		doc.save(ignore_permissions=True)
	if stale:
		frappe.db.commit()
	return stale
