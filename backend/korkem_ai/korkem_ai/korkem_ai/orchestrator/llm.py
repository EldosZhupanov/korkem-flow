# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""LLM provider layer for the AI gateway.

Per ADR-0011, third-party calls live behind a gateway module rather than being
scattered through business logic -- this is the only place that speaks an LLM
wire protocol, and the only place a provider credential is read. Nothing above
this module knows which vendor answered, and the mobile client never holds a
key at all (see `docs/ai_workspace_architecture.md` §2).

Every provider exposes one method, `complete_json()`: given a system prompt, a
user message, and a JSON schema, return a parsed dict conforming to that schema.
That is what the orchestrator needs today -- classification and extraction are
both "structured output from one call" (ADR-0003: the orchestrator routes, it
does not implement business logic). Tool calling and streaming are the next
additions and belong on this same interface, not beside it.

## On "they all speak OpenAI now"

They do not, and pretending otherwise is how a gateway acquires silent bugs.
Three wire protocols are implemented here, and each constrains output to a
schema in its own way:

* **Anthropic** -- `output_config.format`, a first-class JSON-schema mode.
* **OpenAI-compatible** -- `response_format: json_schema` with `strict`. This
  one adapter serves OpenAI, OpenRouter and any other endpoint speaking the
  same chat API, because there the difference genuinely *is* only a URL.
* **Gemini** -- `responseMimeType` plus `responseSchema`, and its schema
  dialect is a subset: it rejects the `additionalProperties` and `$schema` keys
  that the others tolerate, so schemas are pruned on the way out.
* **Ollama** -- `format`, which takes the JSON schema directly.

## Two methods, not one

`complete_json()` answers "structured output from one call" and is what the
WhatsApp orchestrator uses. `chat()` answers "here is a conversation and the
tools you may ask for", which is what the workspace assistant needs. They are
separate because the first constrains the model to a schema and forbids
everything else, and the second must leave it free to write prose *or* ask for
a tool -- the same call cannot do both.

Translating tool calls is where the four protocols differ most, and where
"they are all the same really" costs the most: the tool list, the assistant
turn that requests a call, and the turn that carries the result back each have
a different shape per vendor. All four are implemented; none is guessed at.
"""

import json

import frappe
import requests

from korkem_ai.korkem_ai import errors
from korkem_ai.korkem_ai.orchestrator.capabilities import (
	Capability,
	HasCapabilities,
	Support,
)
from korkem_ai.korkem_ai.orchestrator.protocol import (
	AIMessage,
	AIResponse,
	AIStreamEvent,
	AITool,
	AIToolCall,
	AIUsage,
	ToolCallAccumulator,
	parse_arguments,
)

AI_SETTINGS_DOCTYPE = "AI Settings"

#: Long enough for a slow local model, short enough that a wedged provider does
#: not hold a worker forever. LLM calls are queued (ADR-0009), so this bounds a
#: background job rather than a request handler.
REQUEST_TIMEOUT_SECONDS = 120

#: Where each provider lives when the operator does not say otherwise. A
#: default is not a hardcoded dependency: every one of these is overridable
#: from AI Settings, and `OpenAI-compatible` deliberately has none, because an
#: endpoint nobody named cannot be guessed at.
DEFAULT_BASE_URLS = {
	"OpenAI": "https://api.openai.com/v1",
	"OpenRouter": "https://openrouter.ai/api/v1",
	# Groq говорит на диалекте OpenAI, поэтому отдельного адаптера ему не нужно —
	# нужен только адрес, которого человек не должен знать наизусть.
	"Groq": "https://api.groq.com/openai/v1",
	"Google Gemini": "https://generativelanguage.googleapis.com/v1beta",
	# The bench runs in a container; the host's Ollama is not on its localhost.
	"Ollama": "http://host.docker.internal:11434",
}

#: Keys Gemini's schema dialect rejects outright.
_GEMINI_UNSUPPORTED_SCHEMA_KEYS = ("additionalProperties", "$schema", "definitions", "$defs")


class LLMError(errors.AIError):
	"""Raised when the provider is misconfigured or returns something unusable.

	Kept as a name because call sites throughout this module use it for "the
	model gave us something we cannot work with", which has no better code than
	`UNKNOWN`. The cases that *do* have a better code — no configuration, an
	unreachable endpoint, a rejected key, a quota — raise the specific classes
	from `errors` instead, so the client can tell them apart.
	"""


AI_PROVIDER_DOCTYPE = "AI Provider"

#: Adapter class per provider name. One table, so "which providers exist" is a
#: fact with a single home rather than a chain of `if` statements repeated in
#: `get_provider`, `capabilities_for` and every future caller.
PROVIDER_ADAPTERS = {
	"Anthropic": "AnthropicProvider",
	"OpenAI": "OpenAICompatibleProvider",
	"OpenRouter": "OpenAICompatibleProvider",
	"Groq": "OpenAICompatibleProvider",
	"OpenAI-compatible": "OpenAICompatibleProvider",
	"Google Gemini": "GeminiProvider",
	"Ollama": "OllamaProvider",
}


def get_settings():
	return frappe.get_single(AI_SETTINGS_DOCTYPE)


def requirements_for(provider_name: str) -> dict[str, bool]:
	"""What an operator must supply to make this provider work.

	Derived, not listed. `needs_key` is declared by the adapter that knows;
	`needs_base_url` follows from whether a default endpoint exists, because
	"no default" *is* the reason a URL must be given. Both facts used to be
	hardcoded tuples in `settings_api`, duplicating a list in the AI Provider
	doctype — two copies of the same knowledge, one edit away from disagreeing.
	"""
	adapter = globals().get(PROVIDER_ADAPTERS.get(provider_name, ""))
	# A base URL is needed only when nobody has a default: not in our table, and
	# not built into the vendor SDK either. Anthropic is the case that makes the
	# second clause necessary — its SDK knows its own endpoint, so deriving from
	# `DEFAULT_BASE_URLS` alone would demand a URL nobody should have to type.
	has_default = provider_name in DEFAULT_BASE_URLS or getattr(
		adapter, "has_builtin_endpoint", False
	)
	return {
		"needs_key": bool(getattr(adapter, "requires_api_key", True)),
		"needs_base_url": not has_default,
	}


def capabilities_for(provider_name: str) -> dict[str, str]:
	"""What this provider can do, without building one or needing a credential.

	A settings screen has to show capabilities *before* a key is entered, so
	this reads them off the adapter class rather than an instance.
	"""
	adapter = globals().get(PROVIDER_ADAPTERS.get(provider_name, ""))
	if adapter is None:
		return {}
	return {
		capability.value: adapter.capabilities.get(capability, Support.UNKNOWN).value
		for capability in Capability
	}


def resolve(provider_name: str | None = None, model: str | None = None):
	"""Build the adapter for a named provider, or for the configured default.

	This is the gateway's single entry point for "give me something that can
	answer". The caller names a *provider and model* — never a credential —
	and this resolves the secret server-side. That asymmetry is the security
	model: a client can ask for Gemini, and cannot ask for anyone's key.
	"""
	settings = get_settings()
	name = provider_name or settings.provider

	row = None
	if frappe.db.exists(AI_PROVIDER_DOCTYPE, name):
		row = frappe.get_doc(AI_PROVIDER_DOCTYPE, name)
		if not row.enabled:
			errors.throw(
				f"{name} is configured but disabled", errors.AIErrorCode.NOT_CONFIGURED
			)

	if row is None:
		# No per-provider row yet. Fall back to the single AI Settings record,
		# which is where every existing installation's credential still lives —
		# migrating is the operator's choice, not a precondition for answering.
		if name != settings.provider:
			errors.throw(
				f"{name} is not configured", errors.AIErrorCode.NOT_CONFIGURED
			)
		return get_provider(settings)

	return _build(
		provider=row.provider,
		model=model or row.model,
		api_key=row.get_password("api_key", raise_exception=False),
		base_url=(row.base_url or "").strip() or DEFAULT_BASE_URLS.get(row.provider),
		effort=row.effort or "low",
	)


def ensure_configured(provider_name: str | None = None, model: str | None = None):
	"""Fail now if no model could possibly answer.

	Exists so `chat.send` can refuse *before* queuing a turn. It performs no
	network call — configuration is knowable from the database alone, and the
	whole point is to be cheap enough to run on the request path.

	Goes through `resolve` so that a request naming a provider is validated
	against *that* provider's configuration rather than the default's.

	Returns the provider it built, since building it is the check.
	"""
	return resolve(provider_name, model)


def get_provider(settings=None):
	"""Return the configured provider instance.

	Reads configuration once, here, so that adding a provider is adding a branch
	in one function rather than a lookup scattered across callers.
	"""
	settings = settings or get_settings()
	if not settings.enabled:
		errors.throw("AI is not enabled in AI Settings", errors.AIErrorCode.NOT_CONFIGURED)

	provider = settings.provider
	model = settings.model
	if not model:
		errors.throw("No model is set in AI Settings", errors.AIErrorCode.NOT_CONFIGURED)

	api_key = settings.get_password("api_key", raise_exception=False)
	base_url = (settings.base_url or "").strip() or DEFAULT_BASE_URLS.get(provider)

	return _build(
		provider=provider,
		model=model,
		api_key=api_key,
		base_url=base_url,
		effort=settings.effort or "low",
	)


def _build(provider: str, model: str, api_key, base_url, effort: str):
	"""Construct one adapter. The only place a provider name becomes a class."""
	if not model:
		errors.throw("No model is set", errors.AIErrorCode.NOT_CONFIGURED)

	if provider == "Anthropic":
		return AnthropicProvider(
			model=model,
			effort=effort,
			api_key=api_key,
			base_url=base_url,
		)

	if provider == "Ollama":
		return OllamaProvider(model=model, base_url=base_url)

	if provider == "Google Gemini":
		_require(api_key, "Google Gemini needs an API key")
		return GeminiProvider(model=model, api_key=api_key, base_url=base_url)

	if provider in ("OpenAI", "OpenRouter", "Groq", "OpenAI-compatible"):
		# The one case with no default: an OpenAI-compatible endpoint is
		# whatever the operator points it at, and guessing would send a
		# credential somewhere nobody chose.
		_require(base_url, f"{provider} needs a Base URL in AI Settings")
		_require(api_key, f"{provider} needs an API key")
		return OpenAICompatibleProvider(model=model, api_key=api_key, base_url=base_url)

	errors.throw(f"Unknown AI provider: {provider}", errors.AIErrorCode.NOT_CONFIGURED)


def _require(value, message: str):
	"""Every caller of this is checking a *configuration* field, so the code is
	always NOT_CONFIGURED — a missing key or base URL is an operator's job."""
	if not value:
		errors.throw(message, errors.AIErrorCode.NOT_CONFIGURED)


def _post_json(url: str, headers: dict, payload: dict) -> dict:
	"""One HTTP call, with provider errors turned into something readable.

	A provider's own error body is the most useful thing we have when a key is
	wrong or a model name does not exist, so it is surfaced rather than
	swallowed into a bare status code -- but it is surfaced to the *server*
	log and to a System Manager, never to an end user's chat.
	"""
	try:
		response = requests.post(
			url, headers=headers, json=payload, timeout=REQUEST_TIMEOUT_SECONDS
		)
	except requests.RequestException as exc:
		errors.throw(
			f"Could not reach the AI provider: {exc}", errors.AIErrorCode.PROVIDER_UNAVAILABLE
		)

	if response.status_code >= 400:
		# A wrong key and an exhausted quota look identical in the body but call
		# for opposite responses from the operator, so the status decides.
		errors.throw(
			f"AI provider returned {response.status_code}: {response.text[:500]}",
			errors.code_for_status(response.status_code),
		)

	try:
		return response.json()
	except ValueError:
		frappe.throw("AI provider returned a non-JSON response", exc=LLMError)


def _get_json(url: str, headers: dict) -> dict:
	"""A read-only provider call — model catalogues and the like."""
	try:
		response = requests.get(url, headers=headers, timeout=REQUEST_TIMEOUT_SECONDS)
	except requests.RequestException as exc:
		errors.throw(
			f"Could not reach the AI provider: {exc}", errors.AIErrorCode.PROVIDER_UNAVAILABLE
		)

	if response.status_code >= 400:
		errors.throw(
			f"AI provider returned {response.status_code}: {response.text[:500]}",
			errors.code_for_status(response.status_code),
		)

	try:
		return response.json()
	except ValueError:
		frappe.throw("AI provider returned a non-JSON response", exc=LLMError)


def _post_stream(url: str, headers: dict, payload: dict):
	"""Open a streamed POST and yield decoded lines.

	Separate from `_post_json` because the error handling differs in a way that
	matters: a streaming response fails *late*, so the connection is closed
	explicitly rather than left to a garbage collector that may not run for a
	while on a long-lived worker.
	"""
	try:
		response = requests.post(
			url, headers=headers, json=payload, stream=True, timeout=REQUEST_TIMEOUT_SECONDS
		)
	except requests.RequestException as exc:
		errors.throw(
			f"Could not reach the AI provider: {exc}", errors.AIErrorCode.PROVIDER_UNAVAILABLE
		)

	try:
		if response.status_code >= 400:
			errors.throw(
				f"AI provider returned {response.status_code}: {response.text[:500]}",
				errors.code_for_status(response.status_code),
			)

		# SSE bodies are UTF-8. `requests` does not know that: RFC 2616 makes
		# ISO-8859-1 the default for `text/*` when the Content-Type carries no
		# charset, and no provider sends one — so `decode_unicode=True` silently
		# mangles every non-ASCII character.
		#
		# This product answers in Russian and Kazakh, so that is *most* replies.
		# Found by streaming one sentence of Cyrillic and reading it back as
		# "ÐÑÐ¾Ð²ÐµÑÐºÐ°". Applies to all four providers, which share this function.
		if not response.encoding or response.encoding.lower() == "iso-8859-1":
			response.encoding = "utf-8"

		yield from response.iter_lines(decode_unicode=True)
	finally:
		response.close()


def _sse_payloads(lines):
	"""Yield the decoded JSON of each `data:` line in a Server-Sent Events body.

	`[DONE]` is a sentinel, not JSON, and a chunk that will not parse is skipped
	rather than allowed to kill a reply that is otherwise arriving fine.
	"""
	for line in lines:
		if not line or not line.startswith("data:"):
			continue
		payload = line[len("data:") :].strip()
		if not payload or payload == "[DONE]":
			continue
		try:
			yield json.loads(payload)
		except json.JSONDecodeError:
			continue


def stream_from_chat(provider, system: str, messages, tools=()):
	"""Present a non-streaming provider through the streaming interface.

	The answer arrives in one piece rather than incrementally — this is a
	uniform *interface*, not a claim that the provider streams. Callers that
	need to know can compare `provider.streams_natively`.
	"""
	response = provider.chat(system, messages, tools=tools)
	if response.text:
		yield AIStreamEvent.delta(response.text)
	if response.tool_calls:
		yield AIStreamEvent.calls(response.tool_calls)
	yield AIStreamEvent.finished(usage=response.usage, stop_reason=response.stop_reason)


def _parse_json_content(text: str | None) -> dict:
	if not text:
		frappe.throw("The model returned no content", exc=LLMError)
	try:
		return json.loads(text)
	except json.JSONDecodeError:
		frappe.throw("The model returned content that is not valid JSON", exc=LLMError)


def _usage(input_tokens, output_tokens) -> AIUsage | None:
	"""Keep reported zero distinct from a provider that reported nothing."""
	if input_tokens is None and output_tokens is None:
		return None
	return AIUsage(input_tokens=input_tokens, output_tokens=output_tokens)


class AnthropicProvider(HasCapabilities):
	"""Claude via the official Anthropic SDK.

	Uses structured outputs (`output_config.format`) so the model is constrained
	to the schema rather than asked to "reply with JSON" and hoped at.
	"""

	def __init__(
		self,
		model: str,
		effort: str = "low",
		api_key: str | None = None,
		base_url: str | None = None,
	):
		self.model = model
		self.effort = effort
		self.api_key = api_key
		self.base_url = base_url

	def _client(self):
		import anthropic

		# An unset key is not an error: the SDK also resolves ANTHROPIC_AUTH_TOKEN
		# and `ant auth login` profiles from the environment.
		kwargs = {}
		if self.api_key:
			kwargs["api_key"] = self.api_key
		if self.base_url:
			kwargs["base_url"] = self.base_url
		return anthropic.Anthropic(**kwargs)

	def complete_json(self, system: str, user_message: str, schema: dict) -> dict:
		self.usage = None
		response = self._client().messages.create(
			model=self.model,
			max_tokens=1024,
			system=system,
			output_config={
				"effort": self.effort,
				"format": {"type": "json_schema", "schema": schema},
			},
			messages=[{"role": "user", "content": user_message}],
		)
		raw_usage = getattr(response, "usage", None)
		self.usage = _usage(
			getattr(raw_usage, "input_tokens", None),
			getattr(raw_usage, "output_tokens", None),
		)

		if response.stop_reason == "refusal":
			frappe.throw("The model declined to answer this request", exc=LLMError)

		text = next((block.text for block in response.content if block.type == "text"), None)
		return _parse_json_content(text)

	def chat(self, system: str, messages, tools=()) -> AIResponse:
		payload = {
			"model": self.model,
			"max_tokens": 4096,
			"system": system,
			"messages": [self._encode(message) for message in messages],
		}
		if tools:
			payload["tools"] = [
				{
					"name": tool.name,
					"description": tool.description,
					"input_schema": tool.input_schema,
				}
				for tool in tools
			]

		response = self._client().messages.create(**payload)

		if response.stop_reason == "refusal":
			frappe.throw("The model declined to answer this request", exc=LLMError)

		text_parts, calls = [], []
		for block in response.content:
			if block.type == "text":
				text_parts.append(block.text)
			elif block.type == "tool_use":
				arguments, malformed = parse_arguments(block.input)
				calls.append(
					AIToolCall(
						id=block.id, name=block.name, arguments=arguments, malformed=malformed
					)
				)

		usage = getattr(response, "usage", None)
		return AIResponse(
			text="".join(text_parts) or None,
			tool_calls=tuple(calls),
			stop_reason=response.stop_reason,
			usage=AIUsage(
				input_tokens=getattr(usage, "input_tokens", None),
				output_tokens=getattr(usage, "output_tokens", None),
			)
			if usage
			else None,
		)

	#: Anthropic's SDK also resolves a key from the environment, so a blank
	#: field here is a legitimate configuration rather than a mistake.
	requires_api_key = False

	#: …and it knows its own endpoint, so no base URL need be configured.
	has_builtin_endpoint = True

	capabilities = {
		Capability.STREAMING: Support.YES,
		Capability.TOOLS: Support.YES,
		Capability.PARALLEL_TOOLS: Support.YES,
		Capability.STRUCTURED_OUTPUT: Support.YES,
		Capability.JSON_MODE: Support.YES,
		Capability.REASONING: Support.YES,
		Capability.VISION: Support.YES,
		Capability.LOCAL_EXECUTION: Support.NO,
	}

	def stream(self, system: str, messages, tools=()):
		"""Streams through the SDK's own accumulator.

		`messages.stream()` reassembles partial JSON for tool arguments itself,
		so the final message is complete — which is why tool calls are read off
		`get_final_message()` rather than from the deltas. Doing it by hand here
		would be reimplementing, slightly worse, the one part of this the SDK
		already gets right.
		"""
		payload = {
			"model": self.model,
			"max_tokens": 4096,
			"system": system,
			"messages": [self._encode(message) for message in messages],
		}
		if tools:
			payload["tools"] = [
				{
					"name": tool.name,
					"description": tool.description,
					"input_schema": tool.input_schema,
				}
				for tool in tools
			]

		with self._client().messages.stream(**payload) as stream:
			for text in stream.text_stream:
				if text:
					yield AIStreamEvent.delta(text)
			final = stream.get_final_message()

		calls = []
		for block in final.content:
			if block.type == "tool_use":
				arguments, malformed = parse_arguments(block.input)
				calls.append(
					AIToolCall(
						id=block.id, name=block.name, arguments=arguments, malformed=malformed
					)
				)

		if calls:
			yield AIStreamEvent.calls(tuple(calls))

		usage = getattr(final, "usage", None)
		yield AIStreamEvent.finished(
			usage=AIUsage(
				input_tokens=getattr(usage, "input_tokens", None),
				output_tokens=getattr(usage, "output_tokens", None),
			)
			if usage
			else None,
			stop_reason=final.stop_reason,
		)

	@staticmethod
	def _encode(message: AIMessage) -> dict:
		"""Anthropic carries tool results as a *user* turn of tool_result blocks,
		not as a role of its own — the single most commonly mistranslated part
		of this protocol."""
		if message.role == "tool":
			result = message.tool_result
			return {
				"role": "user",
				"content": [
					{
						"type": "tool_result",
						"tool_use_id": result.call_id,
						"content": result.content,
						"is_error": result.is_error,
					}
				],
			}

		if message.role == "assistant" and message.tool_calls:
			content = []
			if message.text:
				content.append({"type": "text", "text": message.text})
			content.extend(
				{
					"type": "tool_use",
					"id": call.id,
					"name": call.name,
					"input": call.arguments,
				}
				for call in message.tool_calls
			)
			return {"role": "assistant", "content": content}

		return {"role": message.role, "content": message.text or ""}


class OpenAICompatibleProvider(HasCapabilities):
	"""Anything speaking the OpenAI chat-completions API.

	One adapter for OpenAI, OpenRouter, vLLM, LM Studio and corporate gateways,
	because between those the difference really is only the base URL and the
	key. Constrains output with `response_format: json_schema` and `strict`,
	which is the OpenAI equivalent of the guarantee the other adapters get.
	"""

	def __init__(self, model: str, api_key: str, base_url: str):
		self.model = model
		self.api_key = api_key
		self.base_url = base_url.rstrip("/")

	def complete_json(self, system: str, user_message: str, schema: dict) -> dict:
		self.usage = None
		body = _post_json(
			f"{self.base_url}/chat/completions",
			headers={
				"Authorization": f"Bearer {self.api_key}",
				"Content-Type": "application/json",
			},
			payload={
				"model": self.model,
				"messages": [
					{"role": "system", "content": system},
					{"role": "user", "content": user_message},
				],
				"response_format": {
					"type": "json_schema",
					"json_schema": {"name": "response", "strict": True, "schema": schema},
				},
				"temperature": 0,
			},
		)
		raw_usage = body.get("usage") or {}
		self.usage = _usage(
			raw_usage.get("prompt_tokens"), raw_usage.get("completion_tokens")
		)

		choices = body.get("choices") or []
		if not choices:
			frappe.throw("The model returned no choices", exc=LLMError)

		return _parse_json_content(choices[0].get("message", {}).get("content"))

	def chat(self, system: str, messages, tools=()) -> AIResponse:
		payload = {
			"model": self.model,
			"messages": [{"role": "system", "content": system}]
			+ [self._encode(message) for message in messages],
		}
		if tools:
			payload["tools"] = [
				{
					"type": "function",
					"function": {
						"name": tool.name,
						"description": tool.description,
						"parameters": tool.input_schema,
					},
				}
				for tool in tools
			]

		body = _post_json(
			f"{self.base_url}/chat/completions",
			headers={
				"Authorization": f"Bearer {self.api_key}",
				"Content-Type": "application/json",
			},
			payload=payload,
		)

		choices = body.get("choices") or []
		if not choices:
			frappe.throw("The model returned no choices", exc=LLMError)

		message = choices[0].get("message", {})
		calls = []
		for raw in message.get("tool_calls") or []:
			function = raw.get("function", {})
			# Arguments arrive as a JSON *string* here, unlike every other
			# provider in this module.
			arguments, malformed = parse_arguments(function.get("arguments"))
			calls.append(
				AIToolCall(
					id=raw.get("id") or function.get("name", ""),
					name=function.get("name", ""),
					arguments=arguments,
					malformed=malformed,
				)
			)

		usage = body.get("usage") or {}
		return AIResponse(
			text=message.get("content") or None,
			tool_calls=tuple(calls),
			stop_reason=choices[0].get("finish_reason"),
			usage=AIUsage(
				input_tokens=usage.get("prompt_tokens"),
				output_tokens=usage.get("completion_tokens"),
			)
			if usage
			else None,
		)

	#: Deliberately conservative: this adapter also serves OpenRouter and any
	#: OpenAI-shaped endpoint an operator points it at, so what is true of
	#: OpenAI itself is not necessarily true of the thing on the other end.
	#: Vision and reasoning are therefore UNKNOWN rather than assumed.
	#: Every endpoint this adapter serves authenticates with a key.
	requires_api_key = True

	capabilities = {
		Capability.STREAMING: Support.YES,
		Capability.TOOLS: Support.YES,
		Capability.PARALLEL_TOOLS: Support.YES,
		Capability.STRUCTURED_OUTPUT: Support.YES,
		Capability.JSON_MODE: Support.YES,
		Capability.LOCAL_EXECUTION: Support.NO,
	}

	def stream(self, system: str, messages, tools=()):
		payload = {
			"model": self.model,
			"messages": [{"role": "system", "content": system}]
			+ [self._encode(message) for message in messages],
			"stream": True,
			# Without this the usage block is omitted from a streamed reply
			# entirely, and the turn ends with no token counts at all.
			"stream_options": {"include_usage": True},
		}
		if tools:
			payload["tools"] = [
				{
					"type": "function",
					"function": {
						"name": tool.name,
						"description": tool.description,
						"parameters": tool.input_schema,
					},
				}
				for tool in tools
			]

		accumulator = ToolCallAccumulator()
		usage = None
		stop_reason = None

		lines = _post_stream(
			f"{self.base_url}/chat/completions",
			headers={
				"Authorization": f"Bearer {self.api_key}",
				"Content-Type": "application/json",
			},
			payload=payload,
		)

		for chunk in _sse_payloads(lines):
			if chunk.get("usage"):
				usage = AIUsage(
					input_tokens=chunk["usage"].get("prompt_tokens"),
					output_tokens=chunk["usage"].get("completion_tokens"),
				)

			for choice in chunk.get("choices") or []:
				stop_reason = choice.get("finish_reason") or stop_reason
				delta = choice.get("delta") or {}

				if delta.get("content"):
					yield AIStreamEvent.delta(delta["content"])

				for fragment in delta.get("tool_calls") or []:
					function = fragment.get("function") or {}
					accumulator.add(
						index=fragment.get("index", 0),
						call_id=fragment.get("id"),
						name=function.get("name"),
						argument_fragment=function.get("arguments"),
					)

		if accumulator:
			yield AIStreamEvent.calls(accumulator.finish())
		yield AIStreamEvent.finished(usage=usage, stop_reason=stop_reason)

	@staticmethod
	def _encode(message: AIMessage) -> dict:
		if message.role == "tool":
			result = message.tool_result
			return {
				"role": "tool",
				"tool_call_id": result.call_id,
				"content": result.content,
			}

		if message.role == "assistant" and message.tool_calls:
			return {
				"role": "assistant",
				"content": message.text,
				"tool_calls": [
					{
						"id": call.id,
						"type": "function",
						"function": {
							"name": call.name,
							"arguments": json.dumps(call.arguments),
						},
					}
					for call in message.tool_calls
				],
			}

		return {"role": message.role, "content": message.text or ""}


class GeminiProvider(HasCapabilities):
	"""Google Gemini via generateContent.

	Gemini takes its schema in `responseSchema` and needs `responseMimeType`
	set to JSON, and its schema dialect is a *subset* of JSON Schema -- keys the
	other providers ignore are rejected here with a 400, so they are pruned
	rather than passed through and hoped at.
	"""

	def __init__(self, model: str, api_key: str, base_url: str | None = None):
		self.model = model
		self.api_key = api_key
		self.base_url = (base_url or DEFAULT_BASE_URLS["Google Gemini"]).rstrip("/")

	@staticmethod
	def prune_schema(schema):
		"""Drop the keys Gemini rejects, at every depth."""
		if isinstance(schema, dict):
			return {
				key: GeminiProvider.prune_schema(value)
				for key, value in schema.items()
				if key not in _GEMINI_UNSUPPORTED_SCHEMA_KEYS
			}
		if isinstance(schema, list):
			return [GeminiProvider.prune_schema(item) for item in schema]
		return schema

	def complete_json(self, system: str, user_message: str, schema: dict) -> dict:
		self.usage = None
		body = _post_json(
			f"{self.base_url}/models/{self.model}:generateContent",
			headers={"x-goog-api-key": self.api_key, "Content-Type": "application/json"},
			payload={
				"systemInstruction": {"parts": [{"text": system}]},
				"contents": [{"role": "user", "parts": [{"text": user_message}]}],
				"generationConfig": {
					"responseMimeType": "application/json",
					"responseSchema": self.prune_schema(schema),
					"temperature": 0,
				},
			},
		)
		raw_usage = body.get("usageMetadata") or {}
		self.usage = _usage(
			raw_usage.get("promptTokenCount"), raw_usage.get("candidatesTokenCount")
		)

		candidates = body.get("candidates") or []
		if not candidates:
			frappe.throw("The model returned no candidates", exc=LLMError)

		parts = candidates[0].get("content", {}).get("parts") or []
		text = next((part.get("text") for part in parts if part.get("text")), None)
		return _parse_json_content(text)

	def list_models(self) -> list[dict]:
		"""What this key can see, from Gemini's own catalogue.

		Advisory, and deliberately labelled so. Gemini lists models that a given
		key may not actually call — `gemini-2.5-flash` appears here and then
		answers 404 "no longer available to new users". Only a connection test
		settles it, which is why the settings screen offers both.
		"""
		body = _get_json(
			f"{self.base_url}/models",
			headers={"x-goog-api-key": self.api_key},
		)
		models = []
		for entry in body.get("models") or []:
			methods = entry.get("supportedGenerationMethods") or []
			if "generateContent" not in methods:
				continue
			models.append(
				{
					"id": entry["name"].removeprefix("models/"),
					"display_name": entry.get("displayName") or entry["name"],
					"context_window": entry.get("inputTokenLimit"),
					# Gemini's catalogue does not say whether a model does tool
					# calling, so this stays unknown rather than being guessed.
					"supports_tools": Support.UNKNOWN.value,
					"supports_streaming": Support.YES.value,
				}
			)
		return sorted(models, key=lambda m: m["id"])

	def _payload(self, system: str, messages, tools=()) -> dict:
		"""One request body, shared by the unary and streamed calls.

		Shared deliberately: when these were built separately the streamed path
		quietly lost the tool declarations, which is invisible until a model
		that would have called a tool simply does not.
		"""
		payload = {
			"systemInstruction": {"parts": [{"text": system}]},
			"contents": [self._encode(message) for message in messages],
		}
		if tools:
			payload["tools"] = [
				{
					"functionDeclarations": [
						{
							"name": tool.name,
							"description": tool.description,
							"parameters": self.prune_schema(tool.input_schema),
						}
						for tool in tools
					]
				}
			]
		return payload

	@staticmethod
	def _decode_call(part: dict, index: int) -> AIToolCall:
		"""One `functionCall` part, normalized.

		Newer Gemini models issue their own call id; older ones did not. Theirs
		is preferred when present and a stable synthetic one is used otherwise,
		so the rest of the system can always address a call. (Either way the id
		a *user* confirms is the Pending Action's, not this one — see chat.py.)
		"""
		call = part["functionCall"]
		arguments, malformed = parse_arguments(call.get("args"))
		return AIToolCall(
			id=call.get("id") or f"{call.get('name', 'call')}-{index}",
			name=call.get("name", ""),
			arguments=arguments,
			malformed=malformed,
			# Must come back verbatim on the next request or Gemini rejects the
			# whole conversation. See AIToolCall.provider_meta.
			provider_meta=(
				{"thoughtSignature": part["thoughtSignature"]}
				if part.get("thoughtSignature")
				else {}
			),
		)

	def chat(self, system: str, messages, tools=()) -> AIResponse:
		payload = self._payload(system, messages, tools)

		body = _post_json(
			f"{self.base_url}/models/{self.model}:generateContent",
			headers={"x-goog-api-key": self.api_key, "Content-Type": "application/json"},
			payload=payload,
		)

		candidates = body.get("candidates") or []
		if not candidates:
			frappe.throw("The model returned no candidates", exc=LLMError)

		text_parts, calls = [], []
		for index, part in enumerate(candidates[0].get("content", {}).get("parts") or []):
			if part.get("text"):
				text_parts.append(part["text"])
			elif part.get("functionCall"):
				calls.append(self._decode_call(part, index))

		usage = body.get("usageMetadata") or {}
		return AIResponse(
			text="".join(text_parts) or None,
			tool_calls=tuple(calls),
			stop_reason=candidates[0].get("finishReason"),
			usage=AIUsage(
				input_tokens=usage.get("promptTokenCount"),
				output_tokens=usage.get("candidatesTokenCount"),
			)
			if usage
			else None,
		)

	#: Gemini authenticates with an API key on every request.
	requires_api_key = True

	capabilities = {
		Capability.STREAMING: Support.YES,
		Capability.TOOLS: Support.YES,
		Capability.PARALLEL_TOOLS: Support.YES,
		Capability.STRUCTURED_OUTPUT: Support.YES,
		Capability.JSON_MODE: Support.YES,
		Capability.REASONING: Support.YES,
		Capability.VISION: Support.YES,
		Capability.LOCAL_EXECUTION: Support.NO,
	}

	def stream(self, system: str, messages, tools=()):
		"""Gemini's own SSE endpoint, rather than one call pretending to stream.

		`streamGenerateContent?alt=sse` emits the same candidate shape as the
		unary call, one chunk at a time. Tool calls are accumulated across
		chunks and emitted once at the end: a half-arrived `functionCall` is not
		a thing anyone can act on, and its `thoughtSignature` has to travel with
		it or the next request is refused.
		"""
		payload = self._payload(system, messages, tools)
		lines = _post_stream(
			f"{self.base_url}/models/{self.model}:streamGenerateContent?alt=sse",
			headers={"x-goog-api-key": self.api_key, "Content-Type": "application/json"},
			payload=payload,
		)

		calls, usage, stop_reason = [], None, None
		for chunk in _sse_payloads(lines):
			for candidate in chunk.get("candidates") or []:
				stop_reason = candidate.get("finishReason") or stop_reason
				for index, part in enumerate(candidate.get("content", {}).get("parts") or []):
					if part.get("text"):
						yield AIStreamEvent(kind="text", text=part["text"])
					elif part.get("functionCall"):
						calls.append(self._decode_call(part, index))
			if chunk.get("usageMetadata"):
				meta = chunk["usageMetadata"]
				usage = AIUsage(
					input_tokens=meta.get("promptTokenCount"),
					output_tokens=meta.get("candidatesTokenCount"),
				)

		if calls:
			yield AIStreamEvent(kind="tool_calls", tool_calls=tuple(calls))
		yield AIStreamEvent(kind="done", usage=usage, stop_reason=stop_reason)

	@staticmethod
	def _encode(message: AIMessage) -> dict:
		"""Gemini has no tool role either: a result is a `functionResponse` part
		on a *user* turn, and it is matched to its call by name rather than by
		id, which is why the id is ours to invent."""
		if message.role == "tool":
			result = message.tool_result
			return {
				"role": "user",
				"parts": [
					{
						"functionResponse": {
							"name": result.name,
							"response": {"content": result.content},
						}
					}
				],
			}

		if message.role == "assistant" and message.tool_calls:
			parts = []
			if message.text:
				parts.append({"text": message.text})
			for call in message.tool_calls:
				part = {"functionCall": {"name": call.name, "args": call.arguments}}
				# Echoed back exactly as received. Gemini refuses the request
				# outright without it — the tool loop cannot complete a second
				# round trip. Absent for models that never sent one, and absent
				# for a call replayed from a Pending Action, which is why
				# `chat.py` keeps the signature alongside the stored arguments.
				if signature := call.provider_meta.get("thoughtSignature"):
					part["thoughtSignature"] = signature
				parts.append(part)
			return {"role": "model", "parts": parts}

		# Gemini names the assistant "model".
		role = "model" if message.role == "assistant" else "user"
		return {"role": role, "parts": [{"text": message.text or ""}]}


class OllamaProvider(HasCapabilities):
	"""Local model via Ollama's /api/chat endpoint.

	Ollama supports schema-constrained output through its `format` parameter,
	which takes the JSON schema directly -- the same guarantee the Anthropic
	provider gets from output_config.format.
	"""

	def __init__(self, model: str, base_url: str | None = None):
		self.model = model
		self.base_url = (base_url or DEFAULT_BASE_URLS["Ollama"]).rstrip("/")

	def complete_json(self, system: str, user_message: str, schema: dict) -> dict:
		self.usage = None
		body = _post_json(
			f"{self.base_url}/api/chat",
			headers={"Content-Type": "application/json"},
			payload={
				"model": self.model,
				"messages": [
					{"role": "system", "content": system},
					{"role": "user", "content": user_message},
				],
				"format": schema,
				"stream": False,
				"options": {"temperature": 0},
			},
		)
		self.usage = _usage(body.get("prompt_eval_count"), body.get("eval_count"))

		return _parse_json_content(body.get("message", {}).get("content"))

	def chat(self, system: str, messages, tools=()) -> AIResponse:
		payload = {
			"model": self.model,
			"messages": [{"role": "system", "content": system}]
			+ [self._encode(message) for message in messages],
			"stream": False,
		}
		if tools:
			payload["tools"] = [
				{
					"type": "function",
					"function": {
						"name": tool.name,
						"description": tool.description,
						"parameters": tool.input_schema,
					},
				}
				for tool in tools
			]

		body = _post_json(
			f"{self.base_url}/api/chat",
			headers={"Content-Type": "application/json"},
			payload=payload,
		)

		message = body.get("message") or {}
		calls = []
		for index, raw in enumerate(message.get("tool_calls") or []):
			function = raw.get("function", {})
			# Ollama sends arguments as an object, unlike OpenAI proper, and
			# issues no call id.
			arguments, malformed = parse_arguments(function.get("arguments"))
			calls.append(
				AIToolCall(
					id=f"{function.get('name', 'call')}-{index}",
					name=function.get("name", ""),
					arguments=arguments,
					malformed=malformed,
				)
			)

		return AIResponse(
			text=message.get("content") or None,
			tool_calls=tuple(calls),
			stop_reason=body.get("done_reason"),
			usage=AIUsage(
				input_tokens=body.get("prompt_eval_count"),
				output_tokens=body.get("eval_count"),
			),
		)

	#: Measured against `qwen2.5-coder:7b` on 2026-08-07, not read off a
	#: feature list. Ollama's API *has* a `tool_calls` field and advertises a
	#: `tools` capability for that model; the model never populates it and
	#: returns the call as prose instead. Whether some other local model would
	#: is unknown, which is exactly what UNKNOWN is for — the model registry
	#: narrows this per model rather than this line claiming either answer.
	#: Runs locally and has no notion of a credential.
	requires_api_key = False

	capabilities = {
		Capability.STREAMING: Support.YES,
		Capability.TOOLS: Support.UNKNOWN,
		Capability.PARALLEL_TOOLS: Support.UNKNOWN,
		Capability.STRUCTURED_OUTPUT: Support.YES,
		Capability.JSON_MODE: Support.YES,
		Capability.LOCAL_EXECUTION: Support.YES,
	}

	def stream(self, system: str, messages, tools=()):
		"""Ollama streams newline-delimited JSON objects, not SSE."""
		payload = {
			"model": self.model,
			"messages": [{"role": "system", "content": system}]
			+ [self._encode(message) for message in messages],
			"stream": True,
		}
		if tools:
			payload["tools"] = [
				{
					"type": "function",
					"function": {
						"name": tool.name,
						"description": tool.description,
						"parameters": tool.input_schema,
					},
				}
				for tool in tools
			]

		calls = []
		usage = None
		stop_reason = None

		lines = _post_stream(
			f"{self.base_url}/api/chat",
			headers={"Content-Type": "application/json"},
			payload=payload,
		)

		for line in lines:
			if not line:
				continue
			try:
				chunk = json.loads(line)
			except json.JSONDecodeError:
				continue

			message = chunk.get("message") or {}
			if message.get("content"):
				yield AIStreamEvent.delta(message["content"])

			# Ollama emits whole tool calls, not fragments, so no accumulator.
			for index, raw in enumerate(message.get("tool_calls") or []):
				function = raw.get("function", {})
				arguments, malformed = parse_arguments(function.get("arguments"))
				calls.append(
					AIToolCall(
						id=f"{function.get('name', 'call')}-{len(calls) + index}",
						name=function.get("name", ""),
						arguments=arguments,
						malformed=malformed,
					)
				)

			if chunk.get("done"):
				stop_reason = chunk.get("done_reason")
				usage = AIUsage(
					input_tokens=chunk.get("prompt_eval_count"),
					output_tokens=chunk.get("eval_count"),
				)

		if calls:
			yield AIStreamEvent.calls(tuple(calls))
		yield AIStreamEvent.finished(usage=usage, stop_reason=stop_reason)

	@staticmethod
	def _encode(message: AIMessage) -> dict:
		if message.role == "tool":
			return {"role": "tool", "content": message.tool_result.content}

		if message.role == "assistant" and message.tool_calls:
			return {
				"role": "assistant",
				"content": message.text or "",
				"tool_calls": [
					{"function": {"name": call.name, "arguments": call.arguments}}
					for call in message.tool_calls
				],
			}

		return {"role": message.role, "content": message.text or ""}
