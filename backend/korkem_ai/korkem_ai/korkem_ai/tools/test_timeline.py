# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""One customer, end to end — and everything the timeline must refuse to invent.

Most of this file is about absence. A stage with no document must say so, a
stage the caller cannot see must say something different, and neither may be
filled in from a name that looks similar. On this bench that last one is not
hypothetical: there are 2094 CRM deals and none belongs to a customer this
factory produces for, so any name-similarity join would manufacture a
relationship out of nothing.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import seed_demo

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401

TIMELINE = "crm.customer_timeline"
PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"
CUSTOMER = "Мебель Астана"
BOARD = "ДСП 16мм"


class _TimelineTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		if not frappe.db.exists("Customer", CUSTOMER):
			self.skipTest("seed_demo has not been run on this site")
		seed_demo.seed_users()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def as_user(self, user, customer=CUSTOMER):
		frappe.set_user(user)
		try:
			return registry.execute(TIMELINE, {"customer": customer})
		finally:
			frappe.set_user("Administrator")

	def timeline(self, user=PLANNER, customer=CUSTOMER):
		result = self.as_user(user, customer)
		self.assertTrue(result["ok"], result.get("error"))
		return result["data"]


class TestTheChainIsFollowedByLink(_TimelineTestCase):
	def test_the_customers_orders_are_their_own(self):
		story = self.timeline()

		self.assertEqual(story["customer"], CUSTOMER)
		self.assertEqual(story["sales"]["status"], "present")
		for order in story["sales"]["orders"]:
			with self.subTest(order=order["sales_order"]):
				self.assertEqual(
					frappe.db.get_value("Sales Order", order["sales_order"], "customer"), CUSTOMER
				)

	def test_production_hangs_off_the_sales_order(self):
		story = self.timeline()
		orders = {row["sales_order"] for row in story["sales"]["orders"]}

		self.assertEqual(story["production"]["status"], "present")
		for job in story["production"]["work_orders"]:
			with self.subTest(job=job["work_order"]):
				self.assertIn(job["sales_order"], orders)
				self.assertEqual(
					frappe.db.get_value("Work Order", job["work_order"], "sales_order"),
					job["sales_order"],
				)

	def test_production_progress_is_the_work_orders_own(self):
		job = self.timeline()["production"]["work_orders"][0]

		row = frappe.db.get_value(
			"Work Order", job["work_order"], ["qty", "produced_qty", "status"], as_dict=True
		)
		self.assertEqual(job["qty"], row["qty"])
		self.assertEqual(job["produced_qty"], row["produced_qty"])
		self.assertEqual(job["status"], row["status"])
		self.assertEqual(job["remaining_qty"], row["qty"] - row["produced_qty"])

	def test_the_current_stage_comes_from_the_routing(self):
		job = self.timeline()["production"]["work_orders"][0]

		self.assertEqual(len(job["operations"]), 7)
		self.assertIsNotNone(job["current_operation"])
		self.assertEqual(job["operations"][0]["sequence"], 1)

	def test_the_shortage_is_the_orders_own(self):
		from korkem_ai.korkem_ai.tools.procurement import material_shortage

		story = self.timeline()
		order = story["sales"]["orders"][0]["sales_order"]

		frappe.set_user(PLANNER)
		try:
			direct = material_shortage(order)["not_on_the_shelf"]
		finally:
			frappe.set_user("Administrator")

		self.assertEqual(
			{row["item_code"] for row in story["materials"]["shortages"]},
			{row["item_code"] for row in direct},
		)


class TestAbsenceIsReportedNotInvented(_TimelineTestCase):
	def test_a_stage_with_no_document_says_none(self):
		"""Nothing has been shipped and nothing bought, and the timeline says
		exactly that rather than leaving the section out."""
		story = self.timeline()

		self.assertEqual(story["delivery"]["status"], "none")
		self.assertIn("nothing has been shipped", story["delivery"]["note"])

	def test_a_customer_with_no_crm_deal_is_not_matched_by_name(self):
		"""There are two thousand deals on this bench and none is this
		customer's. A name-similarity join would invent one."""
		story = self.timeline(user="Administrator")

		self.assertEqual(story["crm"]["status"], "none")
		self.assertIsNone(story["crm"]["linked_by"])
		self.assertGreater(frappe.db.count("CRM Deal"), 100, "the fixture no longer has deals")

	def test_no_access_is_a_different_answer_to_no_document(self):
		"""The distinction this tool exists to make. A planner holds no CRM
		role, so «нет сделки» would be a claim they cannot support."""
		as_planner = self.timeline()["crm"]
		as_admin = self.timeline(user="Administrator")["crm"]

		self.assertEqual(as_planner["status"], "no_access")
		self.assertIn("permission", as_planner["note"])
		self.assertEqual(as_admin["status"], "none")
		self.assertNotEqual(as_planner["status"], as_admin["status"])

	def test_a_customer_with_no_orders_reports_none_rather_than_failing(self):
		frappe.set_user("Administrator")
		quiet = frappe.get_doc(
			{
				"doctype": "Customer",
				"customer_name": "Тихий Клиент",
				"customer_type": "Company",
				"customer_group": frappe.db.get_value("Customer Group", {"is_group": 0}, "name"),
				"territory": frappe.db.get_value("Territory", {"is_group": 0}, "name"),
			}
		).insert(ignore_permissions=True)
		frappe.db.commit()
		self.addCleanup(self._remove_customer, quiet.name)

		story = self.timeline(customer="Тихий Клиент")

		self.assertEqual(story["sales"]["status"], "none")
		self.assertEqual(story["production"]["status"], "none")
		self.assertEqual(story["procurement"]["status"], "none")
		self.assertEqual(story["issues"], [])

	def test_an_unknown_customer_is_a_sentence_not_a_traceback(self):
		result = self.as_user(PLANNER, customer="Никого Такого Нет")

		self.assertFalse(result["ok"])
		self.assertIn("No customer matching", result["error"]["message"])

	def _remove_customer(self, name):
		frappe.set_user("Administrator")
		if frappe.db.exists("Customer", name):
			frappe.delete_doc("Customer", name, force=1, ignore_permissions=True)
		frappe.db.commit()


class TestProcurementIsLinkedThroughTheRequest(_TimelineTestCase):
	def test_a_request_and_its_order_appear_against_the_right_sales_order(self):
		frappe.set_user(PLANNER)
		try:
			order = frappe.get_all(
				"Sales Order", filters={"customer": CUSTOMER, "docstatus": 1}, pluck="name"
			)[0]
			request = registry.execute(
				"inventory.create_material_request",
				{"sales_order": order, "items": [{"item_code": BOARD, "qty": 4}]},
			)["data"]["material_request"]
			placed = registry.execute(
				"procurement.create_purchase_order", {"material_request": request}
			)["data"]
		finally:
			frappe.set_user("Administrator")
		self.addCleanup(self._undo_procurement)

		story = self.timeline()

		self.assertEqual(story["procurement"]["status"], "present")
		entry = story["procurement"]["requests"][0]
		self.assertEqual(entry["material_request"], request)
		self.assertEqual(entry["sales_order"], order)
		self.assertEqual(entry["purchase_orders"][0]["purchase_order"], placed["purchase_order"])
		self.assertEqual(entry["purchase_orders"][0]["supplier"], placed["supplier"])

	def test_a_request_with_no_purchase_order_is_raised_as_an_issue(self):
		frappe.set_user(PLANNER)
		try:
			order = frappe.get_all(
				"Sales Order", filters={"customer": CUSTOMER, "docstatus": 1}, pluck="name"
			)[0]
			registry.execute(
				"inventory.create_material_request",
				{"sales_order": order, "items": [{"item_code": BOARD, "qty": 4}]},
			)
		finally:
			frappe.set_user("Administrator")
		self.addCleanup(self._undo_procurement)

		kinds = {issue["kind"] for issue in self.timeline()["issues"]}

		self.assertIn("not_ordered", kinds)

	def _undo_procurement(self):
		frappe.set_user("Administrator")
		for doctype in ("Purchase Receipt", "Purchase Order", "Material Request"):
			for name in frappe.get_all(doctype, pluck="name"):
				doc = frappe.get_doc(doctype, name)
				if doc.docstatus == 1:
					doc.cancel()
				frappe.delete_doc(doctype, name, force=1, ignore_permissions=True)
		frappe.db.commit()


class TestScopeAndPermissions(_TimelineTestCase):
	def test_it_takes_no_company(self):
		self.assertNotIn("company", registry.get(TIMELINE).input_schema["properties"])

	def test_it_is_a_read_needing_no_confirmation(self):
		spec = registry.get(TIMELINE)

		self.assertIs(spec.risk, registry.Risk.READ)
		self.assertFalse(spec.requires_confirmation)

	def test_another_companys_orders_never_appear(self):
		story = self.timeline()
		shown = {row["sales_order"] for row in story["sales"]["orders"]}

		for name in shown:
			with self.subTest(order=name):
				self.assertEqual(frappe.db.get_value("Sales Order", name, "company"), "KORKEM")

	def test_a_viewer_sees_sales_but_not_purchasing(self):
		"""`Sales User` grants no Material Request permission, so the viewer's
		procurement section is a blind spot rather than an empty one."""
		story = self.timeline(user=VIEWER)

		self.assertEqual(story["sales"]["status"], "present")
		self.assertEqual(story["procurement"]["status"], "no_access")
