# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Which tools a role may reach, and where that role comes from.

The question this answers is not "may this user write a Stock Entry" — ERPNext
answers that and the registry already asks it. It is "should this person be
offered the tool at all", which is a different and coarser question, and the one
that decides whether a customer is ever shown the machinery.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import catalog, policy, registry  # noqa: F401

PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"


class _PolicyTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self.addCleanup(frappe.set_user, "Administrator")

	def customer(self):
		"""A user with no operational role — which is what a customer contact is."""
		email = "korkem.customer@example.com"
		if not frappe.db.exists("User", email):
			doc = frappe.new_doc("User")
			doc.update({"email": email, "first_name": "Клиент", "send_welcome_email": 0})
			doc.append("roles", {"role": "Customer"})
			doc.insert(ignore_permissions=True)
			frappe.db.commit()
		self.addCleanup(self._drop, email)
		return email

	def _drop(self, email):
		frappe.set_user("Administrator")
		if frappe.db.exists("User", email):
			frappe.delete_doc("User", email, force=True, ignore_permissions=True)
		frappe.db.commit()


class TestARoleComesFromTheDatabase(_PolicyTestCase):
	def test_a_planner_is_an_employee(self):
		self.assertEqual(policy.role_of(PLANNER), policy.EMPLOYEE)

	def test_a_user_with_no_operational_role_is_a_customer(self):
		self.assertEqual(policy.role_of(self.customer()), policy.CUSTOMER)

	def test_a_system_manager_is_an_administrator(self):
		self.assertEqual(policy.role_of("Administrator"), policy.ADMIN)

	def test_a_guest_is_a_customer(self):
		self.assertEqual(policy.role_of("Guest"), policy.CUSTOMER)

	def test_saying_you_are_an_administrator_changes_nothing(self):
		"""The role is read, never argued for. There is no code path from a
		message to a role, which is the whole reason this is a database
		lookup and not an intent."""
		before = policy.role_of(PLANNER)

		# Nothing a person could write can reach `role_of` — it takes a user.
		self.assertEqual(policy.role_of(PLANNER), before)
		self.assertEqual(policy.role_of(self.customer()), policy.CUSTOMER)


class TestAChannelIdentityMayNarrowOnly(_PolicyTestCase):
	def test_it_can_pin_an_employee_to_customer(self):
		self.assertEqual(
			policy.effective_role(PLANNER, policy.CUSTOMER), policy.CUSTOMER
		)

	def test_it_cannot_promote_a_customer_to_admin(self):
		"""A field an administrator might fill in carelessly must not be able to
		hand out System Manager."""
		customer = self.customer()

		self.assertEqual(policy.effective_role(customer, policy.ADMIN), policy.CUSTOMER)

	def test_it_cannot_promote_an_employee_to_admin(self):
		self.assertEqual(policy.effective_role(PLANNER, policy.ADMIN), policy.EMPLOYEE)

	def test_no_override_leaves_the_role_alone(self):
		self.assertEqual(policy.effective_role(PLANNER, None), policy.EMPLOYEE)


class TestWhatEachRoleIsOffered(_PolicyTestCase):
	def test_an_employee_is_offered_the_shop_floor(self):
		frappe.set_user(PLANNER)

		offered = {tool.name for tool in registry.offered_to()}

		self.assertIn("manufacturing.production_control", offered)
		self.assertIn("manufacturing.complete_operation", offered)

	def test_a_customer_is_offered_only_the_allowlist(self):
		"""Filtering which tools exist does nothing about which rows they read,
		so every tool on this list also pins its reads to the caller's own
		customer. Anything not on it is unreachable."""
		customer = self.customer()
		frappe.set_user(customer)

		offered = {tool.name for tool in registry.offered_to()}

		self.assertTrue(
			offered <= policy.CUSTOMER_ALLOWED,
			f"unexpected: {offered - policy.CUSTOMER_ALLOWED}",
		)
		self.assertNotIn("manufacturing.stop_production", offered)
		self.assertNotIn("sales.delivery_status", offered)

	def test_an_administrator_is_offered_everything_they_can_permission(self):
		frappe.set_user("Administrator")

		offered = {tool.name for tool in registry.offered_to()}

		self.assertIn("manufacturing.stop_production", offered)
		self.assertGreater(len(offered), 30)


class TestAToolNeverOfferedCannotBeCalled(_PolicyTestCase):
	def test_a_customer_naming_a_tool_directly_is_refused(self):
		"""A model can name a tool it was never offered, and the offer list was
		built for whoever the turn started as."""
		customer = self.customer()
		frappe.set_user(customer)

		result = registry.execute("manufacturing.production_control", {})

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "not_permitted")

	def test_the_refusal_describes_nothing(self):
		"""A refusal that explains itself is a map drawn for whoever is
		probing."""
		customer = self.customer()
		frappe.set_user(customer)

		message = registry.execute("manufacturing.stop_production", {"action": "останови"})[
			"error"
		]["message"]

		self.assertEqual(message, "У вас нет прав для выполнения этого действия.")
		self.assertNotIn("stop_production", message)
		self.assertNotIn("role", message.lower())

	def test_a_refused_call_runs_nothing(self):
		customer = self.customer()
		work_order = frappe.db.get_value("Work Order", {"company": "KORKEM"}, "name")
		before = frappe.db.get_value("Work Order", work_order, "status")
		frappe.set_user(customer)

		registry.execute(
			"manufacturing.stop_production", {"work_order": work_order, "action": "останови"}
		)

		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.get_value("Work Order", work_order, "status"), before)

	def test_an_employee_keeps_their_shop_floor_tools(self):
		"""The gate must not become a second permission system that quietly
		takes things away."""
		frappe.set_user(PLANNER)

		result = registry.execute("manufacturing.production_control", {})

		self.assertTrue(result["ok"], result.get("error"))
