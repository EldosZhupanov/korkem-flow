# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Streaming, across the transports the providers actually use.

Two wire formats and one SDK, and the hard part is the same in all three: a
reply arrives in pieces and has to be reassembled without inventing content or
losing the end of it.

The bug this file exists to prevent is the OpenAI tool-call fragment. A call is
spread across many chunks keyed by `index`; only the first carries the id and
the name, and the arguments are built a few characters at a time. Treat each
chunk as a whole call and you get a dozen calls to the empty-string tool with
unparseable arguments — which looks, from the UI, exactly like the model being
stupid.
"""

from unittest.mock import MagicMock, patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.orchestrator import llm
from korkem_ai.korkem_ai.orchestrator.capabilities import Capability, Support
from korkem_ai.korkem_ai.orchestrator.protocol import (
	AIMessage,
	AITool,
	ToolCallAccumulator,
)

SEARCH_DEALS = AITool(name="crm.search_deals", description="Find deals", input_schema={})


def _streamed(lines, status=200):
	response = MagicMock()
	response.status_code = status
	response.text = "error body"
	response.iter_lines.return_value = iter(lines)
	return response


class TestToolCallAccumulator(IntegrationTestCase):
	def test_reassembles_one_call_from_many_fragments(self):
		accumulator = ToolCallAccumulator()
		accumulator.add(0, "call_1", "crm.search_deals", '{"sta')
		accumulator.add(0, None, None, 'tus": "Op')
		accumulator.add(0, None, None, 'en"}')

		calls = accumulator.finish()

		self.assertEqual(len(calls), 1)
		self.assertEqual(calls[0].id, "call_1")
		self.assertEqual(calls[0].name, "crm.search_deals")
		self.assertEqual(calls[0].arguments, {"status": "Open"})
		self.assertFalse(calls[0].malformed)

	def test_keeps_parallel_calls_apart_by_index(self):
		accumulator = ToolCallAccumulator()
		accumulator.add(0, "a", "crm.search_deals", '{"status":"Open"}')
		accumulator.add(1, "b", "tasks.list", '{"overdue":true}')

		calls = accumulator.finish()

		self.assertEqual([call.name for call in calls], ["crm.search_deals", "tasks.list"])
		self.assertEqual(calls[1].arguments, {"overdue": True})

	def test_truncated_arguments_are_flagged_not_invented(self):
		"""A cut-off stream must not produce a call that looks complete."""
		accumulator = ToolCallAccumulator()
		accumulator.add(0, "a", "crm.search_deals", '{"status": "Op')

		call = accumulator.finish()[0]

		self.assertTrue(call.malformed)
		self.assertEqual(call.arguments, {})

	def test_empty_accumulator_is_falsy(self):
		self.assertFalse(ToolCallAccumulator())


class TestSSEParsing(IntegrationTestCase):
	def test_skips_keepalives_the_done_sentinel_and_junk(self):
		payloads = list(
			llm._sse_payloads(
				[
					"",
					": keepalive",
					'data: {"a": 1}',
					"data: not json at all",
					"data: [DONE]",
				]
			)
		)

		self.assertEqual(payloads, [{"a": 1}])


class TestOpenAICompatibleStreaming(IntegrationTestCase):
	def _provider(self):
		return llm.OpenAICompatibleProvider(
			model="gpt-5", api_key="k", base_url="https://api.example/v1"
		)

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_yields_text_deltas_then_done(self, mock_post):
		mock_post.return_value = _streamed(
			[
				'data: {"choices":[{"delta":{"content":"Hel"}}]}',
				'data: {"choices":[{"delta":{"content":"lo"}}]}',
				'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}',
				'data: {"usage":{"prompt_tokens":7,"completion_tokens":2},"choices":[]}',
				"data: [DONE]",
			]
		)

		events = list(self._provider().stream("sys", [AIMessage.user("hi")]))

		self.assertEqual([e.text for e in events if e.kind == "text"], ["Hel", "lo"])
		done = events[-1]
		self.assertEqual(done.kind, "done")
		self.assertEqual(done.stop_reason, "stop")
		self.assertEqual(done.usage.total_tokens, 9)

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_reassembles_a_tool_call_split_across_chunks(self, mock_post):
		mock_post.return_value = _streamed(
			[
				'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1",'
				'"function":{"name":"crm.search_deals","arguments":""}}]}}]}',
				'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
				'"function":{"arguments":"{\\"sta"}}]}}]}',
				'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
				'"function":{"arguments":"tus\\": \\"Open\\"}"}}]}}]}',
				'data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}',
				"data: [DONE]",
			]
		)

		events = list(self._provider().stream("sys", [AIMessage.user("deals?")], [SEARCH_DEALS]))

		calls = [e for e in events if e.kind == "tool_calls"]
		self.assertEqual(len(calls), 1, "one event carrying complete calls, not one per fragment")
		call = calls[0].tool_calls[0]
		self.assertEqual(call.name, "crm.search_deals")
		self.assertEqual(call.arguments, {"status": "Open"})
		self.assertEqual(events[-1].kind, "done")

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_asks_for_usage_which_is_otherwise_omitted_when_streaming(self, mock_post):
		mock_post.return_value = _streamed(["data: [DONE]"])

		list(self._provider().stream("sys", [AIMessage.user("hi")]))

		_, kwargs = mock_post.call_args
		self.assertTrue(kwargs["json"]["stream"])
		self.assertEqual(kwargs["json"]["stream_options"], {"include_usage": True})
		self.assertTrue(kwargs["stream"])

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_an_http_error_is_raised_not_streamed_as_content(self, mock_post):
		mock_post.return_value = _streamed([], status=401)

		with self.assertRaises(frappe.ValidationError):
			list(self._provider().stream("sys", [AIMessage.user("hi")]))


class TestOllamaStreaming(IntegrationTestCase):
	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_reads_newline_delimited_json_not_sse(self, mock_post):
		mock_post.return_value = _streamed(
			[
				'{"message":{"content":"Hel"},"done":false}',
				'{"message":{"content":"lo"},"done":false}',
				'{"message":{"content":""},"done":true,"done_reason":"stop",'
				'"prompt_eval_count":20,"eval_count":5}',
			]
		)

		provider = llm.OllamaProvider(model="m", base_url="http://example:11434")
		events = list(provider.stream("sys", [AIMessage.user("hi")]))

		self.assertEqual([e.text for e in events if e.kind == "text"], ["Hel", "lo"])
		self.assertEqual(events[-1].usage.total_tokens, 25)
		self.assertEqual(events[-1].stop_reason, "stop")

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_emits_whole_tool_calls(self, mock_post):
		mock_post.return_value = _streamed(
			[
				'{"message":{"tool_calls":[{"function":{"name":"tasks.list",'
				'"arguments":{"overdue":true}}}]},"done":false}',
				'{"message":{"content":""},"done":true}',
			]
		)

		provider = llm.OllamaProvider(model="m", base_url="http://example:11434")
		events = list(provider.stream("sys", [AIMessage.user("hi")], [SEARCH_DEALS]))

		call = next(e for e in events if e.kind == "tool_calls").tool_calls[0]
		self.assertEqual(call.name, "tasks.list")
		self.assertEqual(call.arguments, {"overdue": True})


class TestNonStreamingProviderStillStreams(IntegrationTestCase):
	"""Gemini has no SSE wiring yet. The interface is uniform anyway, and it
	says so rather than pretending text is trickling in."""

	def test_every_adapter_declares_whether_it_streams(self):
		"""Gemini used to say no and fake it by buffering one call. It now uses
		`streamGenerateContent?alt=sse` for real, so it says yes — and the fact
		is read off the capability declaration rather than a separate flag that
		could disagree with it."""
		for adapter in (
			llm.GeminiProvider,
			llm.OpenAICompatibleProvider,
			llm.OllamaProvider,
			llm.AnthropicProvider,
		):
			with self.subTest(adapter=adapter.__name__):
				self.assertEqual(
					adapter.capabilities[Capability.STREAMING], Support.YES
				)

	def test_a_capability_nobody_declared_is_unknown_not_false(self):
		"""The distinction the whole three-valued type exists for. Ollama's
		tool support is genuinely unknown — it depends on the model — and
		reading that as "no" would stop us offering tools to a model that can
		use them."""
		self.assertEqual(
			llm.OllamaProvider.capabilities[Capability.TOOLS], Support.UNKNOWN
		)
		local = llm.OllamaProvider(model="qwen2.5-coder:7b")
		self.assertFalse(
			local.can(Capability.TOOLS), "UNKNOWN must never read as permission"
		)
		self.assertEqual(local.supports(Capability.VISION), Support.UNKNOWN)

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_text_arrives_in_pieces_from_gemini_sse(self, mock_post):
		response = MagicMock()
		response.status_code = 200
		response.encoding = "utf-8"
		response.iter_lines.return_value = iter(
			[
				'data: {"candidates":[{"content":{"parts":[{"text":"All of it "}]}}]}',
				'data: {"candidates":[{"content":{"parts":[{"text":"in pieces."}]}}],'
				'"usageMetadata":{"promptTokenCount":7,"candidatesTokenCount":3}}',
			]
		)
		mock_post.return_value = response

		provider = llm.GeminiProvider(model="m", api_key="k", base_url="https://g.example/v1beta")
		events = list(provider.stream("sys", [AIMessage.user("hi")]))

		self.assertEqual([e.kind for e in events], ["text", "text", "done"])
		self.assertEqual("".join(e.text for e in events if e.text), "All of it in pieces.")
		self.assertEqual(events[-1].usage.output_tokens, 3)

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_a_streamed_tool_call_keeps_its_thought_signature(self, mock_post):
		"""Gemini refuses the *next* request if the signature does not come
		back, so losing it in the streaming path breaks the tool loop only on
		the second round trip — the hardest place to notice."""
		response = MagicMock()
		response.status_code = 200
		response.encoding = "utf-8"
		response.iter_lines.return_value = iter(
			[
				'data: {"candidates":[{"content":{"parts":[{"functionCall":'
				'{"name":"crm.search_deals","args":{"limit":5},"id":"abc"},'
				'"thoughtSignature":"SIG"}]}}]}',
			]
		)
		mock_post.return_value = response

		provider = llm.GeminiProvider(model="m", api_key="k", base_url="https://g.example/v1beta")
		events = list(provider.stream("sys", [AIMessage.user("deals?")]))

		call = next(e for e in events if e.kind == "tool_calls").tool_calls[0]
		self.assertEqual(call.id, "abc")
		self.assertEqual(call.provider_meta["thoughtSignature"], "SIG")


class TestAnthropicStreaming(IntegrationTestCase):
	def test_tool_calls_come_from_the_final_message_not_the_deltas(self):
		"""The SDK reassembles partial tool JSON itself; doing it by hand here
		would reimplement, slightly worse, the part it already gets right."""
		provider = llm.AnthropicProvider(model="claude-opus-5", api_key="k")

		tool_block = MagicMock(type="tool_use", id="toolu_1")
		tool_block.name = "crm.search_deals"
		tool_block.input = {"status": "Open"}
		final = MagicMock(
			content=[tool_block],
			stop_reason="tool_use",
			usage=MagicMock(input_tokens=9, output_tokens=3),
		)

		stream = MagicMock()
		stream.text_stream = iter(["Look", "ing"])
		stream.get_final_message.return_value = final
		stream.__enter__ = lambda self: self
		stream.__exit__ = lambda self, *args: False

		with patch.object(provider, "_client") as client:
			client.return_value.messages.stream.return_value = stream
			events = list(provider.stream("sys", [AIMessage.user("deals?")], [SEARCH_DEALS]))

		self.assertEqual([e.text for e in events if e.kind == "text"], ["Look", "ing"])
		call = next(e for e in events if e.kind == "tool_calls").tool_calls[0]
		self.assertEqual(call.name, "crm.search_deals")
		self.assertEqual(events[-1].usage.total_tokens, 12)
