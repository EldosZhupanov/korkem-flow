# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Company boundary of Capture -> Customer -> Opportunity -> CRM Task.

The resource assertions call the same ``frappe.client`` functions as
``/api/resource``.  The endpoint assertions additionally cross Frappe's WSGI
router with a real session id; a direct Python call is not accepted as proof of
an HTTP boundary.
"""

from __future__ import annotations

import json

import frappe
from frappe.auth import CookieManager, LoginManager
from frappe.tests.test_api import FrappeAPITestCase
from frappe.utils import set_request

from korkem_ai.korkem_ai import onboarding
from korkem_ai.korkem_ai.tools import foreign_fixture
from korkem_manufacturing.api import enquiry as enquiry_api
from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import enquiry as enquiry_service

COMPANY_A = "KORKEM"
USER_A = "enquiry.manager.a@korkem.test"
USER_B = "enquiry.manager.b@korkem.test"


class TestEnquiryCompanyIsolation(
	foreign_fixture.UsesForeignCompany, FrappeAPITestCase
):
	"""A company-A manager sees no company-B link except the shared Customer."""

	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		foreign = foreign_fixture.ensure()
		onboarding.create_employee(
			USER_A,
			"Enquiry Manager A",
			roles=["Sales Manager", "Sales User"],
			company=COMPANY_A,
		)
		onboarding.create_employee(
			USER_B,
			"Enquiry Manager B",
			roles=["Sales Manager", "Sales User"],
			company=foreign["company"],
		)
		cls.records_a = cls._make_chain(USER_A, "A", assign=True)
		cls.records_b = cls._make_chain(USER_B, "B", assign=True)
		cls.unconverted_a = cls._make_capture(USER_A, "A pending")
		frappe.set_user("Administrator")
		frappe.db.commit()
		cls.sid_a = cls._sid_for(USER_A)

	@classmethod
	def _make_capture(cls, user: str, label: str) -> str:
		frappe.set_user(user)
		return capture_service.record(
			text=f"Isolation {label}: замерить кухню",
			understood={"customer_hint": f"Isolation Customer {label}"},
		)["capture"]

	@classmethod
	def _make_chain(cls, user: str, label: str, *, assign: bool) -> dict:
		capture = cls._make_capture(user, label)
		result = enquiry_service.convert(
			capture=capture,
			assign_measurer=user if assign else None,
			measure_on=frappe.utils.add_days(frappe.utils.nowdate(), 2),
		)
		return {
			"Capture": capture,
			"Customer": result["customer"],
			"Opportunity": result["enquiry"],
			"CRM Task": str(result["task"]),
		}

	@classmethod
	def _sid_for(cls, user: str) -> str:
		original_request = getattr(frappe.local, "request", None)
		set_request(path="/")
		try:
			frappe.local.cookie_manager = CookieManager()
			frappe.local.login_manager = LoginManager()
			frappe.local.login_manager.login_as(user)
			return frappe.session.sid
		finally:
			frappe.local.request = original_request
			frappe.set_user("Administrator")

	@classmethod
	def tearDownClass(cls):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		# HTTP runs in another connection. Before the fix, the deliberately-red
		# requests committed documents the endpoint should never have created, so
		# cleanup must own every row carrying this fixture's marker rather than only
		# the four names created in setUpClass.
		captures = frappe.get_all(
			"Capture",
			filters={
				"spoken_text": [
					"like",
					"Isolation %",
				]
			},
			fields=["name", "enquiry"],
		)
		# One fixed marker came from the first red run, before markers were made
		# unique. It is still ours and is removed once here.
		for name in frappe.get_all(
			"Capture",
			filters={"spoken_text": "Не отправлять это в другую компанию"},
			pluck="name",
		):
			if name not in {row.name for row in captures}:
				captures.append(frappe._dict(name=name, enquiry=None))

		capture_names = [row.name for row in captures]
		tasks = (
			frappe.get_all(
				"CRM Task",
				filters={
					"reference_doctype": "Capture",
					"reference_docname": ["in", capture_names],
				},
				pluck="name",
			)
			if capture_names
			else []
		)
		if tasks:
			frappe.db.delete(
				"ToDo", {"reference_type": "CRM Task", "reference_name": ["in", tasks]}
			)
		for task in tasks:
			frappe.delete_doc("CRM Task", task, force=True, ignore_permissions=True)

		opportunities = {row.enquiry for row in captures if row.enquiry}
		for row in captures:
			if frappe.db.exists("Capture", row.name):
				frappe.delete_doc("Capture", row.name, force=True, ignore_permissions=True)
		for opportunity in opportunities:
			for comment in frappe.get_all(
				"Comment",
				filters={
					"reference_doctype": "Opportunity",
					"reference_name": opportunity,
				},
				pluck="name",
			):
				frappe.delete_doc("Comment", comment, force=True, ignore_permissions=True)
			if frappe.db.exists("Opportunity", opportunity):
				frappe.delete_doc(
					"Opportunity", opportunity, force=True, ignore_permissions=True
				)
		for customer in frappe.get_all(
			"Customer",
			filters={"customer_name": ["like", "Isolation Customer %"]},
			pluck="name",
		):
			frappe.delete_doc("Customer", customer, force=True, ignore_permissions=True)
		frappe.db.delete("ToDo", {"allocated_to": ["in", [USER_A, USER_B]]})
		for user in (USER_A, USER_B):
			for permission in frappe.get_all(
				"User Permission", filters={"user": user}, pluck="name"
			):
				frappe.delete_doc(
					"User Permission", permission, force=True, ignore_permissions=True
				)
			if frappe.db.exists("User", user):
				frappe.delete_doc("User", user, force=True, ignore_permissions=True)
		frappe.db.commit()
		super().tearDownClass()

	def setUp(self):
		frappe.set_user("Administrator")

	def tearDown(self):
		frappe.set_user("Administrator")
		super().tearDown()

	def _assert_resource_hidden(self, doctype: str) -> None:
		own = self.records_a[doctype]
		foreign = self.records_b[doctype]
		frappe.set_user(USER_A)
		try:
			rows = frappe.client.get_list(
				doctype,
				fields=["name"],
				filters={"name": ["in", [own, foreign]]},
				limit_page_length=2,
			)
			visible = {str(row.name) for row in rows}
			own_doc = frappe.client.get(doctype, own)
			foreign_visible = True
			try:
				frappe.client.get(doctype, foreign)
			except (frappe.PermissionError, frappe.DoesNotExistError):
				foreign_visible = False
		finally:
			frappe.set_user("Administrator")

		self.assertIn(str(own), visible, "positive control cannot list its own row")
		self.assertEqual(str(own_doc.name), str(own))
		self.assertNotIn(str(foreign), visible, f"LEAK: foreign {doctype} in list")
		self.assertFalse(foreign_visible, f"LEAK: foreign {doctype} by name")

	def test_capture_is_hidden_in_resource_list_and_named_get(self):
		self._assert_resource_hidden("Capture")

	def test_opportunity_is_hidden_in_resource_list_and_named_get(self):
		self._assert_resource_hidden("Opportunity")

	def test_capture_task_is_hidden_in_resource_list_and_named_get(self):
		self._assert_resource_hidden("CRM Task")

	def test_customer_is_an_explicit_shared_master(self):
		"""Current model: a Customer belongs to the node, not one Company."""
		foreign = self.records_b["Customer"]
		frappe.set_user(USER_A)
		try:
			doc = frappe.client.get("Customer", foreign)
			candidates = enquiry_api.customer_candidates("Isolation Customer B")
		finally:
			frappe.set_user("Administrator")
		self.assertEqual(doc.name, foreign)
		self.assertIn(foreign, {row["name"] for row in candidates["candidates"]})

	def test_service_and_python_endpoint_refuse_a_foreign_capture(self):
		frappe.set_user(USER_A)
		try:
			with self.assertRaises(frappe.PermissionError):
				enquiry_service.convert(capture=self.records_b["Capture"])
			with self.assertRaises(frappe.PermissionError):
				enquiry_api.convert(capture=self.records_b["Capture"])
		finally:
			frappe.set_user("Administrator")

	def test_http_resource_and_convert_endpoint_refuse_foreign_rows(self):
		for doctype in ("Capture", "Opportunity", "CRM Task"):
			response = self.get(
				self.resource(doctype, self.records_b[doctype]), {"sid": self.sid_a}
			)
			self.assertIn(response.status_code, (403, 404), f"HTTP LEAK: {doctype}")

		response = self.post(
			self.method("korkem_manufacturing.api.enquiry.convert"),
			{"sid": self.sid_a, "capture": self.records_b["Capture"]},
		)
		self.assertIn(response.status_code, (403, 404))

	def test_http_capture_stats_count_only_company_a(self):
		since = frappe.utils.add_days(frappe.utils.nowdate(), -1)
		expected_caught = frappe.db.count(
			"Capture", {"company": COMPANY_A, "creation": [">=", since]}
		)
		all_caught = frappe.db.count("Capture", {"creation": [">=", since]})
		all_captures = frappe.get_all(
			"Capture",
			filters={"name": ["in", [self.records_a["Capture"], self.records_b["Capture"]]]},
			pluck="name",
		)
		self.assertEqual(len(all_captures), 2)
		self.assertGreater(all_caught, expected_caught, "foreign control was not counted")

		response = self.get(
			self.method("korkem_manufacturing.api.capture.stats"),
			{"sid": self.sid_a, "days": 1},
		)
		self.assertEqual(response.status_code, 200)
		self.assertEqual(response.json["message"]["caught"], expected_caught)

	def test_http_capture_cannot_be_assigned_to_the_other_company(self):
		text = f"Isolation rejected {frappe.generate_hash(length=8)}"
		response = self.post(
			self.method("korkem_manufacturing.api.capture.record"),
			{
				"sid": self.sid_a,
				"text": text,
				"assign_to": USER_B,
			},
		)
		self.assertIn(response.status_code, (403, 422))
		self.assertFalse(
			frappe.db.exists("Capture", {"spoken_text": text}),
			"a rejected assignment left a partial Capture",
		)

	def test_http_enquiry_cannot_be_assigned_to_a_foreign_measurer(self):
		response = self.post(
			self.method("korkem_manufacturing.api.enquiry.convert"),
			{
				"sid": self.sid_a,
				"capture": self.unconverted_a,
				"assign_measurer": USER_B,
				"measure_on": frappe.utils.add_days(frappe.utils.nowdate(), 2),
			},
		)
		self.assertIn(response.status_code, (403, 422))
		pending = frappe.get_doc("Capture", self.unconverted_a)
		self.assertNotEqual(pending.status, "Converted")
		self.assertFalse(pending.enquiry)
		self.assertFalse(pending.task)

	def test_http_customer_candidates_follow_the_shared_master_decision(self):
		response = self.get(
			self.method("korkem_manufacturing.api.enquiry.customer_candidates"),
			{"sid": self.sid_a, "name_said": "Isolation Customer B"},
		)
		self.assertEqual(response.status_code, 200)
		self.assertIn(
			self.records_b["Customer"],
			{row["name"] for row in response.json["message"]["candidates"]},
		)
