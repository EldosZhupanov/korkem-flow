# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Дизайн — этап, на котором «готово» обычно врёт."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import acceptance as acceptance_service
from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import design as service
from korkem_manufacturing.services import enquiry as enquiry_service
from korkem_manufacturing.services import proposal as proposal_service


class TestDesignTask(IntegrationTestCase):
	def setUp(self):
		found = frappe.get_all("Item", filters={"is_sales_item": 1}, pluck="name", limit=1)
		if not found:
			self.skipTest("на этом стенде нет ни одной продаваемой позиции")
		capture = capture_service.record(
			text="Кухня",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["capture"]
		enquiry = enquiry_service.convert(capture=capture)["enquiry"]
		quotation = proposal_service.draft(
			enquiry=enquiry, items=[{"item_code": found[0], "qty": 1, "rate": 100000}]
		)["quotation"]
		self.order = acceptance_service.accept(
			quotation=quotation,
			deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 21),
		)["sales_order"]
		self.due = frappe.utils.add_days(frappe.utils.nowdate(), 5)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _attach(self):
		frappe.get_doc(
			{
				"doctype": "File",
				"file_name": "чертёж.dxf",
				"attached_to_doctype": "Sales Order",
				"attached_to_name": self.order,
				"content": "чертёж",
				"is_private": 1,
			}
		).insert(ignore_permissions=True)

	def test_a_design_task_carries_a_deadline_and_a_person(self):
		result = service.assign(
			sales_order=self.order, designer="Administrator", due_on=self.due
		)

		task = frappe.get_doc("CRM Task", result["task"])
		self.assertEqual(task.assigned_to, "Administrator")
		self.assertEqual(task.reference_docname, self.order)
		self.assertEqual(frappe.utils.getdate(task.due_date), frappe.utils.getdate(self.due))

	def test_a_task_without_a_deadline_is_refused(self):
		"""Задача без срока — это пожелание."""
		with self.assertRaises(frappe.ValidationError):
			service.assign(sales_order=self.order, designer="Administrator", due_on="")

	def test_assigning_twice_does_not_create_two_designs(self):
		first = service.assign(
			sales_order=self.order, designer="Administrator", due_on=self.due
		)
		second = service.assign(
			sales_order=self.order, designer="Administrator", due_on=self.due
		)

		self.assertEqual(second["status"], "already_assigned")
		self.assertEqual(second["task"], first["task"])


class TestGotovoMustBeProven(IntegrationTestCase):
	"""Задача, отмеченная выполненной без чертежа, — самая дорогая ложь."""

	def setUp(self):
		found = frappe.get_all("Item", filters={"is_sales_item": 1}, pluck="name", limit=1)
		if not found:
			self.skipTest("на этом стенде нет ни одной продаваемой позиции")
		capture = capture_service.record(
			text="Шкаф",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["capture"]
		enquiry = enquiry_service.convert(capture=capture)["enquiry"]
		quotation = proposal_service.draft(
			enquiry=enquiry, items=[{"item_code": found[0], "qty": 1, "rate": 90000}]
		)["quotation"]
		self.order = acceptance_service.accept(
			quotation=quotation,
			deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 14),
		)["sales_order"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_delivering_with_nothing_attached_is_refused(self):
		service.assign(
			sales_order=self.order,
			designer="Administrator",
			due_on=frappe.utils.add_days(frappe.utils.nowdate(), 3),
		)

		with self.assertRaises(frappe.ValidationError):
			service.deliver(sales_order=self.order)

	def test_the_refusal_says_what_is_missing(self):
		"""Дизайнер, увидевший «приложите чертёж», приложит его за минуту."""
		try:
			service.deliver(sales_order=self.order)
		except frappe.ValidationError as refusal:
			self.assertIn("файл", str(refusal).lower())
		else:
			self.fail("отказа не произошло")

	def test_an_attached_drawing_closes_the_task(self):
		assigned = service.assign(
			sales_order=self.order,
			designer="Administrator",
			due_on=frappe.utils.add_days(frappe.utils.nowdate(), 3),
		)
		frappe.get_doc(
			{
				"doctype": "File",
				"file_name": "чертёж.dxf",
				"attached_to_doctype": "Sales Order",
				"attached_to_name": self.order,
				"content": "чертёж",
				"is_private": 1,
			}
		).insert(ignore_permissions=True)

		result = service.deliver(sales_order=self.order)

		self.assertEqual(result["status"], "delivered")
		self.assertEqual(result["task_closed"], assigned["task"])
		self.assertEqual(
			frappe.db.get_value("CRM Task", assigned["task"], "status"), "Done"
		)


class TestScope(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		import inspect

		self.assertNotIn("company", inspect.signature(service.assign).parameters)
		self.assertNotIn("company", inspect.signature(service.deliver).parameters)

	def test_an_order_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.PermissionError):
			service.deliver(sales_order="does-not-exist")
