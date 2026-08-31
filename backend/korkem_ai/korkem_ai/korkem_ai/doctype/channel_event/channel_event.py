# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""What happened on a channel, in a form that can be read a week later.

## Why a row and not a log line

`frappe.logger` already records tool calls, and that is the right place for
"this took 300ms". It is the wrong place for "who was this, and what did it
turn into" — a shop that has just been told the bot never answered needs to
follow one message from the webhook to the ERPNext document, and a log file
cannot be joined to a `Pending Action`.

## What is deliberately not in here

**No credential, ever** — not the bot token, not the access token, not the
webhook secret, not an Authorization header. The adapters raise typed errors
whose messages are the provider's own words with anything token-shaped removed,
and only those reach `detail`.

**No message body.** The transcript is `Agent Conversation Message`'s job and
lives under that permission. Duplicating a customer's words into an audit table
that a different set of people can read is how an audit trail becomes a leak.
"""

from __future__ import annotations

import frappe
from frappe.model.document import Document

RECEIVED = "received"
DUPLICATE = "duplicate"
IDENTIFIED = "identified"
UNLINKED = "unlinked"
ANSWERED = "answered"
PROPOSED = "proposed"
CONFIRMED = "confirmed"
DISPATCHED = "dispatched"
ACKNOWLEDGED = "acknowledged"
SENT = "sent"
FAILED = "failed"


class ChannelEvent(Document):
	pass


def record(event: str, **fields) -> str | None:
	"""Write one event. Never raises — observability must not break the thing observed.

	Returns the row's name, or `None` if it could not be written, which is a
	deliberate contract: a channel turn that fails because its audit row failed
	would be a worse outcome than a missing audit row.
	"""
	try:
		detail = fields.pop("detail", None)
		doc = frappe.get_doc(
			{
				"doctype": "Channel Event",
				"event": event,
				"detail": (detail or "")[:500] or None,
				**{key: value for key, value in fields.items() if value is not None},
			}
		)
		doc.insert(ignore_permissions=True)
		return doc.name
	except Exception:
		frappe.logger("korkem_ai.channels").warning({"event": event, "audit": "not recorded"})
		return None
