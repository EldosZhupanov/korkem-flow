# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Telling people things.

Three modules, and the split is by *question*:

- `events` — what happened, and who should hear about it;
- `recipients` — which `User` a document names;
- `service` — how a message actually reaches that person, and what to do when it
  does not.

`customer_completion` is the Sprint 1 notifier and is **not** part of that
layering: it walks Work Order → CRM Deal → contact phone and sends WhatsApp
directly. It survives because the Task hook it serves still works and its tests
still pass, and it is confined to work orders carrying an `originating_deal` —
which nothing the assistant creates does. It is superseded rather than removed;
removing it is a decision about the Sprint 1 flow, not about this layer.

Its public names are re-exported here because `hooks.py` names them by the path
this file occupies, and moving code should not change what a hook points at.
"""

from korkem_ai.korkem_ai.notifications.customer_completion import (  # noqa: F401
	build_completion_message,
	whatsapp,
	get_customer_phone,
	log_to_conversation,
	notify_customer_of_completion,
	on_task_update,
)
