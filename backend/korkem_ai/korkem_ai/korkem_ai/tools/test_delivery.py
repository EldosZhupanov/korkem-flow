# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Shipping finished goods — the last step, and the one that empties a shelf.

Two numbers bound every shipment: what is still owed, and what is physically
there. Most of these tests are about the second one, because a delivery note is
the point where a confident number becomes a lorry leaving with stock that does
not exist.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import seed_demo

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401
from korkem_ai.korkem_ai.tools import foreign_fixture

STATUS = "sales.delivery_status"
SHIP = "sales.create_delivery"
TIMELINE = "crm.customer_timeline"
PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"
CUSTOMER = "Мебель Астана"
PRODUCT = "Шкаф Астана"
FINISHED = "Finished Goods - KRK"

#: Stamped on every stock entry this fixture creates, so cleanup can reverse
#: exactly its own and never touch a seeded document. Deliberately not the
#: seed's own marker: `seed_demo.remove()` matches on that one.
FIXTURE_MARKER = "KORKEM test fixture — delivery"


class _DeliveryTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.order = frappe.db.get_value(
			"Sales Order", {"customer": CUSTOMER, "docstatus": 1}, "name"
		)
		if not self.order:
			self.skipTest("seed_demo has not been run on this site")
		seed_demo.seed_users()
		self._clean()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		self._clean()

	def _clean(self):
		"""Undo this test's own documents — by reversing them, not by offsetting them.

		The previous version put the shelf back by posting a compensating
		Material Receipt or Issue. It worked, and it left a permanent pair of
		submitted stock entries on the demo bench every time the suite ran;
		ten of them had accumulated in the KORKEM ledger by Phase 21. A ledger
		that grows every time the tests run is not a ledger anybody can audit.

		So a fixture entry is now cancelled and deleted rather than answered
		with an opposite one. Newest first, because the top-up has to come off
		the shelf before anything it was stacked on.
		"""
		frappe.set_user("Administrator")
		for name in frappe.get_all("Delivery Note", pluck="name"):
			note = frappe.get_doc("Delivery Note", name)
			if note.docstatus == 1:
				note.cancel()
			frappe.delete_doc("Delivery Note", name, force=1, ignore_permissions=True)

		for name in frappe.get_all(
			"Stock Entry",
			filters={"remarks": ["like", f"%{FIXTURE_MARKER}%"]},
			pluck="name",
			order_by="creation desc",
		):
			entry = frappe.get_doc("Stock Entry", name)
			if entry.docstatus == 1:
				entry.cancel()
			frappe.delete_doc("Stock Entry", name, force=1, ignore_permissions=True)

		frappe.db.delete("Pending Action", {"tool": SHIP})
		frappe.db.commit()

	def top_up(self, qty: float):
		"""Put `qty` extra units on the shelf for a test that needs them.

		Tagged so `_clean` can find and reverse exactly these and never a seeded
		document. This is stock appearing from nowhere, which is why it is
		confined to the fixture: the four cabinets it conjures cannot be
		manufactured for real, because the board for them is precisely the
		shortage the rest of the suite is built on.
		"""
		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Receipt",
				"company": "KORKEM",
				"remarks": FIXTURE_MARKER,
				"items": [
					{
						"item_code": PRODUCT,
						"qty": qty,
						"t_warehouse": FINISHED,
						"basic_rate": 100000,
						"allow_zero_valuation_rate": 1,
					}
				],
			}
		)
		entry.insert(ignore_permissions=True)
		entry.submit()
		frappe.db.commit()
		return entry.name

	def on_hand(self) -> float:
		frappe.set_user("Administrator")
		return float(
			frappe.db.get_value("Bin", {"item_code": PRODUCT, "warehouse": FINISHED}, "actual_qty") or 0
		)

	def as_user(self, user, tool, args=None):
		frappe.set_user(user)
		try:
			return registry.execute(tool, args or {})
		finally:
			frappe.set_user("Administrator")

	def status(self, **args):
		result = self.as_user(PLANNER, STATUS, args)
		self.assertTrue(result["ok"], result.get("error"))
		return result["data"]

	def mine(self):
		return next(
			row for row in self.status()["orders"] if row["sales_order"] == self.order
		)

	def ship(self, **args):
		return self.as_user(PLANNER, SHIP, {"sales_order": self.order, **args})


class TestWhatCanBeShippedIsBoundedByBoth(_DeliveryTestCase):
	def test_shippable_is_the_smaller_of_owed_and_on_hand(self):
		"""Ten are owed and six exist, so six is the answer — not ten."""
		order = self.mine()

		self.assertEqual(order["ordered_qty"], 10.0)
		self.assertEqual(order["pending_qty"], 10.0)
		self.assertEqual(order["shippable_now"], 6.0)
		self.assertEqual(order["delivery_state"], "PARTIAL")

	def test_availability_is_what_is_on_the_shelf_not_what_is_projected(self):
		line = self.mine()["items"][0]

		self.assertEqual(line["available_qty"], self.on_hand())
		self.assertEqual(line["short_by"], 4.0)

	def test_erpnext_status_is_reported_beside_our_reading(self):
		"""Two vocabularies, both shown — ours is an interpretation, not a
		replacement."""
		order = self.mine()

		self.assertEqual(
			order["erpnext_status"],
			frappe.db.get_value("Sales Order", self.order, "status"),
		)
		self.assertIn(order["delivery_state"], ("READY", "PARTIAL", "BLOCKED", "DELIVERED", "CLOSED"))


class TestShippingMovesRealStock(_DeliveryTestCase):
	def test_a_partial_shipment_sends_what_exists(self):
		before = self.on_hand()

		result = self.ship()

		self.assertTrue(result["ok"], result.get("error"))
		data = result["data"]
		self.assertEqual(data["status"], "delivered")
		self.assertFalse(data["fully_delivered"])
		self.assertEqual(data["items"][0]["qty"], 6.0)
		self.assertEqual(self.on_hand(), before - 6.0, "the shelf did not empty")

	def test_the_note_is_a_real_submitted_document_linked_to_the_order(self):
		data = self.ship()["data"]

		frappe.set_user("Administrator")
		note = frappe.get_doc("Delivery Note", data["delivery_note"])
		self.assertEqual(note.docstatus, 1, "an unsubmitted note ships nothing")
		self.assertEqual(note.customer, CUSTOMER)
		self.assertEqual(note.company, "KORKEM")
		self.assertEqual(note.items[0].against_sales_order, self.order)
		self.assertEqual(note.items[0].warehouse, FINISHED)
		self.assertEqual(note.owner, PLANNER)

	def test_the_sales_order_records_what_went_out(self):
		self.ship()

		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.get_value("Sales Order", self.order, "per_delivered"), 60.0)
		self.assertEqual(
			frappe.db.get_value("Sales Order Item", {"parent": self.order}, "delivered_qty"), 6.0
		)

	def test_what_is_left_becomes_blocked_rather_than_ready(self):
		"""Four are still owed and the shelf is empty — that is not "ready to
		ship", and calling it so would send somebody to an empty warehouse."""
		self.ship()

		order = self.mine()

		self.assertEqual(order["delivered_qty"], 6.0)
		self.assertEqual(order["pending_qty"], 4.0)
		self.assertEqual(order["shippable_now"], 0.0)
		self.assertEqual(order["delivery_state"], "BLOCKED")


class TestTheQuantityIsNeverTheModels(_DeliveryTestCase):
	def test_asking_for_more_than_exists_ships_what_exists(self):
		before = self.on_hand()

		data = self.ship(items=[{"item_code": PRODUCT, "qty": 400}])["data"]

		self.assertEqual(data["items"][0]["qty"], 6.0)
		self.assertEqual(data["adjusted"], [{"item_code": PRODUCT, "asked": 400.0, "shipped": 6.0}])
		self.assertEqual(self.on_hand(), before - 6.0, "400 cabinets left the building")

	def test_a_smaller_shipment_than_available_is_honoured(self):
		"""Sending two of the six is a normal thing to ask for."""
		before = self.on_hand()

		data = self.ship(items=[{"item_code": PRODUCT, "qty": 2}])["data"]

		self.assertEqual(data["items"][0]["qty"], 2.0)
		self.assertEqual(data["adjusted"], [])
		self.assertEqual(self.on_hand(), before - 2.0)

	def test_a_non_positive_quantity_is_refused(self):
		result = self.ship(items=[{"item_code": PRODUCT, "qty": 0}])

		self.assertFalse(result["ok"])
		self.assertIn("greater than zero", result["error"]["message"])

	def test_an_item_not_on_the_order_is_refused(self):
		result = self.ship(items=[{"item_code": "ДСП 16мм", "qty": 1}])

		self.assertFalse(result["ok"])
		self.assertIn("no line for", result["error"]["message"])


class TestShippingTwiceShipsNothingTwice(_DeliveryTestCase):
	def test_a_second_shipment_with_an_empty_shelf_creates_no_note(self):
		self.ship()
		before = self.on_hand()

		again = self.ship()

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "nothing_shippable")
		self.assertEqual(self.on_hand(), before)
		self.assertEqual(frappe.db.count("Delivery Note"), 1)

	def test_a_fully_delivered_order_reports_already_delivered(self):
		frappe.set_user("Administrator")
		# Put the remaining four on the shelf so the order can be finished.
		self.top_up(4)

		first = self.ship()["data"]
		self.assertTrue(first["fully_delivered"])

		again = self.ship()

		self.assertEqual(again["data"]["status"], "already_delivered")
		self.assertEqual(frappe.db.count("Delivery Note"), 1)


class TestTheOrderMustBeShippable(_DeliveryTestCase):
	def test_an_unknown_order_is_a_sentence_not_a_traceback(self):
		result = self.as_user(PLANNER, SHIP, {"sales_order": "SAL-ORD-9999-99999"})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"])

	def test_a_closed_order_cannot_be_shipped(self):
		frappe.set_user("Administrator")
		kept = frappe.db.get_value("Sales Order", self.order, "status")
		frappe.db.set_value("Sales Order", self.order, "status", "Closed")
		frappe.db.commit()
		self.addCleanup(self._restore_status, kept)

		result = self.ship()

		self.assertFalse(result["ok"])
		self.assertIn("Closed", result["error"]["message"])
		self.assertEqual(frappe.db.count("Delivery Note"), 0)

	def _restore_status(self, kept):
		frappe.set_user("Administrator")
		frappe.db.set_value("Sales Order", self.order, "status", kept)
		frappe.db.commit()


class TestScopeAndPermissions(_DeliveryTestCase):
	def test_neither_tool_takes_a_company(self):
		for name in (STATUS, SHIP):
			with self.subTest(tool=name):
				self.assertNotIn("company", registry.get(name).input_schema["properties"])

	def test_shipping_is_a_write_needing_confirmation(self):
		spec = registry.get(SHIP)

		self.assertIs(spec.risk, registry.Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)

	def test_another_companys_order_cannot_be_read_or_shipped(self):
		frappe.set_user("Administrator")
		foreign = foreign_fixture.ensure()["sales_order"]

		read = self.as_user(PLANNER, STATUS, {"sales_order": foreign})
		write = self.as_user(PLANNER, SHIP, {"sales_order": foreign})

		self.assertFalse(read["ok"])
		self.assertIn("not found", read["error"]["message"].lower())
		self.assertFalse(write["ok"])
		self.assertIn("not found", write["error"]["message"].lower())
		self.assertEqual(frappe.db.count("Delivery Note"), 0)


class TestTheTimelineSeesTheDelivery(_DeliveryTestCase):
	def test_delivery_moves_from_none_to_present(self):
		before = self.as_user(PLANNER, TIMELINE, {"customer": CUSTOMER})["data"]["delivery"]
		self.assertEqual(before["status"], "none")

		note = self.ship()["data"]["delivery_note"]

		after = self.as_user(PLANNER, TIMELINE, {"customer": CUSTOMER})["data"]["delivery"]
		self.assertEqual(after["status"], "present")
		self.assertEqual(after["deliveries"][0]["delivery_note"], note)
		self.assertEqual(after["deliveries"][0]["qty"], 6.0)

	def test_a_blind_spot_is_still_a_blind_spot(self):
		"""Phase 19's distinction must survive a section going live.

		The planner holds no CRM role, so their CRM section stays `no_access`
		even once delivery has real documents in it — filling one section in
		must not quietly downgrade another from "cannot see" to "nothing there".
		The viewer is a useful contrast: `Sales User` *does* grant CRM read, so
		the same customer reads `none` for them.
		"""
		self.ship()

		planner = self.as_user(PLANNER, TIMELINE, {"customer": CUSTOMER})["data"]
		viewer = self.as_user(VIEWER, TIMELINE, {"customer": CUSTOMER})["data"]

		self.assertEqual(planner["crm"]["status"], "no_access")
		self.assertEqual(planner["delivery"]["status"], "present")
		self.assertEqual(viewer["crm"]["status"], "none")
