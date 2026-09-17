"""A known fact id is not permission to read or edit another tenant's memory."""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import memory, memory_api


class TestMemoryIsolation(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.fact = memory.remember(
			scope=memory.COMPANY,
			category="terminology",
			subject="edge",
			predicate="unit",
			value="metres",
		)

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		super().tearDown()

	def test_foreign_company_cannot_update_confirm_or_delete(self):
		# Keep the real fact/storage; substitute only the server-resolved tenant.
		with patch.object(memory, "_company", return_value="another-tenant"):
			for action in (
				lambda: memory_api.update(self.fact, "changed"),
				lambda: memory_api.confirm(self.fact),
				lambda: memory_api.delete(self.fact),
			):
				with self.subTest(action=action):
					with self.assertRaises(frappe.PermissionError):
						action()
		self.assertEqual(frappe.db.get_value(memory.DOCTYPE, self.fact, "value"), "metres")
		self.assertTrue(frappe.db.get_value(memory.DOCTYPE, self.fact, "is_active"))

	def test_guest_cannot_change_company_memory(self):
		frappe.set_user("Guest")
		with self.assertRaises(frappe.PermissionError):
			memory_api.delete(self.fact)

	def test_unqualified_recall_does_not_include_another_users_memory(self):
		name = memory.remember(
			scope=memory.USER,
			category="preference",
			subject="language",
			predicate="preferred",
			value="kk",
			owner="Guest",
		)
		self.assertNotIn(name, [row["name"] for row in memory.recall()])

	def test_missing_company_does_not_fall_back_after_scope_failure(self):
		from korkem_manufacturing.services import scope

		with patch.object(scope, "current_company", side_effect=frappe.PermissionError):
			with self.assertRaises(frappe.PermissionError):
				memory.recall()

	def test_customer_does_not_receive_internal_company_facts(self):
		from korkem_manufacturing.services import identity

		with patch.object(identity, "role_of", return_value=identity.CUSTOMER):
			self.assertEqual(memory.recall(scope=memory.COMPANY), [])
