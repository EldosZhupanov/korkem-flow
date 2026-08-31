# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Writing down what a model asked to do, wherever it was asked.

## Why this is not in `chat.py` any more

It was, and that was the whole defect. `chat.py` recorded a proposal as a
`Pending Action`; the channel gateway did not — it looked for rows by the
provider's call id and skipped every one it could not find. So a foreman who
told the Telegram bot "сделал 6" was answered with a sentence describing the
write and then had nothing to confirm: the row the confirmation layer resolves
against had never been written.

Approval was real and tested. Proposal was not, on that path. One recorder,
used by both, is the only way those two cannot drift again — the same reasoning
that keeps one agent loop behind three channels.

## The name is ours

`Pending Action` is `autoname: hash`, and that name is the call id everything
downstream uses. Providers mint their own ids and change them between requests
(Anthropic and OpenAI both do), so matching on a provider's id could never have
worked.

## The summary is built here, not by the model

A person confirming a write is entitled to see what it will do in their own
language, and the model's prose is not evidence — it is the thing being checked.
So a tool may declare `summarise`, a read-only function of the same arguments
that produces the sentence. It runs under the caller's own permissions before
anything has changed, and a failure in it must never lose the proposal: a
summary is a courtesy, the row is the record.
"""

from __future__ import annotations

import json

import frappe

PENDING_ACTION = "Pending Action"


def summarise(tool: str, arguments: dict) -> str | None:
	"""One human sentence about what this call would do, if its tool offers one."""
	from korkem_ai.korkem_ai.tools import registry

	spec = registry.find(tool)
	if not spec or not spec.summarise:
		return None
	try:
		return spec.summarise(**(arguments or {}))
	except Exception:
		# Deliberately swallowed. A summary that cannot be built is a worse
		# confirmation prompt; a proposal that cannot be written is a write the
		# person can never authorise.
		frappe.log_error(title=f"AI proposal summary failed: {tool}")
		return None


def record(
	pending, turn_id: str, provider: str | None = None, model: str | None = None
) -> list[dict]:
	"""Write each proposed call down, and hand back the ids a human confirms."""
	recorded = []

	for call in pending:
		arguments = call.arguments or {}
		display = {"tool": call.name, "arguments": arguments}
		summary = summarise(call.name, arguments)
		if summary:
			display["summary"] = summary

		action = frappe.get_doc(
			{
				"doctype": PENDING_ACTION,
				"tool": call.name,
				"turn_id": turn_id,
				# Which model proposed this, for the audit trail. Never a
				# credential — the provider *name*, not the key that reaches it.
				"provider": provider,
				"model": model,
				# Opaque continuation data the originating provider needs handed
				# back verbatim. Gemini rejects the follow-up request without its
				# `thoughtSignature`, so a confirmed write would create the record
				# and *then* fail to report it — which is the worst of both.
				"provider_meta": json.dumps(call.provider_meta or {}),
				"action_data": json.dumps(arguments),
				"display_data": json.dumps(display),
				"status": "Pending",
			}
		)
		# The *system* is recording that a model asked; the user has not acted
		# yet, and may well lack write access to this doctype. Ownership is what
		# binds the row to them, and the confirmation layers enforce it.
		action.insert(ignore_permissions=True)

		recorded.append({"id": action.name, "tool": call.name, "arguments": arguments})

	frappe.db.commit()
	return recorded
