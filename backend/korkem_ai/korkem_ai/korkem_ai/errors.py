# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""One taxonomy for everything that can go wrong between a question and an answer.

## Why a code and not a sentence

The assistant fails in ways that call for different actions from different
people. "No provider is configured" is an administrator's job and a five-minute
fix; "the provider is rate limiting us" is nobody's job and will pass; "you are
not allowed to do that" is neither. A single English sentence flattens all three
into *something went wrong*, and — worse — a server-authored sentence cannot be
translated, so a Russian interface ends up quoting English at a factory worker.

So the wire carries a **code**. The client owns the wording, in the user's
language, and can offer the right next step. This module is the only place those
codes are defined, and both halves of the transport use the same ones:

- the HTTP reply to `chat.send`, as `ai_error_code`
- the realtime error event, as `reason`

One vocabulary, two channels. A code that appears in one and not the other is a
bug, and `test_errors.py` pins them together.

## Why validation happens before the queue

`chat.send` used to enqueue first and discover the missing provider inside the
worker. The user got HTTP 200 and then, seconds later, a generic failure — so
the single most common state of a fresh install ("no key yet") was reported as
an unknown error. Configuration is knowable synchronously and costs no network
call, so it is checked while there is still a request to fail.
"""

from __future__ import annotations

import enum

import frappe
import requests


class AIErrorCode(enum.StrEnum):
	"""What went wrong, in the vocabulary the client understands.

	`StrEnum` so the value serialises to JSON as the bare string with no
	`.value` at the call site — a member that reached the wire as
	`"AIErrorCode.UNKNOWN"` would be a silent contract break.
	"""

	#: No usable provider configuration: disabled, no model, or no API key.
	NOT_CONFIGURED = "AI_NOT_CONFIGURED"

	#: Configured, but the endpoint could not be reached or answered with an
	#: error that is not about credentials or quota.
	PROVIDER_UNAVAILABLE = "PROVIDER_UNAVAILABLE"

	#: The provider rejected our credentials, or Frappe rejected the user.
	AUTH_ERROR = "AUTH_ERROR"

	#: Quota or rate limit. Distinct from unavailable because waiting helps.
	RATE_LIMITED = "RATE_LIMITED"

	#: A registered tool failed in a way the turn could not absorb.
	TOOL_ERROR = "TOOL_ERROR"

	#: The provider took too long. Distinct from unavailable: it answered the
	#: connection, it just never finished.
	TIMEOUT = "AI_TIMEOUT"

	#: The configured model name does not exist, or this key may not use it.
	#: Worth its own code because the remedy — pick another model — is specific
	#: and the operator can act on it alone. Seen live: Gemini lists
	#: `gemini-2.5-flash` and then answers 404 "no longer available to new users".
	MODEL_NOT_FOUND = "AI_MODEL_NOT_FOUND"

	#: Tools were offered to a model or provider that cannot use them.
	TOOL_NOT_SUPPORTED = "AI_TOOL_NOT_SUPPORTED"

	#: The model asked for a tool with arguments that failed schema validation.
	INVALID_TOOL_ARGUMENTS = "AI_INVALID_TOOL_ARGUMENTS"

	#: The conversation no longer fits the model's context window.
	CONTEXT_TOO_LARGE = "AI_CONTEXT_TOO_LARGE"

	#: Anything we have not classified. Deliberately last and deliberately
	#: vague — a code that means "we do not know" is honest; one that guesses
	#: sends the user to fix the wrong thing.
	UNKNOWN = "UNKNOWN"


class AIError(frappe.ValidationError):
	"""Base for every failure the assistant reports with a code.

	Subclasses `frappe.ValidationError` so that existing `except
	frappe.ValidationError` handlers — and Frappe's own 417 mapping — keep
	working unchanged.
	"""

	code = AIErrorCode.UNKNOWN


class AINotConfigured(AIError):
	code = AIErrorCode.NOT_CONFIGURED


class ProviderUnavailable(AIError):
	code = AIErrorCode.PROVIDER_UNAVAILABLE


class AIAuthError(AIError):
	code = AIErrorCode.AUTH_ERROR


class RateLimited(AIError):
	code = AIErrorCode.RATE_LIMITED


class AIToolError(AIError):
	code = AIErrorCode.TOOL_ERROR


class AITimeout(AIError):
	code = AIErrorCode.TIMEOUT


class ModelNotFound(AIError):
	code = AIErrorCode.MODEL_NOT_FOUND


class ToolNotSupported(AIError):
	code = AIErrorCode.TOOL_NOT_SUPPORTED


class InvalidToolArguments(AIError):
	code = AIErrorCode.INVALID_TOOL_ARGUMENTS


class ContextTooLarge(AIError):
	code = AIErrorCode.CONTEXT_TOO_LARGE


#: What the user is told for each code, in English, as a last resort.
#:
#: The client translates from the code and never shows these. They exist so a
#: non-mobile caller — a desk page, `curl`, a future web client — still gets a
#: sentence rather than an enum member.
FALLBACK_MESSAGES = {
	AIErrorCode.NOT_CONFIGURED: "AI provider is not configured.",
	AIErrorCode.PROVIDER_UNAVAILABLE: "The AI provider could not be reached.",
	AIErrorCode.AUTH_ERROR: "The AI provider rejected our credentials.",
	AIErrorCode.RATE_LIMITED: "The AI provider is rate limiting requests. Try again shortly.",
	AIErrorCode.TOOL_ERROR: "The assistant could not complete that action.",
	AIErrorCode.TIMEOUT: "The AI provider took too long to answer.",
	AIErrorCode.MODEL_NOT_FOUND: "The configured AI model is not available.",
	AIErrorCode.TOOL_NOT_SUPPORTED: "This model cannot use KORKEM's tools.",
	AIErrorCode.INVALID_TOOL_ARGUMENTS: "The assistant asked for something malformed.",
	AIErrorCode.CONTEXT_TOO_LARGE: "This conversation is too long to continue.",
	AIErrorCode.UNKNOWN: "The assistant could not answer just now.",
}


def throw(message: str, code: AIErrorCode = AIErrorCode.UNKNOWN):
	"""Fail a request with a code the client can act on.

	The code is attached to the HTTP response *before* raising. Frappe
	serialises whatever is on `frappe.local.response` into the error body, so
	the extra key travels alongside `exc_type` and `_server_messages` without
	needing a custom exception handler. Pinned by a test that reads it back off
	a real HTTP call, because it rests on Frappe's response building rather
	than on a documented API.
	"""
	frappe.local.response["ai_error_code"] = str(code)
	frappe.throw(message, exc=_EXCEPTIONS.get(code, AIError))


_EXCEPTIONS = {
	AIErrorCode.NOT_CONFIGURED: AINotConfigured,
	AIErrorCode.PROVIDER_UNAVAILABLE: ProviderUnavailable,
	AIErrorCode.AUTH_ERROR: AIAuthError,
	AIErrorCode.RATE_LIMITED: RateLimited,
	AIErrorCode.TOOL_ERROR: AIToolError,
	AIErrorCode.TIMEOUT: AITimeout,
	AIErrorCode.MODEL_NOT_FOUND: ModelNotFound,
	AIErrorCode.TOOL_NOT_SUPPORTED: ToolNotSupported,
	AIErrorCode.INVALID_TOOL_ARGUMENTS: InvalidToolArguments,
	AIErrorCode.CONTEXT_TOO_LARGE: ContextTooLarge,
	AIErrorCode.UNKNOWN: AIError,
}


def code_for_status(status: int) -> AIErrorCode:
	"""Map a provider's HTTP status onto the taxonomy.

	401/403 and 429 are worth telling apart from everything else because they
	are the two failures with a specific, different remedy: fix the key, or
	wait. Every other 4xx/5xx is the provider being unusable right now.
	"""
	if status in (401, 403):
		return AIErrorCode.AUTH_ERROR
	if status == 404:
		# The model name, not the endpoint: a wrong host fails to connect long
		# before it can 404. Verified live against Gemini.
		return AIErrorCode.MODEL_NOT_FOUND
	if status == 408:
		return AIErrorCode.TIMEOUT
	if status == 413:
		return AIErrorCode.CONTEXT_TOO_LARGE
	if status == 429:
		return AIErrorCode.RATE_LIMITED
	return AIErrorCode.PROVIDER_UNAVAILABLE


def classify(exc: BaseException) -> AIErrorCode:
	"""Reduce any exception to a code.

	Used by the background job, where the failure has already happened and
	there is no request left to fail — the turn still has to tell the user
	*which* kind of wrong it went.
	"""
	if isinstance(exc, AIError):
		return exc.code
	if isinstance(exc, frappe.PermissionError):
		return AIErrorCode.AUTH_ERROR
	if isinstance(exc, requests.Timeout):
		return AIErrorCode.TIMEOUT
	if isinstance(exc, requests.RequestException):
		return AIErrorCode.PROVIDER_UNAVAILABLE
	return AIErrorCode.UNKNOWN


def message_for(code: AIErrorCode) -> str:
	return FALLBACK_MESSAGES.get(code, FALLBACK_MESSAGES[AIErrorCode.UNKNOWN])
