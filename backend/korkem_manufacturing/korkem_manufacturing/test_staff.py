# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Должность и доступ после приглашения — единственный пункт, где цена ошибки
не «неудобно», а «уволенный читает базу клиентов»."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import invitations
from korkem_manufacturing.services import staff as service


class TestStaffAccess(IntegrationTestCase):
	"""Люди заводятся один раз на класс, а не на тест.

	Frappe ограничивает создание учётных записей — шестьдесят в час на весь
	сайт. Тринадцать тестов, каждый со своим сотрудником, выбирают этот бюджет
	за три прогона и роняют чужие тесты, которые тоже заводят людей. Найдено
	полным прогоном: по модулю всё было зелёным.
	"""

	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		cls.email = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		cls.other = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		for email in (cls.email, cls.other):
			invitations.invite_employee(
				email=email, position="shop_floor", first_name="Кайрат"
			)
		frappe.db.commit()

	def setUp(self):
		frappe.set_user("Administrator")
		for email in (self.email, self.other):
			user = frappe.get_doc("User", email)
			user.enabled = 1
			user.set("roles", [])
			for role in invitations.POSITIONS["shop_floor"]:
				user.append("roles", {"role": role})
			user.save(ignore_permissions=True)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _roles(self, email: str) -> set[str]:
		return set(
			frappe.get_all(
				"Has Role",
				filters={"parent": email, "parenttype": "User"},
				parent_doctype="User",
				pluck="role",
			)
		)

	def test_a_position_change_swaps_the_roles_of_the_position(self):
		before = self._roles(self.email)
		self.assertIn("Stock User", before)

		service.change_position(email=self.email, position="accountant")

		after = self._roles(self.email)
		self.assertIn("Accounts User", after)
		self.assertNotIn("Manufacturing User", after)

	def test_roles_we_did_not_grant_survive_a_position_change(self):
		"""Что стоит на человеке помимо должности, поставили не мы."""
		user = frappe.get_doc("User", self.email)
		user.append("roles", {"role": "Newsletter Manager"})
		user.save(ignore_permissions=True)

		service.change_position(email=self.email, position="manager")

		after = self._roles(self.email)
		self.assertIn("Newsletter Manager", after)
		self.assertIn("Sales Manager", after)

	def test_an_unknown_position_is_refused_by_name(self):
		with self.assertRaises(frappe.ValidationError):
			service.change_position(email=self.email, position="директор")

	def test_nobody_changes_their_own_position(self):
		"""Владелец, понизив себя, запирает завод снаружи."""
		with self.assertRaises(frappe.PermissionError):
			service.change_position(email="Administrator", position="shop_floor")

	def test_a_departed_employee_loses_the_way_in(self):
		result = service.deactivate(email=self.email)

		self.assertFalse(result["enabled"])
		self.assertEqual(frappe.db.get_value("User", self.email, "enabled"), 0)

	def test_the_departed_person_is_disabled_and_not_deleted(self):
		"""Он подписывал замеры: оторвать имя от работы нельзя."""
		service.deactivate(email=self.email)

		self.assertTrue(frappe.db.exists("User", self.email))
		self.assertEqual(
			frappe.db.get_value("User", self.email, "first_name"), "Кайрат"
		)

	def test_disabling_twice_is_not_an_error(self):
		service.deactivate(email=self.email)
		again = service.deactivate(email=self.email)
		self.assertEqual(again["status"], "already_disabled")

	def test_a_returning_employee_gets_the_way_back(self):
		service.deactivate(email=self.email)
		result = service.reactivate(email=self.email)

		self.assertTrue(result["enabled"])
		self.assertEqual(frappe.db.get_value("User", self.email, "enabled"), 1)

	def test_nobody_disables_themselves(self):
		with self.assertRaises(frappe.PermissionError):
			service.deactivate(email="Administrator")

	def test_an_employee_cannot_change_anyones_roles(self):
		"""R5: раздача прав не делается тем, у кого их нет."""
		frappe.set_user(self.email)
		with self.assertRaises(frappe.PermissionError):
			service.change_position(email=self.other, position="manager")

	def test_an_employee_cannot_disable_a_colleague(self):
		frappe.set_user(self.email)
		with self.assertRaises(frappe.PermissionError):
			service.deactivate(email=self.other)

	def test_a_user_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.change_position(email="никого@нет.kz", position="manager")

	def test_the_change_leaves_a_trace(self):
		"""R9: опасное действие оставляет след, кто его сделал."""
		service.deactivate(email=self.email)

		trail = frappe.get_all(
			"Comment",
			filters={"reference_doctype": "User", "reference_name": self.email},
			pluck="content",
		)
		self.assertTrue(any("доступ закрыт" in line for line in trail))

	def test_disabling_also_closes_sessions_already_open(self):
		"""Уволенный не выходит из приложения — он уходит вместе с ним.

		Одного `enabled = 0` мало: новый вход после этого даёт 401, а телефон с
		уже открытым приложением продолжает работать с прежней сессией. Найдено
		живым запросом, а не тестом, — тест поставлен, чтобы больше не вернулось.
		"""
		frappe.db.set_value("User", self.email, "enabled", 1)
		# `Sessions` — сырая таблица, а не доктайп с контроллером.
		frappe.db.sql(
			"""INSERT INTO tabSessions (user, sid, sessiondata, lastupdate, status)
			   VALUES (%s, %s, %s, %s, %s)""",
			(self.email, frappe.generate_hash(), "{}", frappe.utils.now(), "Active"),
		)

		result = service.deactivate(email=self.email)

		self.assertGreaterEqual(result["sessions_closed"], 1)
		self.assertEqual(frappe.db.count("Sessions", {"user": self.email}), 0)
