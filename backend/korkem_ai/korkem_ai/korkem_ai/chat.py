# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The workspace assistant's API — the only way in from the mobile app.

## Why sending a message returns immediately

ADR-0009: an LLM call is a third-party call with unbounded latency and must
never block a request handler. So `send` enqueues the turn and returns a turn
id at once; the answer arrives on the user's realtime room as it is produced.
Holding the HTTP response open until a model finishes would tie up a gunicorn
worker for the length of somebody's thinking time, and there are 33 of them.

## …but configuration is checked before the queue

Queuing *everything* was wrong. A site with no provider configured — which is
every site on day one — answered `200 {"turn_id": …}` and then failed inside the
worker, where the only thing left to do was publish a generic error. The most
common state of a fresh install was reported as "something went wrong".

`send` now builds the provider first. That reads the database and opens no
socket, so it costs nothing on the request path, and it turns the commonest
failure into an immediate, typed, actionable refusal. See `errors.py`.

## Why a confirmed action is *not* a replayed turn

`confirm` used to re-run the whole turn with the approved call ids passed back
in, and match them against what the model asked for the second time. That cannot
work: Anthropic and OpenAI mint a fresh random id on every response, so the
approved id never matched and the user would be asked forever. Worse in
principle — the model got to re-decide what it was doing *after* a human had
agreed to something specific.

So a proposal is now **written down** as a `Pending Action` the moment the model
asks, and its document name — server-generated, stable, ours — is the call id
the user confirms. Approving executes exactly the tool and arguments on that
row. The model is never asked to propose again; it is only asked to describe
what already happened. This is also what gives ADR-0014 an audit trail and
ADR-0015 a real approval record, instead of a set of strings living in one
worker's memory.

## What the client may and may not decide

The client sends *text*, and may name a provider and model — but only as
*logical selections*. It never sends a credential and never receives one. The
system prompt and the tool list stay server-side entirely. A request saying
"use Gemini" is honoured by looking Gemini's key up here; a request trying to
supply one has nowhere to put it.

It also cannot approve its own writes: `confirm` takes ids the *server* issued,
for rows the *server* wrote, owned by the caller and still pending.
"""

from __future__ import annotations

import hashlib
import json

import frappe

from korkem_ai.korkem_ai import budget, errors, usage
from korkem_ai.korkem_ai.agent import loop, proposals
from korkem_ai.korkem_ai.orchestrator import llm
from korkem_ai.korkem_ai.orchestrator.protocol import AIMessage, AIToolCall, AIToolResult
from korkem_ai.korkem_ai.tools import registry

#: The realtime event every chat delta and status arrives on. One event name
#: with a `type` inside, rather than a family of names, so a client subscribes
#: once and a new kind of update does not need a client release.
STREAM_EVENT = "korkem_ai_chat"

#: How much conversation the client may hand back. Older turns are the client's
#: to summarise; sending an unbounded history would let a long conversation
#: quietly become the most expensive request in the system.
MAX_HISTORY_MESSAGES = 40

PENDING_ACTION = "Pending Action"


@frappe.whitelist()
def send(
	message: str,
	history: str | list | None = None,
	turn_id: str | None = None,
	provider: str | None = None,
	model: str | None = None,
) -> dict:
	"""Queue one turn. The reply arrives on the realtime channel.

	`provider` and `model` are *logical selections*, never credentials. A client
	may say "answer this with Gemini"; it cannot say "answer this with this
	key". The gateway resolves the secret server-side, which is what keeps the
	mobile app free of anything worth stealing.
	"""
	message = (message or "").strip()
	if not message:
		frappe.throw("Message is empty")

	turn_id = turn_id or frappe.generate_hash(length=12)
	request_id = _request_id(frappe.session.user, turn_id, "send")
	if usage.recorded(request_id):
		return {"turn_id": turn_id, "event": STREAM_EVENT}

	# Before the queue, deliberately: see the module docstring. Raises a typed
	# `AINotConfigured` that reaches the client as `AI_NOT_CONFIGURED`.
	llm.ensure_configured(provider, model)

	# Also before the queue, and for the same reason: a refusal must cost
	# nothing and must reach the person in its own words.
	budget.check()

	frappe.enqueue(
		"korkem_ai.korkem_ai.chat.run_turn_job",
		queue="short",
		user=frappe.session.user,
		turn_id=turn_id,
		message=message,
		history=_parse_history(history),
		approved_calls=[],
		provider=provider,
		model=model,
		request_id=request_id,
		job_id=request_id,
		deduplicate=True,
	)

	return {"turn_id": turn_id, "event": STREAM_EVENT}


@frappe.whitelist()
def confirm(turn_id: str, call_ids: str | list, message: str, history: str | list | None = None):
	"""Approve specific proposals and continue the turn.

	`call_ids` are `Pending Action` names this server issued. Each is checked
	here, synchronously, so an unknown, foreign, expired or already-resolved id
	fails the request rather than failing silently inside a worker.
	"""
	approved = _as_list(call_ids)
	if not approved:
		frappe.throw("Nothing was approved")

	llm.ensure_configured()
	budget.check()

	for call_id in approved:
		_owned_pending_action(call_id)
	request_id = _request_id(
		frappe.session.user,
		turn_id,
		"confirm:" + ",".join(sorted(approved)),
	)

	frappe.enqueue(
		"korkem_ai.korkem_ai.chat.run_turn_job",
		queue="short",
		user=frappe.session.user,
		turn_id=turn_id,
		message=message,
		history=_parse_history(history),
		approved_calls=list(approved),
		request_id=request_id,
		job_id=request_id,
		deduplicate=True,
	)

	return {"turn_id": turn_id, "event": STREAM_EVENT}


@frappe.whitelist()
def reject(call_ids: str | list, reason: str | None = None) -> dict:
	"""Decline proposals. Nothing runs, and the refusal is recorded.

	A rejection is as much a part of the audit trail as an approval — "the
	assistant offered to do this and a human said no" is exactly the kind of
	thing an auditor asks about later.
	"""
	declined = _as_list(call_ids)
	if not declined:
		frappe.throw("Nothing was rejected")

	for call_id in declined:
		_owned_pending_action(call_id).reject(reason=reason)

	return {"rejected": list(declined)}


@frappe.whitelist()
def info() -> dict:
	"""What a client needs to open the realtime channel.

	The **site name** is here because a client cannot derive it. Frappe's
	socket.io middleware requires the namespace to equal the site, and the host
	the app dials is not always that: an Android emulator reaches the bench at
	`10.0.2.2`, so a client guessing from its own base URL connects to
	`/10.0.2.2` and is refused as an invalid namespace — silently, with no
	useful error on the device. Measured, not theorised: that is exactly what
	happened the first time this was run on a device.

	The event name travels with it so the two can never drift apart.
	"""
	return {"site": frappe.local.site, "event": STREAM_EVENT}


@frappe.whitelist()
def available_tools() -> dict:
	"""What this user's assistant can do, for a settings or help screen.

	Schemas are omitted: they are for the model, and a UI listing them would be
	a debug console. Name, description and whether it needs confirmation is
	what a person needs to know.
	"""
	return {
		"tools": [
			{
				"name": spec.name,
				"description": spec.description,
				"risk": spec.risk.value,
				"requires_confirmation": spec.requires_confirmation,
			}
			for spec in registry.available_to()
		]
	}


def run_turn_job(
	user: str,
	turn_id: str,
	message: str,
	history: list,
	approved_calls: list,
	provider: str | None = None,
	model: str | None = None,
	request_id: str | None = None,
):
	"""The background half. Runs as `user`, never as Administrator.

	`frappe.set_user` is what makes every tool inside this turn subject to that
	person's permissions — a job that ran as the site's admin would hand the
	model the whole database, and no amount of care in the tools would undo it.
	"""
	frappe.set_user(user)
	request_id = request_id or _request_id(
		user,
		turn_id,
		"confirm:" + ",".join(sorted(approved_calls)) if approved_calls else "send",
	)

	def publish(payload: dict):
		frappe.publish_realtime(STREAM_EVENT, {"turn_id": turn_id, **payload}, user=user)

	publish({"type": "started"})

	adapter = None
	try:
		messages = _to_messages(history) + [AIMessage.user(message)]

		# Anything already approved runs first, from what was written down —
		# never from what a model says now. Its results are then handed to the
		# model as history, so the turn continues into "here is what happened"
		# rather than starting over at "may I?".
		if approved_calls:
			messages.extend(_carry_out(approved_calls, publish))

		adapter = llm.resolve(provider, model)
		result = loop.run_turn(
			messages, provider=adapter, on_event=publish, run_id=turn_id
		)
	except Exception as exc:
		code = errors.classify(exc)
		frappe.log_error(title="AI chat turn failed", message=frappe.get_traceback())
		# The user gets a code and a sentence, not a traceback: a traceback can
		# quote table names, file paths and other people's data.
		publish({"type": "error", "reason": str(code), "message": errors.message_for(code)})
		# A turn that died still reached the provider and may still be billed.
		# Recorded with no counts rather than not recorded, so the turn appears
		# in a budget as something that happened.
		usage.record_failure(
			adapter=adapter,
			provider=provider,
			model=model,
			turn_id=turn_id,
			request_id=request_id,
			channel="App",
			user=user,
		)
		return

	# One row per turn, at the single point where every outcome is known. It
	# cannot raise and its failure cannot reach the work above it — see
	# `usage.record`.
	usage.record_turn(
		result,
		adapter=adapter,
		provider=provider,
		model=model,
		turn_id=turn_id,
		request_id=request_id,
		channel="App",
		user=user,
	)

	if result.status == "needs_confirmation":
		publish(
			{
				"type": "needs_confirmation",
				"text": result.text,
				"calls": proposals.record(
					result.pending,
					turn_id,
					provider=provider or llm.get_settings().provider,
					model=model or getattr(adapter, "model", None),
				),
			}
		)
		return

	publish(
		{
			"type": "done",
			"status": result.status,
			"text": result.text,
			"usage": {
				"input_tokens": result.usage.input_tokens if result.usage else None,
				"output_tokens": result.usage.output_tokens if result.usage else None,
			},
		}
	)


def _request_id(user: str, turn_id: str, phase: str) -> str:
	"""Stable, non-secret idempotency key for one provider invocation."""
	payload = json.dumps([user, turn_id, phase], ensure_ascii=False, separators=(",", ":"))
	return hashlib.sha256(payload.encode()).hexdigest()


def _carry_out(call_ids: list, publish) -> list[AIMessage]:
	"""Execute approved proposals and shape them as conversation for the model.

	Returns the assistant turn that asked, followed by one tool result per call,
	so the model sees a coherent history: it asked, the tools ran, here is what
	they said. The ids in that synthetic assistant turn are ours, which keeps
	the request and its result matched for every provider.
	"""
	calls: list[AIToolCall] = []
	results: list[AIMessage] = []

	for call_id in call_ids:
		action = _owned_pending_action(call_id)
		arguments = frappe.parse_json(action.action_data) or {}
		calls.append(
			AIToolCall(
				id=action.name,
				name=action.tool,
				arguments=arguments,
				provider_meta=frappe.parse_json(action.provider_meta) or {},
			)
		)

		outcome = action.approve()
		publish({"type": "tool", "tool": action.tool, "ok": bool(outcome.get("ok")), "call_id": action.name})

		results.append(
			AIMessage.tool(
				AIToolResult(
					call_id=action.name,
					name=action.tool,
					content=json.dumps(outcome, default=str),
					is_error=not outcome.get("ok"),
				)
			)
		)

	frappe.db.commit()
	return [AIMessage.assistant(tool_calls=tuple(calls)), *results]


def _owned_pending_action(call_id: str):
	"""The proposal behind a call id, if it is really this caller's to approve.

	Four things are checked and each has a way of going wrong that matters:
	the row exists (an invented id approves nothing), it is a tool call (the
	WhatsApp agent's proposals are not the chat's to resolve), the caller owns
	it (one user must not approve another's writes), and it is still Pending
	(so a replayed confirmation cannot run the same write twice).
	"""
	if not frappe.db.exists(PENDING_ACTION, call_id):
		frappe.throw(f"Unknown confirmation {call_id}")

	action = frappe.get_doc(PENDING_ACTION, call_id)

	if not action.tool:
		frappe.throw(f"{call_id} is not an assistant tool call")

	if action.owner != frappe.session.user:
		# Deliberately the same wording as an unknown id: telling a caller that
		# somebody else's confirmation exists is itself a small leak.
		frappe.throw(f"Unknown confirmation {call_id}")

	if action.status != "Pending":
		frappe.throw(f"Confirmation {call_id} was already {action.status.lower()}")

	return action


def _as_list(value) -> list:
	if isinstance(value, list):
		return value
	return frappe.parse_json(value or "[]") or []


def _parse_history(history) -> list:
	if not history:
		return []
	parsed = history if isinstance(history, list) else frappe.parse_json(history)
	return parsed[-MAX_HISTORY_MESSAGES:]


def _to_messages(history: list) -> list[AIMessage]:
	"""Rebuild prior turns from what the client sent.

	Only `user` and `assistant` prose is accepted. Tool calls and their results
	are deliberately *not* reconstructed from client input — a client that could
	assert "you already ran this tool and it returned X" could fabricate the
	model's evidence, which is a far more interesting attack than any prompt.
	"""
	messages = []
	for entry in history:
		if not isinstance(entry, dict):
			continue
		role = entry.get("role")
		text = (entry.get("text") or "").strip()
		if not text:
			continue
		if role == "assistant":
			messages.append(AIMessage.assistant(text=text))
		elif role == "user":
			messages.append(AIMessage.user(text))
	return messages
