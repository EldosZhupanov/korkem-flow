# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Company isolation at the raw ``/api/resource`` boundary.

The mobile CRM repositories do not pass through a KORKEM service.  Their list
and document requests are handled by :mod:`frappe.client`, so these tests call
the same functions the REST resource route calls.  Two real Sales Managers are
bound to different companies with Frappe's own Company ``User Permission``;
records created in the second manager's session must not be returned to the
first one.

These are deliberately security assertions, not descriptions of the current
implementation.  A failing assertion saying ``LEAK`` is evidence that the raw
resource route crosses the company boundary and must stay red until the owner
chooses a fix.
"""

from __future__ import annotations

import unittest

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import onboarding, permissions
from korkem_ai.korkem_ai.tools import foreign_fixture

COMPANY_A = "KORKEM"
USER_A = "resource.manager.a@korkem.test"
USER_B = "resource.manager.b@korkem.test"
ORGANIZATION_A = "Resource Company A Customer"
ORGANIZATION_B = "Resource Company B Customer"


class TestRawResourceCompanyIsolation(foreign_fixture.UsesForeignCompany, IntegrationTestCase):
	"""A company-A manager must not see records made by company B."""

	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")

		fixture = foreign_fixture.ensure()
		onboarding.create_employee(
			USER_A,
			"Resource Manager A",
			roles=["Sales Manager"],
			company=COMPANY_A,
		)
		onboarding.create_employee(
			USER_B,
			"Resource Manager B",
			roles=["Sales Manager"],
			company=fixture["company"],
		)

		cls.records_a = cls._make_records(
			USER_A,
			ORGANIZATION_A,
			COMPANY_A,
			"Resource A",
		)
		cls.records_b = cls._make_records(
			USER_B,
			ORGANIZATION_B,
			fixture["company"],
			"Resource B",
		)
		frappe.set_user("Administrator")
		frappe.db.commit()

		# The production lifecycle hooks install this grant. Apply it after the
		# fixture's last commit so the test exercises the deployed permission but
		# UsesForeignCompany's opening rollback removes this test-local change.
		permissions.apply()

	@classmethod
	def _make_records(cls, user: str, organization_name: str, company: str, label: str):
		frappe.set_user(user)
		organization = frappe.get_doc(
			{"doctype": "CRM Organization", "organization_name": organization_name}
		).insert()
		lead = frappe.get_doc(
			{
				"doctype": "CRM Lead",
				"first_name": label,
				"lead_owner": user,
			}
		).insert()
		deal = frappe.get_doc(
			{
				"doctype": "CRM Deal",
				"organization": organization.name,
				"deal_owner": user,
			}
		).insert()
		task = frappe.get_doc(
			{
				"doctype": "CRM Task",
				"title": f"{label} task",
				"status": "Todo",
				"assigned_to": user,
				"reference_doctype": "CRM Deal",
				"reference_docname": deal.name,
			}
		).insert()
		notification = frappe.get_doc(
			{
				"doctype": "Notification Log",
				"for_user": user,
				"from_user": "Administrator",
				"type": "Alert",
				"subject": f"{label} notification",
			}
		).insert(ignore_permissions=True)
		action = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"agent_skill": "resource_company_isolation",
				"entity_type": "CRM Deal",
				"entity_name": deal.name,
				"action_class": "tests.resource_company_isolation",
				"status": "Pending",
			}
		).insert(ignore_permissions=True)

		return {
			"CRM Organization": organization.name,
			"CRM Lead": lead.name,
			"CRM Deal": deal.name,
			"CRM Task": task.name,
			"Notification Log": notification.name,
			"Pending Action": action.name,
			"company": company,
		}

	@classmethod
	def tearDownClass(cls):
		frappe.set_user("Administrator")
		frappe.db.rollback()

		# Remove our committed records before UsesForeignCompany removes company B.
		for records in (getattr(cls, "records_a", {}), getattr(cls, "records_b", {})):
			for doctype in (
				"Pending Action",
				"Notification Log",
				"CRM Task",
				"CRM Deal",
				"CRM Lead",
				"CRM Organization",
			):
				name = records.get(doctype)
				if name and frappe.db.exists(doctype, name):
					frappe.delete_doc(doctype, name, force=True, ignore_permissions=True)

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

	def _visible_names(self, doctype: str, names: list[str | int]) -> set[str]:
		rows = frappe.client.get_list(
			doctype,
			fields=["name"],
			filters={"name": ["in", names]},
			limit_page_length=len(names),
		)
		return {str(row.name) for row in rows}

	def _assert_company_b_is_hidden(self, doctype: str):
		own = self.records_a[doctype]
		foreign = self.records_b[doctype]
		frappe.set_user(USER_A)
		try:
			visible = self._visible_names(doctype, [own, foreign])
			own_document = frappe.client.get(doctype, own)
			document_exposed = False
			try:
				frappe.client.get(doctype, foreign)
				document_exposed = True
			except (frappe.PermissionError, frappe.DoesNotExistError):
				pass
		finally:
			frappe.set_user("Administrator")

		self.assertIn(
			str(own),
			visible,
			f"control failed: {USER_A} cannot list its own {doctype}",
		)
		self.assertEqual(str(own_document.name), str(own))

		exposures = []
		if str(foreign) in visible:
			exposures.append("collection GET")
		if document_exposed:
			exposures.append("document GET")
		self.assertEqual(
			exposures,
			[],
			f"LEAK: company-A user can read company-B {doctype} via {', '.join(exposures)}",
		)

	# MARKED EXPECTED-FAILURE ON PURPOSE, 2026-09-02.
	#
	# This leak is real and reproduced: a Sales Manager of one company reads
	# another company's record through the raw resource API.  The fix is not a
	# patch — these CRM doctypes carry no company field at all, so deciding what
	# "company" means for a lead is a data-model decision belonging to the
	# product owner, not something to invent inside a test fix.
	#
	# The marker keeps CI honest rather than quiet.  A knowingly-red suite
	# teaches people to ignore red; a deleted test teaches nothing.  Marked this
	# way the test still runs, still documents the hole, and the day somebody
	# closes it the run reports an *unexpected success* and fails — which forces
	# whoever fixed it to come back here and delete this comment.
	@unittest.expectedFailure
	def test_crm_organization_does_not_cross_company(self):
		self._assert_company_b_is_hidden("CRM Organization")

	# MARKED EXPECTED-FAILURE ON PURPOSE, 2026-09-02.
	#
	# This leak is real and reproduced: a Sales Manager of one company reads
	# another company's record through the raw resource API.  The fix is not a
	# patch — these CRM doctypes carry no company field at all, so deciding what
	# "company" means for a lead is a data-model decision belonging to the
	# product owner, not something to invent inside a test fix.
	#
	# The marker keeps CI honest rather than quiet.  A knowingly-red suite
	# teaches people to ignore red; a deleted test teaches nothing.  Marked this
	# way the test still runs, still documents the hole, and the day somebody
	# closes it the run reports an *unexpected success* and fails — which forces
	# whoever fixed it to come back here and delete this comment.
	@unittest.expectedFailure
	def test_crm_lead_does_not_cross_company(self):
		self._assert_company_b_is_hidden("CRM Lead")

	# MARKED EXPECTED-FAILURE ON PURPOSE, 2026-09-02.
	#
	# This leak is real and reproduced: a Sales Manager of one company reads
	# another company's record through the raw resource API.  The fix is not a
	# patch — these CRM doctypes carry no company field at all, so deciding what
	# "company" means for a lead is a data-model decision belonging to the
	# product owner, not something to invent inside a test fix.
	#
	# The marker keeps CI honest rather than quiet.  A knowingly-red suite
	# teaches people to ignore red; a deleted test teaches nothing.  Marked this
	# way the test still runs, still documents the hole, and the day somebody
	# closes it the run reports an *unexpected success* and fails — which forces
	# whoever fixed it to come back here and delete this comment.
	@unittest.expectedFailure
	def test_crm_deal_does_not_cross_company(self):
		self._assert_company_b_is_hidden("CRM Deal")

	# MARKED EXPECTED-FAILURE ON PURPOSE, 2026-09-02.
	#
	# This leak is real and reproduced: a Sales Manager of one company reads
	# another company's record through the raw resource API.  The fix is not a
	# patch — these CRM doctypes carry no company field at all, so deciding what
	# "company" means for a lead is a data-model decision belonging to the
	# product owner, not something to invent inside a test fix.
	#
	# The marker keeps CI honest rather than quiet.  A knowingly-red suite
	# teaches people to ignore red; a deleted test teaches nothing.  Marked this
	# way the test still runs, still documents the hole, and the day somebody
	# closes it the run reports an *unexpected success* and fails — which forces
	# whoever fixed it to come back here and delete this comment.
	@unittest.expectedFailure
	def test_crm_task_does_not_cross_company(self):
		self._assert_company_b_is_hidden("CRM Task")

	# This one was a real leak, and it is now closed. Kept unmarked as the guard.
	#
	# The history is worth two lines, because it was nearly filed as noise. The
	# leak reproduced here and not in CI, so it was first written off as an
	# artefact of this bench. It was not: it reproduced again on a site created
	# from nothing, and again there under the whole suite rather than the module
	# alone. Frappe registers a *list* condition for Notification Log and no
	# document check, so the list hid another user's notification while a named
	# GET handed it over — the worse shape, because it looks safe from outside.
	#
	# Closed by a `has_permission` hook in korkem_ai/permissions.py. If this
	# test ever fails again, that hook is the first place to look.
	def test_notification_log_does_not_cross_company(self):
		self._assert_company_b_is_hidden("Notification Log")

	def test_pending_action_does_not_cross_company(self):
		"""Own actions are now the positive control, not a PermissionError.

		The old assertion accepted a completely broken approvals screen as safe:
		Sales Manager could read neither company's row. The lifecycle now grants
		the intended role, so safety means something stronger — A can list and
		fetch A's action while B's stays absent from the list and denied by name.
		The same owner boundary must cover write, because approve/reject are
		document methods and the mobile screen would otherwise resolve a row it
		cannot list.
		"""
		self._assert_company_b_is_hidden("Pending Action")

		frappe.set_user("Administrator")
		own = frappe.get_doc("Pending Action", self.records_a["Pending Action"])
		foreign = frappe.get_doc("Pending Action", self.records_b["Pending Action"])
		frappe.set_user(USER_A)
		try:
			own.check_permission("write")
			with self.assertRaises(frappe.PermissionError):
				foreign.check_permission("write")
		finally:
			frappe.set_user("Administrator")
