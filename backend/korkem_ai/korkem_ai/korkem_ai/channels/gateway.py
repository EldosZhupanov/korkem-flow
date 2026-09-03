# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""One brain, several channels.

## What this is for

The app talks to the assistant through `chat.send`, which resolves a provider,
runs `agent/loop.run_turn` as the logged-in user, and streams the answer back.
Telegram and WhatsApp have no session and no socket, but everything *after* the
first step should be identical — the same loop, the same forty-two tools, the same
`Pending Action` confirmation, the same company scoping.

So this module does exactly the two things a channel needs and nothing else:

1. turn a provider-shaped payload into an `InboundMessage`;
2. turn an `InboundMessage` into a turn run **as a real user**.

No business logic lives here. A channel adapter speaks its own wire protocol and
hands over an `InboundMessage`; it never sees a tool, and the assistant never
sees a webhook.

## Why running as a user is the whole point

`scope.current_company()` reads `frappe.session.user`, and so does every
permission check beneath the tools. A webhook arrives as **Guest** — no company,
no rights. Handing a Guest turn to the assistant would not leak data, it would
simply fail; handing it an *administrator* would leak everything.

So an inbound message reaches the assistant only once a `Channel Identity` says
who is speaking, and the turn then runs with `frappe.set_user` — the same
mechanism `chat.run_turn_job` already uses for the app. An unlinked sender gets
a polite refusal and an administrator gets a row to look at.

## Delivery is at-most-once per provider message

Both providers retry. A retried webhook must not run a second turn, and above
all must not run a second *write*: the confirmation flow protects writes behind
a `Pending Action`, but a duplicated question is still a duplicated answer and a
duplicated bill. Every inbound message is recorded by its provider id first, and
a repeat is dropped before anything else happens.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import frappe

from korkem_ai.korkem_ai.doctype.channel_event import channel_event as audit
from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities
from korkem_ai.korkem_ai.channels import confirmation
from korkem_ai.korkem_ai.tools import policy

#: The channels this gateway knows how to answer on. `app` is the Flutter
#: client, which does not come through here — it is listed so a conversation
#: recorded from any source names its origin in one vocabulary.
TELEGRAM = "Telegram"
WHATSAPP = "WhatsApp"
#: Приложение на телефоне человека. Не мессенджер: сюда уходит сигнал,
#: а не сообщение — см. `integrations/push.py`.
PUSH = "Push"

CONVERSATION = "Agent Conversation"
MESSAGE = "Agent Conversation Message"

#: Where the current turn's correlation id lives while the turn runs. A flag
#: rather than an argument for the same reason the role pin is one: everything
#: that wants it — the audit writer, the proposal recorder, the notification
#: service — sits several layers below the call that knows it.
TURN_FLAG = "korkem_turn_id"


def current_turn() -> str | None:
	"""The turn this code is running inside, if any."""
	return frappe.flags.get(TURN_FLAG)


@dataclass(frozen=True)
class InboundMessage:
	"""One message from a channel, in the only shape the assistant sees.

	`external_id` identifies the *person* (a Telegram user id, a phone number);
	`chat_id` identifies where to reply, which for Telegram is a different
	number and for WhatsApp is the same one. Keeping them apart is what lets a
	group chat work later without revisiting identity.
	"""

	channel: str
	external_id: str
	chat_id: str
	text: str
	message_id: str
	sender_name: str | None = None
	metadata: dict = field(default_factory=dict)


def already_seen(channel: str, message_id: str) -> bool:
	"""Whether this provider message has been accepted before.

	Recorded against the conversation message rather than in a table of its own:
	the provider's id is the natural key and it is already being written down.
	"""
	if not message_id:
		return False
	return bool(
		frappe.db.exists(
			MESSAGE, {"external_message_id": message_id, "external_channel": channel}
		)
	)


def conversation_for(message: InboundMessage, user: str | None):
	"""The running conversation for this chat, or a new one.

	Keyed by channel and chat, not by person: two people writing from the same
	group are one thread, and one person writing from two devices is still one
	thread per chat.
	"""
	name = frappe.db.get_value(
		CONVERSATION,
		{"channel": message.channel, "external_chat_id": message.chat_id, "status": "Active"},
		"name",
	)
	if name:
		return frappe.get_doc(CONVERSATION, name)

	doc = frappe.get_doc(
		{
			"doctype": CONVERSATION,
			"channel": message.channel,
			"external_chat_id": message.chat_id,
			"contact_phone": message.external_id if message.channel == WHATSAPP else None,
			"user": user,
			"status": "Active",
			"started_on": frappe.utils.now_datetime(),
		}
	)
	doc.insert(ignore_permissions=True)
	return doc


def record(conversation, sender: str, text: str, message: InboundMessage | None = None):
	"""Write one line of the transcript."""
	row = frappe.get_doc(
		{
			"doctype": MESSAGE,
			"conversation": conversation.name,
			"sender": sender,
			"content": text,
			"sent_at": frappe.utils.now_datetime(),
			"external_message_id": message.message_id if message else None,
			"external_channel": message.channel if message else None,
		}
	)
	row.insert(ignore_permissions=True)
	return row


def accept(message: InboundMessage) -> dict:
	"""Take one inbound message as far as it can safely go.

	Returns what happened, for the adapter's log and for tests. This runs inside
	the webhook, so it does only cheap work: everything that can block — the
	model, the tools — is queued.
	"""
	if already_seen(message.channel, message.message_id):
		# Recorded, because "the provider sent it twice" is the single most
		# useful thing to know when somebody says the bot answered twice.
		audit.record(
			audit.DUPLICATE,
			channel=message.channel,
			provider_message_id=message.message_id,
			status="dropped",
		)
		return {"status": "duplicate", "message_id": message.message_id}

	identity = identities.observe(message.channel, message.external_id, message.sender_name)
	speaker = identities.speaker_for(identity)

	conversation = conversation_for(message, speaker)
	record(conversation, "User", message.text, message)

	if not speaker:
		# An unknown number is not a failure — it is usually a customer, and the
		# sales path already knows what to do with one. So the message goes
		# where it always went, and the identity row is there for an
		# administrator who wants to make this person staff instead.
		#
		# What must not happen is the assistant running for them: it would have
		# no user, therefore no company, therefore no permissions — and the
		# tools would refuse everything with an error a customer should never
		# see.
		if frappe.db.get_single_value("AI Settings", "enabled"):
			from korkem_ai.korkem_ai.orchestrator import router

			router.handle_message_async(
				conversation.name,
				message.text,
				# Only when the provider actually gave us an id. `request_id`
				# is a unique key on `AI Usage Log`, so a synthesised one —
				# "Telegram:None" for every message that lacks an id — would
				# make the second such call collide with the first and be
				# recorded as the same provider request. Two calls counted as
				# one is a quieter failure than a crash and a worse one: the
				# ledger exists to make spend visible.
				#
				# The linked path below already guards this way
				# (`deduplicate=bool(message.message_id)`); this one did not,
				# and two adjacent paths disagreeing about the same fact is how
				# it would have been missed.
				request_id=(
					f"{message.channel}:{message.message_id}" if message.message_id else None
				),
				channel=message.channel,
			)
		audit.record(
			audit.UNLINKED,
			channel=message.channel,
			provider_message_id=message.message_id,
			conversation=conversation.name,
			status="sales_path",
			detail=f"identity {identity.name} speaks for nobody",
		)
		return {
			"status": "unlinked",
			"conversation": conversation.name,
			"identity": identity.name,
		}

	frappe.enqueue(
		"korkem_ai.korkem_ai.channels.gateway.run_turn_job",
		queue="long",
		conversation=conversation.name,
		user=speaker,
		text=message.text,
		channel=message.channel,
		chat_id=message.chat_id,
		channel_role=identity.role or None,
		message_id=message.message_id,
		job_id=f"{message.channel}:{message.message_id}",
		deduplicate=bool(message.message_id),
	)
	role = policy.effective_role(speaker, identity.role or None)
	audit.record(
		audit.IDENTIFIED,
		channel=message.channel,
		provider_message_id=message.message_id,
		conversation=conversation.name,
		user=speaker,
		status=role,
	)
	return {
		"status": "queued",
		"conversation": conversation.name,
		"user": speaker,
		"identity": identity.name,
		"role": role,
	}


def run_turn_job(
	conversation: str,
	user: str,
	text: str,
	channel: str,
	chat_id: str,
	channel_role: str | None = None,
	message_id: str | None = None,
):
	"""The assistant's own turn, run as the person who wrote in.

	`frappe.set_user` is the whole security boundary: every tool in this turn is
	subject to that user's permissions and their company, exactly as it would be
	from the app. A job that ran as Administrator would hand the model the entire
	bench and no care taken in the tools would undo it.
	"""
	# One id for this turn, minted here because this is where the turn begins.
	# Everything it causes — the audit rows, the proposal, the notification that
	# goes back out — carries it, so an incident can be followed from a provider
	# message to an ERPNext document without joining on timestamps.
	turn = f"{channel}:{message_id}" if message_id else frappe.generate_hash(length=12)
	frappe.flags[TURN_FLAG] = turn

	frappe.set_user(user)
	# The pin travels as a flag rather than an argument because everything that
	# asks about a role — the registry, the customer scope, the system
	# instruction — is several layers below this call and none of them should
	# grow a parameter for it. It comes from the `Channel Identity` row, which
	# only an administrator can write.
	#
	# Cleared afterwards, and that is not tidiness: a queue worker reuses its
	# process, and a pin left behind would be applied to the next person's turn.
	frappe.flags[policy.CHANNEL_ROLE_FLAG] = channel_role or None
	try:
		return _run_turn(
			doc_name=conversation,
			user=user,
			text=text,
			channel=channel,
			chat_id=chat_id,
			turn=turn,
			request_id=turn,
		)
	finally:
		frappe.flags.pop(policy.CHANNEL_ROLE_FLAG, None)
		frappe.flags.pop(TURN_FLAG, None)


def _run_turn(
	*,
	doc_name: str,
	user: str,
	text: str,
	channel: str,
	chat_id: str,
	turn: str | None = None,
	request_id: str | None = None,
):
	"""The turn itself, once the session and the role pin are in place."""
	from korkem_ai.korkem_ai import budget, errors, usage
	from korkem_ai.korkem_ai.agent import loop
	from korkem_ai.korkem_ai.orchestrator import llm
	from korkem_ai.korkem_ai.orchestrator.protocol import AIMessage

	conversation = doc_name
	doc = frappe.get_doc(CONVERSATION, conversation)

	# A *linked* customer now reaches the assistant like anybody else. Until
	# Phase 28 they could not: filtering which tools exist does nothing about
	# which rows they read, so the only safe answer was none. What changed is
	# that every customer-reachable tool pins its reads to
	# `scope.current_customer()` — from the session, unreachable from the
	# message — so the same brain can answer them without a second one existing.
	#
	# An *unlinked* sender still never gets here: `accept` sends them to the
	# sales router, because with no user there is no company and every tool
	# would refuse.

	# A reply that decides whether a write runs is answered here, without the
	# model. Letting something that can be argued with re-interpret "подтверждаю"
	# is the one shortcut this flow cannot afford.
	verdict = confirmation.handle(user, conversation, text)
	if verdict:
		audit.record(
			audit.CONFIRMED,
			channel=channel,
			conversation=conversation,
			turn_id=turn,
			user=user,
			status=verdict["status"],
			pending_action=verdict.get("action"),
			work_instruction=verdict.get("instruction"),
		)
		record(doc, "Agent", verdict["reply"])
		deliver(channel, chat_id, verdict["reply"])
		return {"conversation": conversation, "status": verdict["status"]}

	awaiting = None
	adapter = None
	try:
		# Refused before the provider is reached, so the refusal costs nothing.
		# A channel turn spends the same budget as an app turn and is checked
		# the same way — a limit that only the app honoured would be no limit,
		# because Telegram reaches the identical brain.
		budget.check(user)

		adapter = llm.resolve(None, None)
		# Тот же ключ однократного выполнения, что и в приложении: канал ходит
		# в тот же мозг и создаёт те же заказы.
		result = loop.run_turn([AIMessage.user(text)], provider=adapter, run_id=turn)
		# Same single point as the app path: every outcome is known here, and a
		# channel turn costs exactly what an app turn costs. `record_turn`
		# rather than `record` so that nothing about describing the turn is
		# evaluated outside the guard — see its docstring for the fourteen
		# tests that taught us the difference.
		usage.record_turn(
			result,
			adapter=adapter,
			turn_id=turn,
			request_id=request_id,
			conversation=conversation,
			channel=channel if channel in usage.CHANNELS else "App",
			user=user,
		)
		answer = result.text
		if result.status == "needs_confirmation":
			# The proposal is already written down as a Pending Action by the
			# loop. Tying it to this conversation is what lets a bare
			# "подтверждаю" resolve to it later without guessing.
			answer, awaiting = _await_confirmation(doc, result, answer)
	except budget.BudgetExceeded as exc:
		# Its own sentence, not a generic code: somebody who cannot work needs
		# to know whether to wait or to ask for a bigger budget. Nothing is
		# logged as an error, because this is the guard working.
		answer = str(exc)
		record(doc, "Agent", answer)
		deliver(channel, chat_id, answer)
		return {"conversation": conversation, "status": "refused"}
	except Exception as exc:
		frappe.log_error(title="Channel turn failed", message=_safe_traceback())
		usage.record_failure(
			adapter=adapter,
			turn_id=turn,
			request_id=request_id,
			conversation=conversation,
			channel=channel if channel in usage.CHANNELS else "App",
			user=user,
		)
		audit.record(
			audit.FAILED,
			channel=channel,
			conversation=conversation,
			turn_id=turn,
			user=user,
			status=str(errors.classify(exc)),
		)
		answer = errors.message_for(errors.classify(exc))

	record(doc, "Agent", answer)
	# Only one proposal gets buttons. Two sets on one message would be a pair of
	# yes/no pairs with nothing saying which is which, and the text protocol
	# already handles the rare case by naming each action.
	try:
		deliver(channel, chat_id, answer, confirm_for=awaiting)
		audit.record(
			audit.SENT,
			channel=channel,
			conversation=conversation,
			turn_id=turn,
			user=user,
			status="answered",
			pending_action=awaiting,
		)
	except Exception as exc:
		# The turn happened; the reply did not arrive. Recorded as such rather
		# than raised, because retrying the job would re-run the turn — and a
		# turn that already wrote a Pending Action must not write a second one.
		audit.record(
			audit.FAILED,
			channel=channel,
			conversation=conversation,
			turn_id=turn,
			user=user,
			status="delivery_failed",
			detail=_provider_reason(exc),
		)
	return {"conversation": conversation, "status": "answered"}


def _provider_reason(exc: Exception) -> str:
	"""A provider failure in words that are safe to store.

	The adapters raise typed errors carrying the provider's own description with
	anything token-shaped removed. Anything else is reduced to its class name:
	an arbitrary exception's text is exactly where a credential travels.
	"""
	from korkem_ai.korkem_ai.integrations.telegram import TelegramError
	from korkem_ai.korkem_ai.integrations.whatsapp import WhatsAppError

	if isinstance(exc, TelegramError | WhatsAppError):
		return f"{exc.code}: {exc}"
	return type(exc).__name__


def _safe_traceback() -> str:
	"""The traceback, with any bot token redacted out of it.

	Telegram puts its credential in the URL, so a `requests` traceback from a
	call this module did not make — a library retry, a nested helper — could
	still carry one into `Error Log`. Cheap to prevent and unpleasant to discover.
	"""
	from korkem_ai.korkem_ai.integrations import telegram

	try:
		return telegram.redact(frappe.get_traceback(), telegram.token())
	except Exception:
		return frappe.get_traceback()


def _await_confirmation(conversation_doc, result, answer: str | None) -> tuple[str, str | None]:
	"""Attach the turn's proposals to this conversation and ask for a yes.

	The `Pending Action` rows already exist — the loop wrote them when the model
	proposed. All that is added here is which conversation they belong to, so a
	reply in this thread can find them, and the sentence a person answers.
	"""
	from korkem_ai.korkem_ai.agent import proposals

	# Written here, by the same recorder the app uses. This used to look the
	# rows up by the provider's own call id and skip every one it did not find —
	# which was all of them, because nothing on this path had ever written one.
	# A foreman was shown a sentence describing a write and given nothing to
	# confirm.
	# The turn's own id, not the conversation's: a conversation is a thread and
	# a turn is one message in it, and an incident is about the message.
	recorded = proposals.record(
		result.pending, turn_id=current_turn() or conversation_doc.name
	)

	asked = []
	names = []
	for row in recorded:
		action = frappe.get_doc("Pending Action", row["id"])
		action.db_set("conversation", conversation_doc.name, update_modified=False)
		asked.append(confirmation.describe(action))
		names.append(action.name)
		audit.record(
			audit.PROPOSED,
			channel=conversation_doc.channel,
			conversation=conversation_doc.name,
			turn_id=action.turn_id,
			user=action.owner,
			tool=action.tool,
			pending_action=action.name,
			status="awaiting_confirmation",
		)

	if not asked:
		return (answer or "").strip(), None
	text = "\n\n".join(part for part in [(answer or "").strip(), *asked] if part)
	return text, (names[0] if len(names) == 1 else None)


def deliver(
	channel: str,
	chat_id: str,
	text: str,
	confirm_for: str | None = None,
	ask: bool = False,
) -> dict:
	"""Send a reply on whichever channel it came from.

	The one place that knows a channel name maps to an adapter. Adapters are
	imported here rather than at module scope so a site with one channel
	configured does not need the other's settings to exist.

	`confirm_for` names a proposal or a job awaiting an answer. What that looks
	like is the adapter's business — inline buttons on Telegram, an interactive
	message on WhatsApp — and either way a press comes back as the same
	`CONFIRM <id>` text a person could have typed. The gateway does not know what
	a button is.

	`ask` offers a third answer, and only where a third answer is real: a job can
	be answered with a question, a write is a yes or a no.
	"""
	if channel == TELEGRAM:
		from korkem_ai.korkem_ai.integrations import telegram

		return telegram.send_message(chat_id, text, confirm_for=confirm_for, ask=ask)
	if channel == WHATSAPP:
		from korkem_ai.korkem_ai.integrations import whatsapp

		return whatsapp.send_message(chat_id, text, confirm_for=confirm_for, ask=ask)
	if channel == PUSH:
		from korkem_ai.korkem_ai.integrations import push

		# `text` сюда доходит и здесь же остаётся. Push идёт через серверы
		# Google, а мы обещаем клиенту, что содержание его работы не покидает
		# здания (R6): наружу уходит только признак события, а текст человек
		# читает в приложении, забрав его со своего узла. Кнопки подтверждения
		# по той же причине не отправляются — согласиться с предложением можно
		# в приложении, где видно, с чем именно соглашаешься.
		return push.send(chat_id)
	frappe.throw(f"No adapter for channel {channel}")
