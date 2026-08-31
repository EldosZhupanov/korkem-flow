"""Reproducible integration-test setup for KORKEM AI."""

import frappe


FIXTURE_ORGANIZATION = "KORKEM AI Test Fixture"


def before_tests():
	"""Build the documented development fixture before the AI test suite.

	The production, procurement, delivery, timeline and dispatch tests all read
	the same small factory.  Preparing it once here makes ``bench run-tests`` on
	a brand-new site equivalent to running it on a developer's seeded bench.
	``seed`` and ``provision`` are both idempotent and refuse production sites.
	"""
	from korkem_manufacturing import seed_demo, setup

	setup.provision()
	_prepare_crm_records()
	seed_demo.seed()


def _prepare_crm_records():
	"""Create only the cross-app CRM records KORKEM's tests rely on.

	Using Frappe's generic ``make_test_records`` here recursively imports the
	ERPNext test bootstrap.  On a provisioned site that bootstrap attempts to
	insert ``Standard Buying`` a second time, so a narrow fixture is both faster
	and more deterministic.
	"""
	if not frappe.db.exists("CRM Lead Status", "New Lead"):
		frappe.get_doc(
			{"doctype": "CRM Lead Status", "lead_status": "New Lead"}
		).insert(ignore_permissions=True)
	if not frappe.db.exists("CRM Lead Source", "Referral"):
		frappe.get_doc(
			{"doctype": "CRM Lead Source", "source_name": "Referral"}
		).insert(ignore_permissions=True)
	if not frappe.db.exists("CRM Organization", FIXTURE_ORGANIZATION):
		frappe.get_doc(
			{"doctype": "CRM Organization", "organization_name": FIXTURE_ORGANIZATION}
		).insert(ignore_permissions=True)
	if not frappe.db.exists("CRM Deal", {"organization": FIXTURE_ORGANIZATION}):
		frappe.get_doc(
			{
				"doctype": "CRM Deal",
				"organization": FIXTURE_ORGANIZATION,
				"status": "Qualification",
				"deal_owner": "Administrator",
			}
		).insert(ignore_permissions=True)
	frappe.db.commit()
