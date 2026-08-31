# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The one place that decides how a message reaches a person.

## What this is for

Before it, a production tool that wanted to tell somebody something had to know
what a Telegram chat id was. That is the shape of every integration that
eventually grows a second copy of the business rules — so the tools now emit a
*business event*, and this module turns it into a message on whichever channel
that person is actually on.

```
business event  →  recipients (from documents)  →  Notification Delivery
                                                        ↓
                                              channel by preference
                                                        ↓
                                        gateway.deliver → the adapter
```

No tool imports an adapter. No adapter knows what a work order is.

## Nothing is sent to "somebody"

A recipient is always a `User` that a document named, resolved by
`notifications.recipients`. A user with no linked, enabled `Channel Identity`
gets no chat message at all — the delivery is recorded as `Suppressed`, which is
the honest state: there was nobody to send to, and inventing a phone number from
a name is how a customer receives another customer's business.

## Sending never blocks the business transaction

`emit` writes rows and queues. A provider that is down cannot fail a Sales Order,
a Work Order or a confirmation — the delivery is retried on its own schedule and
the ERPNext transaction is already committed by then.

## Idempotency is the row, not a flag

`event_key` is unique. One business event, one recipient, one channel is one row
for ever: a re-delivered webhook, a re-run job, a retried scheduler tick all find
it and stop. Two *different* events that happen to read the same are two rows,
because the key is built from the document and never from the text.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai.doctype.channel_event import channel_event as audit
from korkem_ai.korkem_ai.doctype.notification_delivery import notification_delivery as delivery

DELIVERY = "Notification Delivery"

#: Which chat channel to try first. A `Channel Identity` may carry its own
#: `priority`, and this is the tie-break when several are equal — Telegram first
#: because a bot message is free and a WhatsApp template message is not.
CHANNEL_ORDER = ("Telegram", "WhatsApp")


def identities_for(user: str) -> list[dict]:
	"""Every enabled way to reach this person, best first.

	Ordered by the identity's own `priority` (lower first), then by the channel
	order above, then by which one was heard from most recently. An operator who
	wants WhatsApp preferred says so on the row rather than in a setting nobody
	can find.
	"""
	rows = frappe.get_all(
		"Channel Identity",
		filters={"user": user, "enabled": 1},
		fields=["name", "channel", "external_id", "priority", "last_seen_on"],
	)
	return sorted(
		rows,
		key=lambda row: (
			row.get("priority") or 0,
			CHANNEL_ORDER.index(row["channel"]) if row["channel"] in CHANNEL_ORDER else 99,
			-(row["last_seen_on"].timestamp() if row.get("last_seen_on") else 0),
		),
	)


def emit(
	event: str,
	*,
	recipients: list[str],
	body: str,
	reference_doctype: str | None = None,
	reference_name: str | None = None,
	company: str | None = None,
	key_suffix: str | None = None,
	confirm_for: str | None = None,
	ask: bool = False,
) -> list[str]:
	"""Record one message per recipient and queue it. Never raises.

	Returns the delivery names. A failure to notify must never fail the thing
	being notified about, so everything here is defensive by contract: the
	caller has already written the business document.
	"""
	created = []
	for user in dict.fromkeys(recipients):
		if not user or user in ("Administrator", "Guest"):
			continue
		try:
			name = _record(
				event=event,
				user=user,
				body=body,
				reference_doctype=reference_doctype,
				reference_name=reference_name,
				company=company,
				key_suffix=key_suffix,
				confirm_for=confirm_for,
				ask=ask,
			)
		except Exception:
			frappe.logger("korkem_ai.notifications").warning(
				{"event": event, "recipient": user, "recorded": False}
			)
			continue
		if name:
			created.append(name)
	return created


def _record(
	*,
	event: str,
	user: str,
	body: str,
	reference_doctype: str | None,
	reference_name: str | None,
	company: str | None,
	key_suffix: str | None,
	confirm_for: str | None,
	ask: bool,
) -> str | None:
	key = event_key(event, user, reference_doctype, reference_name, key_suffix)
	existing = frappe.db.get_value(DELIVERY, {"event_key": key}, "name")
	if existing:
		# Said once. A second attempt to say it is the definition of a duplicate.
		return existing

	channels = identities_for(user)
	# A Dynamic Link needs its doctype. A caller that named only a document
	# would otherwise have the whole delivery silently dropped by validation —
	# the reference still identifies the event through the key, so it is the
	# link that is left empty rather than the message that is lost.
	linked = reference_name if reference_doctype else None
	doc = frappe.get_doc(
		{
			"doctype": DELIVERY,
			"event": event,
			"event_key": key,
			"recipient_user": user,
			"company": company,
			"body": body,
			"confirm_for": confirm_for,
			"reference_doctype": reference_doctype,
			"reference_name": linked,
			"turn_id": _current_turn(),
			"status": delivery.PENDING if channels else delivery.SUPPRESSED,
			"channel": channels[0]["channel"] if channels else "App",
			"channel_identity": channels[0]["name"] if channels else None,
		}
	)
	doc.flags.ask = ask
	doc.insert(ignore_permissions=True)

	if not channels:
		# Nobody to send to. Recorded rather than dropped: "the foreman never
		# heard" is a fact somebody needs, and it is not an error.
		audit.record(
			audit.SENT,
			user=user,
			status="suppressed_no_channel",
			detail=event,
		)
		return doc.name

	frappe.enqueue(
		"korkem_ai.korkem_ai.notifications.service.attempt",
		queue="short",
		# Inline under test, queued in production — Frappe's own idiom. Without
		# it a test would assert on a message that a worker sends after the test
		# has finished, which is the same as asserting nothing.
		now=bool(frappe.flags.in_test),
		name=doc.name,
		ask=ask,
	)
	return doc.name


def _current_turn() -> str | None:
	"""The turn this send belongs to, when it belongs to one.

	A notification raised by a scheduled job has no turn and that is a true
	answer — the chain starts at the business event instead.
	"""
	from korkem_ai.korkem_ai.channels import gateway

	return gateway.current_turn()


def event_key(
	event: str,
	user: str,
	reference_doctype: str | None,
	reference_name: str | None,
	suffix: str | None = None,
) -> str:
	"""One business event, one recipient — built from the document.

	Never from the body: two stoppages of the same job read identically and are
	two events, and one webhook delivered twice is one. `suffix` is what a caller
	adds when the document alone does not distinguish them — an operation name, a
	sequence number.
	"""
	parts = [event, user, reference_doctype or "", reference_name or "", suffix or ""]
	return ":".join(parts)[:140]


def attempt(name: str, ask: bool = False) -> str:
	"""Try to deliver one recorded message, once.

	The status is claimed with a conditional UPDATE before anything is sent, so
	two workers picking up the same row — a retry tick racing the original queue
	job — cannot both send it.
	"""
	from korkem_ai.korkem_ai.channels import gateway

	if not frappe.db.exists(DELIVERY, name):
		return "missing"

	if not _claim(name):
		return "already_in_flight"

	doc = frappe.get_doc(DELIVERY, name)
	identity = (
		frappe.db.get_value(
			"Channel Identity", doc.channel_identity, ["channel", "external_id", "enabled"], as_dict=True
		)
		if doc.channel_identity
		else None
	)
	if not identity or not identity.enabled:
		# An administrator unlinked them between recording and sending.
		doc.db_set({"status": delivery.SUPPRESSED, "error": "no enabled channel identity"}, notify=False)
		return delivery.SUPPRESSED

	try:
		response = gateway.deliver(
			identity.channel,
			identity.external_id,
			doc.body,
			confirm_for=doc.confirm_for or None,
			ask=bool(ask or doc.flags.get("ask")),
		)
	except Exception as exc:
		code, message = _classify(exc)
		status = doc.mark_failed(code, message)
		audit.record(
			audit.FAILED,
			channel=identity.channel,
			user=doc.recipient_user,
			turn_id=doc.turn_id,
			status=status.lower().replace(" ", "_"),
			detail=f"{doc.event}: {code}",
		)
		if status == delivery.RETRYING:
			_try_fallback(doc)
		return status

	doc.mark_sent(_provider_message_id(response))
	audit.record(
		audit.SENT,
		channel=identity.channel,
		user=doc.recipient_user,
		turn_id=doc.turn_id,
		status="notification",
		detail=doc.event,
	)
	return delivery.SENT


def _claim(name: str) -> bool:
	"""Move this row into `Sending`, and let the database decide who won."""
	frappe.db.sql(
		"""
		UPDATE `tabNotification Delivery`
		   SET status = %(sending)s
		 WHERE name = %(name)s AND status IN %(open)s
		""",
		{
			"name": name,
			"sending": delivery.SENDING,
			"open": (delivery.PENDING, delivery.RETRYING),
		},
	)
	return frappe.db._cursor.rowcount == 1


def _try_fallback(doc) -> None:
	"""Move a retrying message to the person's other channel, once.

	Only after a *transient* failure and only to a channel that has not already
	been tried for this delivery — a fallback that loops between two dead bots is
	worse than one that stops.

	`identities_for` is filtered by `user`, so a fallback can only ever reach
	another way of contacting **the same person**. That is the property that
	matters and it is worth stating: one person's Telegram must never fall back
	to somebody else's WhatsApp, and the only reason it cannot is that the query
	is keyed on the user rather than on the message.
	"""
	alternatives = [
		row
		for row in identities_for(doc.recipient_user)
		if row["name"] != doc.channel_identity
	]
	if not alternatives:
		return
	doc.db_set(
		{"channel": alternatives[0]["channel"], "channel_identity": alternatives[0]["name"]},
		notify=False,
	)


def _classify(exc: Exception) -> tuple[str, str]:
	"""A provider failure as a code and a message that is safe to store."""
	from korkem_ai.korkem_ai.integrations.telegram import TelegramError
	from korkem_ai.korkem_ai.integrations.whatsapp import WhatsAppError

	if isinstance(exc, TelegramError | WhatsAppError):
		return exc.code, str(exc)
	# Anything else is reduced to its class name: an arbitrary exception's text
	# is exactly where a credential travels.
	return "provider_error", type(exc).__name__


def _provider_message_id(response) -> str | None:
	if not isinstance(response, dict):
		return None
	if response.get("message_id"):
		return str(response["message_id"])
	messages = response.get("messages")
	if isinstance(messages, list) and messages and isinstance(messages[0], dict):
		return messages[0].get("id")
	return None


# --------------------------------------------------------------------------
# The four ways a caller asks for a message
# --------------------------------------------------------------------------


def send_to_user(event: str, user: str, body: str, **kwargs) -> list[str]:
	"""Tell one named person."""
	return emit(event, recipients=[user], body=body, **kwargs)


def send_to_customer(event: str, sales_order: str, body: str, **kwargs) -> list[str]:
	"""Tell the customer whose order this is — through the portal binding only."""
	from korkem_ai.korkem_ai.notifications import recipients

	return emit(
		event,
		recipients=recipients.customers_for_sales_order(sales_order),
		body=body,
		reference_doctype="Sales Order",
		reference_name=sales_order,
		company=recipients.company_of("Sales Order", sales_order),
		**kwargs,
	)


def send_to_instruction_owner(event: str, instruction, body: str, **kwargs) -> list[str]:
	"""Tell whoever gave this instruction what the employee said."""
	return emit(
		event,
		recipients=[instruction.owner],
		body=body,
		reference_doctype="Work Instruction",
		reference_name=instruction.name,
		company=instruction.company,
		**kwargs,
	)


def retry(name: str) -> dict:
	"""An administrator asking for one more attempt.

	Idempotent by construction: `reopen` is a conditional UPDATE, so a second tap
	— or a tap racing the scheduler — moves nothing and sends nothing. A delivery
	that already arrived is not retryable at all, because re-sending it would be
	the duplicate this whole layer exists to prevent.
	"""
	if not frappe.db.exists(DELIVERY, name):
		return {"ok": False, "reason": "not_found"}

	if not delivery.reopen(name):
		status = frappe.db.get_value(DELIVERY, name, "status")
		return {"ok": False, "reason": "not_retryable", "status": status}

	outcome = attempt(name)
	return {"ok": outcome == delivery.SENT, "status": outcome}


def cancel(name: str) -> dict:
	"""Stop trying to deliver this one."""
	if not frappe.db.exists(DELIVERY, name):
		return {"ok": False, "reason": "not_found"}
	if not delivery.cancel(name):
		return {
			"ok": False,
			"reason": "not_cancellable",
			"status": frappe.db.get_value(DELIVERY, name, "status"),
		}
	return {"ok": True, "status": delivery.CANCELLED}


def retry_all(limit: int = 50) -> dict:
	"""Try again everything an administrator could have tried one at a time.

	Deliberately *not* everything that ever failed: `Suppressed` rows had nobody
	to send to and `Sent` rows arrived, so neither is eligible. Bounded, because
	an operator pressing this after a long outage should not queue a thousand
	messages in one request.
	"""
	names = frappe.get_all(
		DELIVERY,
		filters={"status": ["in", delivery.RETRYABLE_BY_HAND]},
		pluck="name",
		order_by="creation asc",
		limit=limit,
	)
	results = [retry(name) for name in names]
	return {
		"attempted": len(results),
		"sent": len([row for row in results if row.get("ok")]),
	}


def send_to_channel_identity(event: str, identity_name: str, body: str, **kwargs) -> list[str]:
	"""Tell whoever a specific linked identity speaks for.

	The identity still has to name a user: a row with nobody behind it speaks for
	nobody, which is the same rule inbound messages follow.
	"""
	user = frappe.db.get_value("Channel Identity", identity_name, "user")
	if not user:
		return []
	return emit(event, recipients=[user], body=body, **kwargs)
