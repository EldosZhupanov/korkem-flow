# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The internal AI protocol.

One vocabulary for talking to a language model, which the provider adapters in
`llm.py` translate to and from. Nothing above `llm.py` — not the tool registry,
not the agent loop, not the chat endpoint — may import a vendor SDK or know the
shape of a vendor's JSON. That is the whole point of having this module: swapping
Anthropic for a local Ollama changes one setting, not the call sites.

The types are deliberately small and frozen. A message is a fact about what has
already happened in a conversation, and a mutable one is how a history quietly
diverges from what was actually sent.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field


@dataclass(frozen=True)
class AITool:
	"""A capability offered to the model.

	`input_schema` is JSON Schema. It is not advisory: it is what the provider
	constrains generated arguments against, and what the registry validates a
	call against before anything executes.
	"""

	name: str
	description: str
	input_schema: dict


@dataclass(frozen=True)
class AIToolCall:
	"""The model asking for a tool to be run. It has not been run yet."""

	id: str
	name: str
	arguments: dict = field(default_factory=dict)

	#: True when the provider handed back arguments that would not parse.
	#: Kept as data rather than raised, because the right response is to tell
	#: the model its call was malformed and let it try again — killing the turn
	#: over a bad JSON fragment loses the whole conversation.
	malformed: bool = False

	#: Opaque bytes the *originating* provider needs handed back verbatim.
	#:
	#: Nothing above `llm.py` may read or interpret this. It exists because some
	#: providers make a tool call only half-portable: Gemini returns a
	#: `thoughtSignature` beside each `functionCall` and **rejects the next
	#: request** if it is not echoed back — "Function call is missing a
	#: thought_signature … required for tools to work correctly". Found by
	#: running it, not by reading docs.
	#:
	#: Modelling it as an opaque bag rather than a `thought_signature` field is
	#: what keeps the protocol provider-agnostic: the next provider with its own
	#: continuation token needs no change here, and the agent loop never learns
	#: that any of this exists.
	provider_meta: dict = field(default_factory=dict, compare=False)


@dataclass(frozen=True)
class AIToolResult:
	"""What running a tool produced, on its way back to the model."""

	call_id: str
	name: str
	content: str
	is_error: bool = False


@dataclass(frozen=True)
class AIMessage:
	"""One turn. `system` is not a role here — it is passed separately to
	`chat()`, because Anthropic and Gemini take it as its own field rather than
	as a message, and pretending otherwise would push that difference upward.
	"""

	role: str
	text: str | None = None
	tool_calls: tuple[AIToolCall, ...] = ()
	tool_result: AIToolResult | None = None

	@staticmethod
	def user(text: str) -> AIMessage:
		return AIMessage(role="user", text=text)

	@staticmethod
	def assistant(text: str | None = None, tool_calls: tuple[AIToolCall, ...] = ()) -> AIMessage:
		return AIMessage(role="assistant", text=text, tool_calls=tool_calls)

	@staticmethod
	def tool(result: AIToolResult) -> AIMessage:
		return AIMessage(role="tool", tool_result=result)


@dataclass(frozen=True)
class AIUsage:
	"""Token counts, when the provider reports them.

	`None` means "not reported", which is different from zero — a usage panel
	showing a confident 0 for a provider that never said is lying.
	"""

	input_tokens: int | None = None
	output_tokens: int | None = None

	@property
	def total_tokens(self) -> int | None:
		if self.input_tokens is None and self.output_tokens is None:
			return None
		return (self.input_tokens or 0) + (self.output_tokens or 0)


@dataclass(frozen=True)
class AIResponse:
	"""One reply: prose, tool requests, or both."""

	text: str | None = None
	tool_calls: tuple[AIToolCall, ...] = ()
	usage: AIUsage | None = None
	stop_reason: str | None = None

	@property
	def wants_tools(self) -> bool:
		return bool(self.tool_calls)


def parse_arguments(raw) -> tuple[dict, bool]:
	"""Normalise provider-supplied tool arguments to a dict.

	Providers disagree: OpenAI sends a JSON *string*, Anthropic and Ollama send
	an object, and a small local model sends whatever it manages. Returns the
	arguments and whether they had to be given up on.
	"""
	if isinstance(raw, dict):
		return raw, False
	if raw in (None, ""):
		return {}, False
	if isinstance(raw, str):
		try:
			parsed = json.loads(raw)
		except json.JSONDecodeError:
			return {}, True
		return (parsed, False) if isinstance(parsed, dict) else ({}, True)
	return {}, True


@dataclass(frozen=True)
class AIStreamEvent:
	"""One thing that happened while a reply was being produced.

	Deliberately one type with a `kind` rather than a class hierarchy: these are
	published over a realtime channel as JSON, and a flat shape survives that
	round trip without a serialiser that has to be kept in step at both ends.

	Kinds:

	* ``text``      -- a fragment of prose. Append it; never replace on it.
	* ``tool_calls``-- the model has finished asking for tools. Arguments are
	  complete by this point, which is why they arrive as one event rather than
	  as fragments: a half-parsed argument list is not something a caller can do
	  anything useful with.
	* ``done``      -- the turn ended. Carries usage when the provider reports it.
	"""

	kind: str
	text: str | None = None
	tool_calls: tuple[AIToolCall, ...] = ()
	usage: AIUsage | None = None
	stop_reason: str | None = None

	@staticmethod
	def delta(text: str) -> AIStreamEvent:
		return AIStreamEvent(kind="text", text=text)

	@staticmethod
	def calls(tool_calls: tuple[AIToolCall, ...]) -> AIStreamEvent:
		return AIStreamEvent(kind="tool_calls", tool_calls=tool_calls)

	@staticmethod
	def finished(usage: AIUsage | None = None, stop_reason: str | None = None) -> AIStreamEvent:
		return AIStreamEvent(kind="done", usage=usage, stop_reason=stop_reason)


class ToolCallAccumulator:
	"""Reassembles tool calls that arrive in fragments.

	The OpenAI streaming format sends a tool call across many chunks, keyed by
	`index`, with the arguments string built up a few characters at a time. Only
	the first fragment carries the id and the name. Treating each chunk as a
	whole call is the classic bug here: you end up with a dozen calls to the
	empty-string tool.
	"""

	def __init__(self):
		self._by_index: dict[int, dict] = {}

	def add(self, index: int, call_id: str | None, name: str | None, argument_fragment: str | None):
		entry = self._by_index.setdefault(index, {"id": None, "name": None, "arguments": ""})
		if call_id:
			entry["id"] = call_id
		if name:
			entry["name"] = name
		if argument_fragment:
			entry["arguments"] += argument_fragment

	def finish(self) -> tuple[AIToolCall, ...]:
		calls = []
		for index in sorted(self._by_index):
			entry = self._by_index[index]
			arguments, malformed = parse_arguments(entry["arguments"])
			calls.append(
				AIToolCall(
					id=entry["id"] or f"{entry['name'] or 'call'}-{index}",
					name=entry["name"] or "",
					arguments=arguments,
					malformed=malformed,
				)
			)
		return tuple(calls)

	def __bool__(self) -> bool:
		return bool(self._by_index)
