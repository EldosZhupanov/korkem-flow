# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Демо-сотрудник принадлежит КОРКЕМ, а не тому, кто последним завёл компанию.

## Что сломалось

Ночью 4 сентября на стенде появилась вторая компания — её завели через
приложение, проверяя регистрацию. Она стала умолчанием сайта. У демо-сотрудников
своей привязки не было, поэтому «чья это смена» стало отвечаться про неё, и
тридцать семь тестов цеха начали падать с «заказ не найден»: фикстура брала
заказ КОРКЕМ, а инструмент искал его в чужой компании.

Ни один из тридцати семи не показывал на причину. Поэтому привязка теперь
явная, а этот файл следит, чтобы она не пропала.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import scope
from korkem_manufacturing import seed_demo

PLANNER = "korkem.planner@example.com"


class TestSeededStaffBelongToKorkem(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		seed_demo.seed_users()

	def test_a_seeded_user_is_bound_to_korkem(self):
		"""Именно этот список читает `scope.current_company()` первым — до
		умолчания пользователя и до умолчания сайта."""
		allowed = frappe.get_all(
			"User Permission",
			filters={"user": PLANNER, "allow": "Company"},
			pluck="for_value",
		)
		self.assertEqual(allowed, [seed_demo.COMPANY])

	def test_seeding_twice_does_not_add_a_second_permission(self):
		seed_demo.seed_users()

		allowed = frappe.get_all(
			"User Permission",
			filters={"user": PLANNER, "allow": "Company"},
			pluck="for_value",
		)
		self.assertEqual(allowed, [seed_demo.COMPANY])

	def test_administrator_asking_which_company_gets_korkem(self):
		"""Почти весь набор тестов цеха ходит по демо-заводу от лица
		Administrator, а своей компании у него нет. Пока ответ приходил от
		умолчания сайта, его менял кто угодно, кто заводил компанию в
		приложении, — и семьдесят один тест падал с «заказ не найден».
		"""
		self.assertEqual(
			frappe.db.get_single_value("Global Defaults", "default_company"),
			seed_demo.COMPANY,
		)
		# Отдельной строкой, потому что это отдельное поле: на вопрос «какая
		# компания» отвечает глобальное умолчание `company`, а не настройка
		# сайта. Пока менялась только вторая, `scope.current_company()`
		# продолжал называть прежнюю компанию.
		frappe.set_user("Administrator")
		self.assertEqual(scope.current_company(), seed_demo.COMPANY)

	def test_every_seeded_user_gets_one(self):
		unbound = [
			email
			for email in seed_demo.USERS
			if not frappe.db.exists(
				"User Permission",
				{"user": email, "allow": "Company", "for_value": seed_demo.COMPANY},
			)
		]
		self.assertEqual(unbound, [])
