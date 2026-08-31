# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Usage accounting, and the promise that it cannot break anything.

The tests that matter most here are not the ones checking that a row is
written. They are the ones checking what happens when it *cannot* be written:
accounting is analytics, and analytics must never cost a production order.
"""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import usage
from korkem_ai.korkem_ai.orchestrator.protocol import AIUsage


class UsageTestCase(IntegrationTestCase):
	def tearDown(self) -> None:
		frappe.db.rollback()

	def _rows(self, **filters):
		return frappe.get_all(
			usage.DOCTYPE,
			filters=filters,
			fields=[
				"name",
				"user",
				"status",
				"provider",
				"model",
				"turn_id",
				"channel",
				"tokens_reported",
				"input_tokens",
				"output_tokens",
				"total_tokens",
				"cost_basis",
				"estimated_cost",
			],
		)


class TestATurnLeavesARecord(UsageTestCase):
	def test_a_reported_turn_is_written_with_its_counts(self):
		name = usage.record(
			AIUsage(input_tokens=1200, output_tokens=340),
			provider="Anthropic",
			model="claude-opus-5",
			status="answered",
			turn_id="turn-abc",
		)

		self.assertIsNotNone(name)
		row = self._rows(name=name)[0]
		self.assertEqual(row.user, frappe.session.user)
		self.assertEqual(row.status, "answered")
		self.assertEqual(row.provider, "Anthropic")
		self.assertEqual(row.model, "claude-opus-5")
		self.assertEqual(row.turn_id, "turn-abc")
		self.assertEqual(row.input_tokens, 1200)
		self.assertEqual(row.output_tokens, 340)
		self.assertEqual(row.total_tokens, 1540)
		self.assertEqual(row.tokens_reported, 1)

	def test_a_turn_that_failed_is_still_a_turn(self):
		"""It reached the provider, so it may still be billed."""
		name = usage.record(
			None, provider="OpenAI", model="gpt-5", status="failed", turn_id="turn-dead"
		)

		row = self._rows(name=name)[0]
		self.assertEqual(row.status, "failed")
		self.assertEqual(row.total_tokens, 0)
		self.assertEqual(row.tokens_reported, 0, "no counts were reported, and the row says so")

	def test_an_unreported_zero_is_not_a_claim_that_it_was_free(self):
		"""The distinction AIUsage keeps with None has to survive the database.

		A budget that treats an unreported turn as costing nothing can be
		exhausted for nothing.
		"""
		reported = usage.record(
			AIUsage(input_tokens=0, output_tokens=0),
			provider="Ollama",
			model="local",
			status="answered",
		)
		silent = usage.record(
			AIUsage(), provider="Ollama", model="local", status="answered"
		)

		self.assertEqual(self._rows(name=reported)[0].tokens_reported, 1)
		self.assertEqual(self._rows(name=silent)[0].tokens_reported, 0)

	def test_a_channel_turn_records_its_channel(self):
		name = usage.record(
			AIUsage(input_tokens=10, output_tokens=5),
			provider="Anthropic",
			model="m",
			status="answered",
			channel="Telegram",
		)
		self.assertEqual(self._rows(name=name)[0].channel, "Telegram")

	def test_an_unknown_channel_does_not_lose_the_row(self):
		"""A Select that rejects the value would throw, and the row would vanish.

		Counting the spend matters more than knowing precisely where it came
		from, so an unrecognised channel is recorded as App rather than dropped.
		"""
		name = usage.record(
			AIUsage(input_tokens=1, output_tokens=1),
			provider="Anthropic",
			model="m",
			status="answered",
			channel="Carrier Pigeon",
		)
		self.assertIsNotNone(name)
		self.assertEqual(self._rows(name=name)[0].channel, "App")


class TestAccountingCannotBreakTheWork(UsageTestCase):
	"""The whole point of the savepoint.

	A dropped usage row costs a line in a report. A poisoned transaction costs
	a production order.
	"""

	def test_a_failure_returns_none_instead_of_raising(self):
		with patch.object(usage, "_insert", side_effect=RuntimeError("disk on fire")):
			self.assertIsNone(
				usage.record(AIUsage(input_tokens=1), provider="X", model="Y", status="answered")
			)

	def test_a_failure_leaves_earlier_writes_intact(self):
		"""The transaction survives, and so does what the turn already did."""
		todo = frappe.get_doc({"doctype": "ToDo", "description": "a real business write"}).insert()

		with patch.object(usage, "_insert", side_effect=RuntimeError("disk on fire")):
			usage.record(AIUsage(input_tokens=1), provider="X", model="Y", status="answered")

		# Still there, still readable, and the connection still works.
		self.assertTrue(frappe.db.exists("ToDo", todo.name))
		self.assertEqual(
			frappe.db.get_value("ToDo", todo.name, "description"), "a real business write"
		)
		frappe.get_doc({"doctype": "ToDo", "description": "written after the failure"}).insert()

	def test_a_failure_is_logged_rather_than_swallowed_silently(self):
		with patch.object(usage, "_insert", side_effect=RuntimeError("disk on fire")):
			with patch.object(frappe, "log_error") as logged:
				usage.record(AIUsage(input_tokens=1), provider="X", model="Y", status="answered")

		self.assertTrue(logged.called, "an accounting failure nobody can see is not acceptable")


class TestCostIsHonestAboutBeingAnEstimate(UsageTestCase):
	def test_without_a_rate_the_cost_is_not_priced(self):
		name = usage.record(
			AIUsage(input_tokens=1_000_000, output_tokens=1_000_000),
			provider="Anthropic",
			model="m",
			status="answered",
		)
		row = self._rows(name=name)[0]
		self.assertEqual(row.cost_basis, "not priced")
		self.assertEqual(row.estimated_cost, 0)

	def test_with_a_rate_the_cost_is_multiplied_out(self):
		provider = frappe.get_doc(
			{
				"doctype": "AI Provider",
				"provider": "Anthropic",
				"model": "priced-model",
				"input_rate_per_1k": 3.0,
				"output_rate_per_1k": 15.0,
				"rate_currency": "KZT",
			}
		).insert(ignore_permissions=True)

		name = usage.record(
			AIUsage(input_tokens=2000, output_tokens=1000),
			provider=provider.name,
			model="priced-model",
			status="answered",
		)

		row = self._rows(name=name)[0]
		self.assertEqual(row.cost_basis, "provider rate")
		# 2 * 3.0 + 1 * 15.0
		self.assertAlmostEqual(row.estimated_cost, 21.0, places=6)


class TestSpentToday(UsageTestCase):
	def test_it_sums_this_users_turns_only(self):
		before = usage.spent_today()["tokens"]

		usage.record(
			AIUsage(input_tokens=100, output_tokens=50),
			provider="A",
			model="m",
			status="answered",
		)
		usage.record(
			AIUsage(input_tokens=10, output_tokens=5), provider="A", model="m", status="answered"
		)
		usage.record(
			AIUsage(input_tokens=999_999, output_tokens=0),
			provider="A",
			model="m",
			status="answered",
			user="somebody.else@example.com",
		)

		self.assertEqual(usage.spent_today()["tokens"], before + 165)

	def test_an_unreported_turn_still_counts_as_a_turn(self):
		before = usage.spent_today()["turns"]
		usage.record(None, provider="A", model="m", status="failed")
		self.assertEqual(usage.spent_today()["turns"], before + 1)


class TestDescribingATurnCannotBreakIt(UsageTestCase):
	"""The regression that cost fourteen channel tests.

	`record()` is protected inside its own body, but the first wiring built its
	arguments at the call site — `result.usage`, `llm.get_settings().provider` —
	where nothing protects them. A turn stub without a `usage` attribute raised
	an `AttributeError` that the gateway caught as a failed turn, so proposals
	stopped being written and a working assistant reported that it could not
	answer.

	`record_turn` reads everything uncertain inside the guard. These tests hold
	that boundary.
	"""

	def test_a_result_without_usage_is_recorded_rather_than_raising(self):
		class TurnStub:
			status = "answered"

		name = usage.record_turn(TurnStub(), provider="A", model="m")

		self.assertIsNotNone(name, "a turn with no usage attribute is still a turn")
		self.assertEqual(self._rows(name=name)[0].tokens_reported, 0)

	def test_a_result_missing_everything_still_does_not_raise(self):
		self.assertIsNotNone(usage.record_turn(object(), provider="A", model="m"))

	def test_it_takes_the_status_from_the_result(self):
		class TurnStub:
			status = "needs_confirmation"
			usage = AIUsage(input_tokens=5, output_tokens=5)

		name = usage.record_turn(TurnStub(), provider="A", model="m")
		row = self._rows(name=name)[0]
		self.assertEqual(row.status, "needs_confirmation")
		self.assertEqual(row.total_tokens, 10)

	def test_an_explicit_provider_beats_the_configured_default(self):
		class TurnStub:
			status = "answered"
			usage = AIUsage(input_tokens=1, output_tokens=1)

		name = usage.record_turn(TurnStub(), provider="Chosen By Caller", model="m")
		self.assertEqual(self._rows(name=name)[0].provider, "Chosen By Caller")

	def test_the_model_comes_from_the_adapter_when_the_caller_named_none(self):
		class TurnStub:
			status = "answered"
			usage = AIUsage(input_tokens=1, output_tokens=1)

		class Adapter:
			model = "model-from-adapter"

		name = usage.record_turn(TurnStub(), adapter=Adapter(), provider="A")
		self.assertEqual(self._rows(name=name)[0].model, "model-from-adapter")
