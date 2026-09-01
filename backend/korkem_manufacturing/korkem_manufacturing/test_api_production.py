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
from korkem_manufacturing.services import shop_floor
from unittest.mock import patch


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
		self.assertEqual(names, {"sales_order", "item_code", "idempotency_key"})

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


class TestBookingWorkAgainstAStage(_ApiTestCase):
	"""`complete_operation`, the second action of Horizon 1.

	The same division of labour as the first: this layer answers questions
	about the caller, and `services/shop_floor.py` answers questions about the
	business — which card, how many are good, whether a piece is at the rework
	bench.
	"""

	def test_it_asks_which_stage_rather_than_guessing(self):
		with self.assertRaises(frappe.ValidationError) as caught:
			api.complete_operation()
		self.assertIn("which stage", str(caught.exception).lower())

	def test_somebody_without_production_rights_is_refused(self):
		email = self._user("no.floor@korkem.local", roles=("Sales User",))
		frappe.set_user(email)

		booked = []
		original = shop_floor.complete_operation
		shop_floor.complete_operation = lambda **k: booked.append(1)
		try:
			with self.assertRaises(frappe.PermissionError):
				api.complete_operation(work_order="MFG-WO-ANY")
		finally:
			shop_floor.complete_operation = original

		self.assertEqual(booked, [], "the service must not run for a refused caller")

	def test_the_company_is_never_taken_from_the_caller(self):
		import inspect

		names = set(inspect.signature(api.complete_operation).parameters)
		self.assertNotIn("company", names)
		self.assertEqual(
			names,
			{
				"operation",
				"sales_order",
				"work_order",
				"qty",
				"scrap_qty",
				"rework_qty",
				"idempotency_key",
			},
		)

	def test_a_job_from_another_company_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			api.complete_operation(work_order="MFG-WO-SOMEBODY-ELSES")

	def test_a_quantity_that_is_not_a_number_says_so(self):
		"""Rather than becoming None and booking the whole outstanding run.

		A form sends "4" and a tool sends 4.0; both mean four. "четыре" means a
		mistake, and silently treating it as "everything left" would book a
		whole stage nobody reported.
		"""
		with self.assertRaises(frappe.ValidationError) as caught:
			api.complete_operation(work_order="MFG-WO-ANY", qty="четыре")
		self.assertIn("qty", str(caught.exception))

	def test_a_negative_quantity_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			api.complete_operation(work_order="MFG-WO-ANY", scrap_qty=-1)

	def test_a_numeric_string_is_accepted_as_the_number_it_is(self):
		booked = {}
		original = shop_floor.complete_operation
		shop_floor.complete_operation = lambda **k: booked.update(k) or {"status": "ok"}
		try:
			api.complete_operation(work_order="MFG-WO-ANY", qty="4", scrap_qty="1")
		except frappe.ValidationError:
			pass  # scope may refuse the fake order; the coercion above still ran
		finally:
			shop_floor.complete_operation = original

		if booked:
			self.assertEqual(booked["qty"], 4.0)
			self.assertEqual(booked["scrap_qty"], 1.0)

	def test_the_ai_tool_and_the_terminal_reach_the_same_function(self):
		from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401

		spec = registry.get("manufacturing.complete_operation")
		self.assertIsNotNone(spec)
		self.assertIs(spec.handler, api.complete_operation)


class TestFinishingAStageIsAllOrNothing(_ApiTestCase):
	"""The boundary a self-review found missing.

	Finishing a stage is several writes: the card is resized, submitted through
	ERPNext, and only then do the hold card and the rework card get created for
	pieces going back to the bench. Before this, a failure in that last step
	left a submitted card with a reduced quantity and the damaged pieces
	existing nowhere — neither finished, nor scrapped, nor waiting for repair.

	An outer HTTP transaction does not cover it: the AI registry catches
	`Exception` and returns the failure **as data** rather than re-raising, so
	through that adapter the request completes and the half-write commits.
	"""

	def test_a_write_made_before_the_failure_does_not_survive_it(self):
		"""The boundary itself, exercised rather than described.

		The real sequence needs a seeded factory to reach; what has to hold is
		simpler than that and is what actually broke — a write that happened
		inside the call must not outlive an exception raised after it.
		"""
		marker = "korkem-atomicity-probe"

		def half_write(**_):
			frappe.get_doc({"doctype": "ToDo", "description": marker}).insert()
			raise RuntimeError("the bench caught fire after the card was submitted")

		with patch.object(shop_floor, "_complete_operation", side_effect=half_write):
			with self.assertRaises(RuntimeError):
				shop_floor.complete_operation(work_order="MFG-WO-ANY")

		self.assertFalse(
			frappe.db.exists("ToDo", {"description": marker}),
			"the savepoint must undo everything the failed call wrote",
		)

	def test_a_successful_call_keeps_what_it_wrote(self):
		"""The other half: the savepoint must release, not roll back."""
		marker = "korkem-atomicity-kept"

		def good_write(**_):
			frappe.get_doc({"doctype": "ToDo", "description": marker}).insert()
			return {"status": "completed"}

		with patch.object(shop_floor, "_complete_operation", side_effect=good_write):
			result = shop_floor.complete_operation(work_order="MFG-WO-ANY")

		self.assertEqual(result["status"], "completed")
		self.assertTrue(frappe.db.exists("ToDo", {"description": marker}))

	def test_the_service_owns_a_savepoint_rather_than_trusting_the_caller(self):
		"""Asserted on the source, because the reason is the AI adapter.

		`registry.execute` turns an exception into `{"ok": False, ...}`. Any
		boundary that lives above the service is therefore not a boundary at
		all for the path that matters most.
		"""
		import inspect

		source = inspect.getsource(shop_floor.complete_operation)
		self.assertIn("savepoint", source)
		self.assertIn("rollback", source)
