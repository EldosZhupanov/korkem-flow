# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""WhatsApp Business (Meta Cloud API) integration.

Per ADR-0011 (integrations through gateways) this module is the one place that
speaks the WhatsApp wire protocol -- signature verification, payload shape,
the actual HTTP calls. Nothing else in this app should import `requests` or
know about Meta's JSON shape directly.

Real, correct integration code against Meta's documented Cloud API
(https://developers.facebook.com/docs/whatsapp/cloud-api/). Live send/receive
against the real WhatsApp network has NOT been verified end-to-end in this
environment -- no real WhatsApp Business Account/credentials are available
here. The webhook signature verification, payload parsing, and outbound
request construction are exercised by real (non-network) tests instead.
"""

import hashlib
import hmac

import frappe
import requests

from korkem_ai.korkem_ai.integrations.telegram import classify_status as telegram_classify

WHATSAPP_SETTINGS_DOCTYPE = "WhatsApp Settings"


def get_settings():
	return frappe.get_single(WHATSAPP_SETTINGS_DOCTYPE)


class WhatsAppError(frappe.ValidationError):
	"""Meta refused, or could not be reached. Never carries a credential."""

	def __init__(self, message: str, code: str = "provider_error", payload: dict | None = None):
		super().__init__(message)
		self.code = code
		self.payload = payload or {}


def verify_webhook_signature(
	payload_bytes: bytes, signature_header: str | None, app_secret: str | None
) -> bool:
	"""Verify Meta's `X-Hub-Signature-256` header against the raw request body.

	See https://developers.facebook.com/docs/graph-api/webhooks/getting-started#validate-payloads

	A **missing app secret is a failed verification, not a crash.** It used to be
	the latter: `app_secret.encode` on `None` raised `AttributeError`, so a site
	that had not finished configuring answered Meta with a 500 instead of a 401 —
	and the difference matters, because a 500 is what a caller retries.
	It is also, deliberately, not a pass: an unauthenticated public endpoint is
	not something to fail open on.
	"""
	if not app_secret or not signature_header or not signature_header.startswith("sha256="):
		return False

	expected = hmac.new(app_secret.encode("utf-8"), payload_bytes, hashlib.sha256).hexdigest()
	provided = signature_header.removeprefix("sha256=")
	return hmac.compare_digest(expected, provided)


#: Meta caps an interactive button's `title` at 20 characters and its `id` at
#: 256 (https://developers.facebook.com/docs/whatsapp/cloud-api/guides/send-messages).
#: Both labels below are well inside it, and a Pending Action name is a
#: ten-character hash.
BUTTON_CONFIRM = "confirm:"
BUTTON_CANCEL = "cancel:"
BUTTON_ASK = "ask:"


def _text_of(message: dict) -> str | None:
	"""What this message says, whether it was typed or pressed.

	A button press arrives as an `interactive` message carrying the id we put on
	the button, and is rendered here as the text protocol it stands for —
	`CONFIRM <id>` — so a press and a typed reply travel exactly the same path
	and cannot drift apart.
	"""
	kind = message.get("type")
	if kind == "text":
		return (message.get("text") or {}).get("body")

	if kind == "interactive":
		reply = (message.get("interactive") or {}).get("button_reply") or {}
		button_id = reply.get("id") or ""
		if button_id.startswith(BUTTON_CONFIRM):
			return f"CONFIRM {button_id[len(BUTTON_CONFIRM):]}"
		if button_id.startswith(BUTTON_CANCEL):
			return f"CANCEL {button_id[len(BUTTON_CANCEL):]}"
		if button_id.startswith(BUTTON_ASK):
			return f"ASK {button_id[len(BUTTON_ASK):]}"
	return None


def parse_inbound_messages(payload: dict) -> list[dict]:
	"""Extract text messages from a Meta Cloud API webhook payload.

	Payload shape (trimmed to what we read):
	{"entry": [{"changes": [{"value": {"messages": [
		{"from": "<phone>", "id": "<message_id>", "timestamp": "<unix>",
		 "type": "text", "text": {"body": "<text>"}}
	]}}]}]}

	Returns a flat list of {"from", "message_id", "timestamp", "text"} dicts,
	silently skipping non-text messages (images/audio/etc. are out of scope
	for this slice) and any entry that doesn't match the expected shape.
	"""
	messages = []
	for entry in payload.get("entry", []):
		for change in entry.get("changes", []):
			value = change.get("value", {})
			for message in value.get("messages", []):
				text = _text_of(message)
				if not text:
					continue
				messages.append(
					{
						"from": message.get("from"),
						"message_id": message.get("id"),
						"timestamp": message.get("timestamp"),
						"text": text,
					}
				)
	return messages


def confirmation_buttons(body: str, action_name: str, ask: bool = False) -> dict:
	"""An interactive message for one specific proposal or job.

	The action's name travels in the button id, so a press is unambiguous even
	when the person has several open — the case a bare "да" has to refuse.

	`ask` adds a third button, and Meta allows exactly three, which is the whole
	budget. It is offered only where a third answer is real: being given work can
	be answered with a question, a write cannot.
	"""
	buttons = [
		{"type": "reply", "reply": {"id": f"{BUTTON_CONFIRM}{action_name}", "title": "Подтвердить"}},
		{"type": "reply", "reply": {"id": f"{BUTTON_CANCEL}{action_name}", "title": "Отмена"}},
	]
	if ask:
		buttons = [
			{"type": "reply", "reply": {"id": f"{BUTTON_CONFIRM}{action_name}", "title": "Принял"}},
			{"type": "reply", "reply": {"id": f"{BUTTON_CANCEL}{action_name}", "title": "Не могу"}},
			{"type": "reply", "reply": {"id": f"{BUTTON_ASK}{action_name}", "title": "Уточнить"}},
		]
	return {
		"type": "interactive",
		"interactive": {
			"type": "button",
			"body": {"text": body[:1024]},
			"action": {"buttons": buttons},
		},
	}


#: Meta's Graph API host and the version used when a site has not chosen one.
#: Named here so the settings screen's connection test and the send path cannot
#: disagree about where "WhatsApp" is.
#: Meta documents no hard cap, and a webhook body is attacker-influenced in the
#: sense that anybody who knows the URL can POST to it. This is the point past
#: which we stop reading rather than hashing megabytes on their behalf.
MAX_PAYLOAD_BYTES = 1_000_000

API_ROOT = "https://graph.facebook.com"
DEFAULT_API_VERSION = "v21.0"
TIMEOUT_SECONDS = 15


def _call(path: str, method: str = "post", json_body: dict | None = None, params: dict | None = None) -> dict:
	"""One Graph API call, with the credential kept out of every outcome.

	Meta sends the token in a header rather than the URL, so the leak Telegram
	has is not present here — but `raise_for_status` still produces an exception
	nobody can act on, and a settings screen needs Meta's own words. Both
	adapters therefore fail the same way: a typed error with a code and a message
	that is safe to store.
	"""
	settings = get_settings()
	access_token = settings.get_password("access_token", raise_exception=False)
	if not access_token or not settings.phone_number_id:
		raise WhatsAppError(
			"Access token or phone number ID is not set.", code="not_configured"
		)

	url = f"{API_ROOT}/{settings.api_version or DEFAULT_API_VERSION}/{path}"
	# `requests.post` / `requests.get` by name rather than `requests.request`:
	# the call is what everything downstream patches and reads, and a generic
	# dispatcher would move the URL to the second argument for no gain.
	call = requests.get if method == "get" else requests.post
	try:
		response = call(
			url,
			headers={
				"Authorization": f"Bearer {access_token}",
				"Content-Type": "application/json",
			},
			json=json_body,
			params=params,
			timeout=TIMEOUT_SECONDS,
		)
	except Exception as exc:
		raise WhatsAppError(str(exc)[:300], code="provider_unavailable") from None

	try:
		body = response.json()
	except ValueError:
		raise WhatsAppError(
			f"WhatsApp answered {response.status_code} with something that is not JSON.",
			code="provider_error",
		) from None

	if response.status_code >= 400 or "error" in body:
		error = body.get("error") or {}
		raise WhatsAppError(
			str(error.get("message") or response.text)[:300],
			# The same reading as Telegram's, from the one function that holds
			# it: a rate limit is retryable and a rejected token is not, and two
			# adapters disagreeing about that is two different retry policies.
			code=telegram_classify(response.status_code),
			payload=body,
		)
	return body


def describe_number() -> dict:
	"""Read the configured phone number back from Meta.

	The cheapest call that proves the token, the number and the permission
	between them are all real — which is what Test Connection asks.
	"""
	settings = get_settings()
	return _call(
		settings.phone_number_id,
		method="get",
		params={"fields": "display_phone_number,verified_name,quality_rating"},
	)


def send_message(
	to: str, body: str, confirm_for: str | None = None, ask: bool = False
) -> dict:
	"""Send a WhatsApp message via the Cloud API. Real, synchronous HTTP call --
	callers that don't want to block on it should use queue_send_message() instead.
	"""
	settings = get_settings()
	if not settings.enabled:
		raise WhatsAppError("WhatsApp integration is not enabled.", code="disabled")

	return _call(
		f"{settings.phone_number_id}/messages",
		json_body={
			"messaging_product": "whatsapp",
			"to": to,
			**(
				confirmation_buttons(body, confirm_for, ask=ask)
				if confirm_for
				else {"type": "text", "text": {"body": body}}
			),
		},
	)


def queue_send_message(to: str, body: str):
	"""Async dispatch, per ADR-0009 -- never block a request on a third-party API call."""
	frappe.enqueue(
		"korkem_ai.korkem_ai.integrations.whatsapp.send_message",
		queue="short",
		to=to,
		body=body,
	)


@frappe.whitelist(allow_guest=True)
def webhook(**kwargs):
	"""Single endpoint handling both halves of Meta's webhook contract:

	GET  -- verification handshake (hub.mode/hub.verify_token/hub.challenge)
	POST -- actual message events, signature-verified against App Secret

	Exposed at /api/method/korkem_ai.korkem_ai.integrations.whatsapp.webhook
	"""
	settings = get_settings()

	if frappe.request.method == "GET":
		return _handle_verification(settings)

	return _handle_inbound(settings)


def check_verification_request(mode: str | None, token: str | None, challenge: str | None, expected_token: str, enabled: bool) -> tuple[int, str]:
	"""Pure decision logic for Meta's GET verification handshake -- no request-context
	dependency, so it's directly unit-testable.
	"""
	if mode != "subscribe" or not enabled or token != expected_token:
		return 403, "Forbidden"
	return 200, challenge or ""


def _handle_verification(settings):
	status_code, body = check_verification_request(
		mode=frappe.form_dict.get("hub.mode"),
		token=frappe.form_dict.get("hub.verify_token"),
		challenge=frappe.form_dict.get("hub.challenge"),
		# Same reason as the signature check below: a site that is enabled and
		# half-configured must answer 401, not 500.
		expected_token=settings.get_password("webhook_verify_token", raise_exception=False)
		if settings.enabled
		else "",
		enabled=bool(settings.enabled),
	)
	return _plain_text_response(body, status_code)


def _handle_inbound(settings):
	if not settings.enabled:
		return _plain_text_response("WhatsApp integration disabled", 403)

	raw_body = frappe.request.get_data()
	if len(raw_body) > MAX_PAYLOAD_BYTES:
		# Acknowledged and dropped, before the signature is even computed: an
		# oversized body is not something we can answer, and hashing it is work
		# an unauthenticated caller would be choosing for us.
		return _plain_text_response("OK", 200)

	signature = frappe.get_request_header("X-Hub-Signature-256")

	# `verify_webhook_signature` documents that a missing app secret is a failed
	# verification and not a crash — and it is right. It just never got the
	# chance: `get_password` threw one line earlier, which is the same 500 the
	# helper was written to prevent.
	app_secret = settings.get_password("app_secret", raise_exception=False)
	if not verify_webhook_signature(raw_body, signature, app_secret):
		return _plain_text_response("Invalid signature", 401)

	try:
		payload = frappe.parse_json(raw_body.decode("utf-8"))
	except Exception:
		# Signed by Meta and still unparseable. Acknowledged rather than 500'd,
		# because a 500 is what they retry and it will not parse next time.
		return _plain_text_response("OK", 200)

	if not isinstance(payload, dict):
		return _plain_text_response("OK", 200)

	for message in parse_inbound_messages(payload):
		_dispatch_inbound_message(message)

	return _plain_text_response("OK", 200)


def _plain_text_response(body: str, status_code: int):
	"""Return a genuine Response object -- Frappe passes these through unmodified
	(see frappe/handler.py's `handle()`), unlike a plain string/dict return, which
	gets JSON-wrapped as {"message": ...}. Meta's webhook contract requires the raw
	challenge/ack text as the literal response body, not JSON.
	"""
	from werkzeug.wrappers import Response

	return Response(body, status=status_code, mimetype="text/plain")


def _dispatch_inbound_message(message: dict):
	"""Hand the message to the assistant — the same one the app talks to.

	This used to call `orchestrator.router`, a Sprint 1 keyword classifier with
	one skill and canned replies for everything else. So a customer on WhatsApp
	and a planner in the app were talking to two different systems that happened
	to share a name: the app had thirty-seven tools, ERPNext scoping and a
	confirmation flow, and WhatsApp had a lookup table.

	`channels.gateway` resolves who is writing, and runs the real turn as that
	person. The router remains for nothing and should be removed once no
	conversation depends on it.
	"""
	from korkem_ai.korkem_ai.channels import gateway

	return gateway.accept(
		gateway.InboundMessage(
			channel=gateway.WHATSAPP,
			external_id=message["from"],
			chat_id=message["from"],
			text=message["text"],
			message_id=message["message_id"],
			sender_name=message.get("sender_name"),
		)
	)
