# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The digital administrator remembers after the owner returns to the CNC."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities
from korkem_ai.korkem_ai.notifications import events, recipients
from korkem_ai.korkem_ai.orchestrator import llm
from korkem_manufacturing import setup
from korkem_manufacturing.services import capture, reminders

OWNER = "reminder.owner@korkem.test"
EXTERNAL_ID = "31999003"


class TestDigitalAdministratorReminders(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		# The development worker outlives hooks.py edits. Production migrate clears
		# this cache; the focused module must exercise the checked-out subscribers.
		frappe.clear_cache()

	def setUp(self):
		frappe.set_user("Administrator")
		self._owner()
		self.sent = []
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=lambda channel, external_id, text, **kwargs: self.sent.append(
				{"channel": channel, "external_id": external_id, "text": text}
			)
			or {"message_id": "reminder-test"},
		)
		patcher.start()
		self.addCleanup(patcher.stop)
		identity = identities.observe("Telegram", EXTERNAL_ID, "Reminder Owner")
		identity.db_set("user", OWNER)
		self.assertIn(OWNER, recipients.owners_for_company(setup.COMPANY))
		hooks = frappe.get_hooks("korkem_domain_events")
		self.assertIn(reminders.STALE_CAPTURE, hooks)
		self.assertIn(reminders.MEASUREMENT_TASK, hooks)

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		super().tearDown()

	def test_a_capture_left_without_a_task_for_a_day_reaches_the_owner(self):
		name = self._stale_capture("Айгуль ждёт замер кухни")

		# If any reminder path asks a model to interpret the sentence, this test
		# fails. The text and the clock are already enough.
		with patch.object(llm, "get_provider", side_effect=RuntimeError("LLM is off")):
			result = reminders.run()

		row = self._delivery(reminders.STALE_CAPTURE, "Capture", name)
		self.assertGreaterEqual(result["stale_captures"], 1)
		self.assertEqual(row.recipient_user, OWNER)
		self.assertEqual(row.status, "Sent")
		self.assertIn("Айгуль", row.body)
		self.assertEqual(len([item for item in self.sent if "Айгуль" in item["text"]]), 1)

	def test_the_existing_delivery_subscriber_can_reach_the_owner(self):
		name = self._stale_capture("Проверить сам путь доставки")

		created = events.stale_capture(name, setup.COMPANY)

		self.assertEqual(len(created), 1)
		self.assertEqual(
			frappe.db.get_value("Notification Delivery", created[0], "recipient_user"),
			OWNER,
		)

	def test_an_overdue_measurement_task_reaches_the_owner(self):
		task = self._task(assigned_to=OWNER, overdue=True)

		result = reminders.run()

		row = self._delivery(reminders.MEASUREMENT_TASK, "CRM Task", task)
		self.assertGreaterEqual(result["overdue_tasks"], 1)
		self.assertIn("срок прошёл", row.body)

	def test_a_measurement_task_without_an_assignee_reaches_the_owner(self):
		task = self._task(assigned_to=None, overdue=False)

		result = reminders.run()

		row = self._delivery(reminders.MEASUREMENT_TASK, "CRM Task", task)
		self.assertGreaterEqual(result["unassigned_tasks"], 1)
		self.assertIn("исполнитель не назначен", row.body)

	def test_the_hourly_job_never_says_the_same_thing_twice(self):
		name = self._stale_capture("Не потерять повторным напоминанием")

		reminders.run()
		reminders.run()

		rows = frappe.get_all(
			"Notification Delivery",
			filters={
				"event": reminders.STALE_CAPTURE,
				"recipient_user": OWNER,
				"reference_doctype": "Capture",
				"reference_name": name,
			},
			pluck="name",
		)
		self.assertEqual(len(rows), 1)
		self.assertEqual(
			len([item for item in self.sent if "Не потерять" in item["text"]]), 1
		)

	def test_an_overdue_unassigned_task_is_one_subject_not_two_messages(self):
		task = self._task(assigned_to=None, overdue=True)

		result = reminders.run()

		row = self._delivery(reminders.MEASUREMENT_TASK, "CRM Task", task)
		self.assertGreaterEqual(result["subjects"], 1)
		self.assertIn("срок прошёл", row.body)
		self.assertIn("исполнитель не назначен", row.body)
		self.assertEqual(
			len([item for item in self.sent if "Замерить кухню" in item["text"]]), 1
		)

	def _owner(self) -> None:
		if not frappe.db.exists("User", OWNER):
			frappe.get_doc(
				{
					"doctype": "User",
					"email": OWNER,
					"first_name": "Reminder Owner",
					"enabled": 1,
					"send_welcome_email": 0,
					"roles": [{"role": "System Manager"}],
				}
			).insert(ignore_permissions=True)
		if not frappe.db.exists(
			"User Permission",
			{"user": OWNER, "allow": "Company", "for_value": setup.COMPANY},
		):
			frappe.get_doc(
				{
					"doctype": "User Permission",
					"user": OWNER,
					"allow": "Company",
					"for_value": setup.COMPANY,
					"apply_to_all_doctypes": 1,
				}
			).insert(ignore_permissions=True)
		frappe.clear_cache(user=OWNER)

	def _stale_capture(self, text: str) -> str:
		frappe.set_user(OWNER)
		try:
			result = capture.record(text=text)
		finally:
			frappe.set_user("Administrator")
		frappe.db.set_value(
			"Capture",
			result["capture"],
			"creation",
			frappe.utils.add_to_date(frappe.utils.now_datetime(), hours=-25),
			update_modified=False,
		)
		return result["capture"]

	def _task(self, *, assigned_to: str | None, overdue: bool) -> str:
		frappe.set_user(OWNER)
		try:
			result = capture.record(text="Замерить кухню, Абая 12")
		finally:
			frappe.set_user("Administrator")
		task = frappe.get_doc(
			{
				"doctype": "CRM Task",
				"title": "Замерить кухню, Абая 12",
				"status": "Todo",
				"assigned_to": assigned_to,
				"due_date": frappe.utils.add_to_date(
					frappe.utils.now_datetime(), days=-1 if overdue else 1
				),
				"reference_doctype": "Capture",
				"reference_docname": result["capture"],
			}
		).insert(ignore_permissions=True)
		frappe.db.set_value(
			"Capture", result["capture"], "task", str(task.name), update_modified=False
		)
		return str(task.name)

	def _delivery(self, event: str, doctype: str, name: str):
		rows = frappe.get_all(
			"Notification Delivery",
			filters={
				"event": event,
				"recipient_user": OWNER,
				"reference_doctype": doctype,
				"reference_name": name,
			},
			pluck="name",
		)
		self.assertEqual(len(rows), 1)
		return frappe.get_doc("Notification Delivery", rows[0])
