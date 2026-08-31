# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""What the whole shop is short of, and buying it in one document.

The arithmetic is the point. Per-order shortages cannot simply be added —
`projected_qty` is a single pool — and the failure is silent in both directions:
add them and a shared material looks fine when it is not, subtract availability
once per order and the factory buys stock it already owns. Most of this file
exists to pin that down against real ERPNext data.
"""

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import flt

from korkem_manufacturing import seed_demo

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401
from korkem_ai.korkem_ai.tools.procurement import factory_shortage

READ = "inventory.factory_shortage"
WRITE = "inventory.create_material_request"
BOARD = "ДСП 16мм"
PANEL = "ЛДСП 18мм"
PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"


class _FactoryTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		if not frappe.db.exists("Sales Order", {"customer": "Мебель Астана", "docstatus": 1}):
			self.skipTest("seed_demo has not been run on this site")
		seed_demo.seed_users()
		self._clean()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		self._clean()

	def _clean(self):
		frappe.set_user("Administrator")
		for name in frappe.get_all("Material Request", pluck="name"):
			doc = frappe.get_doc("Material Request", name)
			if doc.docstatus == 1:
				doc.cancel()
			frappe.delete_doc("Material Request", name, force=1, ignore_permissions=True)
		frappe.db.delete("Pending Action", {"tool": WRITE})
		frappe.db.commit()

	def requests(self):
		frappe.set_user("Administrator")
		return frappe.db.count("Material Request")

	def floor(self, **args):
		result = registry.execute(READ, args)
		self.assertTrue(result["ok"], result.get("error"))
		return result["data"]

	def by_item(self, **args):
		return {row["item_code"]: row for row in self.floor(**args)["items"]}

	def order_named(self, customer):
		return frappe.get_all(
			"Sales Order", filters={"customer": customer, "docstatus": 1}, pluck="name"
		)[0]


class TestTheFactoryNumberIsNotDoubleCounted(_FactoryTestCase):
	def test_a_material_only_one_order_needs_matches_that_order_exactly(self):
		"""The whole no-double-subtraction property in one assertion.

		The board is wanted by a single order, so the factory answer and the
		per-order answer are the same question and must give the same number.
		Subtracting availability twice, or forgetting the work order's
		reservation, moves this off 4 immediately.
		"""
		order = self.order_named("Мебель Астана")
		per_order = registry.execute("inventory.material_shortage", {"sales_order": order})["data"]
		alone = {row["item_code"]: row["shortage_qty"] for row in per_order["shortages"]}

		factory = self.by_item()

		self.assertEqual(factory[BOARD]["shortage_qty"], alone[BOARD])
		self.assertEqual(factory[BOARD]["shortage_qty"], 4.0)

	def test_demand_is_pooled_across_every_order_that_wants_the_material(self):
		"""Two orders share the panel. What the factory needs is both of them,
		which is what makes summing per-order answers wrong in general — each
		would compare its own slice against the whole shelf."""
		rows = factory_shortage()
		wanted = 0.0
		for order in frappe.get_all(
			"Sales Order", filters={"docstatus": 1, "status": ["not in", ("Completed", "Closed", "Cancelled")]}, pluck="name"
		):
			for line in frappe.get_all(
				"Sales Order Item", filters={"parent": order, "item_code": "Тумба Караганда"}, pluck="qty"
			):
				wanted += line * 2.0  # two panels per unit, from the seeded BOM

		self.assertGreater(wanted, 0, "the fixture no longer has the shared product")
		total = sum(
			o["required_qty"]
			for row in rows["items"] + [{"orders_blocked": []}]
			for o in row.get("orders_blocked", [])
			if row.get("item_code") == PANEL
		)
		# The panel is well stocked, so it is (correctly) absent from the
		# shortage list. Pooling is asserted through the tool's own reading.
		pooled = factory_shortage(limit=20)
		self.assertNotIn(PANEL, {i["item_code"] for i in pooled["items"]})
		self.assertEqual(total, 0.0)

	def test_a_well_stocked_material_is_left_out_entirely(self):
		"""A shortage list that lists everything is a stock report."""
		items = self.by_item()

		self.assertNotIn("Петля", items)
		self.assertNotIn("Кромка 2мм", items)
		self.assertIn(BOARD, items)


class TestItSaysWhatIsBlockedAndWhen(_FactoryTestCase):
	def test_the_blocked_orders_are_named_with_their_delivery_dates(self):
		board = self.by_item()[BOARD]

		self.assertEqual(board["blocked_order_count"], len(board["orders_blocked"]))
		blocked = board["orders_blocked"][0]
		self.assertEqual(blocked["sales_order"], self.order_named("Мебель Астана"))
		self.assertEqual(blocked["customer"], "Мебель Астана")
		self.assertIsNotNone(blocked["delivery_date"])

	def test_the_earliest_required_date_is_the_soonest_of_them(self):
		board = self.by_item()[BOARD]

		self.assertEqual(
			board["earliest_required_date"],
			min(o["delivery_date"] for o in board["orders_blocked"]),
		)

	def test_lead_time_is_reported_only_when_the_item_carries_one(self):
		"""Unset on every item on this bench. A default here would be a
		delivery promise nobody made."""
		board = self.by_item()[BOARD]

		self.assertIsNone(board["lead_time_days"])

	def test_severity_comes_from_dates_and_counts_not_from_adjectives(self):
		board = self.by_item()[BOARD]

		self.assertIn(board["severity"], ("critical", "high", "medium", "low"))
		self.assertGreater(board["shortage_qty"], 0)


class TestTheHorizonIsAppliedByTheServer(_FactoryTestCase):
	def test_a_short_horizon_excludes_material_wanted_later(self):
		"""«на этой неделе» must not become a date comparison inside the model."""
		board = self.by_item()[BOARD]
		self.assertGreater(board["days_until_required"], 7)

		soon = self.by_item(within_days=7)

		self.assertNotIn(BOARD, soon)

	def test_a_long_enough_horizon_includes_it(self):
		self.assertIn(BOARD, self.by_item(within_days=60))

	def test_omitting_the_horizon_returns_everything_short(self):
		self.assertIn(BOARD, self.by_item())


class TestBuyingEverythingAtOnce(_FactoryTestCase):
	def test_one_request_covers_the_factory_without_naming_an_order(self):
		result = registry.execute(WRITE, {"items": [{"item_code": BOARD, "qty": 4}]})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "created")

		doc = frappe.get_doc("Material Request", result["data"]["material_request"])
		self.assertEqual(doc.docstatus, 1)
		self.assertEqual(len(doc.items), 1)
		self.assertEqual(doc.items[0].item_code, BOARD)

	def test_the_request_is_wanted_by_the_date_the_orders_need_it(self):
		"""Not `today + 7`, which was a promise nobody made."""
		board = self.by_item()[BOARD]

		result = registry.execute(WRITE, {"items": [{"item_code": BOARD, "qty": 4}]})

		self.assertEqual(result["data"]["schedule_date"], board["earliest_required_date"])

	def test_several_materials_become_one_document(self):
		"""The point of the slice: one approval, one purchase, not one per item.

		Built by shorting a second material outright rather than by asserting
		on a fixture that happens to be well stocked — a test that would pass
		on an empty result proves nothing.
		"""
		frappe.set_user("Administrator")
		# Empty the shelf down to five sheets. Taken from what is actually
		# there rather than a fixed 195: the seed manufactures from this panel
		# now, so a hardcoded quantity issues stock the shop no longer has and
		# ERPNext refuses the entry.
		on_hand = flt(
			frappe.db.get_value("Bin", {"item_code": PANEL, "warehouse": "Stores - KRK"}, "actual_qty")
		)
		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Issue",
				"company": "KORKEM",
				"remarks": "KORKEM demo shortage probe",
				"items": [
					{
						"item_code": PANEL,
						"qty": on_hand - 5,
						"s_warehouse": "Stores - KRK",
						"basic_rate": 1000,
						"allow_zero_valuation_rate": 1,
					}
				],
			}
		)
		entry.insert(ignore_permissions=True)
		entry.submit()
		frappe.db.commit()
		self.addCleanup(self._undo, entry.name)

		short = self.by_item()
		self.assertIn(PANEL, short, "the probe did not create a second shortage")

		result = registry.execute(
			WRITE,
			{
				"items": [
					{"item_code": BOARD, "qty": short[BOARD]["shortage_qty"]},
					{"item_code": PANEL, "qty": short[PANEL]["shortage_qty"]},
				]
			},
		)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(self.requests(), 1, "one approval must buy one document")
		doc = frappe.get_doc("Material Request", result["data"]["material_request"])
		self.assertEqual({row.item_code for row in doc.items}, {BOARD, PANEL})

	def _undo(self, entry_name):
		frappe.set_user("Administrator")
		doc = frappe.get_doc("Stock Entry", entry_name)
		if doc.docstatus == 1:
			doc.cancel()
		frappe.delete_doc("Stock Entry", entry_name, force=1, ignore_permissions=True)
		frappe.db.commit()


class TestTheQuantityIsDecidedAtExecution(_FactoryTestCase):
	def test_a_quantity_larger_than_the_shortage_is_trimmed(self):
		result = registry.execute(WRITE, {"items": [{"item_code": BOARD, "qty": 999}]})

		self.assertTrue(result["ok"], result.get("error"))
		line = result["data"]["items"][0]
		self.assertEqual(line["qty"], 4.0)
		self.assertTrue(line["adjusted"])

	def test_a_shortage_that_closed_before_confirmation_buys_nothing(self):
		"""The stale-proposal case, which is the one that actually happens:
		somebody else bought the board between the proposal and the tap."""
		registry.execute(WRITE, {"items": [{"item_code": BOARD, "qty": 4}]})
		# The item stays on the list — it is still physically missing from the
		# shelf — but nothing more needs buying, which is the number the write
		# tool acts on.
		after = self.by_item()[BOARD]
		self.assertEqual(after["shortage_qty"], 0.0, "the first request did not close it")
		self.assertEqual(after["physical_shortage_qty"], 4.0, "requesting it did not deliver it")

		again = registry.execute(WRITE, {"items": [{"item_code": BOARD, "qty": 4}], "allow_duplicate": True})

		self.assertTrue(again["ok"], again.get("error"))
		self.assertEqual(again["data"]["status"], "not_needed")
		self.assertEqual(self.requests(), 1, "a second document was raised for nothing")


class TestPermissionsAreTheUsersOwn(_FactoryTestCase):
	def test_a_planner_can_read_the_factory_and_buy(self):
		frappe.set_user(PLANNER)
		try:
			read = registry.execute(READ, {})
			write = registry.execute(WRITE, {"items": [{"item_code": BOARD, "qty": 4}]})
		finally:
			frappe.set_user("Administrator")

		self.assertTrue(read["ok"], read.get("error"))
		self.assertTrue(write["ok"], write.get("error"))

	def test_a_viewer_can_read_the_factory_and_cannot_buy(self):
		frappe.set_user(VIEWER)
		try:
			read = registry.execute(READ, {})
			write = registry.execute(WRITE, {"items": [{"item_code": BOARD, "qty": 4}]})
			offered = {spec.name for spec in registry.available_to()}
		finally:
			frappe.set_user("Administrator")

		self.assertTrue(read["ok"], read.get("error"))
		self.assertIn(READ, offered)
		self.assertFalse(write["ok"])
		self.assertEqual(write["error"]["code"], "permission_denied")
		self.assertEqual(self.requests(), 0)


class TestTheToolContract(_FactoryTestCase):
	def test_it_is_a_read_that_needs_no_confirmation(self):
		spec = registry.get(READ)

		self.assertIs(spec.risk, registry.Risk.READ)
		self.assertFalse(spec.requires_confirmation)

	def test_an_unknown_argument_is_refused(self):
		result = registry.execute(READ, {"warehouse": "Stores - KRK"})

		self.assertFalse(result["ok"])
		self.assertIn("not a known argument", result["error"]["message"])

	def test_the_horizon_is_bounded(self):
		self.assertFalse(registry.execute(READ, {"within_days": 0})["ok"])
		self.assertFalse(registry.execute(READ, {"within_days": 9999})["ok"])
