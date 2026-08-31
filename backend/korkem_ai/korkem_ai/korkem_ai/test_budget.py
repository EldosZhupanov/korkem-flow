# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The budget guard: what it refuses, what it must never refuse, and where.

Two properties matter more than the arithmetic:

* **Off by default.** Every limit ships as zero, and zero means unlimited.
  Turning these on for a running pilot with a guessed number would stop the
  factory mid-shift, so the numbers get set from a week of real usage.
* **Enforced on the server.** The app, Telegram, WhatsApp and `curl` all reach
  the same brain, so a limit honoured by only one of them is not a limit.
"""

from __future__ import annotations

import frappe
from unittest.mock import patch

from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import budget, usage
from korkem_ai.korkem_ai.orchestrator.protocol import AIUsage


class BudgetTestCase(IntegrationTestCase):
	def tearDown(self) -> None:
		frappe.db.rollback()
		frappe.cache().delete_keys(budget.RATE_KEY)

	def _limits(self, **values):
		settings = frappe.get_single("AI Settings")
		for field in (
			"daily_tokens_per_user",
			"daily_cost_per_user",
			"daily_tokens_per_company",
			"daily_cost_per_company",
			"turns_per_minute_per_user",
		):
			setattr(settings, field, values.get(field, 0))
		settings.save(ignore_permissions=True)

	def _spend(self, tokens: int, user: str | None = None):
		usage.record(
			AIUsage(input_tokens=tokens, output_tokens=0),
			provider="Anthropic",
			model="m",
			status="answered",
			user=user,
		)


class TestUnlimitedIsTheDefault(BudgetTestCase):
	def test_zero_means_no_limit(self):
		self._limits()
		self._spend(10_000_000)
		budget.check()  # must not raise

	def test_a_site_that_never_configured_ai_settings_is_not_blocked(self):
		"""A missing settings row must not become an accidental refusal."""
		self._limits()
		budget.check()


class TestTheDailyTokenBudget(BudgetTestCase):
	def test_under_the_limit_passes(self):
		self._limits(daily_tokens_per_user=1000)
		self._spend(999)
		budget.check()

	def test_at_the_limit_refuses(self):
		self._limits(daily_tokens_per_user=1000)
		self._spend(1000)
		with self.assertRaises(budget.BudgetExceeded):
			budget.check()

	def test_the_refusal_says_what_was_used_and_when_it_resets(self):
		self._limits(daily_tokens_per_user=100)
		self._spend(250)

		with self.assertRaises(budget.BudgetExceeded) as caught:
			budget.check()

		message = str(caught.exception)
		self.assertIn("250", message, "the person is told what they have used")
		self.assertIn("100", message, "and what the limit is")
		self.assertIn("полночь", message, "and when they can work again")

	def test_another_users_spending_does_not_refuse_me(self):
		self._limits(daily_tokens_per_user=100)
		self._spend(5000, user="somebody.else@example.com")
		budget.check()


class TestTheCompanyBudget(BudgetTestCase):
	def test_one_users_spending_can_exhaust_the_company(self):
		self._limits(daily_tokens_per_company=100)
		self._spend(500)
		with self.assertRaises(budget.BudgetExceeded) as caught:
			budget.check()
		self.assertIn("компании", str(caught.exception))


class TestTheBurstGuard(BudgetTestCase):
	def test_it_refuses_past_the_per_minute_count(self):
		self._limits(turns_per_minute_per_user=3)
		for _ in range(3):
			budget.check()
		with self.assertRaises(budget.BudgetExceeded) as caught:
			budget.check()
		self.assertIn("минуту", str(caught.exception))

	def test_zero_disables_it(self):
		self._limits(turns_per_minute_per_user=0)
		for _ in range(20):
			budget.check()


class TestTheGuardFailsOpenOnCacheTrouble(BudgetTestCase):
	def test_a_dead_cache_does_not_stop_the_factory(self):
		"""Redis is a convenience here; the database budget is the real ceiling.

		Refusing every turn because a cache is unreachable would turn a minor
		outage into a stopped shift.
		"""
		self._limits(turns_per_minute_per_user=1)

		# One command fails, which is what a flaky cache actually looks like.
		#
		# Two broader versions of this test were wrong before this one. Patching
		# the global `frappe.cache` broke unrelated ERPNext code that reads it as
		# an object; patching `make_key` on the instance then broke
		# `frappe.log_error` inside the guard's own except branch, so the error
		# escaped from the handler rather than from the thing being handled.
		with patch.object(frappe.cache(), "incr", side_effect=RuntimeError("redis is gone")):
			budget.check()  # must not raise
