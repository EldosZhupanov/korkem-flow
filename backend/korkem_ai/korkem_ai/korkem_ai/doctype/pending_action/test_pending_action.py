# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_to_date, now_datetime


class TestPendingAction(IntegrationTestCase):
	def tearDown(self) -> None:
		frappe.db.rollback()

	def _make_todo(self, description="original"):
		return frappe.get_doc({"doctype": "ToDo", "description": description}).insert()

	def test_defaults_expiry_window(self):
		todo = self._make_todo()
		action = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"entity_type": "ToDo",
				"entity_name": todo.name,
				"action_class": "korkem_ai.korkem_ai.utils.test_actions.set_todo_description",
				"action_data": {"todo": todo.name, "description": "updated"},
			}
		).insert()

		self.assertEqual(action.status, "Pending")
		self.assertTrue(action.expires_at)

	def test_approve_executes_action_and_records_result(self):
		todo = self._make_todo()
		action = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"entity_type": "ToDo",
				"entity_name": todo.name,
				"action_class": "korkem_ai.korkem_ai.utils.test_actions.set_todo_description",
				"action_data": {"todo": todo.name, "description": "updated by approval"},
			}
		).insert()

		action.approve()
		action.reload()

		self.assertEqual(action.status, "Approved")
		self.assertEqual(action.resolved_by, "Administrator")
		self.assertTrue(action.resolved_at)
		self.assertEqual(frappe.parse_json(action.result_data).get("description"), "updated by approval")

		todo.reload()
		self.assertEqual(todo.description, "updated by approval")

	def test_approve_twice_fails(self):
		todo = self._make_todo()
		action = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"entity_type": "ToDo",
				"entity_name": todo.name,
				"action_class": "korkem_ai.korkem_ai.utils.test_actions.set_todo_description",
				"action_data": {"todo": todo.name, "description": "first approval"},
			}
		).insert()

		action.approve()

		with self.assertRaises(frappe.ValidationError):
			action.approve()

	def test_approve_fails_when_target_deleted(self):
		"""Invariant 9: re-validate at approval time, not just proposal time."""
		todo = self._make_todo()
		action = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"entity_type": "ToDo",
				"entity_name": todo.name,
				"action_class": "korkem_ai.korkem_ai.utils.test_actions.set_todo_description",
				"action_data": {"todo": todo.name, "description": "should not apply"},
			}
		).insert()

		frappe.delete_doc("ToDo", todo.name, force=True)

		with self.assertRaises(frappe.ValidationError):
			action.approve()

		action.reload()
		self.assertEqual(action.status, "Pending")

	def test_reject(self):
		todo = self._make_todo()
		action = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"entity_type": "ToDo",
				"entity_name": todo.name,
				"action_class": "korkem_ai.korkem_ai.utils.test_actions.set_todo_description",
				"action_data": {"todo": todo.name, "description": "should not apply"},
			}
		).insert()

		action.reject(reason="Not needed")
		action.reload()

		self.assertEqual(action.status, "Rejected")
		self.assertEqual(frappe.parse_json(action.result_data).get("reason"), "Not needed")

		todo.reload()
		self.assertEqual(todo.description, "original")

	def test_expire_stale_pending_actions(self):
		from korkem_ai.korkem_ai.doctype.pending_action.pending_action import (
			expire_stale_pending_actions,
		)

		todo = self._make_todo()
		action = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"entity_type": "ToDo",
				"entity_name": todo.name,
				"action_class": "korkem_ai.korkem_ai.utils.test_actions.set_todo_description",
				"action_data": {"todo": todo.name, "description": "too late"},
				"expires_at": add_to_date(now_datetime(), hours=-1),
			}
		).insert()

		expired_names = expire_stale_pending_actions()
		self.assertIn(action.name, expired_names)

		action.reload()
		self.assertEqual(action.status, "Expired")
