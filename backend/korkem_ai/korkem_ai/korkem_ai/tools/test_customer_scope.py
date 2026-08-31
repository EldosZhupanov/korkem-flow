# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""What a customer may see, and how the boundary is decided.

The rule under test is one sentence: the customer a read is filtered by comes
from the session and never from the request. Everything else here is a way of
trying to get round that.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import customer_access
from korkem_ai.korkem_ai.tools import catalog, policy, registry, scope  # noqa: F401

PLANNER = "korkem.planner@example.com"
MINE = "Мебель Астана"
THEIRS = "Караганда Мебель"


class _CustomerTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self.email = self._customer_user(MINE)
		self.addCleanup(frappe.set_user, "Administrator")
		self.addCleanup(self._unlink)

	def _customer_user(self, customer, email="korkem.client@example.com"):
		"""A real customer account, bound the way an administrator would bind it.

		The account may already exist — it is the one the device test signs in
		as. What was found is remembered so teardown puts it back rather than
		deleting somebody else's account as a side effect of running the suite.
		"""
		self._pre_existing = bool(frappe.db.exists("User", email))
		self._pre_linked = (
			[
				row.parent
				for row in frappe.get_all(
					"Portal User", filters={"user": email}, fields=["parent"]
				)
			]
			if self._pre_existing
			else []
		)
		if not self._pre_existing:
			doc = frappe.new_doc("User")
			doc.update({"email": email, "first_name": "Клиент", "send_welcome_email": 0})
			doc.insert(ignore_permissions=True)
		customer_access.link(email, customer)
		return email

	def _detach(self):
		"""Take the account's customer binding away, and leave it away.

		The teardown below puts things back; a test that wants to see an
		unlinked account calls this instead, or the restoration undoes what the
		test was trying to set up.
		"""
		frappe.set_user("Administrator")
		for customer in (MINE, THEIRS):
			customer_access.unlink("korkem.client@example.com", customer)

	def _unlink(self):
		frappe.set_user("Administrator")
		email = "korkem.client@example.com"
		if frappe.db.exists("User", email):
			self._detach()
			if self._pre_existing:
				for customer in self._pre_linked:
					customer_access.link(email, customer)
			else:
				frappe.delete_doc("User", email, force=True, ignore_permissions=True)
		frappe.db.commit()

	def order_of(self, customer):
		frappe.set_user("Administrator")
		return frappe.get_all(
			"Sales Order", filters={"customer": customer, "docstatus": 1}, pluck="name"
		)[0]

	def as_customer(self, tool, args=None):
		frappe.set_user(self.email)
		try:
			return registry.execute(tool, args or {})
		finally:
			frappe.set_user("Administrator")


class TestTheCustomerComesFromTheSession(_CustomerTestCase):
	def test_a_linked_user_resolves_to_their_customer(self):
		frappe.set_user(self.email)

		self.assertEqual(scope.current_customer(), MINE)

	def test_an_unlinked_user_resolves_to_nobody(self):
		self._detach()
		email = "korkem.stranger@example.com"
		doc = frappe.new_doc("User")
		doc.update({"email": email, "first_name": "Никто", "send_welcome_email": 0})
		doc.append("roles", {"role": customer_access.ROLE})
		doc.insert(ignore_permissions=True)
		self.addCleanup(
			lambda: frappe.delete_doc("User", email, force=True, ignore_permissions=True)
		)
		frappe.set_user(email)

		with self.assertRaises(scope.CustomerNotLinked):
			scope.current_customer()

	def test_the_refusal_tells_them_what_to_do(self):
		self._detach()
		frappe.set_user(self.email)

		with self.assertRaises(scope.CustomerNotLinked) as caught:
			scope.current_customer()

		self.assertIn("администратору", str(caught.exception))

	def test_staff_are_not_pinned_to_a_customer(self):
		frappe.set_user(PLANNER)

		self.assertIsNone(scope.customer_scope())


class TestACustomerSeesOnlyTheirOwn(_CustomerTestCase):
	def test_their_orders_are_returned(self):
		result = self.as_customer("sales.search_sales_orders", {})

		self.assertTrue(result["ok"], result.get("error"))
		customers = {row["customer"] for row in result["data"]["sales_orders"]}
		self.assertEqual(customers, {MINE})

	def test_naming_another_customer_returns_their_own(self):
		"""The argument narrows within a scope; it never chooses one."""
		result = self.as_customer("sales.search_sales_orders", {"customer": THEIRS})

		self.assertTrue(result["ok"], result.get("error"))
		customers = {row["customer"] for row in result["data"]["sales_orders"]}
		self.assertNotIn(THEIRS, customers)
		self.assertIn(MINE, customers or {MINE})

	def test_the_timeline_is_their_own_whatever_they_name(self):
		result = self.as_customer("crm.customer_timeline", {"customer": THEIRS})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["customer"], MINE)

	def test_delivery_is_answered_without_showing_the_factorys_shelf(self):
		"""`sales.delivery_status` reads `Bin` — warehouse quantities — so it is
		not a customer tool. The timeline's delivery section answers "когда
		доставка" from Delivery Notes and stops there."""
		refused = self.as_customer("sales.delivery_status", {})

		self.assertFalse(refused["ok"])
		self.assertEqual(refused["error"]["code"], "not_permitted")

		allowed = self.as_customer("crm.customer_timeline", {})
		self.assertTrue(allowed["ok"], allowed.get("error"))
		self.assertIn("delivery", frappe.as_json(allowed["data"]).lower())

	def test_their_own_orders_carry_a_status_they_can_act_on(self):
		mine = self.order_of(MINE)

		result = self.as_customer("sales.search_sales_orders", {})

		self.assertTrue(result["ok"], result.get("error"))
		names = {row["name"] for row in result["data"]["sales_orders"]}
		self.assertIn(mine, names)
		self.assertTrue(all(row.get("status") for row in result["data"]["sales_orders"]))


class TestAnotherCustomersOrderIsAbsent(_CustomerTestCase):
	def test_it_never_appears_among_their_orders(self):
		theirs = self.order_of(THEIRS)

		result = self.as_customer("sales.search_sales_orders", {})

		names = {row["name"] for row in result["data"]["sales_orders"]}
		self.assertNotIn(theirs, names)

	def test_frappes_own_permission_layer_refuses_it_too(self):
		"""Not only our filter. The User Permission written at linking time is
		what holds if the Python boundary is ever wrong — so it is tested
		directly, without going through a tool."""
		theirs = self.order_of(THEIRS)
		frappe.set_user(self.email)
		try:
			# `get_list`, not `get_all`. `frappe.get_all` ignores permissions by
			# design — which is why the tools are checked for it — so asking it
			# whether a permission works proves nothing at all.
			readable = frappe.get_list(
				"Sales Order", filters={"name": theirs}, pluck="name"
			)
			self.assertEqual(readable, [], "Frappe handed over another customer's order")
			self.assertFalse(
				frappe.has_permission("Sales Order", "read", doc=theirs),
				"Frappe granted document read on another customer's order",
			)
		finally:
			frappe.set_user("Administrator")

	def test_the_refusal_names_no_other_customer(self):
		theirs = self.order_of(THEIRS)

		result = self.as_customer("crm.customer_timeline", {"customer": THEIRS})

		self.assertNotIn(THEIRS, frappe.as_json(result))
		self.assertNotIn(theirs, frappe.as_json(result))


class TestACustomerReachesNoWrites(_CustomerTestCase):
	def test_the_only_write_they_reach_is_their_own_order(self):
		"""The allowlist is edited by hand. Phase 28 could assert that every
		tool on it was a read; Phase 29 gave a customer exactly one write — their
		own order — so what is asserted now is that the *set* of writes is
		precisely the one somebody declared on purpose."""
		writes = {
			name
			for name in policy.CUSTOMER_ALLOWED
			if registry.get(name).risk is not registry.Risk.READ
		}

		self.assertEqual(writes, set(policy.CUSTOMER_ALLOWED_WRITES))
		self.assertEqual(writes, {"sales.create_sales_order"})

	def test_that_one_write_is_still_confirmed_like_any_other(self):
		"""What the allowlist grants is the right to be *asked*, not to act."""
		for name in policy.CUSTOMER_ALLOWED_WRITES:
			with self.subTest(tool=name):
				self.assertTrue(registry.get(name).requires_confirmation)

	def test_production_tools_are_refused(self):
		for name in (
			"manufacturing.production_control",
			"manufacturing.stop_production",
			"manufacturing.complete_production",
			"inventory.factory_shortage",
			"procurement.search_purchase_orders",
		):
			with self.subTest(tool=name):
				result = self.as_customer(name, {})
				self.assertFalse(result["ok"])
				self.assertEqual(result["error"]["code"], "not_permitted")

	def test_a_write_creates_no_pending_action(self):
		frappe.set_user("Administrator")
		before = frappe.db.count("Pending Action")

		self.as_customer(
			"manufacturing.stop_production", {"work_order": "X", "action": "останови"}
		)

		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.count("Pending Action"), before)

	def test_they_are_offered_only_the_allowlist(self):
		frappe.set_user(self.email)

		offered = {tool.name for tool in registry.offered_to()}

		self.assertTrue(offered)
		self.assertTrue(
			offered <= policy.CUSTOMER_ALLOWED,
			f"unexpected: {offered - policy.CUSTOMER_ALLOWED}",
		)


class TestStaffAreUnaffected(_CustomerTestCase):
	def test_a_planner_still_sees_every_customer(self):
		frappe.set_user(PLANNER)
		result = registry.execute("sales.search_sales_orders", {})
		frappe.set_user("Administrator")

		customers = {row["customer"] for row in result["data"]["sales_orders"]}
		self.assertIn(THEIRS, customers)

	def test_a_planner_can_still_ask_about_one_customer(self):
		frappe.set_user(PLANNER)
		result = registry.execute("crm.customer_timeline", {"customer": THEIRS})
		frappe.set_user("Administrator")

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["customer"], THEIRS)

	def test_a_planner_can_still_read_another_customers_order(self):
		theirs = self.order_of(THEIRS)
		frappe.set_user(PLANNER)
		result = registry.execute("sales.delivery_status", {"sales_order": theirs})
		frappe.set_user("Administrator")

		self.assertTrue(result["ok"], result.get("error"))
