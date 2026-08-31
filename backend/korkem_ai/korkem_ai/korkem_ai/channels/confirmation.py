# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Answering from a chat app — a write to authorise, or a job to accept.

## What this is not

It is not a second approval model. `Pending Action` already does the hard part
— it records the tool and its arguments when the model proposes them, re-checks
the target still exists, claims itself with a single conditional UPDATE so two
confirmations cannot both win, and refuses once it is no longer `Pending`. All
of that is reused unchanged; the app and the chat apps approve the same row by
the same method.

What was missing is the bit either side of it: turning *"подтверждаю"* in a chat
into a specific row, and refusing when it is not this person's row to approve.

## Why a bare "да" is dangerous, and when it is not

A model that reads agreement out of prose is a model that can be talked into
agreeing. So "да" is never interpreted as approval of *something* — it is
resolved against the conversation, and only when exactly one action is waiting
in it, owned by the person who wrote it. Two waiting actions make "да" ambiguous
and it is refused with both named, because guessing here executes a write
somebody did not ask for.

An explicit `CONFIRM <id>` carries its own answer and does not need the
conversation to be unambiguous — but it still has to be that person's action.

## Two kinds of thing, one protocol

A `Pending Action` asks "shall I run this write?". A `Work Instruction` asks
"will you do this work?". They are different questions and they are answered
with the same two buttons, because to the person holding the phone they are the
same gesture — and because a second button protocol would be a second way for a
press to be misread.

So a name is resolved against both, in that order, and a bare "принял" prefers
the instruction: a foreman accepting a job has not agreed to anything else.

## The reference is the row's own name

`Pending Action` is named by hash, so its name is already short, opaque and
non-sequential — there is nothing to be learned from seeing one and nothing to
be guessed from having seen another. Minting a second identifier would mean
keeping two in step for no gain.

Ownership is what protects it, not obscurity: a name belonging to somebody else
is refused in the same words as a name that does not exist, because confirming
that another person has a pending action is itself worth nothing to them and
something to whoever is asking.
"""

from __future__ import annotations

import re

import frappe
from frappe.utils import now_datetime

from korkem_ai.korkem_ai.doctype.work_instruction import work_instruction as instructions

PENDING_ACTION = "Pending Action"
INSTRUCTION = "Work Instruction"

#: Words that mean yes. Deliberately short and exact — this list decides whether
#: a write runs, so anything ambiguous is left off it. "давай" and "хорошо" are
#: absent on purpose: they agree with a sentence, not necessarily with an action.
YES = frozenset(
	{"да", "подтверждаю", "подтвердить", "подтверждаю.", "ок", "ok", "yes", "confirm", "выполняй"}
)
NO = frozenset(
	{"нет", "отмена", "отменить", "не надо", "cancel", "no", "стоп", "не выполняй"}
)

#: Answers to *being given work*, which is a different question from "shall I
#: run this write". Kept apart so that "принял" resolves against the instruction
#: even when a proposal is also waiting — a foreman accepting a job has not
#: agreed to anything else.
ACCEPTED = frozenset({"принял", "принято", "принимаю", "беру", "accept", "принял задание"})
REFUSED = frozenset({"не могу", "не могу выполнить", "отказываюсь", "не возьму", "reject"})

_EXPLICIT = re.compile(
	r"^\s*(confirm|cancel|ask|подтвердить|отменить|уточнить)\s+([A-Za-z0-9_-]{4,64})\s*$", re.I
)


def waiting_for(user: str, conversation: str | None = None) -> list[dict]:
	"""Actions this person could still approve.

	Scoped to the conversation when one is given, because a chat reply belongs
	to the thread it was written in. Expired rows are excluded here as well as
	refused later — an expired action should not make "да" ambiguous.
	"""
	filters = {"owner": user, "status": "Pending"}
	if conversation:
		filters["conversation"] = conversation
	rows = frappe.get_all(
		PENDING_ACTION,
		filters=filters,
		fields=["name", "tool", "display_data", "expires_at"],
		order_by="creation asc",
	)
	now = now_datetime()
	return [row for row in rows if not row["expires_at"] or row["expires_at"] > now]


def parse(text: str) -> tuple[str | None, str | None]:
	"""What this message is asking for: ("confirm"|"cancel"|None, reference|None)."""
	intent, reference, _prefers = parse_full(text)
	return intent, reference


def parse_full(text: str) -> tuple[str | None, str | None, str | None]:
	"""As `parse`, plus which kind of thing the wording is about.

	The third value is `"instruction"` when the person answered *being given
	work* rather than *being asked to authorise a write*. It only ever breaks a
	tie; it can never reach something that is not theirs.
	"""
	if not text:
		return None, None, None

	explicit = _EXPLICIT.match(text)
	if explicit:
		verb = explicit.group(1).lower()
		if verb in ("ask", "уточнить"):
			# A question is only ever about a job. A proposal answered with
			# "maybe" would sit unresolved, so the third button is not offered
			# there and the word is not accepted there either.
			return "ask", explicit.group(2), "instruction"
		intent = "confirm" if verb in ("confirm", "подтвердить") else "cancel"
		return intent, explicit.group(2), None

	word = text.strip().casefold().rstrip("!.")
	if word in ACCEPTED:
		return "confirm", None, "instruction"
	if word in REFUSED:
		return "cancel", None, "instruction"
	if word in YES:
		return "confirm", None, None
	if word in NO:
		return "cancel", None, None
	return None, None, None


def describe(action) -> str:
	"""What a person is being asked to agree to, and how to say yes.

	The tool's own name is not shown. It is an internal identifier and means
	nothing to a foreman; the display data the proposal recorded is what was
	written for a human to read.
	"""
	detail = ""
	if action.display_data:
		data = frappe.parse_json(action.display_data)
		if isinstance(data, dict):
			detail = data.get("summary") or data.get("message") or ""
	return (
		f"{detail}\n\nПодтвердить?\n"
		f"Ответьте «подтверждаю» или «отмена», либо CONFIRM {action.name} / CANCEL {action.name}."
	).strip()


def handle(user: str, conversation: str, text: str) -> dict | None:
	"""Deal with a confirmation reply, or return None if this is not one.

	`None` means "ordinary message" and the caller should run a normal turn.
	Everything else is answered here without the model being involved at all —
	a reply that decides whether a write runs must not be re-interpreted by
	something that can be argued with.
	"""
	intent, reference, prefers = parse_full(text)
	if not intent:
		return None

	# Ownership is checked against `user`, but `Pending Action.claim` stamps
	# `resolved_by` from the session. If those two ever disagreed, the row would
	# record one person having approved another person's action — a false audit
	# trail, which is worse than no audit trail. The caller runs inside
	# `set_user`, so they agree; this makes it impossible for them not to.
	if frappe.session.user != user:
		frappe.throw(
			"A confirmation must be handled as the person confirming it "
			f"(session is {frappe.session.user}, asked for {user})."
		)

	pending = waiting_for(user, conversation)
	assigned = instructions.open_for(user)

	if reference:
		# A name is answered by whichever kind of thing it is — a proposal or an
		# instruction — and by neither if it is not this person's. One protocol,
		# two kinds of thing, and the button that carries the name does not know
		# which it is.
		action = _mine(reference, user)
		if not action:
			job = _my_instruction(reference, user)
			if job:
				return _answer_instruction(job, intent, text)
			# Same words for "not yours" and "no such thing". Confirming that
			# somebody else has an action pending is worth nothing to them.
			return {"status": "unknown", "reply": "Не нашёл такого действия."}
	elif prefers == "instruction" and len(assigned) == 1:
		return _answer_instruction(
			frappe.get_doc(INSTRUCTION, assigned[0]["name"]), intent, text
		)
	elif not pending:
		if len(assigned) == 1:
			return _answer_instruction(
				frappe.get_doc(INSTRUCTION, assigned[0]["name"]), intent, text
			)
		if len(assigned) > 1:
			listed = "\n".join(f"  {row['name']}" for row in assigned)
			return {
				"status": "ambiguous",
				"reply": (
					f"У вас несколько заданий ({len(assigned)}). Укажите, какое:\n{listed}\n"
					"Например: CONFIRM " + assigned[0]["name"]
				),
			}
		# Nothing open. If the last thing they were asked has already been
		# answered, say that instead — a second press of a button that has
		# already worked must not read as "there was nothing to press".
		last = instructions.latest_for(user)
		if last:
			return {
				"status": "already_answered",
				"instruction": last["name"],
				"reply": _answered(frappe._dict(last)),
			}
		return {"status": "nothing_pending", "reply": "Сейчас нечего подтверждать."}
	elif len(pending) > 1:
		listed = "\n".join(f"  {row['name']}" for row in pending)
		return {
			"status": "ambiguous",
			"reply": (
				f"У вас несколько ожидающих действий ({len(pending)}). Укажите, какое:\n{listed}\n"
				"Например: CONFIRM " + pending[0]["name"]
			),
		}
	else:
		action = frappe.get_doc(PENDING_ACTION, pending[0]["name"])

	# `ASK` is about a job, never about a write. Without this the word would fall
	# through to the approval branch below and *approve* the proposal it named —
	# the third button offered on an instruction, pointed at a Pending Action, and
	# a write nobody agreed to.
	if intent == "ask":
		return {
			"status": "not_askable",
			"action": action.name,
			"reply": "Это действие нужно подтвердить или отменить.",
		}

	if intent == "cancel":
		if action.status != "Pending":
			return {"status": "already_resolved", "reply": _resolved_reply(action)}
		action.reject(reason=f"Cancelled from a channel by {user}")
		return {"status": "cancelled", "action": action.name, "reply": "Отменено. Ничего не выполнено."}

	if action.status != "Pending":
		return {"status": "already_resolved", "action": action.name, "reply": _resolved_reply(action)}

	try:
		action.approve()
	except Exception as exc:
		# `approve` refuses expiry, a vanished target and a lost claim by
		# raising. None of those are faults of the person replying, and none
		# leave the row falsely completed.
		return {"status": "refused", "action": action.name, "reply": str(exc)[:300]}

	return {"status": "approved", "action": action.name, "reply": "Готово, выполнено."}


def _mine(name: str, user: str):
	"""The action with this name, if it belongs to this person."""
	owner = frappe.db.get_value(PENDING_ACTION, name, "owner")
	if not owner or owner != user:
		return None
	return frappe.get_doc(PENDING_ACTION, name)


def _my_instruction(name: str, user: str):
	"""The instruction with this name, if it was given to this person.

	Ownership here is `employee_user`, not `owner`: the row is created by
	whoever dispatched it, and the person entitled to answer is the person it
	was sent to. Somebody else's instruction is refused in the same words as one
	that does not exist.
	"""
	if not frappe.db.exists(INSTRUCTION, name):
		return None
	doc = frappe.get_doc(INSTRUCTION, name)
	return doc if doc.employee_user == user else None


def _answer_instruction(doc, intent: str, text: str) -> dict:
	"""Accept, refuse, or ask about a job — the first two exactly once.

	The second press changes nothing and says so, the same contract a second
	confirmation of a `Pending Action` gets: providers re-deliver, and people
	double-tap.

	A question is different in kind. It resolves nothing, so it can be asked more
	than once, and what it does is put the person who gave the instruction back
	in the conversation.
	"""
	if intent == "ask":
		# Recorded as its own status: "nobody answered" and "somebody asked a
		# question" are different problems for whoever is waiting on this job.
		doc.ask(text)
		delivery = instructions.notify_owner(doc, "спрашивает: что именно нужно уточнить?")
		return {
			"status": "asked",
			"instruction": doc.name,
			"reply": (
				"Передал вопрос тому, кто поставил задание."
				if delivery["delivered"]
				else "Записал. Задание пока не принято — ответьте, когда решите."
			),
		}

	if intent == "cancel":
		if not doc.refuse(text):
			return {"status": "already_answered", "instruction": doc.name, "reply": _answered(doc)}
		instructions.notify_owner(doc, f"не принял задание: «{text}»")
		return {
			"status": "rejected",
			"instruction": doc.name,
			"reply": "Понял, задание не принято. Передал администратору.",
		}

	if not doc.acknowledge(text):
		return {"status": "already_answered", "instruction": doc.name, "reply": _answered(doc)}
	instructions.notify_owner(doc, "принял задание.")
	return {
		"status": "acknowledged",
		"instruction": doc.name,
		"reply": "Задание принято. Отметьте, когда начнёте и когда закончите.",
	}


def _answered(doc) -> str:
	if doc.status == instructions.ACKNOWLEDGED:
		return "Это задание уже принято."
	if doc.status == instructions.REJECTED:
		return "Это задание уже отклонено."
	return "Это задание уже закрыто."


def _resolved_reply(action) -> str:
	if action.status == "Approved":
		return "Это действие уже выполнено."
	if action.status == "Rejected":
		return "Это действие было отменено."
	return "Срок подтверждения истёк. Повторите запрос."
