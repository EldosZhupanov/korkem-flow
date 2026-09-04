# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Чужую работу закрывает тот, чьё это дело.

Дыра найдена 4 сентября и не чтением кода: агент, писавший проверки экрана
«Задачи», спросил — а видит ли рабочий, чья это задача, и может ли закрыть
чужую. Ответ оказался «может любой вошедший, в любой компании»:
`complete_task` не проверял ничего и сохранял с `ignore_permissions=True`.

Роли этого не ловили и поймать не могли: роль знает, что человек — рабочий,
и не знает, кому назначена конкретная строка.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import shop_floor
from korkem_manufacturing.services import authority

IVAN = "korkem.ivan@example.com"
PLANNER = "korkem.planner@example.com"
MANAGER = "korkem.manager@example.com"


class _TaskCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self.addCleanup(frappe.set_user, "Administrator")

	def a_task(self, assigned_to=None):
		order = frappe.get_all(
			"Work Order", filters={"docstatus": ["<", 2]}, pluck="name", limit=1
		)
		if not order:
			self.skipTest("на стенде нет производственных заданий")
		doc = frappe.get_doc(
			{
				"doctype": shop_floor.TASK_DOCTYPE,
				"title": "Проверочная задача цеха",
				"reference_doctype": "Work Order",
				"reference_docname": order[0],
				"assigned_to": assigned_to,
				"status": "Todo",
			}
		).insert(ignore_permissions=True)
		self.addCleanup(
			frappe.delete_doc, shop_floor.TASK_DOCTYPE, doc.name, force=True, ignore_permissions=True
		)
		return doc


class TestWhoMayFinishATask(_TaskCase):
	def test_the_person_it_is_assigned_to_may(self):
		task = self.a_task(assigned_to=IVAN)

		frappe.set_user(IVAN)
		shop_floor.complete_task(task.name)

		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.get_value(shop_floor.TASK_DOCTYPE, task.name, "status"), "Done")

	def test_somebody_else_may_not(self):
		"""Главная проверка файла. До 4 сентября здесь не было ничего."""
		task = self.a_task(assigned_to=IVAN)

		frappe.set_user(PLANNER)
		with self.assertRaises(frappe.PermissionError):
			shop_floor.complete_task(task.name)

		frappe.set_user("Administrator")
		self.assertNotEqual(
			frappe.db.get_value(shop_floor.TASK_DOCTYPE, task.name, "status"),
			"Done",
			"отказ должен быть до записи, а не после",
		)

	def test_a_supervisor_may_close_for_someone_who_went_home(self):
		task = self.a_task(assigned_to=IVAN)

		frappe.set_user(MANAGER)
		if not authority.is_supervisor():
			self.skipTest("на этом стенде у менеджера нет роли старшего")
		shop_floor.complete_task(task.name)

		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.get_value(shop_floor.TASK_DOCTYPE, task.name, "status"), "Done")

	def test_an_unassigned_task_is_not_refused(self):
		"""Ничья задача — не повод останавливать цех: её берут тем, что
		закрывают."""
		task = self.a_task(assigned_to=None)

		frappe.set_user(IVAN)
		shop_floor.complete_task(task.name)

		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.get_value(shop_floor.TASK_DOCTYPE, task.name, "status"), "Done")

	def test_the_refusal_says_what_to_do_instead(self):
		"""Отказ, из которого не следует следующий шаг, читается как поломка."""
		task = self.a_task(assigned_to=IVAN)

		frappe.set_user(PLANNER)
		with self.assertRaises(frappe.PermissionError) as caught:
			shop_floor.complete_task(task.name)

		self.assertIn("старший", str(caught.exception))


class TestTheCheckIsNotOnlyAboutAssignment(_TaskCase):
	def test_a_task_of_another_company_reads_as_absent(self):
		"""«Есть, но не твоя» рассказывает о чужой компании больше, чем следует."""
		from unittest.mock import patch

		from korkem_manufacturing.services import scope

		task = self.a_task(assigned_to=IVAN)

		frappe.set_user(IVAN)
		with patch.object(scope, "belongs_to_company", return_value=False):
			with self.assertRaises(frappe.ValidationError):
				shop_floor.complete_task(task.name)
