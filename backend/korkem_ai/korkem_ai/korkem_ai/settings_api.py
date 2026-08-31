# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The AI Settings API — configuring providers from the app, safely.

## The one rule

**A key goes in and never comes out.** `save_provider` accepts one; nothing here
returns one. What a client gets back is `masked_key` — four leading and four
trailing characters — which is enough to recognise *which* account is configured
and useless to anyone who intercepts it.

That asymmetry is what lets a phone configure a provider at all. The alternative
— shipping the key to the client so it can show it — would put a live credential
in application memory, in a screenshot, in a crash report, and in whatever the
platform backs up.

## Why System Manager only

Configuring a provider spends someone's money and changes what every user of the
site is talking to. `frappe.only_for("System Manager")` gates all of it. The
*chat* endpoints deliberately do not require that: using the assistant is for
everyone, configuring it is not.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai import errors
from korkem_ai.korkem_ai.orchestrator import llm

PROVIDER_DOCTYPE = "AI Provider"

#: Offered to the settings screen so the client does not hardcode a list that
#: would drift from what the backend can actually build.
SUPPORTED_PROVIDERS = list(llm.PROVIDER_ADAPTERS)


@frappe.whitelist()
def list_providers() -> dict:
	"""Every provider the operator could configure, and how far they have got.

	Returns *all* supported providers, configured or not, so the screen can
	offer "Add provider" without a second call and without its own copy of the
	list.
	"""
	frappe.only_for("System Manager")

	configured = {
		row.provider: row
		for row in (
			frappe.get_doc(PROVIDER_DOCTYPE, name)
			for name in frappe.get_all(PROVIDER_DOCTYPE, pluck="name")
		)
	}

	settings = llm.get_settings()
	providers = []
	for name in SUPPORTED_PROVIDERS:
		row = configured.get(name)
		entry = (
			row.as_public_dict()
			if row
			else {
				"provider": name,
				"enabled": False,
				"model": None,
				"base_url": None,
				"effort": "low",
				"has_key": False,
				"masked_key": None,
				"last_tested_at": None,
				"last_test_ok": False,
				"last_test_error": None,
				"capabilities": llm.capabilities_for(name),
			}
		)
		entry["configured"] = row is not None
		entry["is_default"] = name == settings.provider
		entry.update(llm.requirements_for(name))
		providers.append(entry)

	return {"providers": providers, "default_provider": settings.provider}


@frappe.whitelist()
def save_provider(
	provider: str,
	model: str | None = None,
	base_url: str | None = None,
	api_key: str | None = None,
	enabled: int | bool = True,
	effort: str | None = None,
) -> dict:
	"""Create or update one provider's configuration.

	`api_key` is write-only. Omitting it leaves whatever is stored untouched,
	which is what lets a settings screen save a model change without having to
	hold the key in order to send it back.
	"""
	frappe.only_for("System Manager")

	if provider not in SUPPORTED_PROVIDERS:
		errors.throw(f"Unknown provider: {provider}", errors.AIErrorCode.NOT_CONFIGURED)

	if frappe.db.exists(PROVIDER_DOCTYPE, provider):
		row = frappe.get_doc(PROVIDER_DOCTYPE, provider)
	else:
		row = frappe.new_doc(PROVIDER_DOCTYPE)
		row.provider = provider

	row.enabled = 1 if frappe.utils.sbool(enabled) else 0
	if model is not None:
		row.model = model.strip() or None
	if base_url is not None:
		row.base_url = base_url.strip() or None
	if effort:
		row.effort = effort

	# Only when a non-empty value is sent. A screen that renders the masked key
	# and posts the form back must not overwrite the real one with bullets.
	if api_key:
		row.api_key = api_key

	row.save(ignore_permissions=False)
	frappe.db.commit()
	return row.as_public_dict()


@frappe.whitelist()
def delete_provider(provider: str) -> dict:
	"""Forget a provider and its credential."""
	frappe.only_for("System Manager")

	if not frappe.db.exists(PROVIDER_DOCTYPE, provider):
		return {"deleted": False}

	frappe.delete_doc(PROVIDER_DOCTYPE, provider, ignore_permissions=False)
	frappe.db.commit()
	return {"deleted": True}


@frappe.whitelist()
def set_default_provider(provider: str, model: str | None = None) -> dict:
	"""Choose which provider answers when a request does not name one.

	Held on `AI Settings` rather than as a flag on each row, so "the default" is
	one value that cannot be ambiguous — two rows both claiming it is a state
	nobody can resolve.
	"""
	frappe.only_for("System Manager")

	if provider not in SUPPORTED_PROVIDERS:
		errors.throw(f"Unknown provider: {provider}", errors.AIErrorCode.NOT_CONFIGURED)

	values = {"provider": provider, "enabled": 1}
	if model:
		values["model"] = model
	elif frappe.db.exists(PROVIDER_DOCTYPE, provider):
		values["model"] = frappe.db.get_value(PROVIDER_DOCTYPE, provider, "model")

	frappe.db.set_single_value("AI Settings", values)
	frappe.db.commit()
	return {"default_provider": provider, "model": values.get("model")}


@frappe.whitelist()
def test_provider(provider: str | None = None, model: str | None = None) -> dict:
	"""Ask the provider to answer one trivial call, and report what happened.

	A settings screen that only ever says "saved" tells the operator nothing
	about the three things that actually go wrong — wrong key, wrong model name,
	unreachable endpoint. This finds out which, and stores the verdict so the
	screen can show it later without spending credit again.
	"""
	frappe.only_for("System Manager")

	name = provider or llm.get_settings().provider
	try:
		adapter = llm.resolve(name, model)
		adapter.complete_json(
			system='Reply with the JSON object {"ok": true}. Nothing else.',
			user_message="ping",
			schema={
				"type": "object",
				"properties": {"ok": {"type": "boolean"}},
				"required": ["ok"],
			},
		)
	except Exception as exc:
		code = errors.classify(exc)
		frappe.log_error(title="AI connection test failed", message=frappe.get_traceback())
		_record(name, ok=False, error=str(exc))
		# The provider's own words are the most useful thing here and this is a
		# System Manager endpoint, so they are surfaced — but the code is what
		# the UI branches on.
		return {"ok": False, "provider": name, "code": str(code), "error": str(exc)[:500]}

	_record(name, ok=True)
	return {"ok": True, "provider": name, "model": model or _model_of(name)}


@frappe.whitelist()
def list_models(provider: str | None = None) -> dict:
	"""Models this provider offers, when it can be asked.

	Not every provider exposes a catalogue, and the ones that do disagree about
	what "available" means — Gemini lists models this key may not actually use.
	So the list is advisory: `supported` is what the provider says, and only a
	connection test proves a specific model works.
	"""
	frappe.only_for("System Manager")

	name = provider or llm.get_settings().provider
	adapter = llm.resolve(name)

	lister = getattr(adapter, "list_models", None)
	if lister is None:
		return {"provider": name, "supported": False, "models": []}

	return {"provider": name, "supported": True, "models": lister()}


def _record(provider: str, ok: bool, error: str | None = None):
	if frappe.db.exists(PROVIDER_DOCTYPE, provider):
		frappe.get_doc(PROVIDER_DOCTYPE, provider).record_test(ok=ok, error=error)
		frappe.db.commit()


def _model_of(provider: str):
	if frappe.db.exists(PROVIDER_DOCTYPE, provider):
		return frappe.db.get_value(PROVIDER_DOCTYPE, provider, "model")
	return llm.get_settings().model
