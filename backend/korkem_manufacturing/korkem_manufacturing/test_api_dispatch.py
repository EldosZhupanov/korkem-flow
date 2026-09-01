# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The dispatch endpoint: who may ship, and what it refuses.

The fifth and last of Horizon 1's planned actions, and the end of the chain —
everything upstream produces stock on a shelf, this turns it into something
the customer has.
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import setup
from korkem_manufacturing.api import dispatch as api
from korkem_manufacturing.services import dispatch as service


class _DispatchTestCase(IntegrationTestCase):
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


class TestItRefusesMalformedInput(_DispatchTestCase):
	def test_an_empty_order_is_a_question(self):
		with self.assertRaises(frappe.ValidationError) as caught:
			api.create_delivery("")
		self.assertIn("sales order", str(caught.exception).lower())

	def test_a_non_string_order_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			api.create_delivery(None)

	def test_malformed_items_are_refused_rather_than_dropped(self):
		"""Dropping them would ship the whole order.

		Harder to undo than a purchase receipt: the goods have left the
		building, and somebody has to go and get them.
		"""
		with self.assertRaises(frappe.ValidationError) as caught:
			api.create_delivery("SAL-ORD-ANY", items="{not json")
		self.assertIn("items", str(caught.exception))


class TestItChecksTheCaller(_DispatchTestCase):
	def test_a_production_role_alone_cannot_ship(self):
		email = self._user("painter@korkem.local", roles=("Manufacturing User",))
		frappe.set_user(email)

		shipped = []
		original = service.create_delivery
		service.create_delivery = lambda *a, **k: shipped.append(1)
		try:
			with self.assertRaises(frappe.PermissionError):
				api.create_delivery("SAL-ORD-ANY")
		finally:
			service.create_delivery = original

		self.assertEqual(shipped, [], "the service must not run for a refused caller")

	def test_a_stock_user_may_ship(self):
		email = self._user("shipper@korkem.local", roles=("Stock User",))
		frappe.set_user(email)

		called = []
		original = service.create_delivery
		service.create_delivery = lambda *a, **k: called.append(a) or {"status": "ok"}
		try:
			api.create_delivery("SAL-ORD-ANY")
		finally:
			service.create_delivery = original

		self.assertEqual(len(called), 1)


class TestScopeIsTheServersToDecide(_DispatchTestCase):
	def test_no_quantity_and_no_company_may_be_named(self):
		"""Quantities are recomputed from the shelf at execution.

		"Отгрузи 400 шкафов" against an order for ten with six on the shelf
		ships six. The signature is what makes a caller-supplied quantity
		impossible rather than merely discouraged.
		"""
		import inspect

		names = set(inspect.signature(api.create_delivery).parameters)
		self.assertEqual(names, {"sales_order", "items", "idempotency_key"})
		for forbidden in ("qty", "quantity", "company", "warehouse"):
			self.assertNotIn(forbidden, names)

	def test_an_order_from_another_company_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			api.create_delivery("SAL-ORD-SOMEBODY-ELSES")


class TestTheToolIsAnAlias(_DispatchTestCase):
	def test_the_ai_tool_and_the_dispatcher_reach_the_same_function(self):
		from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401

		spec = registry.get("sales.create_delivery")
		self.assertIsNotNone(spec)
		self.assertIs(spec.handler, api.create_delivery)
