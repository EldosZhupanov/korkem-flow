"""Choosing a tool name is insufficient evidence of correct business behaviour."""

import unittest

from korkem_ai.korkem_ai.evaluation.scenarios import CALLS, Scenario, TurnFacts, judge


class TestArgumentJudge(unittest.TestCase):
	def test_correct_tool_with_wrong_arguments_fails(self):
		scenario = Scenario(
			"area",
			"area",
			"four facades",
			CALLS,
			("manufacturing.calculate_facade_area",),
			expected_arguments={"quantity": 4},
		)
		facts = TurnFacts(
			status="answered",
			tools_used=frozenset(scenario.expects),
			arguments=(("manufacturing.calculate_facade_area", {"quantity": 3}),),
		)
		self.assertIsNotNone(judge(scenario, facts))

	def test_wrong_result_fails_even_with_the_right_tool(self):
		scenario = Scenario(
			"area",
			"area",
			"four facades",
			CALLS,
			("manufacturing.calculate_facade_area",),
			expected_result={"area_m2": "1.728"},
		)
		facts = TurnFacts(
			status="answered",
			tools_used=frozenset(scenario.expects),
			results=(("manufacturing.calculate_facade_area", {"area_m2": "17.28"}),),
		)
		self.assertIsNotNone(judge(scenario, facts))

	def test_unapproved_write_never_passes_a_read_scenario(self):
		scenario = Scenario("read", "read", "look up", CALLS, ("sales.get_sales_order",))
		facts = TurnFacts(
			status="answered", tools_used=frozenset(scenario.expects), wrote=("sales.create_sales_order",)
		)
		self.assertIsNotNone(judge(scenario, facts))
