# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""How the domain tells anybody something happened, without knowing who.

## The problem this solves

`korkem_manufacturing` is the domain. `korkem_ai` is one of its clients — the
one that turns a business event into a Telegram message. The dependency runs in
exactly that direction and must keep running that way: a domain that imports the
AI app cannot be reused by a desktop client, cannot be tested without the
orchestrator, and stops being a domain (ADR-0003, ADR-0007).

But starting production genuinely *should* notify somebody. Before this module,
that was done by importing `korkem_ai.korkem_ai.notifications.events` from the
code that starts production — which is why that code could not move out of the
AI app.

## How it works

The domain emits a name and a payload. Frappe's own hook system decides who
hears it, so subscribers register themselves and the domain never learns their
names:

    # korkem_ai/hooks.py
    korkem_domain_events = {
        "production.started": ["korkem_ai.korkem_ai.notifications.on_production_started"],
    }

Nothing here imports a subscriber, and an app that is not installed simply has
no hooks (ADR-0006, ADR-0011).

## A subscriber can never break the business operation

This is the same rule `usage.record` follows and for the same reason: material
has already moved when the event fires. A notification that cannot be delivered
is a delivery problem, and turning it into a failed stock transfer would be
strictly worse. Every subscriber therefore runs inside its own savepoint, and a
failure is logged rather than raised.

That is deliberate and it has a cost: a subscriber that silently fails leaves no
trace in the caller's result. The trace is in the error log, which is where an
operator looks — and `Notification Delivery` records the delivery half
separately.
"""

from __future__ import annotations

import frappe

HOOK = "korkem_domain_events"


def emit(event: str, **payload) -> list[str]:
	"""Announce a business event. Returns the subscribers that ran cleanly.

	Never raises. The caller has already changed the world; this is the part
	that tells people about it.
	"""
	delivered: list[str] = []

	try:
		subscribers = frappe.get_hooks(HOOK).get(event) or []
	except Exception:
		frappe.log_error(
			title=f"Could not resolve subscribers for {event}",
			message=frappe.get_traceback(with_context=True),
		)
		return delivered

	for dotted in subscribers:
		if _call(dotted, event, payload):
			delivered.append(dotted)

	return delivered


def _call(dotted: str, event: str, payload: dict) -> bool:
	savepoint = "korkem_evt_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_attr(dotted)(**payload)
		frappe.db.release_savepoint(savepoint)
		return True
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title=f"Subscriber failed for {event}: {dotted}",
			message=frappe.get_traceback(with_context=True),
		)
		return False
