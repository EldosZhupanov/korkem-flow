"""Contract evaluations use a scripted provider, never pretend to measure an LLM."""

from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.agent.test_loop import _FakeProvider
from korkem_ai.korkem_ai.evaluation import runner
from korkem_ai.korkem_ai.evaluation.internal_cases import INTERNAL_CATALOGUE
from korkem_ai.korkem_ai.orchestrator.protocol import AIResponse, AIToolCall
from korkem_ai.korkem_ai.tools import registry


class TestInternalCases(IntegrationTestCase):
	def test_forty_unique_cases_reference_real_registered_tools(self):
		self.assertEqual(len(INTERNAL_CATALOGUE), 40)
		self.assertEqual(len({case.id for case in INTERNAL_CATALOGUE}), 40)
		for case in INTERNAL_CATALOGUE:
			for name in case.expects:
				with self.subTest(case=case.id, tool=name):
					spec = registry.get(name)
					if case.expected_arguments:
						self.assertEqual(registry.validate_arguments(spec, case.expected_arguments), [])

	def test_all_nine_calculation_contracts_through_real_loop_and_domain(self):
		for case in INTERNAL_CATALOGUE:
			if case.expected_result is None:
				continue
			with self.subTest(case=case.id):
				provider = _FakeProvider(
					AIResponse(
						tool_calls=(
							AIToolCall(id=case.id, name=case.expects[0], arguments=case.expected_arguments),
						)
					),
					AIResponse(text="Результат получен из инструмента."),
				)
				result = runner.run_one(case, provider=provider)
				self.assertTrue(result["passed"], result)
