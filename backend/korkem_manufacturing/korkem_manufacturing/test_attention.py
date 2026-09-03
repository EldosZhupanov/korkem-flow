# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Что требует внимания — работа администратора, сложенная в один ответ."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.api import attention as api
from korkem_manufacturing.services import attention as service
from korkem_manufacturing.services import capture as capture_service


class TestWhatNeedsAttention(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")

	def test_the_answer_has_all_four_questions(self):
		"""Четыре вопроса взяты из интервью, а не придуманы."""
		result = service.today()

		self.assertEqual(
			set(result),
			{
				"unassigned_captures",
				"overdue_tasks",
				"orders_without_design",
				"delivered_not_invoiced",
			},
		)

	def test_something_said_and_never_handed_over_shows_up(self):
		"""Та самая потеря из блокнота, только теперь её видно."""
		captured = capture_service.record(text="Забытое вчера обращение")["capture"]
		frappe.db.set_value(
			"Capture",
			captured,
			"creation",
			frappe.utils.add_days(frappe.utils.now_datetime(), -2),
			update_modified=False,
		)

		names = [row["capture"] for row in service.today()["unassigned_captures"]]
		self.assertIn(captured, names)

	def test_something_said_an_hour_ago_is_not_yet_a_loss(self):
		"""Владелец сказал вечером, разбирает утром — это не потеря."""
		captured = capture_service.record(text="Только что сказанное")["capture"]

		names = [row["capture"] for row in service.today()["unassigned_captures"]]
		self.assertNotIn(captured, names)

	def test_something_handed_to_a_person_is_not_waiting(self):
		captured = capture_service.record(
			text="Передано замерщику", assign_to="Administrator"
		)["capture"]
		frappe.db.set_value(
			"Capture",
			captured,
			"creation",
			frappe.utils.add_days(frappe.utils.now_datetime(), -3),
			update_modified=False,
		)

		names = [row["capture"] for row in service.today()["unassigned_captures"]]
		self.assertNotIn(captured, names)

	def test_an_overdue_measurement_shows_up_with_who_and_when(self):
		captured = capture_service.record(
			text="Замер, который просрочили",
			assign_to="Administrator",
			due_on=frappe.utils.add_days(frappe.utils.nowdate(), -3),
		)["capture"]

		overdue = service.today()["overdue_tasks"]
		mine = [row for row in overdue if row["on"] == captured]
		self.assertEqual(len(mine), 1)
		self.assertEqual(mine[0]["who"], "Administrator")
		self.assertEqual(
			frappe.utils.getdate(mine[0]["was_due"]),
			frappe.utils.getdate(frappe.utils.add_days(frappe.utils.nowdate(), -3)),
		)

	def test_a_finished_task_stops_asking_for_attention(self):
		captured = capture_service.record(
			text="Замер сделан вовремя",
			assign_to="Administrator",
			due_on=frappe.utils.add_days(frappe.utils.nowdate(), -3),
		)["capture"]
		task = frappe.db.get_value("Capture", captured, "task")
		frappe.db.set_value("CRM Task", task, "status", "Done")

		overdue = service.today()["overdue_tasks"]
		self.assertFalse([row for row in overdue if row["on"] == captured])

	def test_the_endpoint_returns_the_same_thing(self):
		self.assertEqual(set(api.today()), set(service.today()))


class TestScope(IntegrationTestCase):
	def test_nothing_here_takes_a_company_argument(self):
		import inspect

		self.assertEqual(set(inspect.signature(service.today).parameters), set())
		self.assertEqual(set(inspect.signature(api.today).parameters), set())
