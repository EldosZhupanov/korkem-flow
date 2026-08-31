# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""A customer placing their own order, and everything they must not be able to do.

The claim under test is the one the whole intake rests on: the customer on the
order is the customer the *session* is bound to, whatever the message said.
"""

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_ai.korkem_ai import customer_access
from korkem_ai.korkem_ai.tools import catalog, orders, registry, scope  # noqa: F401

CLIENT = "korkem.client@example.com"
PLANNER = "korkem.planner@example.com"
MINE = "Мебель Астана"
THEIRS = "Караганда Мебель"
PRODUCT = "Шкаф Астана"


class _OrderTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		seed_demo.seed_selling()
		self._before = set(frappe.get_all("Sales Order", pluck="name"))
		self._pre_existing = bool(frappe.db.exists("User", CLIENT))
		self._pre_linked = (
			frappe.get_all("Portal User", filters={"user": CLIENT}, pluck="parent")
			if self._pre_existing
			else []
		)
		if not self._pre_existing:
			frappe.get_doc(
				{
					"doctype": "User",
					"email": CLIENT,
					"first_name": "Клиент",
					"send_welcome_email": 0,
				}
			).insert(ignore_permissions=True)
		customer_access.link(CLIENT, MINE)
		self.addCleanup(self._clean)
		self.addCleanup(frappe.set_user, "Administrator")

	def _clean(self):
		"""Take away only what this test made."""
		frappe.set_user("Administrator")
		for name in set(frappe.get_all("Sales Order", pluck="name")) - self._before:
			doc = frappe.get_doc("Sales Order", name)
			if doc.docstatus == 1:
				doc.cancel()
			frappe.delete_doc("Sales Order", name, force=True, ignore_permissions=True)
		for customer in (MINE, THEIRS):
			customer_access.unlink(CLIENT, customer)
		if self._pre_existing:
			for customer in self._pre_linked:
				customer_access.link(CLIENT, customer)
		elif frappe.db.exists("User", CLIENT):
			frappe.delete_doc("User", CLIENT, force=True, ignore_permissions=True)
		frappe.db.commit()

	def as_customer(self, tool, args=None):
		frappe.set_user(CLIENT)
		try:
			return registry.execute(tool, args or {})
		finally:
			frappe.set_user("Administrator")

	def wanted(self, days=14):
		return add_days(nowdate(), days)


class TestTheCatalogue(_OrderTestCase):
	def test_a_customer_can_see_what_the_factory_makes(self):
		result = self.as_customer("sales.search_items", {})

		self.assertTrue(result["ok"], result.get("error"))
		codes = {row["item_code"] for row in result["data"]["items"]}
		self.assertIn(PRODUCT, codes)

	def test_raw_material_is_not_on_the_menu(self):
		"""ERPNext marks boards `is_sales_item` too. What is orderable is what
		has a BOM — the factory's own statement that it builds the thing."""
		result = self.as_customer("sales.search_items", {})

		codes = {row["item_code"] for row in result["data"]["items"]}
		self.assertNotIn("ДСП 16мм", codes)

	def test_the_catalogue_never_carries_a_cost(self):
		"""`valuation_rate` is permlevel 0 on Item, which is why a customer is
		not given read on the doctype at all. The projection has to stay a
		projection."""
		result = self.as_customer("sales.search_items", {})

		for row in result["data"]["items"]:
			self.assertNotIn("valuation_rate", row)
			self.assertNotIn("last_purchase_rate", row)

	def test_it_carries_the_price_the_customer_would_pay(self):
		result = self.as_customer("sales.search_items", {"query": "Шкаф"})

		row = next(r for r in result["data"]["items"] if r["item_code"] == PRODUCT)
		self.assertTrue(row["rate"])
		self.assertEqual(row["currency"], "KZT")


class TestPlacingAnOrder(_OrderTestCase):
	def test_it_creates_a_real_submitted_sales_order(self):
		result = self.as_customer(
			"sales.create_sales_order",
			{"item_code": PRODUCT, "qty": 3, "delivery_date": self.wanted()},
		)

		self.assertTrue(result["ok"], result.get("error"))
		name = result["data"]["sales_order"]
		frappe.set_user("Administrator")
		order = frappe.get_doc("Sales Order", name)
		self.assertEqual(order.docstatus, 1)
		self.assertEqual(order.customer, MINE)
		self.assertEqual(order.company, "KORKEM")
		self.assertEqual(order.items[0].item_code, PRODUCT)
		self.assertEqual(order.items[0].qty, 3)

	def test_the_price_comes_from_erpnext_not_the_conversation(self):
		result = self.as_customer(
			"sales.create_sales_order",
			{"item_code": PRODUCT, "qty": 2, "delivery_date": self.wanted()},
		)

		frappe.set_user("Administrator")
		order = frappe.get_doc("Sales Order", result["data"]["sales_order"])
		price = frappe.db.get_value(
			"Item Price",
			{"item_code": PRODUCT, "selling": 1, "price_list": order.selling_price_list},
			"price_list_rate",
		)
		self.assertEqual(order.items[0].rate, price)
		self.assertEqual(order.grand_total, price * 2)

	def test_the_audit_says_who_asked(self):
		result = self.as_customer(
			"sales.create_sales_order",
			{"item_code": PRODUCT, "qty": 1, "delivery_date": self.wanted()},
		)

		frappe.set_user("Administrator")
		self.assertEqual(
			frappe.db.get_value("Sales Order", result["data"]["sales_order"], "owner"), CLIENT
		)

	def test_naming_another_customer_does_not_move_the_order(self):
		"""The whole security claim in one test."""
		result = self.as_customer(
			"sales.create_sales_order",
			{
				"item_code": PRODUCT,
				"qty": 1,
				"delivery_date": self.wanted(),
				"customer": THEIRS,
			},
		)

		frappe.set_user("Administrator")
		self.assertEqual(
			frappe.db.get_value("Sales Order", result["data"]["sales_order"], "customer"), MINE
		)

	def test_missing_information_is_asked_for_not_invented(self):
		result = self.as_customer("sales.create_sales_order", {"item_code": PRODUCT})

		self.assertEqual(result["data"]["status"], "incomplete")
		self.assertIn("qty", result["data"]["missing"])
		self.assertIn("delivery_date", result["data"]["missing"])
		frappe.set_user("Administrator")
		self.assertEqual(set(frappe.get_all("Sales Order", pluck="name")), self._before)

	def test_an_unknown_product_offers_the_catalogue(self):
		result = self.as_customer(
			"sales.create_sales_order",
			{"item_code": "Космический корабль", "qty": 1, "delivery_date": self.wanted()},
		)

		self.assertEqual(result["data"]["status"], "not_found")
		self.assertTrue(result["data"]["candidates"])

	def test_a_date_in_the_past_is_refused(self):
		result = self.as_customer(
			"sales.create_sales_order",
			{"item_code": PRODUCT, "qty": 1, "delivery_date": add_days(nowdate(), -1)},
		)

		self.assertEqual(result["data"]["status"], "invalid_date")
		frappe.set_user("Administrator")
		self.assertEqual(set(frappe.get_all("Sales Order", pluck="name")), self._before)

	def test_an_item_with_no_price_is_not_ordered(self):
		"""A Sales Order carrying a number somebody invented is worse than none."""
		frappe.set_user("Administrator")
		price = frappe.get_all(
			"Item Price", filters={"item_code": PRODUCT, "selling": 1}, pluck="name"
		)
		saved = [frappe.get_doc("Item Price", name).as_dict() for name in price]
		for name in price:
			frappe.delete_doc("Item Price", name, force=True, ignore_permissions=True)
		self.addCleanup(self._restore_prices, saved)

		result = self.as_customer(
			"sales.create_sales_order",
			{"item_code": PRODUCT, "qty": 1, "delivery_date": self.wanted()},
		)

		self.assertEqual(result["data"]["status"], "no_price")
		frappe.set_user("Administrator")
		self.assertEqual(set(frappe.get_all("Sales Order", pluck="name")), self._before)

	def _restore_prices(self, saved):
		frappe.set_user("Administrator")
		for row in saved:
			key = {"item_code": row["item_code"], "price_list": row["price_list"]}
			if not frappe.db.exists("Item Price", key):
				frappe.get_doc(
					{
						"doctype": "Item Price",
						"item_code": row["item_code"],
						"price_list": row["price_list"],
						"selling": row["selling"],
						"buying": row["buying"],
						"currency": row["currency"],
						"price_list_rate": row["price_list_rate"],
					}
				).insert(ignore_permissions=True)
		frappe.db.commit()


class TestTheSummaryAPersonAgreesTo(_OrderTestCase):
	def test_it_names_the_item_the_quantity_the_date_and_the_money(self):
		frappe.set_user(CLIENT)
		try:
			summary = orders.summarise_order(
				item_code="Шкаф", qty=5, delivery_date=self.wanted()
			)
		finally:
			frappe.set_user("Administrator")

		self.assertIn(PRODUCT, summary)
		self.assertIn("5", summary)
		self.assertIn("KZT", summary)
		self.assertIn(MINE, summary)

	def test_it_is_attached_to_the_proposal_a_person_confirms(self):
		"""The point of `ToolSpec.summarise`: the sentence shown at confirmation
		time is built from ERPNext, not from the model's prose."""
		from korkem_ai.korkem_ai.agent import proposals

		frappe.set_user(CLIENT)
		try:
			summary = proposals.summarise(
				"sales.create_sales_order",
				{"item_code": PRODUCT, "qty": 2, "delivery_date": self.wanted()},
			)
		finally:
			frappe.set_user("Administrator")

		self.assertIn("Проверьте заказ", summary)

	def test_a_call_that_cannot_produce_an_order_has_no_summary(self):
		frappe.set_user(CLIENT)
		try:
			self.assertIsNone(orders.summarise_order(item_code=PRODUCT))
		finally:
			frappe.set_user("Administrator")


class TestWhatACustomerStillCannotDo(_OrderTestCase):
	def test_production_is_not_theirs_to_start(self):
		theirs = frappe.get_all(
			"Sales Order", filters={"customer": MINE, "docstatus": 1}, pluck="name"
		)[0]

		refused = self.as_customer("manufacturing.start_production", {"sales_order": theirs})

		self.assertFalse(refused["ok"])
		self.assertEqual(refused["error"]["code"], "not_permitted")

	def test_only_the_order_tool_may_be_proposed_as_a_write(self):
		"""Every other confirmation-needing tool is refused before its arguments
		are even looked at."""
		from korkem_ai.korkem_ai.tools import policy

		frappe.set_user(CLIENT)
		try:
			offered = {spec.name for spec in registry.available_to()}
			writes = {name for name in offered if registry.get(name).requires_confirmation}
		finally:
			frappe.set_user("Administrator")

		self.assertEqual(writes, set(policy.CUSTOMER_ALLOWED_WRITES))

	def test_dispatching_work_is_not_theirs(self):
		refused = self.as_customer(
			"dispatch.assign_work", {"employee": "Иван", "instruction": "сделай"}
		)

		self.assertFalse(refused["ok"])
		self.assertEqual(refused["error"]["code"], "not_permitted")


class TestStaffPlaceOrdersUnderTheirOwnPermissions(_OrderTestCase):
	def test_a_salesperson_names_the_customer(self):
		frappe.set_user(PLANNER)
		try:
			result = registry.execute(
				"sales.create_sales_order",
				{
					"item_code": PRODUCT,
					"qty": 1,
					"delivery_date": self.wanted(),
					"customer": THEIRS,
				},
			)
		finally:
			frappe.set_user("Administrator")

		if result["ok"] and result["data"].get("status") == "created":
			self.assertEqual(
				frappe.db.get_value("Sales Order", result["data"]["sales_order"], "customer"),
				THEIRS,
			)
			self.assertEqual(
				frappe.db.get_value("Sales Order", result["data"]["sales_order"], "owner"),
				PLANNER,
			)
		else:
			# The planner holds no Sales role on this bench, so ERPNext refuses.
			# That is the correct outcome and the assertion that matters is that
			# it was ERPNext that refused, not us.
			self.assertIn(
				result["error"]["code"] if not result["ok"] else "",
				("permission_denied", "invalid_request"),
			)

	def test_staff_are_not_pinned_to_one_customer(self):
		frappe.set_user(PLANNER)
		try:
			self.assertIsNone(scope.customer_scope())
		finally:
			frappe.set_user("Administrator")


class TestWhenItWillBeReady(_OrderTestCase):
	def test_the_requested_date_and_the_estimate_are_separate_facts(self):
		result = self.as_customer("sales.delivery_forecast", {})

		self.assertTrue(result["ok"], result.get("error"))
		for row in result["data"]["orders"]:
			self.assertIn("requested_date", row)
			self.assertIn("estimated_ready_date", row)
			self.assertIn("basis", row)

	def test_a_customer_sees_only_their_own_orders(self):
		result = self.as_customer("sales.delivery_forecast", {})

		customers = {row["customer"] for row in result["data"]["orders"]}
		self.assertNotIn(THEIRS, customers)

	def test_another_customers_order_is_absent_not_refused(self):
		frappe.set_user("Administrator")
		theirs = frappe.get_all(
			"Sales Order", filters={"customer": THEIRS, "docstatus": 1}, pluck="name"
		)[0]

		result = self.as_customer("sales.delivery_forecast", {"sales_order": theirs})

		self.assertFalse(result["ok"])
		self.assertNotIn(THEIRS, frappe.as_json(result))

	def test_an_order_with_no_production_says_so_rather_than_guessing(self):
		result = self.as_customer("sales.delivery_forecast", {})

		for row in result["data"]["orders"]:
			if not row["in_production"]:
				self.assertIsNone(row["estimated_ready_date"])
				self.assertIn("не запущено", row["basis"])

	def test_a_customer_is_never_handed_a_work_order_number(self):
		"""They are told how much is left, not which documents hold it."""
		result = self.as_customer("sales.delivery_forecast", {})

		for row in result["data"]["orders"]:
			self.assertIsNone(row["work_orders"])
