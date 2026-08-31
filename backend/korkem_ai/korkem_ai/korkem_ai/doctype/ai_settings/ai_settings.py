# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document

from korkem_ai.korkem_ai.orchestrator import llm


class AISettings(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		api_key: DF.Password | None
		base_url: DF.Data | None
		effort: DF.Literal["low", "medium", "high", "xhigh", "max"]
		enabled: DF.Check
		model: DF.Data
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
		if not self.enabled:
			return

		if self.base_url:
			self.base_url = self.base_url.strip().rstrip("/")
			if not self.base_url.startswith(("http://", "https://")):
				frappe.throw("Base URL must start with http:// or https://")

		# Every provider except Ollama needs somewhere to send the request, and
		# `OpenAI-compatible` is the one with no default to fall back on.
		if self.provider == "OpenAI-compatible" and not self.base_url:
			frappe.throw("OpenAI-compatible needs a Base URL — there is no default endpoint")

		# Anthropic is the exception: its SDK also resolves a key from the
		# environment, so a blank field there is a legitimate configuration.
		needs_key = self.provider in ("OpenAI", "OpenRouter", "Google Gemini", "OpenAI-compatible")
		if needs_key and not self.get_password("api_key", raise_exception=False):
			frappe.throw(f"{self.provider} needs an API key")


@frappe.whitelist()
def test_connection() -> dict:
	"""Ask the configured provider to answer one trivial schema-constrained call.

	A settings screen that only ever says "saved" tells the operator nothing
	about whether the key is right, the model name exists, or the endpoint is
	reachable — which are the three things that actually go wrong. This finds
	out, and reports which of them failed rather than "something went wrong".

	System Manager only: it spends provider credit and its failure text can
	quote the provider's own error, which may name internal endpoints.
	"""
	frappe.only_for("System Manager")

	settings = llm.get_settings()
	provider = llm.get_provider(settings)

	try:
		provider.complete_json(
			system="Reply with the JSON object {\"ok\": true}. Nothing else.",
			user_message="ping",
			schema={
				"type": "object",
				"properties": {"ok": {"type": "boolean"}},
				"required": ["ok"],
			},
		)
	except Exception as exc:
		frappe.log_error(title="AI connection test failed", message=frappe.get_traceback())
		return {
			"ok": False,
			"provider": settings.provider,
			"model": settings.model,
			"error": str(exc),
		}

	return {"ok": True, "provider": settings.provider, "model": settings.model}
