# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Tool calling across the four wire protocols.

Every provider is mocked at the HTTP or SDK boundary. These tests are about
*translation* — what we put on the wire and what we make of what comes back —
because that is where "they all speak OpenAI now" costs you. Nothing here
proves a live model works; that needs a key and is recorded as unverified.

The three translations worth staring at, all of which are the kind of thing
that half-works and then corrupts a conversation:

* Anthropic and Gemini have **no tool role**. A result goes back as a *user*
  turn carrying a special block.
* OpenAI sends tool arguments as a **JSON string**; the other three send an
  object.
* Gemini issues **no call id** and matches a result to its call by *name*.
"""

import json
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.orchestrator import llm
from korkem_ai.korkem_ai.orchestrator.protocol import (
	AIMessage,
	AITool,
	AIToolCall,
	AIToolResult,
	parse_arguments,
)

SEARCH_DEALS = AITool(
	name="crm.search_deals",
	description="Find deals",
	input_schema={"type": "object", "properties": {"status": {"type": "string"}}},
)


def _http(payload, status=200):
	response = MagicMock()
	response.status_code = status
	response.text = "error body"
	response.json.return_value = payload
	return response


class TestArgumentParsing(IntegrationTestCase):
	def test_object_passes_through(self):
		self.assertEqual(parse_arguments({"a": 1}), ({"a": 1}, False))

	def test_json_string_is_decoded(self):
		self.assertEqual(parse_arguments('{"a": 1}'), ({"a": 1}, False))

	def test_missing_arguments_are_empty_not_malformed(self):
		"""A tool with no required input is called with nothing, legitimately."""
		self.assertEqual(parse_arguments(None), ({}, False))
		self.assertEqual(parse_arguments(""), ({}, False))

	def test_broken_json_is_flagged_rather_than_raised(self):
		"""The right answer is to tell the model its call was malformed, not to
		lose the whole conversation over a bad fragment."""
		arguments, malformed = parse_arguments('{"a": ')
		self.assertEqual(arguments, {})
		self.assertTrue(malformed)

	def test_a_json_scalar_is_not_arguments(self):
		self.assertEqual(parse_arguments("42"), ({}, True))


class TestOpenAICompatibleToolCalling(IntegrationTestCase):
	def _provider(self):
		return llm.OpenAICompatibleProvider(
			model="gpt-5", api_key="k", base_url="https://api.example/v1"
		)

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_offers_tools_as_function_declarations(self, mock_post):
		mock_post.return_value = _http({"choices": [{"message": {"content": "hi"}}]})

		self._provider().chat("sys", [AIMessage.user("hello")], tools=[SEARCH_DEALS])

		_, kwargs = mock_post.call_args
		tool = kwargs["json"]["tools"][0]
		self.assertEqual(tool["type"], "function")
		self.assertEqual(tool["function"]["name"], "crm.search_deals")
		self.assertEqual(tool["function"]["parameters"], SEARCH_DEALS.input_schema)

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_reads_a_tool_call_whose_arguments_are_a_string(self, mock_post):
		mock_post.return_value = _http(
			{
				"choices": [
					{
						"finish_reason": "tool_calls",
						"message": {
							"content": None,
							"tool_calls": [
								{
									"id": "call_1",
									"function": {
										"name": "crm.search_deals",
										"arguments": '{"status": "Open"}',
									},
								}
							],
						},
					}
				],
				"usage": {"prompt_tokens": 11, "completion_tokens": 4},
			}
		)

		response = self._provider().chat("sys", [AIMessage.user("deals?")])

		self.assertTrue(response.wants_tools)
		call = response.tool_calls[0]
		self.assertEqual(call.id, "call_1")
		self.assertEqual(call.arguments, {"status": "Open"})
		self.assertFalse(call.malformed)
		self.assertEqual(response.usage.total_tokens, 15)

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_sends_a_result_back_on_the_tool_role(self, mock_post):
		mock_post.return_value = _http({"choices": [{"message": {"content": "12 deals"}}]})

		self._provider().chat(
			"sys",
			[
				AIMessage.user("deals?"),
				AIMessage.assistant(
					tool_calls=(AIToolCall(id="call_1", name="crm.search_deals"),)
				),
				AIMessage.tool(
					AIToolResult(call_id="call_1", name="crm.search_deals", content='{"n": 12}')
				),
			],
			tools=[SEARCH_DEALS],
		)

		_, kwargs = mock_post.call_args
		sent = kwargs["json"]["messages"]
		self.assertEqual(sent[0]["role"], "system")
		# The assistant turn must carry the call, or the provider rejects the
		# result that follows it as unsolicited.
		self.assertEqual(sent[2]["tool_calls"][0]["id"], "call_1")
		self.assertEqual(json.loads(sent[2]["tool_calls"][0]["function"]["arguments"]), {})
		self.assertEqual(sent[3]["role"], "tool")
		self.assertEqual(sent[3]["tool_call_id"], "call_1")


class TestAnthropicToolCalling(IntegrationTestCase):
	def test_a_result_goes_back_as_a_user_turn_of_tool_result(self):
		"""Anthropic has no tool role. Getting this wrong is a 400 at best and a
		silently ignored result at worst."""
		encoded = llm.AnthropicProvider._encode(
			AIMessage.tool(
				AIToolResult(call_id="toolu_1", name="crm.search_deals", content='{"n": 12}')
			)
		)

		self.assertEqual(encoded["role"], "user")
		block = encoded["content"][0]
		self.assertEqual(block["type"], "tool_result")
		self.assertEqual(block["tool_use_id"], "toolu_1")
		self.assertFalse(block["is_error"])

	def test_an_assistant_turn_carries_tool_use_blocks(self):
		encoded = llm.AnthropicProvider._encode(
			AIMessage.assistant(
				text="Let me look",
				tool_calls=(
					AIToolCall(id="toolu_1", name="crm.search_deals", arguments={"status": "Open"}),
				),
			)
		)

		self.assertEqual(encoded["role"], "assistant")
		self.assertEqual(encoded["content"][0]["type"], "text")
		self.assertEqual(encoded["content"][1]["type"], "tool_use")
		# An object, not a string — the opposite of OpenAI.
		self.assertEqual(encoded["content"][1]["input"], {"status": "Open"})

	def test_reads_text_and_tool_use_from_one_reply(self):
		provider = llm.AnthropicProvider(model="claude-opus-5", api_key="k")

		text_block = MagicMock(type="text")
		text_block.text = "Looking now."
		tool_block = MagicMock(type="tool_use", id="toolu_1")
		# Assigned after construction: `MagicMock(name=...)` names the mock
		# itself rather than setting a `.name` attribute on it.
		tool_block.name = "crm.search_deals"
		tool_block.input = {"status": "Open"}
		sdk_response = MagicMock(
			stop_reason="tool_use",
			content=[text_block, tool_block],
			usage=MagicMock(input_tokens=9, output_tokens=3),
		)

		with patch.object(provider, "_client") as client:
			client.return_value.messages.create.return_value = sdk_response
			response = provider.chat("sys", [AIMessage.user("deals?")], tools=[SEARCH_DEALS])

		self.assertEqual(response.text, "Looking now.")
		self.assertEqual(response.tool_calls[0].name, "crm.search_deals")
		self.assertEqual(response.usage.total_tokens, 12)

	def test_a_refusal_is_surfaced_not_returned_as_an_empty_answer(self):
		provider = llm.AnthropicProvider(model="claude-opus-5", api_key="k")
		sdk_response = MagicMock(stop_reason="refusal", content=[])

		with patch.object(provider, "_client") as client:
			client.return_value.messages.create.return_value = sdk_response
			with self.assertRaises(frappe.ValidationError):
				provider.chat("sys", [AIMessage.user("x")])


class TestGeminiToolCalling(IntegrationTestCase):
	def _provider(self):
		return llm.GeminiProvider(
			model="gemini-2.5-pro", api_key="k", base_url="https://g.example/v1beta"
		)

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_tool_schemas_are_pruned_for_geminis_dialect(self, mock_post):
		mock_post.return_value = _http({"candidates": [{"content": {"parts": [{"text": "hi"}]}}]})
		strict_tool = AITool(
			name="t",
			description="d",
			input_schema={"type": "object", "additionalProperties": False},
		)

		self._provider().chat("sys", [AIMessage.user("hi")], tools=[strict_tool])

		_, kwargs = mock_post.call_args
		declared = kwargs["json"]["tools"][0]["functionDeclarations"][0]
		self.assertNotIn("additionalProperties", declared["parameters"])

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_synthesises_a_call_id_because_gemini_issues_none(self, mock_post):
		mock_post.return_value = _http(
			{
				"candidates": [
					{
						"content": {
							"parts": [
								{
									"functionCall": {
										"name": "crm.search_deals",
										"args": {"status": "Open"},
									}
								}
							]
						}
					}
				]
			}
		)

		response = self._provider().chat("sys", [AIMessage.user("deals?")])

		call = response.tool_calls[0]
		self.assertTrue(call.id)
		self.assertEqual(call.name, "crm.search_deals")
		self.assertEqual(call.arguments, {"status": "Open"})

	def test_a_result_goes_back_by_name_on_a_user_turn(self):
		encoded = llm.GeminiProvider._encode(
			AIMessage.tool(
				AIToolResult(call_id="ignored", name="crm.search_deals", content='{"n": 12}')
			)
		)

		self.assertEqual(encoded["role"], "user")
		# Matched by name, which is why the id we invent never leaves the app.
		self.assertEqual(encoded["parts"][0]["functionResponse"]["name"], "crm.search_deals")

	def test_the_assistant_is_called_model(self):
		self.assertEqual(llm.GeminiProvider._encode(AIMessage.assistant("hi"))["role"], "model")


class TestOllamaToolCalling(IntegrationTestCase):
	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_reads_object_arguments_and_reports_usage(self, mock_post):
		mock_post.return_value = _http(
			{
				"message": {
					"content": "",
					"tool_calls": [
						{
							"function": {
								"name": "crm.search_deals",
								"arguments": {"status": "Open"},
							}
						}
					],
				},
				"prompt_eval_count": 20,
				"eval_count": 5,
				"done_reason": "stop",
			}
		)

		provider = llm.OllamaProvider(model="qwen2.5-coder:7b", base_url="http://example:11434")
		response = provider.chat("sys", [AIMessage.user("deals?")], tools=[SEARCH_DEALS])

		call = response.tool_calls[0]
		self.assertEqual(call.arguments, {"status": "Open"})
		self.assertFalse(call.malformed)
		self.assertEqual(response.usage.total_tokens, 25)
		self.assertIsNone(response.text)


class TestNoToolsMeansNoToolField(IntegrationTestCase):
	"""A model offered no tools cannot ask for one. Sending an empty list is a
	400 on some providers, so the key is omitted entirely."""

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_openai_omits_the_key(self, mock_post):
		mock_post.return_value = _http({"choices": [{"message": {"content": "hi"}}]})

		llm.OpenAICompatibleProvider(
			model="m", api_key="k", base_url="https://api.example/v1"
		).chat("sys", [AIMessage.user("hi")])

		_, kwargs = mock_post.call_args
		self.assertNotIn("tools", kwargs["json"])

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_ollama_omits_the_key(self, mock_post):
		mock_post.return_value = _http({"message": {"content": "hi"}})

		llm.OllamaProvider(model="m", base_url="http://example:11434").chat(
			"sys", [AIMessage.user("hi")]
		)

		_, kwargs = mock_post.call_args
		self.assertNotIn("tools", kwargs["json"])
