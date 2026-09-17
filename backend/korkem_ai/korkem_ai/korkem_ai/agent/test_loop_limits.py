"""Bounds apply to actual tools, not only provider round trips."""

from unittest.mock import patch

from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.agent import loop
from korkem_ai.korkem_ai.agent.test_loop import _FakeProvider
from korkem_ai.korkem_ai.orchestrator.protocol import AIMessage, AIResponse, AIToolCall


class TestExecutionLimits(IntegrationTestCase):
	def test_a_single_provider_response_cannot_execute_unbounded_calls(self):
		provider = _FakeProvider(
			AIResponse(
				tool_calls=tuple(AIToolCall(id=str(i), name="profile.current_user") for i in range(100))
			)
		)
		with patch.object(loop, "_run") as execute:
			result = loop.run_turn([AIMessage.user("hi")], provider=provider)
		self.assertEqual(result.status, "exhausted")
		execute.assert_not_called()

	def test_cancel_before_provider_call(self):
		provider = _FakeProvider(AIResponse(text="not reached"))
		result = loop.run_turn([AIMessage.user("hi")], provider=provider, should_cancel=lambda: True)
		self.assertEqual(result.status, "cancelled")
		self.assertEqual(provider.calls, [])

	def test_repeated_calls_stop_even_with_new_provider_call_ids(self):
		provider = _FakeProvider(
			*(AIResponse(tool_calls=(AIToolCall(id=str(i), name="profile.current_user"),)) for i in range(5))
		)
		result = loop.run_turn([AIMessage.user("hi")], provider=provider)
		self.assertEqual(result.status, "exhausted")
		self.assertLessEqual(len(result.executed), 3)
