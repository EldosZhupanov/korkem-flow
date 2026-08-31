# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""One message the system decided to send, and what became of it.

## Why a row per delivery

Because a message that was not delivered is a fact somebody needs, and a message
delivered twice is a bug. Both are questions about *this* send, not about the
business event — a stopped work order is one event with three recipients, and it
is perfectly normal for two of them to arrive and one to be waiting on a bot that
is down.

## `event_key` is the whole idempotency guarantee

One business event, one recipient, one channel → one row, enforced by a unique
index rather than by a check somebody remembered to write. A re-delivered
webhook, a re-run job and a double-tapped button all find the existing row and
change nothing. The key is built from the *document*, never from the message
text, for the same reason inbound deduplication is: two events can legitimately
say the same words.

## Retries are bounded, and only for the failures worth retrying

`ATTEMPTS` tries with exponential backoff, and a permanent refusal — a rejected
credential, a chat that blocked the bot — sets no next attempt at all. Retrying
an invalid token achieves nothing except telling the provider we still have it.
"""

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import add_to_date, now_datetime

PENDING = "Pending"
SENDING = "Sending"
SENT = "Sent"
RETRYING = "Retrying"
FAILED = "Failed"
DEAD_LETTER = "Dead Letter"
SUPPRESSED = "Suppressed"
CANCELLED = "Cancelled"

#: How many times a transient failure is retried before the row is left alone.
#: Four, spread over roughly twenty minutes — long enough to ride out a provider
#: blip, short enough that nobody is told about a stopped machine an hour late.
ATTEMPTS = 4

#: Seconds before each retry: one minute, four, sixteen. Exponential, bounded,
#: and written down rather than computed so the schedule is readable.
BACKOFF_SECONDS = (60, 240, 960)

#: Failures where trying again is the wrong thing. A rejected token stays
#: rejected until somebody edits the settings; a blocked chat stays blocked.
PERMANENT = frozenset({"not_configured", "invalid_credentials", "disabled", "forbidden"})

#: Statuses an administrator may ask to try again from. A `Dead Letter` is
#: included on purpose and `Sent` is not: reviving an exhausted delivery is a
#: decision somebody makes, and re-sending one that arrived is a duplicate.
RETRYABLE_BY_HAND = (RETRYING, FAILED, DEAD_LETTER)


class NotificationDelivery(Document):
	def mark_sent(self, provider_message_id: str | None = None):
		self.db_set(
			{
				"status": SENT,
				"sent_at": now_datetime(),
				"provider_message_id": provider_message_id,
				"error": None,
				"next_attempt_at": None,
			},
			notify=False,
		)

	def mark_failed(self, code: str, error: str):
		"""Record a failure, and decide whether it is worth another attempt.

		Three outcomes, and the difference between them is what stops this from
		becoming a loop: a permanent refusal goes straight to `Failed`, a
		transient one is scheduled, and one that has used its attempts becomes a
		`Dead Letter` — visible, finished, and not retried again.
		"""
		attempts = (self.attempt_count or 0) + 1

		if code in PERMANENT:
			status, next_attempt = FAILED, None
		elif attempts >= ATTEMPTS:
			status, next_attempt = DEAD_LETTER, None
		else:
			status = RETRYING
			next_attempt = add_to_date(
				now_datetime(), seconds=BACKOFF_SECONDS[min(attempts - 1, len(BACKOFF_SECONDS) - 1)]
			)

		self.db_set(
			{
				"status": status,
				"attempt_count": attempts,
				"failed_at": now_datetime(),
				"error": (error or "")[:500],
				"next_attempt_at": next_attempt,
			},
			notify=False,
		)
		return status


def reopen(name: str) -> bool:
	"""Put a finished delivery back in the queue, once.

	The transition is a conditional UPDATE for the same reason `_claim` is: two
	administrators tapping Retry on the same row, or a Retry racing the
	scheduler, must produce one send and not two. `attempt_count` is deliberately
	*not* reset — the history of how hard this has already been tried is the
	thing an operator is looking at.
	"""
	frappe.db.sql(
		"""
		UPDATE `tabNotification Delivery`
		   SET status = %(pending)s, next_attempt_at = %(now)s, error = NULL
		 WHERE name = %(name)s AND status IN %(retryable)s
		""",
		{
			"name": name,
			"pending": PENDING,
			"now": now_datetime(),
			"retryable": RETRYABLE_BY_HAND,
		},
	)
	return frappe.db._cursor.rowcount == 1


def cancel(name: str) -> bool:
	"""Stop trying. Only from a state that is still trying."""
	frappe.db.sql(
		"""
		UPDATE `tabNotification Delivery`
		   SET status = %(cancelled)s, next_attempt_at = NULL
		 WHERE name = %(name)s AND status IN %(open)s
		""",
		{
			"name": name,
			"cancelled": CANCELLED,
			"open": (PENDING, RETRYING, FAILED, DEAD_LETTER),
		},
	)
	return frappe.db._cursor.rowcount == 1


def due(limit: int = 50) -> list[str]:
	"""Deliveries waiting to be tried again, oldest first."""
	return frappe.get_all(
		"Notification Delivery",
		filters={
			"status": RETRYING,
			"next_attempt_at": ["<=", now_datetime()],
		},
		pluck="name",
		order_by="next_attempt_at asc",
		limit=limit,
	)


def retry_due():
	"""Scheduled task: try again the ones whose backoff has elapsed.

	Runs on the scheduler rather than in a sleeping worker, because a retry that
	holds a queue slot for sixteen minutes is a retry that costs more than the
	message is worth.
	"""
	from korkem_ai.korkem_ai.notifications import service

	for name in due():
		service.attempt(name)
