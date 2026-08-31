# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""What a provider can actually do, declared rather than guessed.

## Why this exists as data

The gateway has to decide things like "may I offer tools on this turn?" and
"will text trickle in, or arrive whole?". Those answers differ per provider and
sometimes per *model*, and the two ways of getting them wrong are both bad:

- **Inferring from the name.** `"Ollama"` tells you nothing; the same server
  serves a model that emits structured tool calls and one that does not. We
  measured exactly that — `qwen2.5-coder:7b` advertises a `tools` capability
  through Ollama's API and then returns the call as prose.
- **Assuming true and finding out at runtime.** That turns a capability gap into
  a failed turn in front of a user.

So capability is a three-valued fact — yes, no, **unknown** — attached to the
adapter, and `unknown` is a real answer that must not be read as yes.

## Provider capability vs model capability

A provider's declaration is the ceiling: Gemini's API supports tools, so
`GeminiProvider` says yes. Whether a *particular* model honours it is a
narrower question the model registry answers, and it can only ever narrow.
"""

from __future__ import annotations

import enum


class Capability(enum.StrEnum):
	"""The questions the gateway needs answered before it composes a request."""

	STREAMING = "supports_streaming"
	TOOLS = "supports_tools"
	PARALLEL_TOOLS = "supports_parallel_tools"
	STRUCTURED_OUTPUT = "supports_structured_output"
	JSON_MODE = "supports_json_mode"
	VISION = "supports_vision"
	REASONING = "supports_reasoning"
	LOCAL_EXECUTION = "supports_local_execution"


class Support(enum.StrEnum):
	"""Three-valued, because "we have not checked" is not "no".

	`UNKNOWN` is what an honest adapter says about a capability nobody has
	verified. Callers must treat it as "do not rely on this" rather than as
	either answer — `Capability.TOOLS` being UNKNOWN means offer tools if you
	like, but be ready for prose.
	"""

	YES = "yes"
	NO = "no"
	UNKNOWN = "unknown"


class HasCapabilities:
	"""Mixin giving every adapter the same way of being asked.

	A mixin rather than an interface check because the adapters are duck-typed
	by design (see `llm.py`) — this adds one shared implementation without
	forcing an inheritance hierarchy on four classes that share no behaviour.
	"""

	#: Overridden per adapter. Anything unlisted is UNKNOWN, which is the safe
	#: default: a capability nobody thought about should not read as supported.
	capabilities: dict[Capability, Support] = {}

	def supports(self, capability: Capability) -> Support:
		return self.capabilities.get(capability, Support.UNKNOWN)

	def can(self, capability: Capability) -> bool:
		"""True only for a definite yes. `UNKNOWN` is not permission."""
		return self.supports(capability) is Support.YES

	@property
	def streams_natively(self) -> bool:
		"""Kept as a name because `agent/loop.py` and its tests ask for it.

		Now derived from the declaration instead of being a second, separately
		maintained fact that could disagree with it.
		"""
		return self.can(Capability.STREAMING)

	def capability_report(self) -> dict[str, str]:
		"""Every capability with its value, for a settings screen or a doctor
		command. Includes the unknowns — they are the interesting ones."""
		return {
			capability.value: self.supports(capability).value
			for capability in Capability
		}
