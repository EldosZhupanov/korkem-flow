# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai import hooks
from korkem_ai.korkem_ai import permissions


class TestPermissions(IntegrationTestCase):
	def _perms(self, doctype: str, role: str) -> dict | None:
		rows = frappe.get_all(
			"Custom DocPerm",
			filters={"parent": doctype, "role": role, "permlevel": 0},
			fields=["read", "write", "create", "delete"],
		)
		return rows[0] if rows else None

	def test_grants_are_applied(self):
		permissions.apply()

		self.assertEqual(self._perms("Pending Action", "Sales Manager").read, 1)
		self.assertEqual(self._perms("Pending Action", "Sales Manager").write, 1)

	def test_clean_install_and_migrate_both_apply_the_policy(self):
		"""A patch is skipped on clean install, so it cannot own site policy."""
		method = "korkem_ai.korkem_ai.permissions.apply"

		self.assertEqual(hooks.after_install, method)
		self.assertIn(method, hooks.after_migrate)

	def test_work_order_stays_read_only_for_sales(self):
		"""The one grant that must never widen.

		Production state is changed on the shop floor through task completion.
		A sales role that could write a Work Order could mark someone else's
		work finished.
		"""
		permissions.apply()

		for role in ("Sales User", "Sales Manager"):
			perms = self._perms("Work Order", role)
			self.assertEqual(perms.read, 1, role)
			self.assertEqual(perms.write, 0, role)
			self.assertEqual(perms.create, 0, role)
			self.assertEqual(perms.delete, 0, role)

	def test_existing_roles_survive(self):
		"""add_permission copies the standard rules into Custom DocPerm first.

		If it did not, granting read to Sales User would silently revoke
		Manufacturing User's access -- Frappe ignores standard DocPerms entirely
		once any Custom DocPerm exists for the doctype.
		"""
		permissions.apply()

		manufacturing = self._perms("Work Order", "Manufacturing User")
		self.assertIsNotNone(manufacturing)
		self.assertEqual(manufacturing.read, 1)
		self.assertEqual(manufacturing.write, 1)

	def test_is_idempotent(self):
		permissions.apply()
		before = frappe.db.count("Custom DocPerm", {"parent": "Work Order"})

		permissions.apply()

		self.assertEqual(
			frappe.db.count("Custom DocPerm", {"parent": "Work Order"}), before
		)

	def test_skips_a_doctype_the_site_does_not_have(self):
		original = permissions.MOBILE_GRANTS
		permissions.MOBILE_GRANTS = (("No Such DocType", "Sales User", {"read": 1}),)
		try:
			permissions.apply()  # must not raise
		finally:
			permissions.MOBILE_GRANTS = original
