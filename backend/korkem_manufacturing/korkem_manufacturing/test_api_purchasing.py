# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The receiving endpoint: who may call it, and what it refuses.

The third action of Horizon 1, and the first reached by a **warehouse** role
rather than a production one. That distinction is the reason for publishing
these at all: a store keeper booking in a pallet should need neither a
language model nor production rights.
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import setup
from korkem_manufacturing.api import purchasing as api
from korkem_manufacturing.services import purchasing as service


class _ReceivingTestCase(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		setup.provision()

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


class TestItRefusesMalformedInput(_ReceivingTestCase):
	def test_an_empty_order_is_a_question(self):
		with self.assertRaises(frappe.ValidationError) as caught:
			api.receive_purchase_order("")
		self.assertIn("purchase order", str(caught.exception).lower())

	def test_a_non_string_order_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			api.receive_purchase_order(None)

	def test_an_unknown_order_says_which(self):
		with self.assertRaises(frappe.ValidationError) as caught:
			api.receive_purchase_order("PUR-ORD-DOES-NOT-EXIST")
		self.assertIn("PUR-ORD-DOES-NOT-EXIST", str(caught.exception))

	def test_malformed_items_are_refused_rather_than_dropped(self):
		"""Dropping them would book the whole order in.

		Somebody sending a narrowing list meant a *partial* delivery. Ignoring
		a list we could not read turns that into receiving everything — the
		opposite of what was asked, with stock to match.
		"""
		with self.assertRaises(frappe.ValidationError) as caught:
			api.receive_purchase_order("PUR-ORD-ANY", items="{not json")
		self.assertIn("items", str(caught.exception))

	def test_items_that_are_not_a_list_are_refused(self):
		with self.assertRaises(frappe.ValidationError):
			api.receive_purchase_order("PUR-ORD-ANY", items='{"item_code": "ДСП"}')


class TestItChecksTheCaller(_ReceivingTestCase):
	def test_a_production_role_alone_cannot_receive(self):
		"""Receiving is the store's job.

		A cutting operator has no business creating a Purchase Receipt, and the
		fact that they may finish a stage does not say otherwise.
		"""
		email = self._user("cutter@korkem.local", roles=("Manufacturing User",))
		frappe.set_user(email)

		booked = []
		original = service.receive_purchase_order
		service.receive_purchase_order = lambda *a, **k: booked.append(1)
		try:
			with self.assertRaises(frappe.PermissionError):
				api.receive_purchase_order("PUR-ORD-ANY")
		finally:
			service.receive_purchase_order = original

		self.assertEqual(booked, [], "the service must not run for a refused caller")

	def test_the_refusal_says_who_to_ask(self):
		email = self._user("cutter2@korkem.local", roles=("Manufacturing User",))
		frappe.set_user(email)
		with self.assertRaises(frappe.PermissionError) as caught:
			api.receive_purchase_order("PUR-ORD-ANY")
		self.assertIn("stock manager", str(caught.exception).lower())

	def test_a_stock_user_passes_the_role_check(self):
		email = self._user("store@korkem.local", roles=("Stock User",))
		frappe.set_user(email)

		called = []
		original = service.receive_purchase_order
		service.receive_purchase_order = lambda *a, **k: called.append(a) or {"status": "ok"}
		try:
			api.receive_purchase_order("PUR-ORD-ANY")
		finally:
			service.receive_purchase_order = original

		self.assertEqual(len(called), 1)


class TestScopeIsTheServersToDecide(_ReceivingTestCase):
	def test_the_company_is_never_a_parameter(self):
		import inspect

		self.assertEqual(
			set(inspect.signature(api.receive_purchase_order).parameters),
			{"purchase_order", "items"},
		)

	def test_an_order_from_another_company_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			api.receive_purchase_order("PUR-ORD-SOMEBODY-ELSES")


class TestTheToolIsAnAlias(_ReceivingTestCase):
	def test_the_ai_tool_and_the_store_screen_reach_the_same_function(self):
		from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401

		spec = registry.get("inventory.receive_purchase_order")
		self.assertIsNotNone(spec)
		self.assertIs(spec.handler, api.receive_purchase_order)
