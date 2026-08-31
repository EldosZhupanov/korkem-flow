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
