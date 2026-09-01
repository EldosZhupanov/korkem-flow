# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Telegram Bot API integration.

Per ADR-0011 (integrations through gateways) this module is the one place that
speaks Telegram's wire protocol. Nothing else in the app knows what an "update"
is, and this module knows nothing about production, orders or tools — it hands
an `InboundMessage` to `channels.gateway` and sends back whatever comes out.

Webhook-first, per https://core.telegram.org/bots/api#setwebhook. Long polling
is deliberately absent: it needs a process that never stops, and this app has
webhooks and a queue already.

## How the request is trusted

`setWebhook` takes a `secret_token`, and Telegram then sends it back in the
`X-Telegram-Bot-Api-Secret-Token` header on every update
(https://core.telegram.org/bots/api#setwebhook). That is the whole
authentication: the URL is public, so the header is what distinguishes Telegram
from anyone who has guessed it. Compared with `hmac.compare_digest` rather than
`==`, for the same reason the WhatsApp signature is.

## The token is in the URL, which is why nothing here raises with a URL in it

Telegram authenticates by putting the bot token in the *path*:
`https://api.telegram.org/bot<TOKEN>/sendMessage`. So `requests`' own
`raise_for_status()` produces an exception whose text contains the credential —
and `frappe.log_error(message=frappe.get_traceback())`, which every caller in
this app eventually reaches, would then store it in the database in clear.

Measured, not assumed: an HTTPError from that call reads
*"401 Client Error: Unauthorized for url: https://api.telegram.org/bot123:ABC…"*.

`_call` below is therefore the only way this module talks to Telegram. It
raises `TelegramError`, whose message is Telegram's own `description` and never
the URL, and it redacts anything token-shaped as a second line of defence.

## What is verified here

The payload parsing, secret comparison and outbound request construction are
exercised by tests that make no network call. **Live send and receive against
the real Telegram network has not been verified in this environment** — it needs
a public HTTPS URL that Telegram can reach, and this bench is
`korkem.localhost` inside Docker.
"""

from __future__ import annotations

import hmac
import re

import frappe
import requests

TELEGRAM_SETTINGS = "Telegram Settings"
API_ROOT = "https://api.telegram.org"
TIMEOUT_SECONDS = 20


class TelegramError(frappe.ValidationError):
	"""Telegram refused, or could not be reached. Never carries a credential."""

	def __init__(self, message: str, code: str = "provider_error", payload: dict | None = None):
		super().__init__(message)
		self.code = code
		self.payload = payload or {}


def get_settings():
	return frappe.get_single(TELEGRAM_SETTINGS)


def token() -> str | None:
	return get_settings().get_password("bot_token", raise_exception=False)


def redact(text: str, secret: str | None) -> str:
	"""Take a credential out of a message that is about to be shown or stored.

	Belt and braces: `_call` already avoids putting the URL anywhere. This
	catches the case where a message came from somewhere else — a library
	changing its wording, a nested exception — because a token in a log is a
	token published to everybody who can read logs.
	"""
	if secret and secret in text:
		text = text.replace(secret, "«bot token»")
	return re.sub(r"/bot\d+:[A-Za-z0-9_-]+", "/bot«token»", text)


def classify_status(status_code: int) -> str:
	"""What a provider's HTTP status means for whether trying again can help.

	The distinction that matters is retryable vs not, and it is not the same as
	success vs failure:

	* **401 / 404** — the token is wrong or the bot does not exist. Permanent
	  until somebody edits the settings; retrying only tells Telegram we still
	  have the same bad token.
	* **403** — the bot is blocked by that chat, or was removed from it. Also
	  permanent, and a different fix: somebody has to unblock it.
	* **429** — rate limited. The one refusal that retrying is *exactly* the
	  right answer to, which is why it must not be lumped in with the others.
	* **5xx** — the provider is having a bad day. Retryable.
	"""
	if status_code in (401, 404):
		return "invalid_credentials"
	if status_code == 403:
		return "forbidden"
	if status_code == 429:
		return "rate_limited"
	if status_code >= 500:
		return "provider_unavailable"
	return "provider_error"


def _call(method: str, payload: dict | None = None, http: str = "post") -> dict:
	"""One Telegram API call, with the credential kept out of every outcome.

	Returns the `result` object. Raises `TelegramError` with a code the settings
	screen can branch on: `not_configured`, `invalid_credentials`,
	`provider_unavailable`, `provider_error`.
	"""
	secret = token()
	if not secret:
		raise TelegramError("Bot token is not configured.", code="not_configured")

	url = f"{API_ROOT}/bot{secret}/{method}"
	try:
		response = (requests.post if http == "post" else requests.get)(
			url, json=payload or {}, timeout=TIMEOUT_SECONDS
		)
	except Exception as exc:
		# The reason, not the URL — `requests` puts the whole URL in its own
		# message, and the whole URL is the credential.
		raise TelegramError(
			redact(str(exc)[:300], secret), code="provider_unavailable"
		) from None

	try:
		body = response.json()
	except ValueError:
		raise TelegramError(
			f"Telegram answered {response.status_code} with something that is not JSON.",
			code="provider_error",
		) from None

	if not body.get("ok"):
		description = redact(str(body.get("description") or "")[:300], secret)
		raise TelegramError(
			description or f"Telegram refused with {response.status_code}.",
			code=classify_status(response.status_code),
			payload=body,
		)
	return body.get("result") if isinstance(body.get("result"), dict) else {"result": body.get("result")}


def verify_secret(header_value: str | None, expected: str | None) -> bool:
	"""Whether this request carries the secret we gave Telegram.

	A missing expectation means the bot was configured without one, and an
	unauthenticated public endpoint is not something to fail open on.
	"""
	if not expected or not header_value:
		return False
	return hmac.compare_digest(header_value, expected)


#: Telegram caps `callback_data` at 64 bytes
#: (https://core.telegram.org/bots/api#inlinekeyboardbutton). A Pending Action
#: name is a ten-character hash, so `confirm:<name>` fits with room to spare —
#: but the cap is why the row's own name is carried rather than anything richer.
CALLBACK_CONFIRM = "confirm:"
CALLBACK_CANCEL = "cancel:"
CALLBACK_ASK = "ask:"


def confirmation_markup(action_name: str, ask: bool = False) -> dict:
	"""Inline buttons for one specific proposal or job.

	The name travels in `callback_data`, so a press is unambiguous even if the
	person has several open or answers an old message — which is exactly the case
	a bare "да" has to refuse.

	`ask` adds a third button, and only where a third answer is real: being given
	work can be answered with a question, whereas a write is a yes or a no and
	offering "maybe" there would leave a proposal in a state nothing resolves.
	"""
	row = [
		{"text": "✅ Подтвердить", "callback_data": f"{CALLBACK_CONFIRM}{action_name}"},
		{"text": "❌ Отмена", "callback_data": f"{CALLBACK_CANCEL}{action_name}"},
	]
	if ask:
		row = [
			{"text": "✅ Принял", "callback_data": f"{CALLBACK_CONFIRM}{action_name}"},
			{"text": "❌ Не могу", "callback_data": f"{CALLBACK_CANCEL}{action_name}"},
			{"text": "❓ Уточнить", "callback_data": f"{CALLBACK_ASK}{action_name}"},
		]
	return {"inline_keyboard": [row]}


def _from_callback(payload: dict) -> dict | None:
	"""A button press, rendered as the text protocol it stands for.

	A press becomes `CONFIRM <id>`, which the confirmation layer already
	understands — so a native button and a typed reply travel exactly the same
	path and cannot drift apart.
	"""
	query = payload.get("callback_query")
	if not isinstance(query, dict):
		return None

	data = query.get("data") or ""
	sender = query.get("from") or {}
	chat = ((query.get("message") or {}).get("chat")) or {}
	if not sender.get("id") or not chat.get("id"):
		return None

	if data.startswith(CALLBACK_CONFIRM):
		text = f"CONFIRM {data[len(CALLBACK_CONFIRM):]}"
	elif data.startswith(CALLBACK_CANCEL):
		text = f"CANCEL {data[len(CALLBACK_CANCEL):]}"
	elif data.startswith(CALLBACK_ASK):
		text = f"ASK {data[len(CALLBACK_ASK):]}"
	else:
		return None

	return {
		"external_id": str(sender["id"]),
		"chat_id": str(chat["id"]),
		"text": text,
		# Keyed on the callback id, so Telegram re-delivering the press is
		# recognised as the same one and dropped.
		"message_id": f"cb:{query.get('id')}",
		"sender_name": sender.get("first_name") or sender.get("username"),
		"callback_query_id": query.get("id"),
	}


def parse_update(payload: dict) -> dict | None:
	"""The one message in a Telegram update, or None.

	Telegram sends one update per request and wraps it in `message`,
	`edited_message` or `callback_query`
	(https://core.telegram.org/bots/api#update). Anything without text — a
	photo, a sticker, a join event — is not something this assistant can answer,
	and is skipped rather than half-handled.
	"""
	pressed = _from_callback(payload)
	if pressed:
		return pressed

	message = payload.get("message") or payload.get("edited_message")
	if not isinstance(message, dict):
		return None

	text = message.get("text")
	chat = message.get("chat") or {}
	sender = message.get("from") or {}
	if not text or not chat.get("id") or not sender.get("id"):
		return None

	name = " ".join(
		part for part in (sender.get("first_name"), sender.get("last_name")) if part
	) or sender.get("username")

	return {
		"external_id": str(sender["id"]),
		"chat_id": str(chat["id"]),
		"text": text,
		"message_id": f"{chat['id']}:{message.get('message_id')}",
		"sender_name": name,
	}


def answer_callback(callback_query_id: str) -> None:
	"""Stop the spinner on a pressed button.

	Best effort: Telegram shows a loading state until this is called, but
	failing to clear it must never lose the confirmation that was already
	accepted. https://core.telegram.org/bots/api#answercallbackquery
	"""
	try:
		_call("answerCallbackQuery", {"callback_query_id": callback_query_id})
	except TelegramError:
		# Deliberately not logged with a traceback: the failure is a spinner,
		# and the traceback is where a credential would travel.
		frappe.logger("korkem_ai.channels").info(
			{"channel": "Telegram", "event": "answer_callback_failed"}
		)


def send_message(
	chat_id: str, text: str, confirm_for: str | None = None, ask: bool = False
) -> dict:
	"""Send one reply. https://core.telegram.org/bots/api#sendmessage"""
	if not get_settings().enabled:
		raise TelegramError("Telegram integration is disabled.", code="disabled")

	body = {"chat_id": chat_id, "text": text}
	if confirm_for:
		body["reply_markup"] = confirmation_markup(confirm_for, ask=ask)
	return _call("sendMessage", body)


def get_me() -> dict:
	"""Who this bot is, according to Telegram.

	https://core.telegram.org/bots/api#getme — the cheapest call that proves a
	token is real, which is what the settings screen's Test Connection asks.
	"""
	return _call("getMe", http="get")


def get_webhook_info() -> dict:
	"""What Telegram thinks it should be doing with our updates.

	https://core.telegram.org/bots/api#getwebhookinfo — `url`,
	`pending_update_count` and `last_error_message` are the three facts that
	explain a bot that has stopped answering, and none of them is guessable from
	our side.
	"""
	return _call("getWebhookInfo", http="get")


def delete_webhook(drop_pending: bool = False) -> dict:
	"""Stop Telegram sending here. https://core.telegram.org/bots/api#deletewebhook

	`drop_pending` is false by default and deliberately so: the updates queued at
	Telegram are messages real people sent, and throwing them away must be
	something somebody asks for.
	"""
	return _call("deleteWebhook", {"drop_pending_updates": bool(drop_pending)})


#: The only update types this assistant can answer. Telegram sends everything it
#: has unless told otherwise, and every type we do not handle is a webhook
#: delivery, a queue job and a log line spent on nothing.
ALLOWED_UPDATES = ["message", "edited_message", "callback_query"]

#: Telegram's own documented maximum for an update is well under this; anything
#: larger is not something this assistant can answer, and reading it into memory
#: is the only cost of finding that out.
MAX_UPDATE_BYTES = 1_000_000


def set_webhook(url: str) -> dict:
	"""Point Telegram at this site. https://core.telegram.org/bots/api#setwebhook

	The secret is sent here and comes back on every update, which is what makes
	the public endpoint trustworthy. Telegram requires **HTTPS** and refuses a
	private or non-resolvable host, so this is also the call that tells an
	operator their bench is not reachable — in Telegram's own words rather than
	ours.
	"""
	return _call(
		"setWebhook",
		{
			"url": url,
			"secret_token": get_settings().get_password("webhook_secret", raise_exception=False) or "",
			"allowed_updates": ALLOWED_UPDATES,
			# A webhook set from a settings screen replaces one set from
			# anywhere else; dropping what is already queued would silently lose
			# messages people sent while it was being configured.
			"drop_pending_updates": False,
		},
	)


@frappe.whitelist(allow_guest=True)
def webhook(**kwargs):
	"""Telegram's update endpoint.

	Exposed at
	`/api/method/korkem_ai.korkem_ai.integrations.telegram.webhook`.

	Answers 200 as fast as it can — Telegram retries an update it does not get
	an acknowledgement for, and a retried update that ran a second turn would
	cost twice and answer twice.
	"""
	from werkzeug.wrappers import Response

	from korkem_ai.korkem_ai.channels import gateway

	settings = get_settings()
	if not settings.enabled:
		return Response("Telegram integration disabled", status=403, mimetype="text/plain")

	if not verify_secret(
		frappe.get_request_header("X-Telegram-Bot-Api-Secret-Token"),
		# `raise_exception=False` is the whole point. `verify_secret` already
		# treats a missing expectation as a failed check — but by default
		# `get_password` throws first, so a site that is enabled and not yet
		# configured answered Telegram with a 500. Telegram retries a 500.
		settings.get_password("webhook_secret", raise_exception=False),
	):
		return Response("Invalid secret", status=401, mimetype="text/plain")

	body = frappe.request.get_data()
	if len(body) > MAX_UPDATE_BYTES:
		# Answered 200 and dropped. A 4xx or 5xx makes Telegram redeliver it,
		# and something this large is not an update we could have answered
		# anyway — the retry would cost the same and achieve the same.
		return Response("OK", status=200, mimetype="text/plain")

	try:
		payload = frappe.parse_json(body.decode("utf-8") or "{}")
	except Exception:
		# Malformed JSON used to raise, which Frappe turns into a 500 — and a
		# 500 is exactly what a provider retries. A body we cannot parse will
		# not parse next time either.
		return Response("OK", status=200, mimetype="text/plain")

	parsed = parse_update(payload) if isinstance(payload, dict) else None
	if parsed:
		if parsed.get("callback_query_id"):
			answer_callback(parsed["callback_query_id"])
		gateway.accept(
			gateway.InboundMessage(
				channel=gateway.TELEGRAM,
				external_id=parsed["external_id"],
				chat_id=parsed["chat_id"],
				text=parsed["text"],
				message_id=parsed["message_id"],
				sender_name=parsed["sender_name"],
			)
		)

	return Response("OK", status=200, mimetype="text/plain")
