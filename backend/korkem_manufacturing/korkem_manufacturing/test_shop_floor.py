# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import production, setup, shop_floor


class TestShopFloor(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		setup.provision()

	def tearDown(self):
		frappe.db.rollback()

	def _deal(self):
		organization = frappe.get_doc(
			{"doctype": "CRM Organization", "organization_name": "Shop Floor Buyer LLC"}
		).insert()
		return frappe.get_doc(
			{"doctype": "CRM Deal", "organization": organization.name, "status": "Proposal/Quotation"}
		).insert().name

	def _order_with_task(self):
		result = production.create_production_order_for_deal(deal=self._deal())
		return result["work_order"], result["task"]

	# --- completion ---

	def test_complete_task_marks_it_done(self):
		_, task = self._order_with_task()

		shop_floor.complete_task(task)

		self.assertEqual(frappe.db.get_value("CRM Task", task, "status"), "Done")

	def test_complete_task_appends_notes(self):
		_, task = self._order_with_task()

		shop_floor.complete_task(task, notes="Edge banding finished, 2 panels rejected")

		description = frappe.db.get_value("CRM Task", task, "description")
		self.assertIn("2 panels rejected", description)

	def test_completing_twice_is_rejected(self):
		_, task = self._order_with_task()
		shop_floor.complete_task(task)

		with self.assertRaises(frappe.exceptions.ValidationError):
			shop_floor.complete_task(task)

	# --- the event ---

	def test_completion_is_recorded_on_the_work_order(self):
		work_order, task = self._order_with_task()

		shop_floor.complete_task(task)

		comments = frappe.get_all(
			"Comment",
			filters={"reference_doctype": "Work Order", "reference_name": work_order},
			fields=["content"],
		)
		self.assertTrue(
			any("Production task completed" in c.content for c in comments),
			f"No completion comment on {work_order}; got {comments}",
		)

	def test_desk_status_change_fires_the_same_event(self):
		"""A worker flipping status in the UI must behave like the API call."""
		work_order, task = self._order_with_task()

		doc = frappe.get_doc("CRM Task", task)
		doc.status = "Done"
		doc.save()

		comments = frappe.get_all(
			"Comment",
			filters={"reference_doctype": "Work Order", "reference_name": work_order},
			fields=["content"],
		)
		self.assertTrue(any("Production task completed" in c.content for c in comments))

	def test_event_does_not_refire_on_unrelated_resave(self):
		work_order, task = self._order_with_task()
		shop_floor.complete_task(task)

		doc = frappe.get_doc("CRM Task", task)
		doc.priority = "High"
		doc.save()

		comments = frappe.get_all(
			"Comment",
			filters={"reference_doctype": "Work Order", "reference_name": work_order},
			fields=["content"],
		)
		completions = [c for c in comments if "Production task completed" in c.content]
		self.assertEqual(len(completions), 1, "Completion event fired more than once")

	def test_non_production_task_is_ignored(self):
		"""CRM Tasks on deals/leads must not be treated as shop-floor work."""
		deal = self._deal()
		task = frappe.get_doc(
			{
				"doctype": "CRM Task",
				"title": "Call the customer back",
				"status": "Todo",
				"reference_doctype": "CRM Deal",
				"reference_docname": deal,
			}
		).insert()

		task.status = "Done"
		task.save()  # must not raise

		self.assertFalse(shop_floor.is_production_task(task))

	# --- lookup ---

	def test_get_tasks_for_work_order(self):
		work_order, task = self._order_with_task()

		self.assertEqual(shop_floor.get_tasks_for_work_order(work_order), [task])
