# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Material request → purchase order, and the four quantities that must not merge.

The distinction under test throughout: **required**, **available**, **ordered**
and **received** are different numbers. Collapsing any two of them produces an
answer that reads fine and sends somebody to the saw for board that is still on
a lorry.
"""

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, nowdate

from korkem_manufacturing import seed_demo

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401

REQUESTS = "procurement.search_material_requests"
ORDERS = "procurement.search_purchase_orders"
STATUS = "procurement.procurement_status"
CREATE = "procurement.create_purchase_order"
RECEIVE = "inventory.receive_purchase_order"
RECEIPTS = "procurement.search_receipts"
RAISE = "inventory.create_material_request"

BOARD = "ДСП 16мм"
BOARD_SUPPLIER = "Мебельная база Астана"
PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"


class _BuyingTestCase(IntegrationTestCase):
	#: The board on the shelf before this class runs, read once rather than
	#: written down. It used to be the constant 38 — what the seed received —
	#: which stopped being the answer the moment the seed started manufacturing
	#: from that stock and left 12.8. A fixture that restores to a number
	#: somebody typed will silently invent material as soon as the demo changes.
	_baseline_board: float | None = None

	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		cls._baseline_board = flt(
			frappe.db.get_value("Bin", {"item_code": BOARD, "warehouse": "Stores - KRK"}, "actual_qty")
		)

	def blocked_order(self) -> str:
		"""The seeded order the board shortage is about.

		Resolved from its customer, never written down: a re-seeded bench
		renumbers, and a fixture that names `SAL-ORD-2026-00001` starts failing
		for a reason that has nothing to do with what it tests. The same lesson
		as the hardcoded 38 above.
		"""
		return frappe.get_all(
			"Sales Order",
			filters={"customer": "Мебель Астана", "docstatus": 1},
			pluck="name",
			order_by="creation asc",
		)[0]

	def setUp(self):
		frappe.set_user("Administrator")
		if not frappe.db.exists("Sales Order", {"customer": "Мебель Астана", "docstatus": 1}):
			self.skipTest("seed_demo has not been run on this site")
		seed_demo.seed_users()
		seed_demo.seed_buying()
		self._clean()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		self._clean()

	def _clean(self):
		frappe.set_user("Administrator")
		for doctype in ("Purchase Receipt", "Purchase Order", "Material Request"):
			for name in frappe.get_all(doctype, pluck="name"):
				doc = frappe.get_doc(doctype, name)
				if doc.docstatus == 1:
					doc.cancel()
				frappe.delete_doc(doctype, name, force=1, ignore_permissions=True)
		frappe.db.delete("Pending Action", {"tool": ["in", (CREATE, RECEIVE)]})
		frappe.db.commit()
		self._restore_stock()

	def _restore_stock(self):
		"""Put the shelf back where the seed left it.

		Receipts move the stock ledger, and a cancellation that does not run —
		because the order it belongs to was cancelled first, say — leaves the
		extra material behind. That happened once: the board went to 42 and
		every later test failed with a shortage that no longer existed, which
		looks nothing like the cleanup bug it was. Correcting it here makes one
		leaked receipt a local problem instead of a poisoned suite.
		"""
		on_hand = flt(
			frappe.db.get_value(
				"Bin", {"item_code": BOARD, "warehouse": "Stores - KRK"}, "actual_qty"
			)
		)
		drift = round(on_hand - flt(self._baseline_board), 3)
		if not drift:
			return

		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Issue" if drift > 0 else "Material Receipt",
				"company": "KORKEM",
				"remarks": "KORKEM demo — restoring seeded stock after a test",
				"items": [
					{
						"item_code": BOARD,
						"qty": abs(drift),
						("s_warehouse" if drift > 0 else "t_warehouse"): "Stores - KRK",
						"basic_rate": 1000,
						"allow_zero_valuation_rate": 1,
					}
				],
			}
		)
		entry.insert(ignore_permissions=True)
		entry.submit()
		frappe.db.commit()

	def as_planner(self, tool, args=None):
		frappe.set_user(PLANNER)
		try:
			return registry.execute(tool, args or {})
		finally:
			frappe.set_user("Administrator")

	def raise_request(self, qty=4):
		result = self.as_planner(RAISE, {"items": [{"item_code": BOARD, "qty": qty}]})
		self.assertTrue(result["ok"], result.get("error"))
		return result["data"]["material_request"]

	def place_order(self, request=None, **args):
		result = self.as_planner(CREATE, {"material_request": request or self.raise_request(), **args})
		self.assertTrue(result["ok"], result.get("error"))
		return result["data"]

	def receive(self, purchase_order, qty=None):
		"""Book the goods in, so "it arrived" can be told from "it is on order".

		Cleaned up in `_clean` rather than by `addCleanup`: a receipt has to be
		cancelled before the order it came from, and cleanup order is easier to
		get right in one place than across two mechanisms.
		"""
		from erpnext.buying.doctype.purchase_order.mapper import make_purchase_receipt

		frappe.set_user("Administrator")
		receipt = make_purchase_receipt(purchase_order)
		if qty is not None:
			receipt.items[0].qty = qty
			receipt.items[0].received_qty = qty
		receipt.insert(ignore_permissions=True)
		receipt.submit()
		frappe.db.commit()
		return receipt.name

	def bin_row(self):
		frappe.set_user("Administrator")
		return frappe.db.get_value(
			"Bin",
			{"item_code": BOARD, "warehouse": "Stores - KRK"},
			["actual_qty", "ordered_qty", "indented_qty"],
			as_dict=True,
		)


class TestOpenRequestsAreVisible(_BuyingTestCase):
	def test_a_raised_request_shows_what_is_still_to_order(self):
		name = self.raise_request()

		found = self.as_planner(REQUESTS, {"only_unordered": True})["data"]["material_requests"]

		request = next(r for r in found if r["material_request"] == name)
		self.assertFalse(request["fully_ordered"])
		self.assertEqual(request["purchase_orders"], [])
		item = request["items"][0]
		self.assertEqual(item["item_code"], BOARD)
		self.assertEqual(item["ordered_qty"], 0.0)
		self.assertEqual(item["pending_qty"], 4.0)

	def test_a_fully_ordered_request_drops_out_of_the_unordered_list(self):
		name = self.raise_request()
		self.place_order(name)

		unordered = self.as_planner(REQUESTS, {"only_unordered": True})["data"]["material_requests"]

		self.assertNotIn(name, [r["material_request"] for r in unordered])


class TestTheRequestAndTheOrderPointAtEachOther(_BuyingTestCase):
	def test_the_order_cites_the_request_it_came_from(self):
		name = self.raise_request()

		placed = self.place_order(name)

		frappe.set_user("Administrator")
		row = frappe.get_all(
			"Purchase Order Item",
			filters={"parent": placed["purchase_order"]},
			fields=["material_request", "material_request_item", "item_code", "qty"],
		)[0]
		self.assertEqual(row["material_request"], name)
		self.assertTrue(row["material_request_item"], "the row-level link is what tracks fulfilment")
		self.assertEqual(row["qty"], 4.0)

	def test_the_request_lists_the_order_raised_against_it(self):
		name = self.raise_request()
		placed = self.place_order(name)

		found = self.as_planner(REQUESTS, {})["data"]["material_requests"]

		request = next(r for r in found if r["material_request"] == name)
		self.assertEqual(request["purchase_orders"], [placed["purchase_order"]])
		self.assertEqual(request["items"][0]["ordered_qty"], 4.0)
		self.assertEqual(request["items"][0]["pending_qty"], 0.0)


class TestOrderedIsNotReceived(_BuyingTestCase):
	"""The rule the whole slice turns on."""

	def test_placing_an_order_puts_nothing_on_the_shelf(self):
		before = self.bin_row()

		self.place_order()

		after = self.bin_row()
		self.assertEqual(after["actual_qty"], before["actual_qty"], "buying it did not deliver it")
		self.assertEqual(after["ordered_qty"], 4.0)

	def test_production_is_still_blocked_after_the_order_is_placed(self):
		"""«Заказано» is not «можно резать». A shop told otherwise finds out at
		the saw."""
		self.place_order()

		readiness = self.as_planner(
			"manufacturing.production_control", {"sales_order": self.blocked_order()}
		)["data"]["orders"][0]

		self.assertFalse(readiness["can_start"])
		self.assertEqual(
			{m["item_code"]: m["physical_shortage_qty"] for m in readiness["blocking_materials"]}[BOARD], 4.0
		)

	def test_the_shortage_reports_ordered_and_physical_separately(self):
		self.place_order()

		item = next(
			row
			for row in self.as_planner("inventory.factory_shortage", {})["data"]["items"]
			if row["item_code"] == BOARD
		)

		self.assertEqual(item["shortage_qty"], 0.0, "nothing more needs buying")
		self.assertEqual(item["physical_shortage_qty"], 4.0, "and none of it has arrived")
		self.assertEqual(item["on_order_qty"], 4.0)
		# The shelf, not the shelf plus the lorry. Read rather than written
		# down: the seed manufactures from this board, so the figure is
		# whatever production left behind.
		self.assertEqual(item["available_qty"], flt(self._baseline_board))

	def test_a_received_order_does_reach_the_shelf(self):
		"""The other half of the rule: once it lands, availability moves."""
		placed = self.place_order()
		before = self.bin_row()

		self.receive(placed["purchase_order"])

		after = self.bin_row()
		self.assertEqual(after["actual_qty"], before["actual_qty"] + 4.0)
		self.assertEqual(after["ordered_qty"], 0.0)


class TestPartialReceiptIsReportedHonestly(_BuyingTestCase):
	def test_receiving_half_leaves_the_rest_outstanding(self):
		placed = self.place_order()

		self.receive(placed["purchase_order"], qty=2)

		order = self.as_planner(ORDERS, {})["data"]["purchase_orders"][0]
		self.assertEqual(order["items"][0]["received_qty"], 2.0)
		self.assertEqual(order["items"][0]["pending_qty"], 2.0)
		self.assertEqual(order["pending_qty"], 2.0)
		self.assertLess(order["received_percent"], 100)


class TestDatesAndLateness(_BuyingTestCase):
	def test_an_order_due_in_the_future_is_not_overdue(self):
		placed = self.place_order()

		order = self.as_planner(ORDERS, {})["data"]["purchase_orders"][0]

		self.assertEqual(order["expected_on"], placed["expected_on"])
		self.assertFalse(order["overdue"])
		self.assertEqual(order["days_overdue"], 0)

	def test_a_past_due_order_is_counted_late_by_the_server(self):
		placed = self.place_order()
		frappe.set_user("Administrator")
		frappe.db.set_value(
			"Purchase Order", placed["purchase_order"], "schedule_date", add_days(nowdate(), -5)
		)
		frappe.db.commit()

		order = self.as_planner(ORDERS, {"overdue_only": True})["data"]["purchase_orders"][0]

		self.assertTrue(order["overdue"])
		self.assertEqual(order["days_overdue"], 5)

	def test_the_arrival_horizon_is_applied_by_the_server(self):
		"""«что придёт на этой неделе» must not become date arithmetic inside
		the model."""
		self.place_order()

		soon = self.as_planner(ORDERS, {"arriving_within_days": 1})["data"]["purchase_orders"]
		later = self.as_planner(ORDERS, {"arriving_within_days": 60})["data"]["purchase_orders"]

		self.assertEqual(soon, [])
		self.assertEqual(len(later), 1)


class TestTheChainIsTraceable(_BuyingTestCase):
	def test_a_shortage_with_no_request_says_so(self):
		blocking = self.as_planner(STATUS, {})["data"]["blocking_production"]

		board = next(row for row in blocking if row["item_code"] == BOARD)
		self.assertEqual(board["stage"], "NOT_REQUESTED")
		self.assertIsNone(board["material_request"])
		self.assertIn(self.blocked_order(), board["orders_blocked"])

	def test_a_requested_but_unordered_shortage_says_so(self):
		name = self.raise_request()

		board = next(
			row
			for row in self.as_planner(STATUS, {})["data"]["blocking_production"]
			if row["item_code"] == BOARD
		)

		self.assertEqual(board["stage"], "REQUESTED")
		self.assertEqual(board["material_request"], name)
		self.assertEqual(board["purchase_orders"], [])

	def test_an_ordered_shortage_names_the_supplier_and_the_date(self):
		"""The whole answer to «почему производство ждёт», read out of ERPNext
		rather than assembled by a model from three separate replies."""
		name = self.raise_request()
		placed = self.place_order(name)

		board = next(
			row
			for row in self.as_planner(STATUS, {})["data"]["blocking_production"]
			if row["item_code"] == BOARD
		)

		self.assertEqual(board["stage"], "ORDERED")
		self.assertEqual(board["material_request"], name)
		self.assertEqual(board["purchase_orders"][0]["purchase_order"], placed["purchase_order"])
		self.assertEqual(board["purchase_orders"][0]["supplier"], BOARD_SUPPLIER)
		self.assertEqual(board["purchase_orders"][0]["expected_on"], placed["expected_on"])
		self.assertEqual(board["on_order_qty"], 4.0)


class TestNothingIsInvented(_BuyingTestCase):
	def test_the_supplier_comes_from_the_item_not_from_a_guess(self):
		placed = self.place_order()

		self.assertEqual(placed["supplier"], BOARD_SUPPLIER)

	def test_an_item_with_no_supplier_is_refused_rather_than_assigned_one(self):
		"""There are ten suppliers on this bench. Picking one would produce a
		real letter to a real business that never quoted for the work."""
		name = self.raise_request()
		frappe.set_user("Administrator")
		frappe.db.sql(
			"update `tabItem Default` set default_supplier=null where parent=%s", BOARD
		)
		frappe.db.delete("Item Supplier", {"parent": BOARD})
		frappe.db.commit()

		result = self.as_planner(CREATE, {"material_request": name})

		self.assertTrue(result["ok"])
		self.assertEqual(result["data"]["status"], "supplier_unknown")
		self.assertIn(BOARD, result["data"]["items"])
		self.assertEqual(frappe.db.count("Purchase Order"), 0)

	def test_an_item_with_no_price_is_refused_rather_than_ordered_at_zero(self):
		"""A purchase order with no money on it is one a supplier can read as
		free."""
		name = self.raise_request()
		frappe.set_user("Administrator")
		frappe.db.delete("Item Price", {"item_code": BOARD})
		frappe.db.commit()

		result = self.as_planner(CREATE, {"material_request": name})

		self.assertTrue(result["ok"])
		self.assertEqual(result["data"]["status"], "price_unknown")
		self.assertEqual(frappe.db.count("Purchase Order"), 0)

	def test_an_unknown_supplier_is_refused(self):
		name = self.raise_request()

		result = self.as_planner(CREATE, {"material_request": name, "supplier": "Кто-то"})

		self.assertFalse(result["ok"])
		self.assertIn("does not exist", result["error"]["message"])

	def test_the_quantity_comes_from_the_request_not_from_the_model(self):
		"""The tool takes no quantity at all — there is nothing for a model to
		get wrong."""
		spec = registry.get(CREATE)

		self.assertNotIn("qty", spec.input_schema["properties"])
		self.assertNotIn("items", spec.input_schema["properties"])

	def test_an_unknown_argument_is_refused(self):
		result = self.as_planner(CREATE, {"material_request": "x", "rate": 1})

		self.assertFalse(result["ok"])
		self.assertIn("not a known argument", result["error"]["message"])


class TestTheRequestIsRecheckedAtExecution(_BuyingTestCase):
	def test_a_request_already_ordered_creates_nothing_further(self):
		"""The stale-proposal case: somebody else ordered it while the card was
		on screen."""
		name = self.raise_request()
		self.place_order(name)

		again = self.as_planner(CREATE, {"material_request": name})

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "not_needed")
		self.assertEqual(frappe.db.count("Purchase Order"), 1)

	def test_a_cancelled_request_cannot_be_ordered_against(self):
		name = self.raise_request()
		frappe.set_user("Administrator")
		frappe.get_doc("Material Request", name).cancel()
		frappe.db.commit()

		result = self.as_planner(CREATE, {"material_request": name})

		self.assertFalse(result["ok"])
		self.assertEqual(frappe.db.count("Purchase Order"), 0)

	def test_an_unknown_request_is_a_sentence_not_a_traceback(self):
		result = self.as_planner(CREATE, {"material_request": "MAT-MR-9999-99999"})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"])


class TestPermissionsAndConfirmation(_BuyingTestCase):
	def test_placing_an_order_is_a_write_that_needs_confirmation(self):
		spec = registry.get(CREATE)

		self.assertIs(spec.risk, registry.Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)

	def test_the_read_tools_need_no_confirmation(self):
		for name in (REQUESTS, ORDERS, STATUS):
			with self.subTest(tool=name):
				self.assertIs(registry.get(name).risk, registry.Risk.READ)

	def test_a_viewer_sees_no_procurement_at_all(self):
		"""`Sales User` grants no Material Request permission, so this user
		cannot see what the shop has asked to buy, let alone buy it. Asserted
		rather than worked around: the boundary is ERPNext's, and the fix for
		somebody who needs procurement is a role, not a change here."""
		name = self.raise_request()
		frappe.set_user(VIEWER)
		try:
			read = registry.execute(STATUS, {})
			write = registry.execute(CREATE, {"material_request": name})
			offered = {spec.name for spec in registry.available_to()}
		finally:
			frappe.set_user("Administrator")

		self.assertFalse(read["ok"])
		self.assertEqual(read["error"]["code"], "permission_denied")
		self.assertFalse(write["ok"])
		self.assertEqual(write["error"]["code"], "permission_denied")
		self.assertNotIn(CREATE, offered)
		self.assertNotIn(STATUS, offered)
		self.assertEqual(frappe.db.count("Purchase Order"), 0)


class TestReceivingPutsMaterialOnTheShelf(_BuyingTestCase):
	"""The end of the chain, and the only step that changes what can be cut."""

	def test_the_whole_cycle_unblocks_production(self):
		"""Short → requested → ordered → received → makeable, with every number
		read from ERPNext rather than asserted from the fixture."""
		order = self.place_order()["purchase_order"]

		before = self.as_planner(
			"manufacturing.production_control", {"sales_order": self.blocked_order()}
		)["data"]["orders"][0]
		self.assertFalse(before["can_start"])
		self.assertEqual(
			{m["item_code"]: m["physical_shortage_qty"] for m in before["blocking_materials"]}[BOARD], 4.0
		)
		on_hand = self.bin_row()["actual_qty"]

		received = self.as_planner(RECEIVE, {"purchase_order": order})
		self.assertTrue(received["ok"], received.get("error"))
		self.assertEqual(received["data"]["status"], "created")

		self.assertEqual(self.bin_row()["actual_qty"], on_hand + 4.0)
		self.assertEqual(self.bin_row()["ordered_qty"], 0.0)

		after = self.as_planner(
			"manufacturing.production_control", {"sales_order": self.blocked_order()}
		)["data"]["orders"][0]
		self.assertTrue(after["can_start"], "the material arrived and production is still blocked")
		self.assertEqual(after["blocking_materials"], [])

	def test_the_receipt_is_a_real_erpnext_document_linked_to_the_order(self):
		order = self.place_order()["purchase_order"]

		received = self.as_planner(RECEIVE, {"purchase_order": order})["data"]

		frappe.set_user("Administrator")
		doc = frappe.get_doc("Purchase Receipt", received["purchase_receipt"])
		self.assertEqual(doc.docstatus, 1, "an unsubmitted receipt moves no stock")
		self.assertEqual(doc.items[0].purchase_order, order)
		self.assertTrue(doc.items[0].purchase_order_item, "the row-level link tracks fulfilment")
		self.assertEqual(doc.items[0].warehouse, "Stores - KRK")

	def test_what_arrived_is_readable_afterwards(self):
		order = self.place_order()["purchase_order"]
		received = self.as_planner(RECEIVE, {"purchase_order": order})["data"]

		found = self.as_planner(RECEIPTS, {"received_within_days": 1})["data"]["receipts"]

		receipt = next(r for r in found if r["purchase_receipt"] == received["purchase_receipt"])
		self.assertEqual(receipt["supplier"], BOARD_SUPPLIER)
		self.assertEqual(receipt["days_ago"], 0)
		self.assertEqual(receipt["items"][0]["received_qty"], 4.0)
		self.assertEqual(receipt["items"][0]["purchase_order"], order)


class TestTheQuantityIsTheOrdersNotTheModels(_BuyingTestCase):
	def test_receiving_more_than_was_ordered_books_in_only_what_was_ordered(self):
		"""«Прими 400 листов» against an order for four."""
		order = self.place_order()["purchase_order"]
		on_hand = self.bin_row()["actual_qty"]

		received = self.as_planner(
			RECEIVE, {"purchase_order": order, "items": [{"item_code": BOARD, "qty": 400}]}
		)["data"]

		self.assertEqual(received["items"][0]["received_qty"], 4.0)
		self.assertEqual(received["adjusted"], [{"item_code": BOARD, "asked": 400.0, "received": 4.0}])
		self.assertEqual(self.bin_row()["actual_qty"], on_hand + 4.0, "400 sheets reached the shelf")

	def test_a_partial_delivery_leaves_the_rest_outstanding(self):
		order = self.place_order()["purchase_order"]

		first = self.as_planner(
			RECEIVE, {"purchase_order": order, "items": [{"item_code": BOARD, "qty": 1}]}
		)["data"]

		self.assertFalse(first["fully_received"])
		line = first["order_lines"][0]
		self.assertEqual((line["ordered_qty"], line["received_qty"], line["remaining_qty"]), (4.0, 1.0, 3.0))

		stage = next(
			row
			for row in self.as_planner(STATUS, {})["data"]["blocking_production"]
			if row["item_code"] == BOARD
		)
		self.assertEqual(stage["stage"], "PARTIALLY_RECEIVED")
		self.assertEqual(stage["received_qty"], 1.0)
		self.assertEqual(stage["awaiting_qty"], 3.0)

	def test_the_rest_can_be_received_later(self):
		order = self.place_order()["purchase_order"]
		self.as_planner(RECEIVE, {"purchase_order": order, "items": [{"item_code": BOARD, "qty": 1}]})

		second = self.as_planner(RECEIVE, {"purchase_order": order})["data"]

		self.assertTrue(second["fully_received"])
		line = second["order_lines"][0]
		self.assertEqual((line["received_qty"], line["remaining_qty"]), (4.0, 0.0))

	def test_a_non_positive_quantity_is_refused(self):
		order = self.place_order()["purchase_order"]

		result = self.as_planner(
			RECEIVE, {"purchase_order": order, "items": [{"item_code": BOARD, "qty": 0}]}
		)

		self.assertFalse(result["ok"])
		self.assertIn("greater than zero", result["error"]["message"])


class TestReceivingCannotHappenTwice(_BuyingTestCase):
	def test_a_second_receipt_creates_nothing_and_invents_no_stock(self):
		"""Booking the same delivery twice would put material on the shelf that
		never arrived — the one error in this module that a stocktake finds
		months later."""
		order = self.place_order()["purchase_order"]
		self.as_planner(RECEIVE, {"purchase_order": order})
		on_hand = self.bin_row()["actual_qty"]

		again = self.as_planner(RECEIVE, {"purchase_order": order})

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "not_needed")
		self.assertEqual(self.bin_row()["actual_qty"], on_hand)
		self.assertEqual(frappe.db.count("Purchase Receipt"), 1)


class TestReceivingIsGuarded(_BuyingTestCase):
	def test_it_is_a_write_that_needs_confirmation(self):
		spec = registry.get(RECEIVE)

		self.assertIs(spec.risk, registry.Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)

	def test_an_unknown_order_is_a_sentence_not_a_traceback(self):
		result = self.as_planner(RECEIVE, {"purchase_order": "PUR-ORD-9999-99999"})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"])

	def test_a_viewer_cannot_book_stock_in(self):
		order = self.place_order()["purchase_order"]
		on_hand = self.bin_row()["actual_qty"]

		frappe.set_user(VIEWER)
		try:
			result = registry.execute(RECEIVE, {"purchase_order": order})
			offered = {spec.name for spec in registry.available_to()}
		finally:
			frappe.set_user("Administrator")

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "permission_denied")
		self.assertNotIn(RECEIVE, offered)
		self.assertEqual(self.bin_row()["actual_qty"], on_hand)
		self.assertEqual(frappe.db.count("Purchase Receipt"), 0)
