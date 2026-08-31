# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Creating the three kinds of real person, with the isolation that makes them safe.

The failures worth testing are the quiet ones: an account that has the roles but
not the company restriction can read every company on the site, and a customer
account that is a "user with fewer roles" can read every order. Both look
correct on the user form.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import customer_access, onboarding
from korkem_ai.korkem_ai.tools import scope

COMPANY = "KORKEM"
CUSTOMER = "Мебель Астана"


class _OnboardingTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self.addCleanup(frappe.set_user, "Administrator")

	def account(self, email):
		"""Register `email` for cleanup, whether or not creating it succeeds."""
		self.addCleanup(self._drop, email)
		return email

	def _drop(self, email):
		"""Take the account away again, and make failing to do so harmless.

		Two things learned from leaving two accounts behind on a full run.

		**The account is disabled before it is deleted.** Deleting a User
		updates `tabContact` — Frappe creates one per user — and inside a long
		test run that update can lose to MariaDB's "Record has changed since
		last read". A leaked *enabled* account is not a tidiness problem: the
		provider-settings suite picks "some other enabled user" to prove a
		non-manager is refused, and an owner account left behind holds
		`System Manager`, so it proved the opposite. Disabling first cannot
		fail that way and takes the account out of every such query.

		**The contact goes first, in its own transaction.** Committing before
		the delete means the row is not one this transaction has already read.
		"""
		frappe.set_user("Administrator")
		if frappe.db.exists("User", email):
			frappe.db.set_value("User", email, "enabled", 0, update_modified=False)
		frappe.db.commit()

		for name in frappe.get_all("User Permission", filters={"user": email}, pluck="name"):
			frappe.delete_doc("User Permission", name, force=True, ignore_permissions=True)
		for parent in frappe.get_all(
			"Portal User", filters={"user": email}, pluck="parent", ignore_permissions=True
		):
			if frappe.db.exists("Customer", parent):
				party = frappe.get_doc("Customer", parent)
				party.set("portal_users", [row for row in party.portal_users if row.user != email])
				party.save(ignore_permissions=True)
		for name in frappe.get_all("Contact", filters={"user": email}, pluck="name"):
			frappe.delete_doc("Contact", name, force=True, ignore_permissions=True)
		frappe.db.commit()

		if frappe.db.exists("User", email):
			frappe.delete_doc("User", email, force=True, ignore_permissions=True)
		frappe.db.commit()


class TestAnEmployee(_OnboardingTestCase):
	def test_they_get_the_roles_they_were_given_and_one_company(self):
		email = self.account("pilot.employee@example.com")
		result = onboarding.create_employee(email, "Сотрудник", ["Stock User"], COMPANY)

		self.assertTrue(result["created"])
		self.assertIn("Stock User", result["roles_added"])
		self.assertEqual(
			frappe.get_all(
				"User Permission",
				filters={"user": email, "allow": "Company"},
				pluck="for_value",
			),
			[COMPANY],
		)

	def test_the_company_binding_is_what_the_tools_read(self):
		"""Not a claim about a permission row — the answer the assistant uses."""
		email = self.account("pilot.scoped@example.com")
		onboarding.create_employee(email, "Сотрудник", ["Stock User"], COMPANY)

		frappe.set_user(email)
		self.assertEqual(scope.current_company(), COMPANY)

	def test_the_default_roles_are_the_shop_floor_pair(self):
		email = self.account("pilot.default@example.com")
		result = onboarding.create_employee(email, "Сотрудник", None, COMPANY)
		self.assertEqual(set(result["roles_added"]), set(onboarding.DEFAULT_EMPLOYEE_ROLES))

	def test_running_it_twice_changes_nothing(self):
		email = self.account("pilot.twice@example.com")
		onboarding.create_employee(email, "Сотрудник", ["Stock User"], COMPANY)
		again = onboarding.create_employee(email, "Сотрудник", ["Stock User"], COMPANY)

		self.assertFalse(again["created"])
		self.assertEqual(again["roles_added"], [])
		self.assertFalse(again["company_permission_added"])
		self.assertEqual(
			frappe.db.count("User Permission", {"user": email, "allow": "Company"}), 1
		)

	def test_a_role_added_by_an_administrator_survives_a_re_run(self):
		"""Onboarding adds; it must never quietly narrow a real account."""
		email = self.account("pilot.widened@example.com")
		onboarding.create_employee(email, "Сотрудник", ["Stock User"], COMPANY)

		user = frappe.get_doc("User", email)
		user.append("roles", {"role": "Purchase User"})
		user.save(ignore_permissions=True)

		onboarding.create_employee(email, "Сотрудник", ["Stock User"], COMPANY)
		held = {row.role for row in frappe.get_doc("User", email).roles}
		self.assertIn("Purchase User", held)

	def test_an_employee_cannot_be_made_a_system_manager_here(self):
		email = self.account("pilot.sneaky@example.com")
		with self.assertRaises(frappe.ValidationError):
			onboarding.create_employee(email, "Сотрудник", ["System Manager"], COMPANY)

	def test_a_role_that_does_not_exist_is_refused_rather_than_created(self):
		email = self.account("pilot.typo@example.com")
		with self.assertRaises(frappe.ValidationError):
			onboarding.create_employee(email, "Сотрудник", ["Stok User"], COMPANY)
		self.assertFalse(frappe.db.exists("Role", "Stok User"))

	def test_a_company_that_does_not_exist_is_refused(self):
		email = self.account("pilot.nocompany@example.com")
		with self.assertRaises(frappe.ValidationError):
			onboarding.create_employee(email, "Сотрудник", ["Stock User"], "Нет такой компании")
		self.assertFalse(frappe.db.exists("User", email))


class TestTheOwner(_OnboardingTestCase):
	def test_they_get_every_management_role_and_one_company(self):
		email = self.account("pilot.owner@example.com")
		result = onboarding.create_owner(email, "Владелец", COMPANY)

		held = {row.role for row in frappe.get_doc("User", email).roles}
		for role in onboarding.OWNER_ROLES:
			with self.subTest(role):
				self.assertIn(role, held)
		self.assertTrue(result["company_permission_added"])

	def test_even_the_owner_is_bound_to_a_company(self):
		"""A site can hold more than one; the owner of this factory owns one."""
		email = self.account("pilot.owner2@example.com")
		onboarding.create_owner(email, "Владелец", COMPANY)
		self.assertEqual(
			frappe.db.count("User Permission", {"user": email, "allow": "Company"}), 1
		)


class TestACustomer(_OnboardingTestCase):
	def test_all_three_parts_of_the_binding_are_written(self):
		email = self.account("pilot.client@example.com")
		result = onboarding.create_customer_user(email, CUSTOMER, "Клиент")

		self.assertEqual(result["customer"], CUSTOMER)
		self.assertTrue(
			frappe.db.exists("Portal User", {"user": email, "parent": CUSTOMER})
		)
		self.assertIn(
			customer_access.ROLE,
			{row.role for row in frappe.get_doc("User", email).roles},
		)
		self.assertTrue(
			frappe.db.exists(
				"User Permission",
				{"user": email, "allow": "Customer", "for_value": CUSTOMER},
			)
		)

	def test_they_are_a_website_user_with_no_desk(self):
		email = self.account("pilot.client2@example.com")
		onboarding.create_customer_user(email, CUSTOMER, "Клиент")
		self.assertEqual(frappe.db.get_value("User", email, "user_type"), "Website User")

	def test_they_get_no_company_permission(self):
		"""A customer is scoped by customer. A company grant would widen them."""
		email = self.account("pilot.client3@example.com")
		onboarding.create_customer_user(email, CUSTOMER, "Клиент")
		self.assertEqual(
			frappe.db.count("User Permission", {"user": email, "allow": "Company"}), 0
		)

	def test_they_see_only_their_own_orders(self):
		email = self.account("pilot.client4@example.com")
		onboarding.create_customer_user(email, CUSTOMER, "Клиент")

		frappe.set_user(email)
		customers = {
			row.customer
			for row in frappe.get_list("Sales Order", fields=["customer"], limit_page_length=0)
		}
		self.assertLessEqual(customers, {CUSTOMER})

	def test_a_customer_that_does_not_exist_is_refused(self):
		email = self.account("pilot.client5@example.com")
		with self.assertRaises(frappe.ValidationError):
			onboarding.create_customer_user(email, "Нет такого клиента", "Клиент")
		self.assertFalse(frappe.db.exists("User", email))


class TestNoAccountIsGivenAPassword(_OnboardingTestCase):
	def test_an_onboarded_account_cannot_be_signed_into_yet(self):
		from frappe.utils.password import check_password

		email = self.account("pilot.nopassword@example.com")
		onboarding.create_employee(email, "Сотрудник", ["Stock User"], COMPANY)

		with self.assertRaises(frappe.AuthenticationError):
			check_password(email, "KorkemE2E!2026")

	def test_the_summary_says_so_and_says_what_to_do(self):
		email = self.account("pilot.nopassword2@example.com")
		result = onboarding.create_employee(email, "Сотрудник", ["Stock User"], COMPANY)

		self.assertFalse(result["password_set"])
		self.assertIn("Set a password", result["next_step"])

	def test_no_summary_carries_anything_password_shaped(self):
		email = self.account("pilot.nopassword3@example.com")
		rendered = str(onboarding.create_employee(email, "Сотрудник", ["Stock User"], COMPANY))
		for word in ("password=", "secret", "token"):
			with self.subTest(word):
				self.assertNotIn(word, rendered.lower().replace("password_set", ""))
