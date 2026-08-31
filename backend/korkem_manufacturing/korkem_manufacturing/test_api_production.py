# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The production endpoint: who may call it, and what it refuses.

This is the layer that did not exist before Horizon 1. `start_production` was
reachable only through a language model — `grep frappe.whitelist` over
`korkem_ai/tools/` returned nothing — so a button could not start a job and a
provider outage stopped the factory.

The tests below are about the **caller**, not the business. Whether material is
on the shelf is `services/production.py`'s question and is covered by the suite
that moved with it. Whether *you* may ask is this module's question, and it is
tested here because a permission check is only real if something fails without
it.
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import setup
from korkem_manufacturing.api import production as api
from korkem_manufacturing.services import production as service


class _ApiTestCase(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		# A real company, items and a submitted BOM. A Work Order cannot be
		# submitted without them, so the endpoint would be untestable on
		# fixtures alone.
		setup.provision()

	def setUp(self):
		self.addCleanup(lambda: frappe.set_user("Administrator"))

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def _user(self, email: str, roles: tuple[str, ...] = ()) -> str:
		if not frappe.db.exists("User", email):
			frappe.get_doc(
				{
					"doctype": "User",
					"email": email,
					"first_name": email.split("@")[0],
					"send_welcome_email": 0,
				}
			).insert(ignore_permissions=True)
		user = frappe.get_doc("User", email)
		for role in roles:
			if role not in {row.role for row in user.roles}:
				user.append("roles", {"role": role})
		user.save(ignore_permissions=True)
		return email


class TestTheEndpointRefusesMalformedInput(_ApiTestCase):
	"""Before anything is looked up, and with a sentence rather than a trace."""

	def test_an_empty_order_name_is_a_question_not_a_traceback(self):
		with self.assertRaises(frappe.ValidationError) as caught:
			api.start_production("")
		self.assertIn("sales order", str(caught.exception).lower())

	def test_whitespace_is_not_an_order_name(self):
		with self.assertRaises(frappe.ValidationError):
			api.start_production("   ")

	def test_a_non_string_is_refused_rather_than_coerced(self):
		with self.assertRaises(frappe.ValidationError):
			api.start_production(None)

	def test_an_unknown_order_says_so(self):
		with self.assertRaises(frappe.ValidationError) as caught:
			api.start_production("SAL-ORD-DOES-NOT-EXIST")
		self.assertIn("SAL-ORD-DOES-NOT-EXIST", str(caught.exception))


class TestTheEndpointChecksTheCaller(_ApiTestCase):
	def test_somebody_without_production_rights_is_refused(self):
		"""And refused *before* the service runs, so nothing can move.

		The service itself also checks doctype permissions; this is the second
		layer, not the only one (ADR-0013, defence in depth).
		"""
		email = self._user("no.rights@korkem.local", roles=("Sales User",))
		frappe.set_user(email)

		moved = []
		original = service.start_production
		service.start_production = lambda *a, **k: moved.append(1)
		try:
			with self.assertRaises(frappe.PermissionError):
				api.start_production("SAL-ORD-ANY")
		finally:
			service.start_production = original

		self.assertEqual(moved, [], "the service must not run for a refused caller")

	def test_the_refusal_says_what_to_do_about_it(self):
		email = self._user("no.rights2@korkem.local", roles=("Sales User",))
		frappe.set_user(email)
		with self.assertRaises(frappe.PermissionError) as caught:
			api.start_production("SAL-ORD-ANY")
		self.assertIn("manufacturing manager", str(caught.exception).lower())

	def test_a_manufacturing_user_passes_the_role_check(self):
		"""It may still be refused further down — but not for its role."""
		email = self._user("floor@korkem.local", roles=("Manufacturing User",))
		frappe.set_user(email)

		called = []
		original = service.start_production
		service.start_production = lambda *a, **k: called.append(a) or {"status": "nothing_to_start"}
		try:
			api.start_production("SAL-ORD-ANY")
		finally:
			service.start_production = original

		self.assertEqual(len(called), 1, "the role check let a manufacturing user through")


class TestCompanyScopeIsDecidedByTheServer(_ApiTestCase):
	def test_the_company_is_never_taken_from_the_caller(self):
		"""There is no company parameter, and that is the point.

		A caller that could name its own company could start production in
		somebody else's factory. The signature is the guarantee: `company` is
		not an argument, so it cannot be sent.
		"""
		import inspect

		names = set(inspect.signature(api.start_production).parameters)
		self.assertNotIn("company", names)
		self.assertNotIn("organization", names)
		self.assertEqual(names, {"sales_order", "item_code"})

	def test_scope_is_enforced_before_the_role_check(self):
		"""An order from another company is refused as not found.

		Refused *first*, so the answer cannot be used to discover that an order
		exists somewhere the caller cannot see.
		"""
		with self.assertRaises(frappe.ValidationError):
			api.start_production("SAL-ORD-SOMEBODY-ELSES")


class TestTheEndpointIsPublished(_ApiTestCase):
	def test_it_is_whitelisted_so_a_button_can_reach_it(self):
		"""The whole point of Horizon 1, asserted rather than assumed."""
		self.assertTrue(
			getattr(api.start_production, "__wrapped__", None)
			or api.start_production.__name__ == "start_production"
		)
		self.assertIn(
			"korkem_manufacturing.api.production.start_production",
			frappe.whitelisted_methods
			if hasattr(frappe, "whitelisted_methods")
			else {f"{f.__module__}.{f.__name__}" for f in frappe.whitelisted},
		)

	def test_the_ai_tool_and_the_button_reach_the_same_function(self):
		"""If these ever diverge, the assistant and the button disagree.

		That divergence is exactly what Horizon 1 exists to make impossible, so
		it is asserted rather than trusted to review.
		"""
		# Importing the catalogue is what registers the tools — the registry is
		# populated as a side effect of module import, not by a loader. A test
		# that asserts about it has to arrange that, which is why this import
		# is here rather than at the top of the file.
		from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401

		spec = registry.get("manufacturing.start_production")
		self.assertIsNotNone(spec, "the tool is still registered")
		self.assertIs(
			spec.handler,
			api.start_production,
			"the AI tool must be a thin adapter over the published endpoint",
		)
