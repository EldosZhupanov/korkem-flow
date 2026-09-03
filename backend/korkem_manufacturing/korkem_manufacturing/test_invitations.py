# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Invitation permissions: especially R5, which must fail closed."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import onboarding
from korkem_manufacturing.services import invitations

COMPANY = "KORKEM"
OWNER = "invitation.owner@korkem.test"


class TestEmployeeInvitations(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		# hooks.py changed in this worktree while the development bench stayed
		# alive. A real migrate clears this cache; the focused module does the
		# equivalent so it exercises the checked-out hook, not Redis's old list.
		frappe.clear_cache()
		onboarding.create_owner(OWNER, "Invitation Owner", COMPANY)

	@classmethod
	def tearDownClass(cls):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		cls._drop_user(OWNER)
		frappe.db.commit()
		super().tearDownClass()

	def setUp(self):
		frappe.set_user("Administrator")
		self.created = []

	def tearDown(self):
		frappe.set_user("Administrator")
		for email in reversed(self.created):
			self._drop_user(email)
		for name in frappe.get_all(
			"Comment",
			filters={"content": ["like", "%invitation.%@korkem.test%"]},
			pluck="name",
		):
			frappe.delete_doc("Comment", name, force=True, ignore_permissions=True)
		frappe.db.commit()

	@staticmethod
	def _drop_user(email: str) -> None:
		if not frappe.db.exists("User", email):
			return
		frappe.db.set_value("User", email, "enabled", 0, update_modified=False)
		frappe.db.commit()
		for name in frappe.get_all("User Permission", filters={"user": email}, pluck="name"):
			frappe.delete_doc("User Permission", name, force=True, ignore_permissions=True)
		for name in frappe.get_all("Contact", filters={"user": email}, pluck="name"):
			frappe.delete_doc("Contact", name, force=True, ignore_permissions=True)
		frappe.db.commit()
		frappe.delete_doc("User", email, force=True, ignore_permissions=True)

	def _email(self, stem: str) -> str:
		email = f"invitation.{stem}@korkem.test"
		self.created.append(email)
		return email

	def _invite(self, email: str, position: str) -> dict:
		frappe.set_user(OWNER)
		try:
			return invitations.invite_employee(
				email=email, first_name="Invited", position=position
			)
		finally:
			frappe.set_user("Administrator")

	def test_owner_can_invite_and_the_action_is_audited(self):
		email = self._email("warehouse")
		result = self._invite(email, "warehouse")

		self.assertTrue(result["created"])
		self.assertEqual(result["position"], "warehouse")
		self.assertEqual(set(result["roles_added"]), {"Stock User"})
		self.assertEqual(
			frappe.get_all(
				"User Permission",
				filters={"user": email, "allow": "Company"},
				pluck="for_value",
			),
			[COMPANY],
		)
		audit = frappe.get_all(
			"Comment",
			filters={
				"reference_doctype": "Company",
				"reference_name": COMPANY,
				"content": ["like", f"%{OWNER}%{email}%warehouse%"],
			},
			pluck="name",
		)
		self.assertTrue(audit, "the invitation has no R9 audit record")

	#: Каждая должность и то, что человек по ней получает. Записано здесь
	#: целиком и вручную: словарь на сервере — это раздача прав, и менять его
	#: молча нельзя. Любое расхождение обязано провалить проверку, а не
	#: подстроиться под неё.
	EXPECTED_ROLES = {
		"manager": {"Sales User", "Sales Manager"},
		"measurer": {"Sales User"},
		"designer": {"Manufacturing User", "Item Manager"},
		"shop_manager": {"Manufacturing Manager", "Manufacturing User", "Stock User"},
		"cutter": {"Manufacturing User", "Stock User"},
		"edge_banding": {"Manufacturing User", "Stock User"},
		"cnc": {"Manufacturing User", "Stock User"},
		"painter": {"Manufacturing User", "Stock User"},
		"assembler": {"Manufacturing User", "Stock User"},
		"warehouse": {"Stock User"},
		"installer": {"Manufacturing User", "Stock User"},
		"accountant": {"Accounts User"},
		"shop_floor": {"Manufacturing User", "Stock User"},
	}

	def test_the_table_of_positions_is_the_one_written_down_here(self):
		"""Сверка таблицы, без создания людей.

		Раньше эта проверка приглашала по человеку на должность. С четырьмя
		должностями это стоило четыре учётные записи, с тринадцатью — тринадцать,
		а Frappe ограничивает создание пользователей шестьюдесятью в час на сайт:
		набор начал бы ронять сам себя и соседние тесты. Раздачу прав можно
		сверить, ничего не создавая; сквозной путь проверяют тесты ниже.
		"""
		self.assertEqual(
			{position: set(roles) for position, roles in invitations.POSITIONS.items()},
			self.EXPECTED_ROLES,
			"словарь должностей разошёлся с тем, что здесь записано. Это раздача "
			"прав: если расхождение намеренное — обновите таблицу выше вместе с ним",
		)

	def test_every_role_named_here_exists_on_the_site(self):
		"""Опечатка в названии роли не должна становиться правом.

		`_require_roles` отказывается приглашать с несуществующей ролью — но
		узнать об этом при живом приглашении значило бы узнать от клиента.
		"""
		named = {role for roles in invitations.POSITIONS.values() for role in roles}
		missing = sorted(r for r in named if not frappe.db.exists("Role", r))
		self.assertFalse(missing, f"этих ролей нет на сайте: {missing}")

	def test_the_two_ends_of_the_mapping_still_work_end_to_end(self):
		"""Две должности целиком: самая широкая и самая узкая."""
		for position in ("shop_manager", "measurer"):
			with self.subTest(position=position):
				result = self._invite(self._email(position), position)
				self.assertEqual(
					set(result["roles_added"]), self.EXPECTED_ROLES[position]
				)

	def test_an_ordinary_employee_cannot_invite_anyone(self):
		caller = self._email("ordinary")
		target = self._email("ordinary-target")
		self._invite(caller, "shop_floor")

		frappe.set_user(caller)
		try:
			with self.assertRaises(frappe.PermissionError):
				invitations.invite_employee(
					email=target, first_name="Target", position="warehouse"
				)
		finally:
			frappe.set_user("Administrator")
		self.assertFalse(frappe.db.exists("User", target))

	def test_service_guard_is_not_accidentally_delegated_to_onboarding(self):
		"""Mutation proof: deleting only_for makes this test fail.

		The onboarding call is replaced with a harmless success, so its own
		defence-in-depth check cannot make this service-level R5 test pass.
		"""
		caller = self._email("guard")
		self._invite(caller, "shop_floor")
		fake = {
			"user": "nobody@example.com",
			"company": COMPANY,
			"created": True,
			"roles_added": [],
			"password_set": False,
		}

		frappe.set_user(caller)
		try:
			with patch.object(invitations.onboarding, "create_employee", return_value=fake) as call:
				with self.assertRaises(frappe.PermissionError):
					invitations.invite_employee(
						email="nobody@example.com", position="warehouse"
					)
				call.assert_not_called()
		finally:
			frappe.set_user("Administrator")

	def test_manager_cannot_create_a_second_owner(self):
		manager = self._email("manager")
		target = self._email("second-owner")
		self._invite(manager, "manager")

		frappe.set_user(manager)
		try:
			with self.assertRaises(frappe.PermissionError):
				invitations.invite_employee(
					email=target, first_name="Second Owner", position="owner"
				)
		finally:
			frappe.set_user("Administrator")
		self.assertFalse(frappe.db.exists("User", target))

	def test_employee_cannot_add_a_role_to_their_own_user_document(self):
		"""The direct Frappe route discards the protected roles child field."""
		email = self._email("self-escalation")
		self._invite(email, "shop_floor")

		frappe.set_user(email)
		try:
			frappe.client.set_value(
				"User",
				email,
				"roles",
				[{"role": "System Manager"}],
			)
		finally:
			frappe.set_user("Administrator")
		self.assertNotIn(
			"System Manager", {row.role for row in frappe.get_doc("User", email).roles}
		)

	def test_r5_hook_refuses_self_role_change_even_with_docperm_bypassed(self):
		"""The domain guard survives an internal ``ignore_permissions`` save."""
		email = self._email("hook-self-escalation")
		self._invite(email, "shop_floor")

		frappe.set_user(email)
		try:
			user = frappe.get_doc("User", email)
			user.append("roles", {"role": "System Manager"})
			with self.assertRaises(frappe.PermissionError):
				user.save(ignore_permissions=True)
		finally:
			frappe.set_user("Administrator")
		self.assertNotIn(
			"System Manager", {row.role for row in frappe.get_doc("User", email).roles}
		)

	def test_owner_position_is_not_an_invitable_job(self):
		with self.assertRaises(frappe.ValidationError):
			self._invite(self._email("owner-position"), "owner")
