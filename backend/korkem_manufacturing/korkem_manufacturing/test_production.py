# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import production, setup


class TestProduction(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		# Real company + BOM, not fixtures: a Work Order cannot be submitted
		# without them, so the flow under test would be untestable otherwise.
		setup.provision()

	def tearDown(self):
		frappe.db.rollback()

	def _deal(self):
		organization = frappe.get_doc(
			{"doctype": "CRM Organization", "organization_name": "Facade Buyer LLC"}
		).insert()
		return frappe.get_doc(
			{"doctype": "CRM Deal", "organization": organization.name, "status": "Proposal/Quotation"}
		).insert().name

	def _worker(self):
		email = "worker@korkem.local"
		if not frappe.db.exists("User", email):
			frappe.get_doc(
				{"doctype": "User", "email": email, "first_name": "Shop Worker"}
			).insert(ignore_permissions=True)
		return email

	# --- work order ---

	def test_creates_submitted_work_order_linked_to_deal(self):
		deal = self._deal()

		name = production.create_production_order(deal=deal, qty=5)

		work_order = frappe.get_doc("Work Order", name)
		self.assertEqual(work_order.docstatus, 1, "Work Order must be submitted, not draft")
		self.assertEqual(work_order.originating_deal, deal)
		self.assertEqual(work_order.qty, 5)
		self.assertEqual(work_order.production_item, setup.FINISHED_ITEM)
		self.assertEqual(work_order.company, setup.COMPANY)

	def test_work_order_explodes_bom_into_required_items(self):
		"""Proof the BOM is really driving material requirements."""
		name = production.create_production_order(deal=self._deal(), qty=2)

		work_order = frappe.get_doc("Work Order", name)
		required = {row.item_code: row.required_qty for row in work_order.required_items}
		self.assertEqual(set(required), set(setup.RAW_ITEMS))
		# BOM is 1 of each raw item per unit, so qty=2 must require 2 of each.
		self.assertEqual(set(required.values()), {2})

	def test_rejects_deal_that_does_not_exist(self):
		with self.assertRaises(frappe.exceptions.LinkValidationError):
			production.create_production_order(deal="CRM-DEAL-does-not-exist")

	# --- task ---

	def test_task_references_work_order_and_worker(self):
		work_order = production.create_production_order(deal=self._deal())
		worker = self._worker()

		task_name = production.assign_production_task(work_order, assigned_to=worker)

		task = frappe.get_doc(production.TASK_DOCTYPE, task_name)
		self.assertEqual(task.reference_doctype, "Work Order")
		self.assertEqual(task.reference_docname, work_order)
		self.assertEqual(task.assigned_to, worker)
		self.assertEqual(task.status, "Todo")
		self.assertIn(work_order, task.title)

	# --- combined command ---

	def test_command_creates_order_and_task_together(self):
		deal = self._deal()

		result = production.create_production_order_for_deal(deal=deal, qty=3, assigned_to=self._worker())

		self.assertTrue(frappe.db.exists("Work Order", result["work_order"]))
		task = frappe.get_doc(production.TASK_DOCTYPE, result["task"])
		self.assertEqual(task.reference_docname, result["work_order"])
		self.assertEqual(
			frappe.db.get_value("Work Order", result["work_order"], "originating_deal"), deal
		)
