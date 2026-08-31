# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import dashboard


class TestDashboard(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def _sales_user(self) -> str:
		email = "dashboard.rep@korkem.test"
		if not frappe.db.exists("User", email):
			user = frappe.get_doc(
				{
					"doctype": "User",
					"email": email,
					"first_name": "Dashboard",
					"send_welcome_email": 0,
					"roles": [{"role": "Sales User"}],
				}
			)
			user.insert(ignore_permissions=True)
		return email

	def _pending_action(self):
		"""A Pending Action needs a real target: entity_name is a Dynamic Link."""
		organization = frappe.get_doc(
			{"doctype": "CRM Organization", "organization_name": "Dashboard Buyer LLC"}
		).insert()
		deal = frappe.get_doc(
			{
				"doctype": "CRM Deal",
				"organization": organization.name,
				"status": "Proposal/Quotation",
			}
		).insert()

		return frappe.get_doc(
			{
				"doctype": "Pending Action",
				"agent_skill": "create_quote",
				"status": "Pending",
				"entity_type": "CRM Deal",
				"entity_name": deal.name,
				"action_class": "CreateQuoteAction",
			}
		).insert()

	# --- shape ---

	def test_summary_reports_every_metric(self):
		summary = dashboard.get_summary()

		self.assertEqual(summary["user"], "Administrator")
		self.assertEqual(
			set(summary["metrics"]),
			{
				"open_deals",
				"open_leads",
				"my_open_tasks",
				"overdue_tasks",
				"pending_actions",
				"work_orders_in_progress",
			},
		)
		self.assertIsInstance(summary["attention"], list)

	def test_counts_are_integers_for_a_user_who_may_read(self):
		summary = dashboard.get_summary()

		for name in ("open_deals", "open_leads", "pending_actions"):
			self.assertIsInstance(summary["metrics"][name], int, name)

	# --- permissions ---

	def test_metric_is_none_not_zero_when_the_caller_may_not_look(self):
		"""The distinction this endpoint exists to preserve.

		A Sales User cannot read Pending Action -- resolving an approval is a
		Sales *Manager*'s job. Reporting 0 would state, with total confidence,
		something the caller has no standing to know.

		Work Order is deliberately *not* checked here: korkem_ai.permissions
		grants Sales User read on it so a salesperson can answer "when does my
		kitchen ship". This test asserted the opposite until that grant landed.
		"""
		frappe.set_user(self._sales_user())

		metrics = dashboard.get_summary()["metrics"]

		self.assertIsNone(metrics["pending_actions"])

	def test_refused_counts_leave_no_error_message_on_a_successful_call(self):
		"""A 200 must not carry `_server_messages`.

		Frappe queues an "Insufficient Permission" message on the way out of every
		refused read. Clients parse that field and show it as an error, so leaving
		it attached turns a working dashboard into a screen full of red.
		"""
		frappe.set_user(self._sales_user())
		frappe.local.message_log = []

		dashboard.get_summary()

		self.assertEqual(frappe.get_message_log(), [])

	def test_missing_doctype_is_not_an_error(self):
		self.assertIsNone(dashboard._count("Doctype That Does Not Exist", []))
		self.assertEqual(dashboard._safe_list("Doctype That Does Not Exist"), [])

	# --- attention list ---

	def test_attention_puts_pending_actions_before_overdue_tasks(self):
		"""A Pending Action blocks an agent waiting on a human; nothing else in
		the system moves until it is resolved. Overdue work is merely late."""
		frappe.get_doc(
			{
				"doctype": "CRM Task",
				"title": "Long overdue task",
				"status": "Todo",
				"due_date": "2020-01-01 09:00:00",
			}
		).insert()
		self._pending_action()

		kinds = [item["kind"] for item in dashboard.get_summary()["attention"]]

		self.assertIn("pending_action", kinds)
		self.assertEqual(kinds[0], "pending_action")

	def test_attention_is_capped(self):
		for index in range(dashboard.ATTENTION_LIMIT + 3):
			frappe.get_doc(
				{
					"doctype": "CRM Task",
					"title": f"Overdue {index}",
					"status": "Todo",
					"due_date": "2020-01-01 09:00:00",
				}
			).insert()

		attention = dashboard.get_summary()["attention"]

		self.assertLessEqual(len(attention), dashboard.ATTENTION_LIMIT)
