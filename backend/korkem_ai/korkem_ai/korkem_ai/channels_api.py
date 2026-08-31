# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Configuring the chat channels, and saying who is on the other end.

## Secrets go in and never come out

A token is written with `Password` fields, which Frappe stores encrypted in
`__Auth`, and **no endpoint here returns one**. The screen is told whether a
credential exists — `configured: true` — and never what it is. That is not
politeness: this API answers a mobile client, and an app that has once held a
bot token has published it to every device it runs on.

The same rule applies to saving: an empty string is *not* a value. Sending one
would otherwise clear a working credential every time somebody edited a
checkbox, which is how a settings screen takes a factory's bots offline.

## "Connected" means somebody asked

`test_telegram` calls `getMe`, `test_whatsapp` reads the phone number. Both are
real requests to the real provider, and both report what actually came back —
including "this container cannot reach the internet", which is a true and useful
answer. Nothing here says Connected because a token is present.

The verdict is *stored*, so the screen can open on the last thing that was
actually true rather than spending a provider call to redraw itself, and the six
states it can show are each either a fact about configuration or the outcome of
a real call.

## The provider's own words, without the provider's credential

Both adapters raise a typed error carrying a code and the provider's own
description. Telegram's is the case that forces this: its token lives in the
URL, so `requests`' own exception text *is* the credential. Nothing from a
provider reaches this module except through those types.

## Identity is linked by the provider's own id

`link_identity` takes a Telegram user id or a phone number, never a display
name: anybody can set their own name in a chat app. What it grants is a `User`,
and every tool in that person's turns then runs with exactly that user's ERPNext
permissions — which is why linking is a `System Manager` action.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities

TELEGRAM_SETTINGS = "Telegram Settings"
WHATSAPP_SETTINGS = "WhatsApp Settings"
TIMEOUT_SECONDS = 15

#: What a connection test actually says to a person. Deliberately dull and
#: self-identifying: somebody receiving it must be able to tell at a glance that
#: an administrator was testing a bot rather than that something happened.
TEST_MESSAGE = "KORKEM AI: проверка связи. Это тестовое сообщение, отвечать не нужно."

#: The six things a channel can be, and the only six. Every one of them is
#: either a fact about configuration or the outcome of a real call — there is no
#: state here that means "a token is present, so probably fine".
NOT_CONFIGURED = "not_configured"
DISABLED = "disabled"
READY = "ready"
CONNECTED = "connected"
INVALID_CREDENTIALS = "invalid_credentials"
WEBHOOK_ERROR = "webhook_error"
PROVIDER_UNAVAILABLE = "provider_unavailable"
#: The provider answered and refused for a reason that is neither a bad
#: credential nor an outage: the bot is blocked, or we are being rate limited.
#: These used to fall through to `ready`, which told an operator a channel was
#: fine while every message to it was being refused.
FORBIDDEN = "forbidden"
RATE_LIMITED = "rate_limited"

#: Every state a real call can leave behind. Anything a provider tells us must
#: appear here, or the screen quietly rounds it up to "fine".
VERDICTS = (
	CONNECTED,
	INVALID_CREDENTIALS,
	FORBIDDEN,
	RATE_LIMITED,
	WEBHOOK_ERROR,
	PROVIDER_UNAVAILABLE,
)


def _has(doctype: str, field: str) -> bool:
	"""Whether a credential is set, without ever reading it out."""
	try:
		return bool(frappe.get_single(doctype).get_password(field, raise_exception=False))
	except Exception:
		return False


#: What each state means to a person, and whether trying again could change it.
#: Held in one table so a screen, an API caller and a test cannot disagree about
#: what "degraded" means.
HEALTH = {
	NOT_CONFIGURED: ("Не настроен: не хватает учётных данных.", False),
	DISABLED: ("Настроен, но выключен.", False),
	READY: ("Настроен и включён. Проверка связи ещё не выполнялась.", True),
	CONNECTED: ("Связь с провайдером подтверждена.", True),
	INVALID_CREDENTIALS: ("Провайдер отклонил учётные данные.", False),
	FORBIDDEN: ("Провайдер отказал: бот заблокирован или нет прав.", False),
	RATE_LIMITED: ("Провайдер ограничивает частоту запросов.", True),
	WEBHOOK_ERROR: ("Провайдер не может доставлять сообщения на наш адрес.", True),
	PROVIDER_UNAVAILABLE: ("Провайдер недоступен.", True),
}


def _health(state: str, settings, counts: dict) -> dict:
	"""One channel's condition, in a form an administrator can act on.

	A code to branch on, a sentence to read, when it was last checked, what the
	provider last said, and whether trying again could plausibly help — the last
	being the difference between "wait" and "go and fix something".
	"""
	message, retryable = HEALTH.get(state, ("Неизвестное состояние.", False))
	return {
		"code": state,
		"message": message,
		"retryable": retryable,
		"checked_at": str(settings.last_checked_on) if settings.last_checked_on else None,
		"last_error": settings.last_error,
		"failed_deliveries": counts["failed"],
		"pending_retries": counts["retrying"],
	}


def _delivery_counts(channel: str) -> dict:
	from korkem_ai.korkem_ai.doctype.notification_delivery import notification_delivery as nd

	return {
		"failed": frappe.db.count(
			"Notification Delivery",
			{"channel": channel, "status": ["in", (nd.FAILED, nd.DEAD_LETTER)]},
		),
		"retrying": frappe.db.count(
			"Notification Delivery", {"channel": channel, "status": nd.RETRYING}
		),
	}


def _traffic(channel: str) -> dict:
	"""When this channel last carried a message, each way.

	Read from what already exists — the conversation transcript for inbound, the
	delivery record for outbound — rather than from counters somebody has to
	remember to increment.
	"""
	inbound = frappe.get_all(
		"Agent Conversation Message",
		filters={"external_channel": channel, "sender": "User"},
		fields=["sent_at"],
		order_by="sent_at desc",
		limit=1,
	)
	outbound = frappe.get_all(
		"Notification Delivery",
		filters={"channel": channel, "status": "Sent"},
		fields=["sent_at"],
		order_by="sent_at desc",
		limit=1,
	)
	return {
		"last_inbound_at": str(inbound[0]["sent_at"]) if inbound else None,
		"last_outbound_at": str(outbound[0]["sent_at"]) if outbound else None,
	}


def _state(enabled: bool, credentials: dict, last_status: str | None = None) -> str:
	"""What the screen shows.

	Configuration first, because a missing credential is a fact and outranks a
	stale verdict. Then the last *real* call, if there has been one — that is
	the only thing allowed to say `connected`. Failing both, `ready` means
	"nothing is missing and nobody has asked yet", which is deliberately not the
	same word as connected.
	"""
	if not all(credentials.values()):
		return NOT_CONFIGURED
	if not enabled:
		return DISABLED
	if last_status in VERDICTS:
		return last_status
	return READY


def _mask(value: str | None) -> str | None:
	"""The tail of a credential, and never enough of it to be one.

	Four characters is enough to tell two accounts apart when somebody is
	looking at the wrong one, and useless to anybody reading over a shoulder.
	Shorter than that and nothing is shown at all, because a short secret masked
	is a short secret published.
	"""
	if not value or len(value) < 8:
		return None
	return "••••••••" + value[-4:]


def _hint(doctype: str, field: str) -> str | None:
	try:
		return _mask(frappe.get_single(doctype).get_password(field, raise_exception=False))
	except Exception:
		return None


def _remember(doctype: str, status: str, error: str | None = None) -> None:
	"""Write down what the last real call found.

	Stored rather than recomputed so the screen can open on the truth instead of
	spending an operator's provider quota to redraw itself.
	"""
	frappe.db.set_single_value(
		doctype,
		{
			"last_status": status,
			"last_error": (error or "")[:500] or None,
			"last_checked_on": frappe.utils.now_datetime(),
		},
	)
	frappe.db.commit()


@frappe.whitelist()
def channel_status() -> dict:
	"""How far each channel's setup has got. Never a credential."""
	frappe.only_for("System Manager")

	telegram = frappe.get_single(TELEGRAM_SETTINGS)
	whatsapp = frappe.get_single(WHATSAPP_SETTINGS)

	telegram_creds = {
		"bot_token": _has(TELEGRAM_SETTINGS, "bot_token"),
		"webhook_secret": _has(TELEGRAM_SETTINGS, "webhook_secret"),
	}
	whatsapp_creds = {
		"access_token": _has(WHATSAPP_SETTINGS, "access_token"),
		"phone_number_id": bool(whatsapp.phone_number_id),
		"webhook_verify_token": _has(WHATSAPP_SETTINGS, "webhook_verify_token"),
	}

	telegram_state = _state(bool(telegram.enabled), telegram_creds, telegram.last_status)
	whatsapp_state = _state(bool(whatsapp.enabled), whatsapp_creds, whatsapp.last_status)

	return {
		"telegram": {
			"channel": "Telegram",
			"enabled": bool(telegram.enabled),
			"configured": telegram_creds,
			"state": telegram_state,
			"health": _health(telegram_state, telegram, _delivery_counts("Telegram")),
			**_traffic("Telegram"),
			"bot_username": telegram.bot_username,
			"webhook_url": telegram.webhook_url or _webhook_url("telegram"),
			"last_status": telegram.last_status,
			"last_error": telegram.last_error,
			"last_checked_on": str(telegram.last_checked_on) if telegram.last_checked_on else None,
			"hints": {
				"bot_token": _hint(TELEGRAM_SETTINGS, "bot_token"),
				"webhook_secret": _hint(TELEGRAM_SETTINGS, "webhook_secret"),
			},
		},
		"whatsapp": {
			"channel": "WhatsApp",
			"enabled": bool(whatsapp.enabled),
			"configured": whatsapp_creds,
			"state": whatsapp_state,
			"health": _health(whatsapp_state, whatsapp, _delivery_counts("WhatsApp")),
			**_traffic("WhatsApp"),
			"display_name": whatsapp.display_name,
			"phone_number_id": whatsapp.phone_number_id,
			"business_account_id": whatsapp.business_account_id,
			"api_version": whatsapp.api_version,
			"webhook_url": whatsapp.webhook_url or _webhook_url("whatsapp"),
			"last_status": whatsapp.last_status,
			"last_error": whatsapp.last_error,
			"last_checked_on": str(whatsapp.last_checked_on) if whatsapp.last_checked_on else None,
			"hints": {
				"access_token": _hint(WHATSAPP_SETTINGS, "access_token"),
				"webhook_verify_token": _hint(WHATSAPP_SETTINGS, "webhook_verify_token"),
				"app_secret": _hint(WHATSAPP_SETTINGS, "app_secret"),
			},
		},
	}


def _webhook_url(channel: str) -> str:
	base = (frappe.utils.get_url() or "").rstrip("/")
	return f"{base}/api/method/korkem_ai.korkem_ai.integrations.{channel}.webhook"


@frappe.whitelist()
def save_telegram(
	bot_token: str | None = None,
	webhook_secret: str | None = None,
	webhook_url: str | None = None,
	enabled: int | bool | None = None,
) -> dict:
	"""Store what was actually typed. An empty field changes nothing."""
	frappe.only_for("System Manager")

	settings = frappe.get_single(TELEGRAM_SETTINGS)
	if enabled is not None:
		settings.enabled = 1 if frappe.utils.cint(enabled) else 0
	if bot_token:
		settings.bot_token = bot_token
	if webhook_secret:
		settings.webhook_secret = webhook_secret
	if webhook_url:
		settings.webhook_url = webhook_url
	settings.save(ignore_permissions=True)
	frappe.db.commit()
	return channel_status()["telegram"]


@frappe.whitelist()
def save_whatsapp(
	access_token: str | None = None,
	phone_number_id: str | None = None,
	business_account_id: str | None = None,
	webhook_verify_token: str | None = None,
	app_secret: str | None = None,
	api_version: str | None = None,
	webhook_url: str | None = None,
	enabled: int | bool | None = None,
) -> dict:
	frappe.only_for("System Manager")

	settings = frappe.get_single(WHATSAPP_SETTINGS)
	if enabled is not None:
		settings.enabled = 1 if frappe.utils.cint(enabled) else 0
	for field, value in (
		("phone_number_id", phone_number_id),
		("business_account_id", business_account_id),
		("api_version", api_version),
		("webhook_url", webhook_url),
		("access_token", access_token),
		("webhook_verify_token", webhook_verify_token),
		("app_secret", app_secret),
	):
		if value:
			setattr(settings, field, value)
	settings.save(ignore_permissions=True)
	frappe.db.commit()
	return channel_status()["whatsapp"]


@frappe.whitelist()
def test_telegram() -> dict:
	"""Ask Telegram who this bot is, and remember what it said.

	https://core.telegram.org/bots/api#getme — the cheapest call that proves a
	token is real. The verdict is stored, so the screen can open on the truth
	without spending a call to redraw itself.
	"""
	frappe.only_for("System Manager")

	from korkem_ai.korkem_ai.integrations import telegram

	try:
		bot = telegram.get_me()
	except telegram.TelegramError as exc:
		_remember(TELEGRAM_SETTINGS, exc.code, str(exc))
		return {"ok": False, "code": exc.code, "error": str(exc)}

	_remember(TELEGRAM_SETTINGS, CONNECTED)
	# What the bot calls itself, so an operator can see *which* bot answered.
	# A name, not a credential.
	frappe.db.set_single_value(TELEGRAM_SETTINGS, "bot_username", bot.get("username"))
	frappe.db.commit()
	return {
		"ok": True,
		"code": CONNECTED,
		"bot_username": bot.get("username"),
		"bot_id": bot.get("id"),
	}


@frappe.whitelist()
def test_whatsapp() -> dict:
	"""Read the configured phone number back from Meta, and remember the verdict."""
	frappe.only_for("System Manager")

	from korkem_ai.korkem_ai.integrations import whatsapp

	try:
		number = whatsapp.describe_number()
	except whatsapp.WhatsAppError as exc:
		_remember(WHATSAPP_SETTINGS, exc.code, str(exc))
		return {"ok": False, "code": exc.code, "error": str(exc)}

	_remember(WHATSAPP_SETTINGS, CONNECTED)
	frappe.db.set_single_value(WHATSAPP_SETTINGS, "display_name", number.get("verified_name"))
	frappe.db.commit()
	return {
		"ok": True,
		"code": CONNECTED,
		"phone_number": number.get("display_phone_number"),
		"verified_name": number.get("verified_name"),
	}


@frappe.whitelist()
def configure_telegram_webhook(url: str | None = None) -> dict:
	"""Tell Telegram where to send updates, and check that it agrees.

	Two calls, not one: `setWebhook` answering `ok` means Telegram accepted the
	URL, and `getWebhookInfo` is the only way to learn what it has *since* found
	there — a certificate it does not trust, a 500, a queue that is backing up.
	An operator staring at a bot that has stopped answering needs the second.

	Telegram requires a public HTTPS URL and refuses anything else, in its own
	words, which is exactly the message to show rather than one of ours.
	"""
	frappe.only_for("System Manager")

	from korkem_ai.korkem_ai.integrations import telegram

	target = (url or "").strip() or _webhook_url("telegram")
	try:
		telegram.set_webhook(target)
		info = telegram.get_webhook_info()
	except telegram.TelegramError as exc:
		code = WEBHOOK_ERROR if exc.code == "provider_error" else exc.code
		_remember(TELEGRAM_SETTINGS, code, str(exc))
		return {"ok": False, "code": code, "error": str(exc)}

	frappe.db.set_single_value(TELEGRAM_SETTINGS, "webhook_url", target)
	last_error = info.get("last_error_message")
	_remember(
		TELEGRAM_SETTINGS,
		WEBHOOK_ERROR if last_error else CONNECTED,
		last_error,
	)
	return {
		"ok": not last_error,
		"code": WEBHOOK_ERROR if last_error else CONNECTED,
		"url": info.get("url"),
		"pending_update_count": info.get("pending_update_count"),
		"last_error": last_error,
		"error": last_error,
	}


@frappe.whitelist()
def telegram_webhook_info() -> dict:
	"""What Telegram currently thinks it should do with our updates."""
	frappe.only_for("System Manager")

	from korkem_ai.korkem_ai.integrations import telegram

	try:
		info = telegram.get_webhook_info()
	except telegram.TelegramError as exc:
		return {"ok": False, "code": exc.code, "error": str(exc)}

	return {
		"ok": True,
		"url": info.get("url"),
		"pending_update_count": info.get("pending_update_count"),
		"last_error": info.get("last_error_message"),
		"max_connections": info.get("max_connections"),
	}


@frappe.whitelist()
def remove_telegram_webhook(drop_pending: int | bool = False) -> dict:
	"""Stop Telegram sending here.

	`drop_pending` defaults to false: the updates queued at Telegram are messages
	real people sent, and throwing them away has to be something somebody asks
	for rather than a side effect of turning a bot off.
	"""
	frappe.only_for("System Manager")

	from korkem_ai.korkem_ai.integrations import telegram

	try:
		telegram.delete_webhook(drop_pending=bool(frappe.utils.cint(drop_pending)))
	except telegram.TelegramError as exc:
		return {"ok": False, "code": exc.code, "error": str(exc)}

	frappe.db.set_single_value(TELEGRAM_SETTINGS, "webhook_url", None)
	_remember(TELEGRAM_SETTINGS, DISABLED)
	return {"ok": True, "code": DISABLED}


@frappe.whitelist()
def whatsapp_webhook_help() -> dict:
	"""What to paste into Meta's dashboard, and what it will ask for.

	Meta's webhook is configured on their side, not ours: there is no API call
	that registers it. So the honest thing a settings screen can offer is the two
	values an operator has to copy — and the verify token is *not* one of them,
	because it is a secret this API does not hand back.
	"""
	frappe.only_for("System Manager")

	settings = frappe.get_single(WHATSAPP_SETTINGS)
	return {
		"callback_url": settings.webhook_url or _webhook_url("whatsapp"),
		"verify_token_configured": _has(WHATSAPP_SETTINGS, "webhook_verify_token"),
		"app_secret_configured": _has(WHATSAPP_SETTINGS, "app_secret"),
		"subscribe_to": ["messages"],
	}


@frappe.whitelist()
def send_test_message(channel: str, identity: str | None = None) -> dict:
	"""Send one real message to a linked identity, and say what happened.

	To a **linked identity**, never to a number typed into the screen: the whole
	identity model exists so that a chat address is something an administrator
	has already bound to a person, and a settings screen that can message
	arbitrary numbers is a settings screen that can be used to message anybody.

	Defaults to the caller's own identity — testing a bot by messaging yourself
	is the sane default and needs no target at all.
	"""
	frappe.only_for("System Manager")

	from korkem_ai.korkem_ai.channels import gateway

	row = (
		frappe.db.get_value(
			"Channel Identity",
			identity,
			["name", "channel", "external_id", "enabled", "user"],
			as_dict=True,
		)
		if identity
		else frappe.db.get_value(
			"Channel Identity",
			{"user": frappe.session.user, "channel": channel, "enabled": 1},
			["name", "channel", "external_id", "enabled", "user"],
			as_dict=True,
		)
	)
	if not row or not row.enabled or not row.user:
		return {
			"ok": False,
			"code": "no_identity",
			"error": "Нет связанного получателя для этого канала.",
		}
	if row.channel != channel:
		return {"ok": False, "code": "wrong_channel", "error": "Этот получатель на другом канале."}

	from korkem_ai.korkem_ai.doctype.channel_event import channel_event as audit
	from korkem_ai.korkem_ai.doctype.notification_delivery import notification_delivery as nd

	# Recorded like any other outbound message, so a test appears in the same
	# delivery centre an operator is already reading — and deliberately nothing
	# else: no model, no tool, no Pending Action, no ERPNext transaction.
	record = frappe.get_doc(
		{
			"doctype": "Notification Delivery",
			"event": "channel.test",
			"event_key": f"channel.test:{row.name}:{frappe.generate_hash(length=8)}",
			"recipient_user": row.user,
			"channel": row.channel,
			"channel_identity": row.name,
			"body": TEST_MESSAGE,
			"status": nd.SENDING,
		}
	)
	record.insert(ignore_permissions=True)

	try:
		response = gateway.deliver(row.channel, row.external_id, TEST_MESSAGE)
	except Exception as exc:
		code, message = _provider_failure(exc)
		record.mark_failed(code, message)
		audit.record(
			audit.FAILED, channel=row.channel, user=row.user, status="test_message", detail=code
		)
		_remember(_settings_for(channel), code, message)
		return {"ok": False, "code": code, "error": message, "delivery": record.name}

	record.mark_sent(
		str((response or {}).get("message_id")) if isinstance(response, dict) else None
	)
	audit.record(
		audit.SENT, channel=row.channel, user=row.user, status="test_message"
	)
	_remember(_settings_for(channel), CONNECTED)
	return {"ok": True, "code": CONNECTED, "sent_to": row.name, "delivery": record.name}


def _settings_for(channel: str) -> str:
	return TELEGRAM_SETTINGS if channel == "Telegram" else WHATSAPP_SETTINGS


def _provider_failure(exc: Exception) -> tuple[str, str]:
	"""A provider failure as a code and a message that is safe to store."""
	from korkem_ai.korkem_ai.integrations.telegram import TelegramError
	from korkem_ai.korkem_ai.integrations.whatsapp import WhatsAppError

	if isinstance(exc, TelegramError | WhatsAppError):
		return exc.code, str(exc)
	return "provider_error", type(exc).__name__


@frappe.whitelist()
def disconnect_channel(channel: str) -> dict:
	"""Switch a channel off and stop the provider delivering to us.

	Deliberately does **not** delete the credentials. "Turn it off for now" and
	"forget my bot token" are different intentions, and a screen that conflates
	them makes the destructive one the easy one.
	"""
	frappe.only_for("System Manager")

	settings = frappe.get_single(_settings_for(channel))
	settings.enabled = 0
	settings.save(ignore_permissions=True)

	removed = None
	if channel == "Telegram":
		removed = remove_telegram_webhook()

	_remember(_settings_for(channel), DISABLED)
	return {"ok": True, "code": DISABLED, "webhook": removed}


# --------------------------------------------------------------------------
# Deliveries — what was sent, what was not, and one more try
# --------------------------------------------------------------------------


@frappe.whitelist()
def list_deliveries(
	status: str | None = None, channel: str | None = None, limit: int | None = None
) -> dict:
	"""What the system tried to tell people, and how it went.

	No credential and no message *body* of anybody else's conversation: the body
	here is the notification this layer composed, which is the thing an operator
	is being asked to judge.
	"""
	frappe.only_for("System Manager")

	filters = {}
	if status:
		filters["status"] = status
	if channel:
		filters["channel"] = channel

	rows = frappe.get_all(
		"Notification Delivery",
		filters=filters,
		fields=[
			"name",
			"event",
			"event_key",
			"recipient_user",
			"channel",
			"status",
			"attempt_count",
			"next_attempt_at",
			"sent_at",
			"failed_at",
			"error",
			"body",
			"reference_doctype",
			"reference_name",
			"company",
		],
		order_by="creation desc",
		limit_page_length=min(int(limit or 50), 200),
	)
	# Counted per state rather than grouped in SQL: Frappe's query builder
	# refuses a function written as a string, and eight cheap counts are clearer
	# than one clever query.
	from korkem_ai.korkem_ai.doctype.notification_delivery import notification_delivery as nd

	summary = {
		state: frappe.db.count("Notification Delivery", {"status": state})
		for state in (
			nd.PENDING,
			nd.SENDING,
			nd.SENT,
			nd.RETRYING,
			nd.FAILED,
			nd.DEAD_LETTER,
			nd.SUPPRESSED,
			nd.CANCELLED,
		)
	}

	return {"deliveries": rows, "summary": summary, "count": len(rows)}


@frappe.whitelist()
def retry_delivery(name: str) -> dict:
	"""One more attempt at one message. Idempotent: a second tap moves nothing."""
	frappe.only_for("System Manager")

	from korkem_ai.korkem_ai.notifications import service

	return service.retry(name)


@frappe.whitelist()
def cancel_delivery(name: str) -> dict:
	frappe.only_for("System Manager")

	from korkem_ai.korkem_ai.notifications import service

	return service.cancel(name)


@frappe.whitelist()
def retry_all_deliveries(limit: int | None = None) -> dict:
	frappe.only_for("System Manager")

	from korkem_ai.korkem_ai.notifications import service

	return service.retry_all(limit=min(int(limit or 50), 200))


# --------------------------------------------------------------------------
# Work instructions — who was asked, and what they said
# --------------------------------------------------------------------------


@frappe.whitelist()
def list_work_instructions(status: str | None = None, limit: int | None = None) -> dict:
	"""The dispatch board.

	Read with `get_list`, so what an administrator sees here is exactly what
	ERPNext would let them see anywhere else — this endpoint grants nothing.
	"""
	filters = {"status": status} if status else {}
	rows = frappe.get_list(
		"Work Instruction",
		filters=filters,
		fields=[
			"name",
			"owner",
			"employee_user",
			"instruction",
			"status",
			"channel",
			"sales_order",
			"work_order",
			"due_date",
			"creation",
			"sent_at",
			"acknowledged_at",
			"rejected_at",
			"response",
			"company",
		],
		order_by="creation desc",
		limit_page_length=min(int(limit or 50), 200),
	)
	for row in rows:
		answered = row["acknowledged_at"] or row["rejected_at"]
		row["response_seconds"] = (
			int((answered - row["creation"]).total_seconds()) if answered and row["creation"] else None
		)
	return {"instructions": rows, "count": len(rows)}


# --------------------------------------------------------------------------
# Who is on the other end
# --------------------------------------------------------------------------


@frappe.whitelist()
def list_identities(channel: str | None = None) -> dict:
	"""Every sender the bots have heard from, and who they are."""
	frappe.only_for("System Manager")

	filters = {"channel": channel} if channel else {}
	rows = frappe.get_all(
		"Channel Identity",
		filters=filters,
		fields=[
			"name",
			"channel",
			"external_id",
			"display_name",
			"user",
			"role",
			"enabled",
			"last_seen_on",
		],
		order_by="last_seen_on desc",
		limit_page_length=100,
	)
	for row in rows:
		row["customer"] = (
			frappe.db.get_value(
				"Portal User", {"user": row["user"], "parenttype": "Customer"}, "parent"
			)
			if row["user"]
			else None
		)
		# A phone number is somebody's personal contact detail, and an
		# administrator picking the right row needs to recognise it rather than
		# read it out. The full value is never needed by the screen — every
		# action takes the row's own name.
		row["external_id_masked"] = _mask_address(row["external_id"])
	return {"identities": rows, "count": len(rows)}


def _mask_address(value: str | None) -> str | None:
	"""A chat id or phone number, recognisable but not transcribable."""
	if not value:
		return None
	if len(value) <= 4:
		return "•" * len(value)
	return "•" * (len(value) - 4) + value[-4:]


@frappe.whitelist()
def set_identity_priority(name: str, priority: int) -> dict:
	"""Which way to reach this person first.

	Lower is tried first. It changes routing and nothing else — an identity that
	is not linked to a user still speaks for nobody whatever its priority.
	"""
	frappe.only_for("System Manager")

	identity = frappe.get_doc("Channel Identity", name)
	identity.priority = frappe.utils.cint(priority)
	identity.save(ignore_permissions=True)
	frappe.db.commit()
	return {"name": identity.name, "priority": identity.priority}


@frappe.whitelist()
def link_identity(
	channel: str, external_id: str, user: str, role: str | None = None
) -> dict:
	"""Say that this Telegram id or phone number is this person.

	Everything that follows — which company, which tools, which rows — is that
	user's own ERPNext permissions. This is the only thing an administrator has
	to get right for a channel to be safe.
	"""
	frappe.only_for("System Manager")

	if not frappe.db.exists("User", user):
		frappe.throw(f"User {user} not found.")

	identity = identities.find(channel, external_id) or identities.observe(channel, external_id)
	identity.user = user
	identity.role = role or None
	identity.enabled = 1
	identity.save(ignore_permissions=True)
	frappe.db.commit()
	return {
		"name": identity.name,
		"channel": identity.channel,
		"external_id": identity.external_id,
		"user": identity.user,
		"role": identity.role,
		"enabled": bool(identity.enabled),
	}


@frappe.whitelist()
def unlink_identity(name: str) -> dict:
	"""Take the person away, keep the row.

	The sender still exists and will write again; what is removed is the right
	to act as anybody. Deleting the row would only mean the next message
	recreates it and an administrator sees a stranger they have already decided
	about.
	"""
	frappe.only_for("System Manager")

	identity = frappe.get_doc("Channel Identity", name)
	identity.user = None
	identity.role = None
	identity.enabled = 0
	identity.save(ignore_permissions=True)
	frappe.db.commit()
	return {"name": identity.name, "user": None, "enabled": False}
