# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Which instruction is in force, and why a customer needs a different one.

The staff instruction tells the model to say "I found none of yours, or you may
not be allowed to see it". That is the right thing to say to a foreman and the
wrong thing to say to a customer: it turns an absence into a hint that the thing
exists. The wording is not the boundary — the boundary is the pinned scope and
ERPNext's permissions — but a boundary that announces itself has already given
away what it was protecting.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.agent import prompt
from korkem_ai.korkem_ai.tools import policy

PLANNER = "korkem.planner@example.com"


class TestTheInstructionMatchesTheRole(IntegrationTestCase):
	def test_staff_get_the_staff_instruction(self):
		built = prompt.build(role=policy.EMPLOYEE)

		self.assertIn("member of factory staff", built)

	def test_no_role_at_all_is_still_the_staff_instruction(self):
		"""Every caller before this phase passed no role. None of them changed."""
		self.assertEqual(prompt.build(), prompt.SYSTEM_INSTRUCTION)

	def test_a_customer_is_not_told_they_work_at_the_factory(self):
		built = prompt.build(role=policy.CUSTOMER)

		self.assertIn("customer of the factory", built)
		self.assertNotIn("member of factory staff", built)

	def test_a_customer_is_never_told_to_blame_permissions(self):
		"""The one sentence this instruction exists for."""
		built = prompt.build(role=policy.CUSTOMER)

		self.assertIn("do not say it belongs to somebody else", built)
		self.assertNotIn("are not allowed to see it", built)

	def test_the_session_context_is_added_either_way(self):
		for role in (policy.EMPLOYEE, policy.CUSTOMER):
			built = prompt.build(role=role, user_full_name="Клиент", today="2026-08-11")

			self.assertIn("Клиент", built)
			self.assertIn("2026-08-11", built)


class TestTheRoleComesFromTheDatabase(IntegrationTestCase):
	"""Not from the message, not from an argument the model produced."""

	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self.addCleanup(frappe.set_user, "Administrator")

	def test_the_planner_is_staff(self):
		frappe.set_user(PLANNER)

		self.assertNotEqual(policy.role_of(), policy.CUSTOMER)

	def test_somebody_with_no_factory_role_is_a_customer(self):
		email = "korkem.promptcheck@example.com"
		if not frappe.db.exists("User", email):
			doc = frappe.new_doc("User")
			doc.update({"email": email, "first_name": "Гость", "send_welcome_email": 0})
			doc.insert(ignore_permissions=True)
		self.addCleanup(frappe.delete_doc, "User", email, force=True, ignore_permissions=True)

		self.assertEqual(policy.role_of(email), policy.CUSTOMER)


class TestWhatKorkemRemembersReachesTheModel(IntegrationTestCase):
	"""Память попадает в инструкцию, а не в разговор.

	Память — не реплика собеседника, а условие, в котором он работает. «ЛДСП
	считаем в квадратных метрах» верно до вопроса и после него; вставленное в
	историю как чьи-то слова, оно однажды будет процитировано обратно человеку
	как его собственная фраза.
	"""

	def setUp(self):
		from korkem_ai.korkem_ai import memory

		frappe.db.delete(memory.DOCTYPE)

	def tearDown(self):
		from korkem_ai.korkem_ai import memory

		frappe.db.delete(memory.DOCTYPE)

	def test_a_company_fact_is_in_the_instruction(self):
		from korkem_ai.korkem_ai import memory

		memory.remember(
			scope=memory.COMPANY, category="terminology", subject="ЛДСП",
			predicate="единица измерения", value="квадратные метры",
		)

		text = prompt.build(user_full_name="Владелец", today="2026-09-04")

		self.assertIn("квадратные метры", text)

	def test_an_inferred_fact_is_marked_as_inferred(self):
		"""Модель должна отличать «сказали» от «мы предположили».

		На первом можно строить ответ, на втором — уточняющий вопрос.
		"""
		from korkem_ai.korkem_ai import memory

		memory.remember(
			scope=memory.COMPANY, category="process", subject="раскрой",
			predicate="порядок", value="сначала длинные детали",
			source_type="inferred",
		)

		text = prompt.build(user_full_name="Владелец", today="2026-09-04")

		self.assertIn("inferred, not confirmed", text)

	def test_the_model_is_told_this_is_not_current_business_state(self):
		"""Иначе модель назовёт остаток по памяти вместо того, чтобы спросить."""
		from korkem_ai.korkem_ai import memory

		memory.remember(
			scope=memory.COMPANY, category="rule", subject="кромка",
			predicate="единица", value="метры",
		)

		text = prompt.build(user_full_name="Владелец", today="2026-09-04")

		self.assertIn("must be looked up with a tool", text)

	def test_an_empty_memory_adds_nothing(self):
		"""Пустой раздел «что я помню» — это токены за молчание."""
		text = prompt.build(user_full_name="Владелец", today="2026-09-04")

		self.assertNotIn("What KORKEM remembers", text)

	def test_a_broken_memory_never_breaks_the_turn(self):
		"""Память, уронившая ход, хуже отсутствующей памяти."""
		from unittest.mock import patch

		from korkem_ai.korkem_ai import memory

		with patch.object(memory, "recall", side_effect=RuntimeError("база упала")):
			text = prompt.build(user_full_name="Владелец", today="2026-09-04")

		self.assertIn("Владелец", text)
