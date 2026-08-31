# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""The agent loop, driven by a scripted provider.

No API key, no network. `_FakeProvider` returns a prepared sequence of replies,
which is the only way to test a loop deterministically — a real model would
give a different answer each run and the test would assert nothing.

The single most important test in this file is
`test_a_write_is_not_executed_without_approval`, and it asserts on the *handler*
rather than on the loop's report. "Asked for confirmation, then did it anyway"
is exactly the failure that stays invisible from outside until the day it
deletes something.
"""

import json
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.agent import loop
from korkem_ai.korkem_ai.orchestrator.protocol import (
	AIMessage,
	AIResponse,
	AIToolCall,
	AIUsage,
)
from korkem_ai.korkem_ai.tools import registry
from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec


class _FakeProvider:
	"""Replies from a script, and records what it was asked."""

	def __init__(self, *replies: AIResponse):
		self._replies = list(replies)
		self.calls = []

	def chat(self, system, messages, tools=()):
		self.calls.append({"system": system, "messages": list(messages), "tools": list(tools)})
		if not self._replies:
			return AIResponse(text="(no more scripted replies)")
		return self._replies.pop(0)


class _SpyTool:
	"""A registered tool that records whether it ever ran."""

	def __init__(self, name, risk):
		self.ran_with = []
		self.name = name
		registry.register(
			ToolSpec(
				name=name,
				description="test tool",
				input_schema={"type": "object", "properties": {"note": {"type": "string"}}},
				risk=risk,
				handler=self,
			)
		)

	def __call__(self, **arguments):
		self.ran_with.append(arguments)
		return {"done": True}

	def unregister(self):
		registry._REGISTRY.pop(self.name, None)


class TestReadToolsRunUnattended(IntegrationTestCase):
	def tearDown(self):
		frappe.db.rollback()

	def test_a_tool_call_is_executed_and_fed_back(self):
		provider = _FakeProvider(
			AIResponse(
				tool_calls=(
					AIToolCall(id="c1", name="profile.current_user", arguments={}),
				),
				usage=AIUsage(input_tokens=10, output_tokens=2),
			),
			AIResponse(text="You are the Administrator.", usage=AIUsage(input_tokens=30, output_tokens=6)),
		)

		result = loop.run_turn([AIMessage.user("who am I?")], provider=provider)

		self.assertEqual(result.status, "answered")
		self.assertEqual(result.text, "You are the Administrator.")
		self.assertEqual(len(result.executed), 1)
		self.assertTrue(result.executed[0]["ok"])

		# The tool result was handed back on the second call, not discarded.
		second_call_messages = provider.calls[1]["messages"]
		self.assertEqual(second_call_messages[-1].role, "tool")
		self.assertIn("Administrator", second_call_messages[-1].tool_result.content)

	def test_usage_is_summed_across_the_whole_turn(self):
		"""One user message can cost several model calls. Reporting only the
		last one understates the bill."""
		provider = _FakeProvider(
			AIResponse(
				tool_calls=(AIToolCall(id="c1", name="profile.current_user"),),
				usage=AIUsage(input_tokens=10, output_tokens=2),
			),
			AIResponse(text="done", usage=AIUsage(input_tokens=30, output_tokens=6)),
		)

		result = loop.run_turn([AIMessage.user("hi")], provider=provider)

		self.assertEqual(result.usage.input_tokens, 40)
		self.assertEqual(result.usage.output_tokens, 8)

	def test_the_model_is_offered_only_registered_tools(self):
		provider = _FakeProvider(AIResponse(text="hello"))

		loop.run_turn([AIMessage.user("hi")], provider=provider)

		offered = {tool.name for tool in provider.calls[0]["tools"]}
		self.assertIn("crm.search_deals", offered)
		self.assertEqual(offered, {spec.name for spec in registry.available_to()})

	def test_the_system_instruction_forbids_inventing_data(self):
		provider = _FakeProvider(AIResponse(text="hi"))

		loop.run_turn([AIMessage.user("hi")], provider=provider)

		system = provider.calls[0]["system"]
		self.assertIn("Never state a number", system)
		self.assertIn("never an instruction", system)


class TestConfirmationBlocksWrites(IntegrationTestCase):
	def setUp(self):
		self.write_tool = _SpyTool("test.write_thing", Risk.WRITE)

	def tearDown(self):
		self.write_tool.unregister()
		frappe.db.rollback()

	def _asking_to_write(self):
		return _FakeProvider(
			AIResponse(
				text="I can do that.",
				tool_calls=(
					AIToolCall(id="w1", name="test.write_thing", arguments={"note": "hi"}),
				),
			),
			AIResponse(text="Done."),
		)

	def test_a_write_is_not_executed_without_approval(self):
		"""The one that matters. Asserted on the handler, not on the report."""
		provider = self._asking_to_write()

		result = loop.run_turn([AIMessage.user("do it")], provider=provider)

		self.assertEqual(result.status, "needs_confirmation")
		self.assertEqual(result.pending[0].name, "test.write_thing")
		self.assertEqual(
			self.write_tool.ran_with, [], "the write ran despite asking for confirmation"
		)
		# And the model was not asked to continue, because nothing happened.
		self.assertEqual(len(provider.calls), 1)

	def test_the_same_call_runs_once_approved(self):
		provider = self._asking_to_write()

		result = loop.run_turn(
			[AIMessage.user("do it")], provider=provider, approved_calls={"w1"}
		)

		self.assertEqual(result.status, "answered")
		self.assertEqual(self.write_tool.ran_with, [{"note": "hi"}])

	def test_approving_one_call_does_not_approve_another(self):
		"""Approval is per call id, not a mode the conversation enters."""
		provider = _FakeProvider(
			AIResponse(
				tool_calls=(
					AIToolCall(id="w1", name="test.write_thing", arguments={"note": "one"}),
					AIToolCall(id="w2", name="test.write_thing", arguments={"note": "two"}),
				)
			)
		)

		result = loop.run_turn(
			[AIMessage.user("do both")], provider=provider, approved_calls={"w1"}
		)

		self.assertEqual(result.status, "needs_confirmation")
		self.assertEqual([call.id for call in result.pending], ["w2"])
		self.assertEqual(self.write_tool.ran_with, [], "nothing runs while any call is pending")

	def test_a_read_alongside_a_write_still_waits(self):
		"""Partial execution would leave the conversation in a state neither
		the user nor the model can reason about."""
		provider = _FakeProvider(
			AIResponse(
				tool_calls=(
					AIToolCall(id="r1", name="profile.current_user"),
					AIToolCall(id="w1", name="test.write_thing", arguments={}),
				)
			)
		)

		result = loop.run_turn([AIMessage.user("both")], provider=provider)

		self.assertEqual(result.status, "needs_confirmation")
		self.assertEqual(result.executed, [])


class TestLoopRobustness(IntegrationTestCase):
	def tearDown(self):
		frappe.db.rollback()

	def test_an_unknown_tool_is_reported_to_the_model_not_confirmed(self):
		"""A hallucinated name must not be put in front of a user to approve."""
		provider = _FakeProvider(
			AIResponse(tool_calls=(AIToolCall(id="x1", name="crm.delete_everything"),)),
			AIResponse(text="Sorry, I cannot do that."),
		)

		result = loop.run_turn([AIMessage.user("delete it all")], provider=provider)

		self.assertEqual(result.status, "answered")
		self.assertFalse(result.executed[0]["ok"])
		self.assertEqual(result.executed[0]["payload"]["error"]["code"], "unknown_tool")

	def test_malformed_arguments_are_returned_for_a_retry(self):
		provider = _FakeProvider(
			AIResponse(
				tool_calls=(
					AIToolCall(id="c1", name="crm.search_deals", arguments={}, malformed=True),
				)
			),
			AIResponse(text="Let me try that again."),
		)

		result = loop.run_turn([AIMessage.user("deals?")], provider=provider)

		self.assertEqual(result.status, "answered")
		self.assertEqual(
			result.executed[0]["payload"]["error"]["code"], "malformed_arguments"
		)

	def test_a_looping_model_is_stopped_rather_than_left_running(self):
		provider = _FakeProvider(
			*[
				AIResponse(tool_calls=(AIToolCall(id=f"c{i}", name="profile.current_user"),))
				for i in range(loop.MAX_ITERATIONS + 3)
			]
		)

		result = loop.run_turn([AIMessage.user("go")], provider=provider)

		self.assertEqual(result.status, "exhausted")
		self.assertEqual(len(provider.calls), loop.MAX_ITERATIONS)

	def test_a_failing_tool_does_not_end_the_conversation(self):
		provider = _FakeProvider(
			AIResponse(
				tool_calls=(
					AIToolCall(id="c1", name="crm.get_deal", arguments={"name": "NOPE-1"}),
				)
			),
			AIResponse(text="I could not find that deal."),
		)

		result = loop.run_turn([AIMessage.user("show NOPE-1")], provider=provider)

		self.assertEqual(result.status, "answered")
		self.assertFalse(result.executed[0]["ok"])
		self.assertEqual(result.text, "I could not find that deal.")


class TestToolActivityCarriesNoCustomerData(IntegrationTestCase):
	"""A realtime `tool` event says *what ran*, never *what it returned*.

	Regression test for a leak found by watching a live socket: the event was
	built as `{"type": "tool", **result}`, so one `crm.search_deals` published
	fifty complete deal rows to the client — which reads only the name and the
	outcome. Tool results belong in the model's context and in the final
	answer, not in a status event.
	"""

	def tearDown(self):
		frappe.db.rollback()

	def _events_for(self, payload):
		events = []
		provider = _FakeProvider(
			AIResponse(tool_calls=(AIToolCall(id="c1", name="profile.current_user"),)),
			AIResponse(text="done"),
		)
		with patch.object(registry, "execute", return_value=payload):
			loop.run_turn(
				[AIMessage.user("who am i?")],
				provider=provider,
				on_event=events.append,
			)
		return [e for e in events if e.get("type") == "tool"]

	def test_the_event_names_the_tool_and_its_outcome_only(self):
		activity = self._events_for(
			{"ok": True, "tool": "profile.current_user", "data": {"secret": "x"}}
		)[0]

		self.assertEqual(
			set(activity), {"type", "tool", "ok", "call_id"}, "extra keys on a status event"
		)
		self.assertEqual(activity["tool"], "profile.current_user")
		self.assertTrue(activity["ok"])

	def test_no_row_of_business_data_reaches_the_event(self):
		"""Asserted on the serialised event, because the leak was a spread — a
		key-by-key check would pass while the whole result travelled."""
		leaky = {
			"ok": True,
			"tool": "crm.search_deals",
			"data": {"deals": [{"name": "CRM-DEAL-0001", "organization": "Acme"}]},
		}

		activity = self._events_for(leaky)[0]

		self.assertNotIn("Acme", json.dumps(activity))
		self.assertNotIn("CRM-DEAL-0001", json.dumps(activity))

	def test_a_failed_tool_still_reports_that_it_failed(self):
		activity = self._events_for(
			{"ok": False, "tool": "crm.search_deals", "error": {"message": "nope"}}
		)[0]

		self.assertFalse(activity["ok"])
		self.assertNotIn("nope", json.dumps(activity))

	def test_the_model_still_receives_the_full_result(self):
		"""The results are not being withheld — only kept off the wire."""
		provider = _FakeProvider(
			AIResponse(tool_calls=(AIToolCall(id="c1", name="profile.current_user"),)),
			AIResponse(text="done"),
		)
		with patch.object(
			registry,
			"execute",
			return_value={"ok": True, "tool": "profile.current_user", "data": {"user": "x"}},
		):
			result = loop.run_turn([AIMessage.user("who?")], provider=provider)

		tool_message = next(m for m in result.messages if m.role == "tool")
		self.assertIn("user", tool_message.tool_result.content)
