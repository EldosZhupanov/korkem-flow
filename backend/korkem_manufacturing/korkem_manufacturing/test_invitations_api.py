# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Приглашение сотрудника через endpoint, а не через панель ERPNext."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.api import invitations as api
from korkem_manufacturing.services import invitations as service


class TestInvitingFromTheApp(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")

	def test_positions_come_from_the_server(self):
		"""Должность — это набор прав, и список у неё один."""
		listed = {row["position"] for row in api.positions()}
		self.assertEqual(listed, set(service.POSITIONS))
		for row in api.positions():
			self.assertEqual(sorted(row["roles"]), sorted(service.POSITIONS[row["position"]]))

	def test_an_invited_measurer_gets_the_roles_of_the_position(self):
		email = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		result = api.invite(email=email, position="shop_floor", first_name="Кайрат")

		self.assertEqual(result["user"], email)
		self.assertTrue(result["created"])
		self.assertEqual(result["position"], "shop_floor")
		self.assertTrue(result["roles_added"])

	def test_no_password_ever_comes_back(self):
		"""Ответ содержит имена и признаки, но никогда — учётные данные."""
		email = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		result = api.invite(email=email, position="warehouse")

		self.assertFalse(result["password_set"])
		body = frappe.as_json(result).lower()
		for word in ("password", "secret", "token", "пароль"):
			self.assertNotIn(f'"{word}":', body)

	def test_an_unknown_position_is_refused_by_name(self):
		with self.assertRaises(frappe.ValidationError):
			api.invite(email="x@korkem.kz", position="директор")

	def test_an_employee_cannot_invite(self):
		"""Приглашение — это раздача прав, и её не делает тот, у кого их нет."""
		email = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		api.invite(email=email, position="shop_floor")

		frappe.set_user(email)
		with self.assertRaises(frappe.PermissionError):
			api.invite(email="another@korkem.kz", position="manager")
