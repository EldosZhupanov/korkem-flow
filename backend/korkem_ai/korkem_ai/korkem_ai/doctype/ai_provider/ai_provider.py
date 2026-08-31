# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""One configured provider, and the only place its credential lives.

## Why a doctype per provider rather than one settings row

`AI Settings` held a single provider, so configuring OpenAI meant erasing the
Gemini key. The product needs several at once — a cloud model for real work, a
local one for offline and privacy-sensitive use — and choosing between them per
request. That is a row per provider, with `AI Settings` demoted to holding
*which one is the default*.

## The credential rule

`api_key` is a Frappe `Password` field: encrypted at rest with the site's
encryption key and readable only through `get_password()`. Nothing in this
module ever returns it, and `masked_key()` is what a settings screen gets.

The client never sends a key to a provider and never receives one back. It
sends a provider name; the server resolves the secret. That is the whole
security model, and it is why the mobile app can be decompiled without leaking
anything.
"""

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import now_datetime

# Which providers need a key is declared by the adapters themselves — see
# `llm.requirements_for`. It used to be a tuple here *and* a different
# expression in `settings_api`, which is two copies of one fact.


class AIProvider(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		api_key: DF.Password | None
		base_url: DF.Data | None
		effort: DF.Literal["low", "medium", "high", "xhigh", "max"]
		enabled: DF.Check
		last_test_error: DF.SmallText | None
		last_test_ok: DF.Check
		last_tested_at: DF.Datetime | None
		model: DF.Data | None
		provider: DF.Literal[
			"Anthropic", "OpenAI", "OpenRouter", "Google Gemini", "Ollama", "OpenAI-compatible"
		]
	# end: auto-generated types

	def validate(self):
		"""Refuse a configuration that cannot possibly work.

		Caught here rather than at the first chat message, because a setting
		that saves cleanly and then fails on use is indistinguishable, to the
		person who saved it, from the feature being broken.
		"""
		if self.base_url:
			self.base_url = self.base_url.strip().rstrip("/")
			if not self.base_url.startswith(("http://", "https://")):
				frappe.throw("Base URL must start with http:// or https://")

		if not self.enabled:
			return

		from korkem_ai.korkem_ai.orchestrator import llm

		requires = llm.requirements_for(self.provider)

		if requires["needs_base_url"] and not self.base_url:
			frappe.throw(f"{self.provider} needs a Base URL — there is no default endpoint")

		if not self.model:
			frappe.throw(f"{self.provider} needs a model")

		if requires["needs_key"] and not self.get_password(
			"api_key", raise_exception=False
		):
			frappe.throw(f"{self.provider} needs an API key")

	def masked_key(self) -> str | None:
		"""What a settings screen may show. Never the key itself.

		Enough tail to recognise *which* key is configured — an operator with
		two accounts needs to tell them apart — and never enough to use. Short
		values are hidden entirely rather than half-revealed, because masking
		four characters of a six-character secret is not masking.
		"""
		key = self.get_password("api_key", raise_exception=False)
		if not key:
			return None
		if len(key) < 12:
			return "•" * 8
		return f"{key[:4]}{'•' * 8}{key[-4:]}"

	def record_test(self, ok: bool, error: str | None = None):
		"""Remember how the last connection test went.

		Stored so the settings screen can say "Connected" on open without
		spending provider credit re-testing every time it is looked at.
		"""
		self.db_set(
			{
				"last_tested_at": now_datetime(),
				"last_test_ok": 1 if ok else 0,
				# Truncated: a provider's error body can be long, and the useful
				# part is always at the front.
				"last_test_error": (error or "")[:500] or None,
			},
			notify=False,
			commit=False,
		)

	def as_public_dict(self) -> dict:
		"""The provider as a client may see it — no secret, ever."""
		from korkem_ai.korkem_ai.orchestrator import llm

		return {
			"provider": self.provider,
			"enabled": bool(self.enabled),
			"model": self.model,
			"base_url": self.base_url,
			"effort": self.effort,
			"has_key": bool(self.get_password("api_key", raise_exception=False)),
			"masked_key": self.masked_key(),
			"last_tested_at": str(self.last_tested_at) if self.last_tested_at else None,
			"last_test_ok": bool(self.last_test_ok),
			"last_test_error": self.last_test_error,
			"capabilities": llm.capabilities_for(self.provider),
		}
