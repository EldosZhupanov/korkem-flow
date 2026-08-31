# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Starting production — the first thing that changes the shop floor.

Everything before this described the factory. This moves material out of the
store and puts a job in progress, so the interesting assertions are about what
must *not* happen: starting a job whose board is still on order, starting one
twice, or starting another company's.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import flt

from korkem_manufacturing import seed_demo

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401

START = "manufacturing.start_production"
CONTROL = "manufacturing.production_control"
PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"

#: The seeded order nobody has started and that lacks nothing.
READY_CUSTOMER = "Павлодар Уют"
#: The seeded order that is four sheets short.
BLOCKED_CUSTOMER = "Мебель Астана"
BOARD = "ДСП 16мм"


def _order(customer):
	rows = frappe.get_all(
		"Sales Order", filters={"customer": customer, "docstatus": 1}, pluck="name"
	)
	return rows[0] if rows else None


class _ProductionTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.ready = _order(READY_CUSTOMER)
		self.blocked = _order(BLOCKED_CUSTOMER)
		if not (self.ready and self.blocked):
			self.skipTest("seed_demo has not been run on this site")
		seed_demo.seed_users()
		self._clean()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		self._clean()

	def own_work_orders(self):
		"""The jobs this fixture is allowed to touch.

		Only the order nobody has started, which is the one every test here
		starts for itself. The other two seeded orders carry real manufacturing
		entries now, and a fixture that cancels those is not cleaning up after
		itself — it is deleting the factory.
		"""
		return frappe.get_all(
			"Work Order", filters={"sales_order": self.ready, "docstatus": ["<", 2]}, pluck="name"
		)

	def _clean(self):
		"""Undo a start: the transfer first, then the job it belongs to.

		Scoped to `own_work_orders`. An earlier version swept every
		`Material Transfer for Manufacture` on the site, which was harmless
		only for as long as the seed contained no production of its own. Once
		the seed started manufacturing for real it cancelled the seeded
		transfers too, taking `produced_qty` back to zero and emptying the
		finished-goods shelf — and the delivery suite then failed with what
		looked like a delivery bug thirty tests later.
		"""
		frappe.set_user("Administrator")
		mine = self.own_work_orders()
		for name in (
			frappe.get_all(
				"Stock Entry",
				filters={
					"purpose": "Material Transfer for Manufacture",
					"docstatus": 1,
					"work_order": ["in", mine],
				},
				pluck="name",
			)
			if mine
			else []
		):
			frappe.get_doc("Stock Entry", name).cancel()
			frappe.delete_doc("Stock Entry", name, force=1, ignore_permissions=True)

		for name in mine:
			doc = frappe.get_doc("Work Order", name)
			if doc.docstatus == 1:
				doc.cancel()
			frappe.delete_doc("Work Order", name, force=1, ignore_permissions=True)

		frappe.db.delete("Pending Action", {"tool": START})
		frappe.db.commit()

	def as_user(self, user, tool, args=None):
		frappe.set_user(user)
		try:
			return registry.execute(tool, args or {})
		finally:
			frappe.set_user("Administrator")

	def start(self, sales_order):
		return self.as_user(PLANNER, START, {"sales_order": sales_order})

	def on_hand(self, item, warehouse="Stores - KRK"):
		frappe.set_user("Administrator")
		return frappe.db.get_value("Bin", {"item_code": item, "warehouse": warehouse}, "actual_qty")


class TestMaterialOnOrderIsNotMaterialOnTheShelf(_ProductionTestCase):
	def test_an_order_short_of_board_cannot_be_started(self):
		result = self.start(self.blocked)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "blocked")
		self.assertEqual(
			{m["item_code"] for m in result["data"]["blocking_materials"]}, {BOARD}
		)

	def test_a_blocked_start_moves_no_stock_and_plans_no_job(self):
		before = self.on_hand(BOARD)
		planned = frappe.db.count("Work Order", {"sales_order": self.blocked, "docstatus": 1})

		self.start(self.blocked)

		self.assertEqual(self.on_hand(BOARD), before)
		self.assertEqual(
			frappe.db.count("Work Order", {"sales_order": self.blocked, "docstatus": 1}), planned
		)

	def test_asking_the_control_tool_gives_the_same_answer(self):
		"""The read and the write must agree about whether a job can run, or a
		user is told yes by one and no by the other."""
		order = self.as_user(PLANNER, CONTROL, {"sales_order": self.blocked})["data"]["orders"][0]

		self.assertFalse(order["can_start"])
		self.assertEqual({m["item_code"] for m in order["blocking_materials"]}, {BOARD})


class TestStartingPlansTheWorkAndMovesTheMaterial(_ProductionTestCase):
	def test_an_order_with_no_work_order_gets_one(self):
		"""Nobody had planned this order. Starting it is what plans it — and the
		work order is what carries the seven operations."""
		result = self.start(self.ready)

		self.assertTrue(result["ok"], result.get("error"))
		data = result["data"]
		self.assertEqual(data["status"], "started")
		self.assertIsNotNone(data["work_order_created"])

		frappe.set_user("Administrator")
		job = frappe.get_doc("Work Order", data["work_order"])
		self.assertEqual(job.docstatus, 1)
		self.assertEqual(job.sales_order, self.ready)
		self.assertEqual(len(job.operations), 7, "the job has no stages")

	def test_a_failed_transfer_rolls_back_the_work_order(self):
		"""The registry reports failures as data, so the service owns rollback.

		A request handler would roll the transaction back after an exception. The
		AI registry deliberately catches one so the rest of a turn can continue;
		without a savepoint here that left a submitted Work Order behind even
		though no material reached work in progress.
		"""
		before = frappe.db.count("Work Order", {"sales_order": self.ready, "docstatus": 1})

		with patch(
			"erpnext.manufacturing.doctype.work_order.mapper.make_stock_entry",
			side_effect=RuntimeError("stock mapper unavailable"),
		):
			result = self.start(self.ready)

		self.assertFalse(result["ok"])
		self.assertEqual(
			frappe.db.count("Work Order", {"sales_order": self.ready, "docstatus": 1}),
			before,
			"a failed start must not leave a submitted job without its transfer",
		)

	def test_a_named_item_never_starts_another_items_existing_job(self):
		"""A multi-item order may have an older startable job for another line."""
		first_source = frappe.get_doc("Sales Order", self.ready)
		second_source = frappe.get_doc("Sales Order", self.blocked).items[0]
		first_item = first_source.items[0].item_code
		second_item = second_source.item_code
		if first_item == second_item:
			self.skipTest("the seed does not contain two distinct manufactured items")

		order = frappe.copy_doc(first_source)
		order.items[0].qty = 1
		order.append(
			"items",
			{
				"item_code": second_item,
				"qty": 2,
				"rate": second_source.rate,
				"delivery_date": second_source.delivery_date,
				"warehouse": second_source.warehouse,
			},
		)
		order.insert()
		order.submit()

		first_line = order.items[0]
		job = frappe.new_doc("Work Order")
		job.update(
			{
				"production_item": first_item,
				"bom_no": frappe.db.get_value(
					"BOM", {"item": first_item, "is_active": 1, "is_default": 1}, "name"
				),
				"company": order.company,
				"qty": 1,
				"sales_order": order.name,
				"sales_order_item": first_line.name,
				"wip_warehouse": "Work In Progress - KRK",
				"fg_warehouse": first_line.warehouse,
				"planned_start_date": frappe.utils.nowdate(),
			}
		)
		job.set_work_order_operations()
		job.insert()
		job.submit()

		mapped_items = []

		def fail_after_selecting_job(work_order, *args, **kwargs):
			mapped_items.append(frappe.db.get_value("Work Order", work_order, "production_item"))
			raise RuntimeError("stop after selecting the job")

		with (
			patch(
				"korkem_manufacturing.services.production.material_shortage",
				return_value={"not_on_the_shelf": []},
			),
			patch(
				"erpnext.manufacturing.doctype.work_order.mapper.make_stock_entry",
				side_effect=fail_after_selecting_job,
			),
		):
			result = self.as_user(
				PLANNER,
				START,
				{"sales_order": order.name, "item_code": second_item},
			)

		self.assertFalse(result["ok"])
		self.assertEqual(
			mapped_items,
			[second_item],
			"the requested item must select only its own Work Order",
		)

	def test_the_material_actually_leaves_the_store(self):
		panel = "ЛДСП 18мм"
		before = self.on_hand(panel)

		result = self.start(self.ready)["data"]

		self.assertLess(self.on_hand(panel), before, "nothing left the store")
		frappe.set_user("Administrator")
		transfer = frappe.get_doc("Stock Entry", result["material_transfer"])
		self.assertEqual(transfer.docstatus, 1)
		self.assertEqual(transfer.purpose, "Material Transfer for Manufacture")
		self.assertTrue(
			all(row.t_warehouse.startswith("Work In Progress") for row in transfer.items)
		)

	def test_the_job_reports_its_real_erpnext_status_and_stage(self):
		"""Read back from the database, not reported from intent."""
		data = self.start(self.ready)["data"]

		frappe.set_user("Administrator")
		self.assertEqual(
			data["work_order_status"], frappe.db.get_value("Work Order", data["work_order"], "status")
		)
		self.assertEqual(data["work_order_status"], "In Process")
		self.assertEqual(data["current_operation"], "Раскрой")
		self.assertEqual(data["next_operation"], "Кромление")

	def test_the_control_tool_then_shows_the_stage(self):
		self.start(self.ready)

		order = self.as_user(PLANNER, CONTROL, {"sales_order": self.ready})["data"]["orders"][0]

		job = order["work_orders"][0]
		self.assertEqual(job["current_operation"], "Раскрой")
		self.assertEqual(job["current_workstation"], "Раскрой")
		self.assertEqual(job["next_operation"], "Кромление")
		self.assertEqual(len(job["operations"]), 7)


class TestStartingTwiceDoesNothingTwice(_ProductionTestCase):
	def test_a_second_start_moves_no_further_material(self):
		panel = "ЛДСП 18мм"
		self.start(self.ready)
		after_first = self.on_hand(panel)

		again = self.start(self.ready)

		self.assertTrue(again["ok"], again.get("error"))
		self.assertEqual(again["data"]["status"], "already_started")
		self.assertEqual(self.on_hand(panel), after_first, "material was transferred twice")


class TestStartingIsGuarded(_ProductionTestCase):
	def test_it_is_a_write_that_needs_confirmation(self):
		spec = registry.get(START)

		self.assertIs(spec.risk, registry.Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)

	def test_it_takes_no_quantity_from_the_model(self):
		"""How much to build comes from the order. There is no number for a
		model to get wrong."""
		properties = registry.get(START).input_schema["properties"]

		self.assertNotIn("qty", properties)
		self.assertNotIn("company", properties)

	def test_an_unknown_order_is_a_sentence_not_a_traceback(self):
		result = self.as_user(PLANNER, START, {"sales_order": "SAL-ORD-9999-99999"})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"])

	def test_a_manufacturing_user_may_start_production(self):
		"""Recorded rather than assumed. Both demo users hold `Manufacturing
		User`, and in ERPNext that role owns work orders and stock entries — so
		starting a job is legitimately theirs. The viewer's boundary is *buying*,
		not producing, and pretending otherwise would be a test asserting a role
		model that does not exist."""
		self.assertIn("Manufacturing User", frappe.get_roles(VIEWER))

		result = self.as_user(VIEWER, START, {"sales_order": self.ready})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "started")

	def test_someone_without_production_rights_is_refused_and_moves_nothing(self):
		"""The negative case that matters, built by removing the permission
		rather than by finding a user who happens to lack it."""
		before = self.on_hand("ЛДСП 18мм")
		real = frappe.has_permission

		def without_production(doctype, ptype="read", *args, **kwargs):
			if doctype in ("Work Order", "Stock Entry") and ptype in ("create", "submit"):
				return False
			return real(doctype, ptype, *args, **kwargs)

		with patch("korkem_ai.korkem_ai.tools.registry.frappe.has_permission", without_production):
			result = self.as_user(PLANNER, START, {"sales_order": self.ready})

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "permission_denied")
		self.assertEqual(self.on_hand("ЛДСП 18мм"), before)


SHOP = "manufacturing.shop_floor"
START_OP = "manufacturing.start_operation"
FINISH_OP = "manufacturing.complete_operation"
FIRST = "Раскрой"
SECOND = "Кромление"


class _ShopFloorTestCase(_ProductionTestCase):
	"""Every test here needs a job actually running on the floor."""

	def setUp(self):
		super().setUp()
		started = self.start(self.ready)
		self.assertTrue(started["ok"], started.get("error"))
		self.work_order = started["data"]["work_order"]

	def _clean(self):
		"""Job cards reference the work order, so they go first.

		Learned the hard way: deleting a work order without them leaves cards
		pointing at a document that no longer exists, and every ERPNext call
		against one fails with "Could not find Work Order".

		Scoped to this fixture's own jobs. It used to delete every job card on
		the site, which was invisible while the seeded work orders were never
		looked at on the floor — and left the demo factory with no shop floor at
		all once they were. Same shape as the stock-entry sweep Phase 22 found.
		"""
		frappe.set_user("Administrator")
		mine = self.own_work_orders()
		for name in (
			frappe.get_all("Job Card", filters={"work_order": ["in", mine]}, pluck="name")
			if mine
			else []
		):
			card = frappe.get_doc("Job Card", name)
			if card.docstatus == 1:
				card.cancel()
			frappe.delete_doc("Job Card", name, force=1, ignore_permissions=True)
		super()._clean()

	def cards(self):
		frappe.set_user("Administrator")
		return {
			row["operation"]: row
			for row in frappe.get_all(
				"Job Card",
				filters={"work_order": self.work_order},
				fields=["name", "operation", "status", "docstatus", "total_completed_qty", "for_quantity"],
			)
		}

	def floor(self):
		return self.as_user(PLANNER, SHOP, {"work_order": self.work_order})["data"]


class TestTheFloorIsReadFromJobCards(_ShopFloorTestCase):
	def test_starting_a_job_opens_a_card_for_every_stage(self):
		"""ERPNext creates them when the work order is submitted, so nothing in
		KORKEM creates a job card."""
		self.assertEqual(len(self.cards()), 7)
		self.assertEqual(self.cards()[FIRST]["status"], "Open")

	def test_the_first_stage_is_queued_and_nothing_is_running(self):
		floor = self.floor()

		self.assertEqual(floor["summary"]["operations_running"], 0)
		queued = [row["operation"] for s in floor["workstations"] for row in s["queued"]]
		self.assertIn(FIRST, queued)

	def test_progress_is_reported_against_the_cards_own_quantity(self):
		self.as_user(PLANNER, START_OP, {"operation": FIRST, "work_order": self.work_order})
		self.as_user(
			PLANNER, FINISH_OP, {"operation": FIRST, "work_order": self.work_order, "qty": 2}
		)

		card = self.cards()[FIRST]

		self.assertEqual(card["total_completed_qty"], 2.0)
		self.assertEqual(card["for_quantity"], 5.0)


class TestStartingAndFinishingAStage(_ShopFloorTestCase):
	def test_starting_puts_the_stage_on_its_workstation(self):
		result = self.as_user(PLANNER, START_OP, {"operation": FIRST, "work_order": self.work_order})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "started")
		self.assertEqual(result["data"]["job_card_status"], "Work In Progress")
		self.assertEqual(result["data"]["workstation"], "Раскрой")

		running = [
			row["operation"] for s in self.floor()["workstations"] for row in s["running"]
		]
		self.assertEqual(running, [FIRST])

	def test_a_time_log_is_what_records_it(self):
		"""Not a status flag of our own — the shop floor is costed against
		these."""
		self.as_user(PLANNER, START_OP, {"operation": FIRST, "work_order": self.work_order})

		frappe.set_user("Administrator")
		card = frappe.get_doc("Job Card", self.cards()[FIRST]["name"])
		self.assertEqual(len(card.time_logs), 1)
		self.assertIsNotNone(card.time_logs[0].from_time)
		self.assertIsNone(card.time_logs[0].to_time)

	def test_finishing_submits_the_card_and_advances_the_work_order(self):
		"""Booking every piece closes the stage.

		Phase 23 changed what a *partial* booking does: it used to submit the
		card and abandon the rest, and it now leaves the stage open so the
		remainder can be booked later. So this asks for the whole five rather
		than three — three is now a partial run, which is tested next door.
		"""
		self.as_user(PLANNER, START_OP, {"operation": FIRST, "work_order": self.work_order})

		result = self.as_user(
			PLANNER, FINISH_OP, {"operation": FIRST, "work_order": self.work_order, "qty": 5}
		)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "completed")
		self.assertEqual(result["data"]["next_operation"], SECOND)

		frappe.set_user("Administrator")
		operation = frappe.get_all(
			"Work Order Operation",
			filters={"parent": self.work_order, "sequence_id": 1},
			fields=["status", "completed_qty"],
		)[0]
		self.assertEqual(operation["status"], "Completed", "ERPNext did not advance the job")
		self.assertEqual(operation["completed_qty"], 5.0)

	def test_the_next_stage_becomes_the_current_one(self):
		self.as_user(PLANNER, START_OP, {"operation": FIRST, "work_order": self.work_order})
		self.as_user(PLANNER, FINISH_OP, {"operation": FIRST, "work_order": self.work_order})

		# No operation named — "what is current" has to come from the routing.
		result = self.as_user(PLANNER, START_OP, {"work_order": self.work_order})

		self.assertEqual(result["data"]["operation"], SECOND)
		self.assertEqual(result["data"]["workstation"], "Кромка и сверловка")

	def test_finishing_without_a_start_still_records_both_ends(self):
		"""A floor that only touches the card once when the work is done. The
		log still needs a beginning, or the hours are meaningless."""
		result = self.as_user(
			PLANNER, FINISH_OP, {"operation": FIRST, "work_order": self.work_order}
		)

		self.assertEqual(result["data"]["status"], "completed")
		frappe.set_user("Administrator")
		card = frappe.get_doc("Job Card", self.cards()[FIRST]["name"])
		self.assertTrue(card.time_logs[0].from_time and card.time_logs[0].to_time)


class TestSayingItTwiceChangesNothing(_ShopFloorTestCase):
	def test_starting_a_running_stage_adds_no_second_time_log(self):
		"""Two open logs would double the hours the operation is costed at."""
		self.as_user(PLANNER, START_OP, {"operation": FIRST, "work_order": self.work_order})

		again = self.as_user(PLANNER, START_OP, {"operation": FIRST, "work_order": self.work_order})

		self.assertEqual(again["data"]["status"], "already_running")
		frappe.set_user("Administrator")
		self.assertEqual(len(frappe.get_doc("Job Card", self.cards()[FIRST]["name"]).time_logs), 1)

	def test_finishing_a_finished_stage_books_no_further_quantity(self):
		self.as_user(PLANNER, START_OP, {"operation": FIRST, "work_order": self.work_order})
		self.as_user(
			PLANNER, FINISH_OP, {"operation": FIRST, "work_order": self.work_order, "qty": 2}
		)

		again = self.as_user(
			PLANNER, FINISH_OP, {"operation": FIRST, "work_order": self.work_order, "qty": 2}
		)

		# Phase 23: two of five leaves the stage open, so a second booking of two
		# is the rest of the run rather than a repeat of the first. What must
		# never happen is more than the stage was opened for — that is the
		# invariant, and ERPNext enforces it on the card.
		self.assertEqual(again["data"]["good_qty"], 4.0)
		self.assertEqual(self.cards()[FIRST]["total_completed_qty"], 4.0)
		self.assertLessEqual(
			self.cards()[FIRST]["total_completed_qty"], self.cards()[FIRST]["for_quantity"]
		)

	def test_a_closed_stage_cannot_be_booked_again(self):
		"""Once every piece is accounted for the card is submitted, and saying
		so again books nothing."""
		self.as_user(PLANNER, FINISH_OP, {"operation": FIRST, "work_order": self.work_order})

		again = self.as_user(PLANNER, FINISH_OP, {"operation": FIRST, "work_order": self.work_order})

		self.assertEqual(again["data"]["status"], "already_complete")
		self.assertEqual(self.cards()[FIRST]["total_completed_qty"], 5.0)


class TestTheStageIsGuarded(_ShopFloorTestCase):
	def test_both_writes_need_confirmation(self):
		for name in (START_OP, FINISH_OP):
			with self.subTest(tool=name):
				spec = registry.get(name)
				self.assertIs(spec.risk, registry.Risk.WRITE)
				self.assertTrue(spec.requires_confirmation)

	def test_the_shop_floor_read_needs_none(self):
		self.assertIs(registry.get(SHOP).risk, registry.Risk.READ)

	def test_no_shop_floor_tool_takes_a_company(self):
		for name in (SHOP, START_OP, FINISH_OP):
			with self.subTest(tool=name):
				self.assertNotIn("company", registry.get(name).input_schema["properties"])

	def test_an_unknown_stage_names_the_real_ones(self):
		result = self.as_user(
			PLANNER, FINISH_OP, {"operation": "Полировка", "work_order": self.work_order}
		)

		self.assertFalse(result["ok"])
		self.assertIn(FIRST, result["error"]["message"])

	def test_more_than_the_card_holds_cannot_be_booked(self):
		self.as_user(PLANNER, START_OP, {"operation": FIRST, "work_order": self.work_order})

		self.as_user(
			PLANNER, FINISH_OP, {"operation": FIRST, "work_order": self.work_order, "qty": 500}
		)

		self.assertEqual(self.cards()[FIRST]["total_completed_qty"], 5.0, "500 pieces were booked")

	def test_another_companys_job_cannot_be_touched(self):
		"""A work order that is not this company's must not be findable, let
		alone advanceable."""
		frappe.set_user("Administrator")
		foreign = frappe.db.get_value("Work Order", {"company": ["!=", "KORKEM"]}, "name")
		if not foreign:
			self.skipTest("no other company's work order on this bench")

		result = self.as_user(PLANNER, FINISH_OP, {"work_order": foreign})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"].lower())


RELEASE = "manufacturing.complete_production"


class TestARunningJobCanBeGivenMoreMaterial(_ProductionTestCase):
	"""The gap Phase 22 opened by making the fixture honest.

	A job is started, its material is transferred, it is built and the material
	is consumed. The units still outstanding then need *their* material moved
	across — and until this, `start_production` answered "already running" and
	there was no way through the assistant to move it, so a part-built order
	could never be finished.

	Runs against the seeded Караганда job, which is genuinely in that state: 20
	ordered, 5 built, 5 units' worth transferred. Nothing is contrived.
	"""

	PARTLY_BUILT = "Караганда Мебель"

	def setUp(self):
		super().setUp()
		self.partly_built = _order(self.PARTLY_BUILT)
		if not self.partly_built:
			self.skipTest("seed_demo has not been run on this site")
		self.job = frappe.get_all(
			"Work Order",
			filters={"sales_order": self.partly_built, "docstatus": 1},
			pluck="name",
		)[0]
		# This class touches a seeded job rather than one it created, so it
		# undoes precisely the entries it adds and nothing the seed posted.
		self.entries_before = set(
			frappe.get_all("Stock Entry", filters={"work_order": self.job}, pluck="name")
		)
		self.addCleanup(self._undo_own_entries)

	def _undo_own_entries(self):
		frappe.set_user("Administrator")
		added = [
			name
			for name in frappe.get_all(
				"Stock Entry", filters={"work_order": self.job}, pluck="name", order_by="creation desc"
			)
			if name not in self.entries_before
		]
		for name in added:
			entry = frappe.get_doc("Stock Entry", name)
			if entry.docstatus == 1:
				entry.cancel()
			frappe.delete_doc("Stock Entry", name, force=1, ignore_permissions=True)
		frappe.db.commit()

	def state(self):
		frappe.set_user("Administrator")
		row = frappe.db.get_value(
			"Work Order",
			self.job,
			["qty", "produced_qty", "material_transferred_for_manufacturing", "status"],
			as_dict=True,
		)
		return dict(row)

	def test_the_seeded_job_is_genuinely_part_built(self):
		"""The precondition, asserted rather than assumed."""
		row = self.state()

		self.assertEqual(row["status"], "In Process")
		self.assertGreater(row["produced_qty"], 0)
		self.assertLess(row["material_transferred_for_manufacturing"], row["qty"])

	def test_material_for_the_outstanding_units_is_moved(self):
		row = self.state()
		outstanding = row["qty"] - row["material_transferred_for_manufacturing"]

		result = self.as_user(PLANNER, START, {"sales_order": self.partly_built})

		self.assertTrue(result["ok"], result.get("error"))
		data = result["data"]
		self.assertEqual(data["status"], "started")
		self.assertTrue(data["topped_up"], "reported as a fresh start, not a top-up")
		self.assertEqual(data["transferred_for_qty"], outstanding)
		self.assertEqual(self.state()["material_transferred_for_manufacturing"], row["qty"])

	def test_it_moves_what_is_outstanding_not_the_whole_job(self):
		"""Transferring the full 20 units' worth again would move material for
		the five already built and consumed."""
		row = self.state()

		self.as_user(PLANNER, START, {"sales_order": self.partly_built})

		frappe.set_user("Administrator")
		transfer = frappe.get_all(
			"Stock Entry",
			filters={"work_order": self.job, "purpose": "Material Transfer for Manufacture"},
			fields=["name", "fg_completed_qty"],
			order_by="creation desc",
		)[0]
		self.assertEqual(
			flt(transfer["fg_completed_qty"]),
			row["qty"] - row["material_transferred_for_manufacturing"],
		)

	def test_production_does_not_restart_the_job(self):
		"""`produced_qty` is production history and a transfer is not production."""
		before = self.state()["produced_qty"]

		self.as_user(PLANNER, START, {"sales_order": self.partly_built})

		self.assertEqual(self.state()["produced_qty"], before)

	def test_a_second_top_up_finds_nothing_left_to_move(self):
		"""Idempotent: once every unit's material is across, the answer goes
		back to what it always was."""
		self.as_user(PLANNER, START, {"sales_order": self.partly_built})

		again = self.as_user(PLANNER, START, {"sales_order": self.partly_built})

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "already_started")

	def test_the_material_gap_is_what_closed(self):
		"""The whole point, measured on the shelf rather than on a message.

		Before this, a job whose first batch had been built and consumed had
		nothing in work-in-progress for the units it had left, and nothing could
		put it there. The top-up is what closes that, so the assertion is the
		panel arriving in WIP in the quantity the outstanding units need.
		"""
		frappe.set_user("Administrator")
		row = self.state()
		outstanding = row["qty"] - row["material_transferred_for_manufacturing"]
		per_unit = flt(
			frappe.db.get_value(
				"Work Order Item", {"parent": self.job, "item_code": "ЛДСП 18мм"}, "required_qty"
			)
		) / flt(row["qty"])
		before = flt(
			frappe.db.get_value(
				"Bin", {"item_code": "ЛДСП 18мм", "warehouse": "Work In Progress - KRK"}, "actual_qty"
			)
		)

		self.as_user(PLANNER, START, {"sales_order": self.partly_built})

		frappe.set_user("Administrator")
		after = flt(
			frappe.db.get_value(
				"Bin", {"item_code": "ЛДСП 18мм", "warehouse": "Work In Progress - KRK"}, "actual_qty"
			)
		)
		self.assertEqual(
			round(after - before, 3),
			round(outstanding * per_unit, 3),
			"work in progress did not receive the outstanding units' material",
		)


PANEL = "ЛДСП 18мм"
FINISHED = "Finished Goods - KRK"
WIP = "Work In Progress - KRK"


class _ManufactureTestCase(_ProductionTestCase):
	"""A job with material in WIP, ready to be released as finished goods.

	"Ready" now includes having passed inspection. The bill of materials is
	marked `inspection_required`, which in ERPNext gates the finished-item row
	of the Manufacture entry as well as the ОТК job card — so a batch with no
	verdict cannot reach the shelf, and a fixture that omits one is not
	describing a job that is ready.

	The quality tests below turn it off, because whether the gate works is
	precisely what they are about.
	"""

	#: Whether the fixture signs the batch off during setup.
	inspect_on_setup = True

	def setUp(self):
		super().setUp()
		seed_demo._valuation_account()
		started = self.start(self.ready)
		self.assertTrue(started["ok"], started.get("error"))
		self.work_order = started["data"]["work_order"]
		if self.inspect_on_setup:
			self.sign_off()

	def run_to_inspection(self):
		"""Book every stage before the inspected one, in full.

		ERPNext will not let a job card be saved out of sequence, so the ОТК
		card cannot carry a verdict until the stages before it are done. That is
		the shop's own order of events, not a fixture detail: nobody inspects a
		cabinet that has not been assembled.
		"""
		frappe.set_user("Administrator")
		for row in frappe.get_all(
			"Work Order Operation",
			filters={"parent": self.work_order},
			fields=["operation"],
			order_by="sequence_id",
		):
			if row["operation"] == "ОТК":
				return
			result = self.as_user(
				PLANNER,
				"manufacturing.complete_operation",
				{"work_order": self.work_order, "operation": row["operation"]},
			)
			# A stage waiting on a rework verdict refuses, and rightly — its
			# held piece is not this fixture's to resolve.
			if not result["ok"] and "исправлени" in result["error"]["message"]:
				continue
			self.assertTrue(result["ok"], result.get("error"))

	def sign_off(self):
		"""Take the job through its stages and record an accepted ОТК verdict."""
		self.run_to_inspection()
		result = self.as_user(
			PLANNER,
			"manufacturing.record_inspection",
			{"work_order": self.work_order, "operation": "ОТК", "result": "принято"},
		)
		self.assertTrue(result["ok"], result.get("error"))
		return result["data"]

	def _clean(self):
		"""Manufacture entries first — they consume what the transfer moved.

		Scoped to this fixture's own jobs, for the reason spelled out in
		`_ProductionTestCase._clean`.
		"""
		frappe.set_user("Administrator")
		mine = self.own_work_orders()
		if mine:
			# Inspections first: they reference the job cards, and a WRITE tool
			# commits, so one survives the rollback and the next test finds a
			# verdict it never recorded.
			cards = frappe.get_all("Job Card", filters={"work_order": ["in", mine]}, pluck="name")
			if cards:
				for name in frappe.get_all(
					"Quality Inspection", filters={"reference_name": ["in", cards]}, pluck="name"
				):
					doc = frappe.get_doc("Quality Inspection", name)
					if doc.docstatus == 1:
						doc.cancel()
					frappe.delete_doc("Quality Inspection", name, force=1, ignore_permissions=True)
			for name in frappe.get_all(
				"Stock Entry",
				filters={"purpose": "Manufacture", "docstatus": 1, "work_order": ["in", mine]},
				pluck="name",
			):
				frappe.get_doc("Stock Entry", name).cancel()
				frappe.delete_doc("Stock Entry", name, force=1, ignore_permissions=True)
			for name in frappe.get_all("Job Card", filters={"work_order": ["in", mine]}, pluck="name"):
				card = frappe.get_doc("Job Card", name)
				if card.docstatus == 1:
					card.cancel()
				frappe.delete_doc("Job Card", name, force=1, ignore_permissions=True)
		super()._clean()

	def release(self, **args):
		return self.as_user(PLANNER, RELEASE, {"work_order": self.work_order, **args})

	def stock(self, warehouse, item="Тумба Караганда"):
		frappe.set_user("Administrator")
		return float(
			frappe.db.get_value("Bin", {"item_code": item, "warehouse": warehouse}, "actual_qty") or 0
		)


class TestReleasingFinishedGoods(_ManufactureTestCase):
	def test_a_completed_operation_alone_puts_nothing_on_the_shelf(self):
		"""The boundary this phase exists to draw. A job card records that work
		happened; only a Manufacture entry produces stock."""
		before = self.stock(FINISHED)

		self.as_user(PLANNER, "manufacturing.complete_operation", {"work_order": self.work_order})

		self.assertEqual(self.stock(FINISHED), before, "finishing an operation created stock")
		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.get_value("Work Order", self.work_order, "produced_qty"), 0.0)

	def test_releasing_moves_material_out_of_wip_and_goods_onto_the_shelf(self):
		finished_before = self.stock(FINISHED)
		wip_before = self.stock(WIP, PANEL)

		result = self.release(qty=2)

		self.assertTrue(result["ok"], result.get("error"))
		data = result["data"]
		self.assertEqual(data["status"], "released")
		self.assertEqual(data["released_qty"], 2.0)
		self.assertEqual(self.stock(FINISHED), finished_before + 2.0)
		self.assertLess(self.stock(WIP, PANEL), wip_before, "nothing left work in progress")

	def test_produced_qty_matches_the_ledger(self):
		"""The defect this phase closes: `produced_qty` used to be a number
		nobody had posted."""
		before = self.stock(FINISHED)

		self.release(qty=2)

		frappe.set_user("Administrator")
		produced = frappe.db.get_value("Work Order", self.work_order, "produced_qty")
		self.assertEqual(produced, 2.0)
		self.assertEqual(self.stock(FINISHED) - before, produced)

	def test_the_entry_is_a_real_manufacture_document(self):
		data = self.release(qty=2)["data"]

		frappe.set_user("Administrator")
		entry = frappe.get_doc("Stock Entry", data["stock_entry"])
		self.assertEqual(entry.docstatus, 1)
		self.assertEqual(entry.purpose, "Manufacture")
		self.assertEqual(entry.work_order, self.work_order)
		self.assertEqual(entry.owner, PLANNER)
		self.assertEqual(entry.company, "KORKEM")

	def test_the_rest_can_be_released_later(self):
		self.release(qty=2)

		second = self.release()["data"]

		self.assertEqual(second["released_qty"], 3.0)
		self.assertEqual(second["produced_qty"], 5.0)
		self.assertEqual(second["remaining_qty"], 0.0)
		self.assertEqual(second["work_order_status"], "Completed")


class TestProducedQtyIsExplainedByTheLedger(_ManufactureTestCase):
	"""The invariant this project is not allowed to break.

	`produced_qty` is not ours to set. ERPNext derives it in
	`StatusService._update_qty_for_purpose` by summing the finished-item rows of
	every submitted Manufacture entry against the job, and recomputes it on any
	stock transaction that touches the work order — which is how a seeded
	`db_set` of 5 was silently erased on this bench without anybody noticing.

	So the test asserts the derivation itself rather than a number a fixture
	chose. Nothing here is compared against a hardcoded seed quantity.
	"""

	def ledger_qty(self):
		"""What ERPNext's own definition of `produced_qty` computes to."""
		frappe.set_user("Administrator")
		return flt(
			frappe.db.sql(
				"""
				select sum(detail.transfer_qty)
				from `tabStock Entry` entry
				join `tabStock Entry Detail` detail on detail.parent = entry.name
				where entry.work_order = %s
				  and entry.docstatus = 1
				  and entry.purpose = 'Manufacture'
				  and detail.is_finished_item = 1
				""",
				self.work_order,
			)[0][0]
		)

	def produced(self):
		frappe.set_user("Administrator")
		return flt(frappe.db.get_value("Work Order", self.work_order, "produced_qty"))

	def test_produced_qty_tracks_the_ledger_through_a_partial_run(self):
		"""0 → 2 → 5, and at every step the field equals the sum of the entries."""
		self.assertEqual(self.ledger_qty(), 0.0, "the job has manufactured nothing yet")
		self.assertEqual(self.produced(), self.ledger_qty())

		self.release(qty=2)
		self.assertEqual(self.produced(), 2.0)
		self.assertEqual(self.produced(), self.ledger_qty())

		self.release(qty=3)
		self.assertEqual(self.produced(), 5.0)
		self.assertEqual(self.produced(), self.ledger_qty())

	def test_two_entries_are_what_five_units_are_made_of(self):
		"""The sum is over entries, not a single one — partial manufacture is
		ERPNext's normal case and the invariant must not assume 1:1."""
		self.release(qty=2)
		self.release(qty=3)

		frappe.set_user("Administrator")
		entries = frappe.get_all(
			"Stock Entry",
			filters={"work_order": self.work_order, "purpose": "Manufacture", "docstatus": 1},
			pluck="name",
		)
		self.assertEqual(len(entries), 2)
		self.assertEqual(self.produced(), 5.0)

	def test_cancelling_an_entry_takes_the_field_back_with_it(self):
		"""ERPNext owns the field in both directions. If it did not, a cancelled
		entry would leave stock removed and the job still claiming it."""
		data = self.release(qty=2)["data"]
		self.assertEqual(self.produced(), 2.0)
		shelf = self.stock(FINISHED)

		frappe.set_user("Administrator")
		frappe.get_doc("Stock Entry", data["stock_entry"]).cancel()

		self.assertEqual(self.produced(), 0.0)
		self.assertEqual(self.produced(), self.ledger_qty())
		self.assertEqual(self.stock(FINISHED), shelf - 2.0)

	def test_the_seeded_factory_has_no_unexplained_production(self):
		"""No work order anywhere on this company may claim output the stock
		ledger cannot account for — the whole point of Phase 22."""
		frappe.set_user("Administrator")
		for job in frappe.get_all(
			"Work Order",
			filters={"company": "KORKEM", "docstatus": 1},
			fields=["name", "produced_qty"],
		):
			ledger = flt(
				frappe.db.sql(
					"""
					select sum(detail.transfer_qty)
					from `tabStock Entry` entry
					join `tabStock Entry Detail` detail on detail.parent = entry.name
					where entry.work_order = %s
					  and entry.docstatus = 1
					  and entry.purpose = 'Manufacture'
					  and detail.is_finished_item = 1
					""",
					job["name"],
				)[0][0]
			)
			self.assertEqual(
				flt(job["produced_qty"]),
				ledger,
				f"{job['name']} claims {job['produced_qty']} produced and the ledger says {ledger}",
			)


class TestNeverMoreThanWasPlanned(_ManufactureTestCase):
	def test_asking_for_more_than_is_left_releases_what_is_left(self):
		self.release(qty=2)

		data = self.release(qty=400)["data"]

		self.assertEqual(data["released_qty"], 3.0)
		self.assertTrue(data["adjusted"])
		self.assertEqual(data["requested_qty"], 400.0)
		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.get_value("Work Order", self.work_order, "produced_qty"), 5.0)

	def test_releasing_a_finished_job_creates_no_second_entry(self):
		self.release()
		before = self.stock(FINISHED)

		again = self.release()

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "already_complete")
		self.assertEqual(self.stock(FINISHED), before, "stock appeared from nowhere")
		# Counted against this job, not site-wide: the seeded factory now
		# carries manufacturing entries of its own.
		self.assertEqual(
			frappe.db.count(
				"Stock Entry",
				{"work_order": self.work_order, "purpose": "Manufacture", "docstatus": 1},
			),
			1,
		)

	def test_a_non_positive_quantity_is_refused(self):
		result = self.release(qty=-1)

		self.assertFalse(result["ok"])
		self.assertIn("greater than zero", result["error"]["message"])


class TestReleasingIsGuarded(_ManufactureTestCase):
	def test_it_is_a_write_needing_confirmation(self):
		spec = registry.get(RELEASE)

		self.assertIs(spec.risk, registry.Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)
		self.assertNotIn("company", spec.input_schema["properties"])

	def test_an_unknown_work_order_is_a_sentence(self):
		result = self.as_user(PLANNER, RELEASE, {"work_order": "MFG-WO-9999-99999"})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"].lower())

	def test_another_companys_job_cannot_be_released(self):
		frappe.set_user("Administrator")
		foreign = frappe.db.get_value("Work Order", {"company": ["!=", "KORKEM"]}, "name")
		if not foreign:
			self.skipTest("no other company's work order on this bench")

		result = self.as_user(PLANNER, RELEASE, {"work_order": foreign})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"].lower())


class TestAmbiguityIsRefusedNotGuessed(_ManufactureTestCase):
	"""Which job to release is a question, not a default.

	Phase 21 found this the hard way: two customers order Тумба Караганда, the
	model named the product, and the wrong job was chosen. ERPNext refused
	because that job had no material in work-in-progress — but it refused by
	luck, and a job that *did* have material would have been released against
	the wrong order and consumed somebody else's board.
	"""

	def setUp(self):
		super().setUp()
		# The fixture's first job already covers the whole order, so ERPNext
		# refuses a second one — correctly, since together they would overbuild
		# it. Splitting a job in two is ordinary shop practice, and ERPNext's
		# own allowance is how it is permitted; the setting is restored after.
		self.allowance = frappe.db.get_single_value(
			"Manufacturing Settings", "overproduction_percentage_for_sales_order"
		)
		frappe.db.set_single_value(
			"Manufacturing Settings", "overproduction_percentage_for_sales_order", 100
		)
		self.addCleanup(
			frappe.db.set_single_value,
			"Manufacturing Settings",
			"overproduction_percentage_for_sales_order",
			self.allowance,
		)

	def second_job_on_the_same_order(self):
		"""A second work order against the order this fixture already started."""
		frappe.set_user("Administrator")
		first = frappe.get_doc("Work Order", self.work_order)
		extra = frappe.get_doc(
			{
				"doctype": "Work Order",
				"production_item": first.production_item,
				"bom_no": first.bom_no,
				"company": first.company,
				"qty": 1,
				"sales_order": first.sales_order,
				"wip_warehouse": first.wip_warehouse,
				"fg_warehouse": first.fg_warehouse,
				"source_warehouse": first.source_warehouse,
			}
		)
		extra.insert(ignore_permissions=True)
		extra.submit()
		return extra.name

	def test_an_order_with_two_open_jobs_refuses_and_lists_them(self):
		extra = self.second_job_on_the_same_order()

		result = self.as_user(PLANNER, RELEASE, {"sales_order": self.ready})

		self.assertFalse(result["ok"])
		message = result["error"]["message"]
		self.assertIn("which one", message.lower())
		# Both candidates named, so a person can answer the question.
		self.assertIn(self.work_order, message)
		self.assertIn(extra, message)

	def test_refusing_writes_nothing(self):
		self.second_job_on_the_same_order()
		frappe.set_user("Administrator")
		before = frappe.db.count("Stock Entry", {"purpose": "Manufacture", "docstatus": 1})

		self.as_user(PLANNER, RELEASE, {"sales_order": self.ready})

		frappe.set_user("Administrator")
		self.assertEqual(
			frappe.db.count("Stock Entry", {"purpose": "Manufacture", "docstatus": 1}), before
		)

	def test_naming_the_job_resolves_it(self):
		"""The refusal is answerable — that is what makes it a question."""
		self.second_job_on_the_same_order()

		result = self.release(qty=1)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["work_order"], self.work_order)

	def test_one_open_job_is_not_ambiguous(self):
		"""The guard must not make the ordinary case harder."""
		result = self.as_user(PLANNER, RELEASE, {"sales_order": self.ready, "qty": 1})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["work_order"], self.work_order)

	def test_a_job_belonging_to_another_order_is_refused(self):
		"""Naming both, inconsistently, is the case that released against the
		wrong customer in Phase 21."""
		frappe.set_user("Administrator")
		other = frappe.db.get_value(
			"Work Order",
			{"company": "KORKEM", "docstatus": 1, "sales_order": ["!=", self.ready]},
			"name",
		)
		if not other:
			self.skipTest("no second seeded job on this bench")

		result = self.as_user(PLANNER, RELEASE, {"sales_order": self.ready, "work_order": other})

		self.assertFalse(result["ok"])
		self.assertIn("not", result["error"]["message"].lower())


class TestManufacturedStockCanBeDelivered(_ManufactureTestCase):
	def test_what_was_just_made_is_what_ships(self):
		"""Phase 20 shipped opening stock. This proves the chain closes on
		goods this factory actually produced."""
		self.release()
		made = self.stock(FINISHED)

		status = self.as_user(PLANNER, "sales.delivery_status", {"sales_order": self.ready})["data"]
		order = status["orders"][0]
		self.assertEqual(order["delivery_state"], "READY")
		self.assertEqual(order["shippable_now"], 5.0)

		shipped = self.as_user(PLANNER, "sales.create_delivery", {"sales_order": self.ready})

		self.assertTrue(shipped["ok"], shipped.get("error"))
		self.assertTrue(shipped["data"]["fully_delivered"])
		self.assertEqual(self.stock(FINISHED), made - 5.0)

	def _clean(self):
		frappe.set_user("Administrator")
		for name in frappe.get_all("Delivery Note", pluck="name"):
			note = frappe.get_doc("Delivery Note", name)
			if note.docstatus == 1:
				note.cancel()
			frappe.delete_doc("Delivery Note", name, force=1, ignore_permissions=True)
		super()._clean()


INSPECT = "manufacturing.record_inspection"
INSPECTED_OP = "ОТК"
FIRST_OP = "Раскрой"


class _ScrapTestCase(_ManufactureTestCase):
	"""A started job whose operations can be booked with spoilage.

	No inspection is recorded in setup: these tests drive the quality workflow
	themselves, and several assert what happens without a verdict.

	Inherits the manufacture fixture: the Павлодар order, five units, material
	in work-in-progress, and cleanup scoped to the jobs these tests start.
	"""

	inspect_on_setup = False

	def card(self, operation, docstatus=None):
		"""The card anybody naming this stage means.

		A stage split for rework has two: the good pieces went out on a
		submitted card, and the held piece waits on a draft one. The open card
		is the live one, which is what `_resolve_card` picks too.
		"""
		frappe.set_user("Administrator")
		if docstatus is None:
			open_card = frappe.db.get_value(
				"Job Card",
				{
					"work_order": self.work_order,
					"operation": operation,
					"docstatus": 0,
					"is_corrective_job_card": 0,
				},
				"name",
			)
			docstatus = 0 if open_card else 1
		row = frappe.db.get_value(
			"Job Card",
			{
				"work_order": self.work_order,
				"operation": operation,
				"docstatus": docstatus,
				"is_corrective_job_card": 0,
			},
			[
				"name",
				"for_quantity",
				"total_completed_qty",
				"process_loss_qty",
				"status",
				"docstatus",
				"quality_inspection",
				"pending_qty",
			],
			as_dict=True,
		)
		return dict(row) if row else None

	def operation_row(self, operation):
		frappe.set_user("Administrator")
		return frappe.get_all(
			"Work Order Operation",
			filters={"parent": self.work_order, "operation": operation},
			fields=["completed_qty", "process_loss_qty", "status"],
		)[0]

	def job(self):
		frappe.set_user("Administrator")
		return frappe.db.get_value(
			"Work Order",
			self.work_order,
			["qty", "produced_qty", "process_loss_qty", "status"],
			as_dict=True,
		)

	def finish(self, operation=None, **args):
		return self.as_user(PLANNER, FINISH_OP, {"work_order": self.work_order, **(
			{"operation": operation} if operation else {}
		), **args})

	def inspect(self, result="принято"):
		return self.as_user(
			PLANNER, INSPECT, {"work_order": self.work_order, "operation": INSPECTED_OP, "result": result}
		)



class TestNormalCompletion(_ScrapTestCase):
	def test_a_stage_with_no_spoilage_books_everything_as_good(self):
		result = self.finish(FIRST_OP)

		self.assertTrue(result["ok"], result.get("error"))
		data = result["data"]
		self.assertEqual(data["status"], "completed")
		self.assertEqual(data["good_qty"], 5.0)
		self.assertEqual(data["scrap_qty"], 0.0)
		self.assertEqual(data["pending_qty"], 0.0)
		self.assertEqual(self.operation_row(FIRST_OP)["completed_qty"], 5.0)
		self.assertEqual(self.operation_row(FIRST_OP)["process_loss_qty"], 0.0)


class TestPartialCompletion(_ScrapTestCase):
	def test_a_stage_stays_open_until_every_piece_is_accounted_for(self):
		first = self.finish(FIRST_OP, qty=2)["data"]

		self.assertEqual(first["status"], "partially_completed")
		self.assertEqual(first["good_qty"], 2.0)
		self.assertEqual(first["pending_qty"], 3.0)
		self.assertEqual(self.card(FIRST_OP)["docstatus"], 0, "submitted with work outstanding")

	def test_the_rest_can_be_booked_afterwards(self):
		self.finish(FIRST_OP, qty=2)

		second = self.finish(FIRST_OP, qty=3)["data"]

		self.assertEqual(second["status"], "completed")
		self.assertEqual(second["good_qty"], 5.0)
		self.assertEqual(second["pending_qty"], 0.0)


class TestScrapIsNotGoodOutput(_ScrapTestCase):
	def test_four_good_and_one_spoiled_closes_a_stage_of_five(self):
		"""«Сделали 4, 1 в брак» — the sentence this phase exists for."""
		data = self.finish(FIRST_OP, qty=4, scrap_qty=1)["data"]

		self.assertEqual(data["status"], "completed")
		self.assertEqual(data["good_qty"], 4.0)
		self.assertEqual(data["scrap_qty"], 1.0)
		self.assertEqual(data["pending_qty"], 0.0)

	def test_erpnext_records_the_loss_on_its_own_operation(self):
		"""Independently, from the Work Order Operation rather than the reply."""
		self.finish(FIRST_OP, qty=4, scrap_qty=1)

		row = self.operation_row(FIRST_OP)

		self.assertEqual(row["completed_qty"], 4.0)
		self.assertEqual(row["process_loss_qty"], 1.0)
		self.assertEqual(self.card(FIRST_OP)["total_completed_qty"], 4.0)
		self.assertEqual(self.card(FIRST_OP)["process_loss_qty"], 1.0)

	def test_partial_then_scrap_reaches_the_same_place(self):
		"""2 good, then 2 good and 1 spoiled — the brief's four-then-one case."""
		self.finish(FIRST_OP, qty=2)

		data = self.finish(FIRST_OP, qty=2, scrap_qty=1)["data"]

		self.assertEqual(data["good_qty"], 4.0)
		self.assertEqual(data["scrap_qty"], 1.0)
		self.assertEqual(data["status"], "completed")

	def test_a_later_stage_cannot_work_on_what_was_spoiled(self):
		"""ERPNext caps an operation at what the one before it passed on, so the
		missing unit is carried forward rather than left pending for ever."""
		self.finish(FIRST_OP, qty=4, scrap_qty=1)

		nxt = frappe.get_all(
			"Work Order Operation",
			filters={"parent": self.work_order},
			fields=["operation"],
			order_by="sequence_id",
		)[1]["operation"]
		data = self.finish(nxt)["data"]

		self.assertEqual(data["good_qty"], 4.0)
		self.assertEqual(data["carried_forward_loss"], 1.0)
		self.assertEqual(data["status"], "completed")

	def test_negative_scrap_is_refused(self):
		result = self.finish(FIRST_OP, scrap_qty=-1)

		self.assertFalse(result["ok"])
		self.assertIn("negative", result["error"]["message"].lower())

	def test_more_than_the_stage_holds_is_trimmed_not_multiplied(self):
		result = self.finish(FIRST_OP, qty=400)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["good_qty"], 5.0)


class TestQualityInspection(_ScrapTestCase):
	def test_an_uninspected_stage_reports_that_none_is_needed(self):
		result = self.as_user(
			PLANNER, INSPECT, {"work_order": self.work_order, "operation": FIRST_OP, "result": "принято"}
		)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "not_required")
		frappe.set_user("Administrator")
		self.assertIsNone(self.card(FIRST_OP)["quality_inspection"])

	def test_the_inspected_stage_will_not_close_without_a_verdict(self):
		self.run_to_inspection()

		result = self.finish(INSPECTED_OP)

		self.assertFalse(result["ok"])
		self.assertIn("quality result", result["error"]["message"].lower())

	def test_a_refused_stage_is_left_untouched(self):
		"""The gate fires before anything is written — ERPNext's own throws on
		submit, by which point the quantities are already booked."""
		self.run_to_inspection()
		before = self.card(INSPECTED_OP)

		self.finish(INSPECTED_OP)

		after = self.card(INSPECTED_OP)
		self.assertEqual(after["total_completed_qty"], before["total_completed_qty"])
		self.assertEqual(after["docstatus"], 0)
		self.assertEqual(after["status"], before["status"])

	def test_a_passed_inspection_is_a_real_submitted_document(self):
		self.run_to_inspection()

		data = self.inspect("принято")["data"]

		frappe.set_user("Administrator")
		doc = frappe.get_doc("Quality Inspection", data["quality_inspection"])
		self.assertEqual(doc.docstatus, 1)
		self.assertEqual(doc.status, "Accepted")
		self.assertEqual(doc.reference_type, "Job Card")
		self.assertEqual(doc.reference_name, self.card(INSPECTED_OP)["name"])
		self.assertEqual(doc.owner, PLANNER)
		self.assertEqual(doc.company, "KORKEM")

	def test_the_stage_closes_once_it_has_passed(self):
		self.run_to_inspection()
		self.inspect("принято")

		result = self.finish(INSPECTED_OP)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "completed")

	def test_a_failed_inspection_keeps_the_goods_off_the_shelf(self):
		"""The requirement in one test: rejected work cannot be released."""
		self.run_to_inspection()
		self.inspect("брак")

		result = self.as_user(PLANNER, RELEASE, {"work_order": self.work_order})

		self.assertFalse(result["ok"])
		frappe.set_user("Administrator")
		self.assertEqual(self.job()["produced_qty"], 0.0)
		self.assertEqual(
			frappe.db.count(
				"Stock Entry",
				{"work_order": self.work_order, "purpose": "Manufacture", "docstatus": 1},
			),
			0,
			"a rejected batch reached finished goods",
		)

	def test_recording_a_verdict_twice_changes_nothing(self):
		self.run_to_inspection()
		first = self.inspect("принято")["data"]

		again = self.inspect("принято")

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "already_inspected")
		self.assertEqual(again["data"]["quality_inspection"], first["quality_inspection"])
		frappe.set_user("Administrator")
		self.assertEqual(
			frappe.db.count("Quality Inspection", {"reference_name": self.card(INSPECTED_OP)["name"]}), 1
		)

	def test_an_unreadable_verdict_is_refused(self):
		result = self.as_user(
			PLANNER, INSPECT, {"work_order": self.work_order, "result": "может быть"}
		)

		self.assertFalse(result["ok"])
		self.assertIn("passed or failed", result["error"]["message"])

	def test_it_is_a_write_needing_confirmation_and_takes_no_company(self):
		spec = registry.get(INSPECT)

		self.assertIs(spec.risk, registry.Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)
		self.assertNotIn("company", spec.input_schema["properties"])

	def test_another_companys_job_cannot_be_inspected(self):
		frappe.set_user("Administrator")
		foreign = frappe.db.get_value("Work Order", {"company": ["!=", "KORKEM"]}, "name")
		if not foreign:
			self.skipTest("no other company's work order on this bench")

		result = self.as_user(PLANNER, INSPECT, {"work_order": foreign, "result": "принято"})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"].lower())


class TestScrapReachesTheLedger(_ScrapTestCase):
	def release_all(self):
		self.run_to_inspection()
		self.inspect("принято")
		self.finish(INSPECTED_OP)
		return self.as_user(PLANNER, RELEASE, {"work_order": self.work_order})

	def test_spoiled_units_never_become_finished_goods(self):
		"""Five started, one spoiled: four on the shelf and the job is finished."""
		self.finish(FIRST_OP, qty=4, scrap_qty=1)

		result = self.release_all()

		self.assertTrue(result["ok"], result.get("error"))
		row = self.job()
		self.assertEqual(row["produced_qty"], 4.0)
		self.assertEqual(row["process_loss_qty"], 1.0)
		self.assertEqual(row["status"], "Completed")

	def test_produced_qty_still_equals_the_manufacture_ledger(self):
		"""The Phase 22 invariant, under scrap. `fg_completed_qty` is five and
		only four are finished items — the difference is the loss, and
		`produced_qty` must follow the goods, not the entry's headline."""
		self.finish(FIRST_OP, qty=4, scrap_qty=1)
		self.release_all()

		frappe.set_user("Administrator")
		ledger = flt(
			frappe.db.sql(
				"""
				select sum(detail.transfer_qty)
				from `tabStock Entry` entry
				join `tabStock Entry Detail` detail on detail.parent = entry.name
				where entry.work_order = %s
				  and entry.docstatus = 1
				  and entry.purpose = 'Manufacture'
				  and detail.is_finished_item = 1
				""",
				self.work_order,
			)[0][0]
		)
		self.assertEqual(ledger, 4.0)
		self.assertEqual(self.job()["produced_qty"], ledger)

	def test_the_stock_ledger_receives_four_not_five(self):
		self.finish(FIRST_OP, qty=4, scrap_qty=1)
		self.release_all()

		frappe.set_user("Administrator")
		entry = frappe.db.get_value(
			"Stock Entry",
			{"work_order": self.work_order, "purpose": "Manufacture", "docstatus": 1},
			"name",
		)
		received = frappe.get_all(
			"Stock Ledger Entry",
			filters={
				"voucher_no": entry,
				"item_code": "Тумба Караганда",
				"is_cancelled": 0,
			},
			fields=["actual_qty", "warehouse"],
		)
		self.assertEqual(len(received), 1)
		self.assertEqual(received[0]["actual_qty"], 4.0)
		self.assertEqual(received[0]["warehouse"], FINISHED)

	def test_the_entry_carries_the_loss_erpnext_computed(self):
		self.finish(FIRST_OP, qty=4, scrap_qty=1)
		self.release_all()

		frappe.set_user("Administrator")
		entry = frappe.get_doc(
			"Stock Entry",
			frappe.db.get_value(
				"Stock Entry",
				{"work_order": self.work_order, "purpose": "Manufacture", "docstatus": 1},
				"name",
			),
		)
		self.assertEqual(flt(entry.process_loss_qty), 1.0)
		self.assertEqual(flt(entry.fg_completed_qty), 5.0)

	def test_releasing_again_after_scrap_creates_nothing(self):
		self.finish(FIRST_OP, qty=4, scrap_qty=1)
		self.release_all()

		again = self.as_user(PLANNER, RELEASE, {"work_order": self.work_order})

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "already_complete")
		self.assertEqual(again["data"]["scrap_qty"], 1.0)
		frappe.set_user("Administrator")
		self.assertEqual(
			frappe.db.count(
				"Stock Entry",
				{"work_order": self.work_order, "purpose": "Manufacture", "docstatus": 1},
			),
			1,
		)


class TestTheStageIsNotGuessedWhenThereAreTwoJobs(_ScrapTestCase):
	"""Booking an operation against the wrong job records work nobody did."""

	def setUp(self):
		super().setUp()
		self.allowance = frappe.db.get_single_value(
			"Manufacturing Settings", "overproduction_percentage_for_sales_order"
		)
		frappe.db.set_single_value(
			"Manufacturing Settings", "overproduction_percentage_for_sales_order", 100
		)
		self.addCleanup(
			frappe.db.set_single_value,
			"Manufacturing Settings",
			"overproduction_percentage_for_sales_order",
			self.allowance,
		)

	def second_job(self):
		frappe.set_user("Administrator")
		first = frappe.get_doc("Work Order", self.work_order)
		extra = frappe.get_doc(
			{
				"doctype": "Work Order",
				"production_item": first.production_item,
				"bom_no": first.bom_no,
				"company": first.company,
				"qty": 1,
				"sales_order": first.sales_order,
				"wip_warehouse": first.wip_warehouse,
				"fg_warehouse": first.fg_warehouse,
				"source_warehouse": first.source_warehouse,
			}
		)
		extra.insert(ignore_permissions=True)
		extra.submit()
		return extra.name

	def test_completing_an_operation_by_order_alone_refuses(self):
		extra = self.second_job()

		result = self.as_user(PLANNER, FINISH_OP, {"sales_order": self.ready, "operation": FIRST_OP})

		self.assertFalse(result["ok"])
		self.assertIn("which one", result["error"]["message"].lower())
		self.assertIn(extra, result["error"]["message"])

	def test_inspecting_by_order_alone_refuses(self):
		self.second_job()

		result = self.as_user(PLANNER, INSPECT, {"sales_order": self.ready, "result": "принято"})

		self.assertFalse(result["ok"])
		self.assertIn("which one", result["error"]["message"].lower())

	def test_naming_the_job_still_works(self):
		self.second_job()

		result = self.finish(FIRST_OP)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["work_order"], self.work_order)


REWORK = "manufacturing.complete_rework"
CORRECTIVE_OP = "Исправление брака"


class TestReworkReturnsAPieceToGoodOutput(_ScrapTestCase):
	"""A spoiled piece that can be saved must not simply vanish.

	The unit is held as `pending_qty` on its own card rather than booked as
	process loss, because loss on a submitted card cannot be taken back and
	nobody has decided yet. ERPNext's corrective job card records the rework
	itself; the piece returns to good output on the card that lost it.
	"""

	def send(self, **args):
		return self.finish(FIRST_OP, qty=4, rework_qty=1, **args)

	def rework(self, result="исправлено", **args):
		return self.as_user(PLANNER, REWORK, {"work_order": self.work_order, "result": result, **args})

	def corrective(self):
		frappe.set_user("Administrator")
		return frappe.get_all(
			"Job Card",
			filters={"work_order": self.work_order, "is_corrective_job_card": 1},
			fields=["name", "operation", "for_operation", "for_job_card", "for_quantity", "docstatus"],
		)

	def test_a_piece_sent_for_rework_is_held_not_lost(self):
		data = self.send()["data"]

		self.assertEqual(data["good_qty"], 4.0)
		self.assertEqual(data["scrap_qty"], 0.0, "a piece being fixed is not scrap")
		self.assertEqual(data["sent_to_rework"], 1.0)
		self.assertIsNotNone(data["held_job_card"])

		# The good pieces are on a submitted card of their own; the held piece
		# waits on a draft one. Both are the same operation.
		good = self.card(FIRST_OP, docstatus=1)
		self.assertEqual(good["for_quantity"], 4.0)
		self.assertEqual(good["total_completed_qty"], 4.0)
		self.assertEqual(good["process_loss_qty"], 0.0)
		held = self.card(FIRST_OP, docstatus=0)
		self.assertEqual(held["for_quantity"], 1.0)
		self.assertEqual(held["total_completed_qty"], 0.0)
		self.assertEqual(held["process_loss_qty"], 0.0)

	def test_the_rework_is_a_real_corrective_job_card(self):
		self.send()

		cards = self.corrective()

		self.assertEqual(len(cards), 1)
		card = cards[0]
		self.assertEqual(card["operation"], CORRECTIVE_OP)
		self.assertEqual(card["for_operation"], FIRST_OP)
		self.assertEqual(card["for_job_card"], self.card(FIRST_OP, docstatus=0)["name"])
		self.assertEqual(card["for_quantity"], 1.0, "the whole stage was sent, not the failed piece")

	def test_a_successful_rework_puts_the_piece_back_in_good_output(self):
		self.send()

		data = self.rework("исправлено")["data"]

		self.assertTrue(data["status"] == "recovered")
		self.assertEqual(data["reworked_qty"], 1.0)
		self.assertEqual(data["good_qty"], 5.0)
		self.assertEqual(data["scrap_qty"], 0.0)
		self.assertEqual(data["pending_qty"], 0.0)

	def test_erpnext_records_the_recovery_on_the_operation(self):
		"""Independently, from the Work Order Operation."""
		self.send()

		self.rework("исправлено")

		row = self.operation_row(FIRST_OP)
		self.assertEqual(row["completed_qty"], 5.0)
		self.assertEqual(row["process_loss_qty"], 0.0)
		self.assertEqual(row["status"], "Completed")

	def test_the_corrective_card_is_submitted_and_carries_no_quantity(self):
		"""ERPNext's design: a corrective card is cost of poor quality. It must
		never add production quantity, or the piece would be counted twice."""
		self.send()

		self.rework("исправлено")

		card = self.corrective()[0]
		self.assertEqual(card["docstatus"], 1)
		frappe.set_user("Administrator")
		self.assertEqual(
			flt(
				frappe.db.get_value(
					"Work Order Operation",
					{"parent": self.work_order, "operation": FIRST_OP},
					"completed_qty",
				)
			),
			5.0,
			"the corrective card added quantity of its own",
		)

	def test_writing_the_piece_off_stops_the_piece_arriving(self):
		"""A card that is entirely loss has no expression in ERPNext — process
		loss is only derived when the card completed something. So the piece
		simply never arrives at the stage, and the stages after it carry it
		forward as their loss, which is the mechanism Phase 23 established."""
		self.send()

		data = self.rework("списать в брак")["data"]

		self.assertEqual(data["status"], "scrapped")
		row = self.operation_row(FIRST_OP)
		self.assertEqual(row["completed_qty"], 4.0, "the four good pieces still stand")
		frappe.set_user("Administrator")
		self.assertEqual(
			frappe.db.count(
				"Job Card",
				{"work_order": self.work_order, "operation": FIRST_OP, "is_corrective_job_card": 0},
			),
			1,
			"the holding card outlived the write-off",
		)

	def test_a_failed_attempt_leaves_the_piece_where_it_was(self):
		"""Failing is not writing off. The piece is still at the bench and can
		be tried again — that is the whole difference."""
		self.send()

		data = self.rework("не удалось")["data"]

		self.assertEqual(data["status"], "unresolved")
		self.assertTrue(data["can_try_again"])
		held = self.card(FIRST_OP, docstatus=0)
		self.assertEqual(held["total_completed_qty"], 0.0)
		self.assertEqual(held["process_loss_qty"], 0.0, "a failed attempt wrote the piece off")
		self.assertEqual(held["docstatus"], 0)
		self.assertEqual(self.operation_row(FIRST_OP)["process_loss_qty"], 0.0)

	def test_a_piece_already_scrapped_cannot_be_reworked(self):
		"""Process loss on a submitted card is final — which is exactly why a
		piece meant for rework is held instead."""
		self.finish(FIRST_OP, qty=4, scrap_qty=1)

		result = self.rework("исправлено")

		self.assertTrue(result["ok"])
		self.assertEqual(result["data"]["status"], "nothing_in_rework")

	def test_a_finished_stage_has_nothing_to_rework(self):
		self.finish(FIRST_OP)

		result = self.rework("исправлено")

		self.assertEqual(result["data"]["status"], "nothing_in_rework")

	def test_saying_it_twice_changes_nothing(self):
		self.send()
		self.rework("исправлено")
		before = self.operation_row(FIRST_OP)["completed_qty"]

		again = self.rework("исправлено")

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "nothing_in_rework")
		self.assertEqual(self.operation_row(FIRST_OP)["completed_qty"], before)
		self.assertEqual(len(self.corrective()), 1, "a second rework card appeared")

	def test_an_unreadable_result_is_refused(self):
		self.send()

		result = self.rework("может быть")

		self.assertFalse(result["ok"])
		self.assertIn("succeeded", result["error"]["message"])

	def test_it_is_a_write_needing_confirmation_and_takes_no_company(self):
		spec = registry.get(REWORK)

		self.assertIs(spec.risk, registry.Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)
		self.assertNotIn("company", spec.input_schema["properties"])

	def test_another_companys_job_cannot_be_reworked(self):
		frappe.set_user("Administrator")
		foreign = frappe.db.get_value("Work Order", {"company": ["!=", "KORKEM"]}, "name")
		if not foreign:
			self.skipTest("no other company's work order on this bench")

		result = self.as_user(PLANNER, REWORK, {"work_order": foreign, "result": "исправлено"})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"].lower())

	def test_more_pieces_than_are_held_cannot_be_reworked(self):
		self.send()

		data = self.rework("исправлено", qty=400)["data"]

		self.assertEqual(data["reworked_qty"], 1.0)
		self.assertEqual(data["good_qty"], 5.0)


class TestReworkReachesTheLedger(_ScrapTestCase):
	def test_a_recovered_piece_is_manufactured_like_any_other(self):
		"""The whole point: five started, one fixed, five on the shelf — and
		`produced_qty` is the Manufacture ledger, not a tally beside it."""
		self.finish(FIRST_OP, qty=4, rework_qty=1)
		self.as_user(PLANNER, REWORK, {"work_order": self.work_order, "result": "исправлено"})
		self.run_to_inspection()
		self.sign_off()
		self.finish(INSPECTED_OP)

		result = self.as_user(PLANNER, RELEASE, {"work_order": self.work_order})

		self.assertTrue(result["ok"], result.get("error"))
		frappe.set_user("Administrator")
		row = self.job()
		self.assertEqual(row["produced_qty"], 5.0, "the recovered piece never reached the shelf")
		self.assertEqual(row["process_loss_qty"], 0.0)
		ledger = flt(
			frappe.db.sql(
				"""
				select sum(detail.transfer_qty)
				from `tabStock Entry` entry
				join `tabStock Entry Detail` detail on detail.parent = entry.name
				where entry.work_order = %s
				  and entry.docstatus = 1
				  and entry.purpose = 'Manufacture'
				  and detail.is_finished_item = 1
				""",
				self.work_order,
			)[0][0]
		)
		self.assertEqual(ledger, row["produced_qty"])

	def test_a_piece_still_at_the_bench_is_not_released(self):
		"""An unresolved rework is neither good nor lost. Releasing the batch
		while one piece is being fixed would receive it as finished goods on
		the strength of a repair nobody has reported."""
		self.finish(FIRST_OP, qty=4, rework_qty=1)
		self.as_user(PLANNER, REWORK, {"work_order": self.work_order, "result": "не исправили"})
		self.run_to_inspection()
		self.sign_off()
		self.finish(INSPECTED_OP)

		result = self.as_user(PLANNER, RELEASE, {"work_order": self.work_order})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["held_for_rework"], 1.0)
		frappe.set_user("Administrator")
		row = self.job()
		self.assertEqual(row["produced_qty"], 4.0, "a piece at the bench reached the shelf")
		self.assertEqual(row["process_loss_qty"], 0.0, "an unresolved piece was written off")


SECOND_OP = "Кромление"


class TestGoodPiecesDoNotWaitForARework(_ScrapTestCase):
	"""Phase 25. One damaged panel must not stop the other four.

	Holding a piece by leaving its card open stopped the line, and the reason is
	exact: an unsubmitted job card contributes nothing to
	`Work Order Operation.completed_qty`, which is what
	`Job Card.validate_previous_operation` reads. Four finished pieces looked
	like none and the next stage refused to start.

	So the stage is split — ERPNext allows several cards per operation and sums
	across them. The good pieces go out on a card that submits; the held piece
	waits on one that does not.
	"""

	def send(self, **args):
		result = self.finish(FIRST_OP, qty=4, rework_qty=1, **args)
		self.assertTrue(result["ok"], result.get("error"))
		return result

	def rework(self, result, **args):
		return self.as_user(PLANNER, REWORK, {"work_order": self.work_order, "result": result, **args})

	def test_the_stage_reports_its_good_pieces_to_the_work_order(self):
		"""The number the next stage actually reads."""
		self.send()

		self.assertEqual(self.operation_row(FIRST_OP)["completed_qty"], 4.0)
		self.assertEqual(self.operation_row(FIRST_OP)["process_loss_qty"], 0.0)

	def test_the_next_stage_runs_on_the_four_that_are_ready(self):
		self.send()

		result = self.finish(SECOND_OP)

		self.assertTrue(result["ok"], result.get("error"))
		data = result["data"]
		self.assertEqual(data["good_qty"], 4.0)
		self.assertEqual(
			data["carried_forward_loss"],
			0.0,
			"a piece at the rework bench was written off as lost downstream",
		)
		self.assertEqual(data["scrap_qty"], 0.0)
		self.assertEqual(self.operation_row(SECOND_OP)["completed_qty"], 4.0)

	def test_the_held_piece_stays_out_of_the_next_stage(self):
		self.send()

		self.finish(SECOND_OP)

		self.assertEqual(self.card(SECOND_OP, docstatus=1)["for_quantity"], 4.0)
		self.assertEqual(self.card(FIRST_OP, docstatus=0)["for_quantity"], 1.0)

	def test_a_recovered_piece_can_be_walked_through_the_rest(self):
		"""It rejoins where it left, and the stages after it have closed on the
		four that were never damaged — so it needs cards of its own."""
		self.send()
		self.finish(SECOND_OP)
		self.rework("исправлено")
		self.assertEqual(self.operation_row(FIRST_OP)["completed_qty"], 5.0)

		result = self.finish(SECOND_OP)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(self.operation_row(SECOND_OP)["completed_qty"], 5.0)

	def test_a_second_attempt_opens_a_second_corrective_card(self):
		self.send()
		self.rework("не удалось")

		again = self.finish(FIRST_OP, rework_qty=1)

		self.assertTrue(again["ok"], again.get("error"))
		self.assertEqual(again["data"]["status"], "sent_to_rework")
		frappe.set_user("Administrator")
		self.assertEqual(
			frappe.db.count(
				"Job Card", {"work_order": self.work_order, "is_corrective_job_card": 1}
			),
			2,
		)

	def test_a_second_attempt_can_succeed(self):
		self.send()
		self.rework("не удалось")
		self.finish(FIRST_OP, rework_qty=1)

		data = self.rework("исправлено")["data"]

		self.assertEqual(data["status"], "recovered")
		self.assertEqual(self.operation_row(FIRST_OP)["completed_qty"], 5.0)
		self.assertEqual(self.operation_row(FIRST_OP)["process_loss_qty"], 0.0)

	def test_a_piece_cannot_be_sent_to_two_benches_at_once(self):
		self.send()

		again = self.finish(FIRST_OP, rework_qty=1)

		self.assertEqual(again["data"]["status"], "already_in_rework")
		frappe.set_user("Administrator")
		self.assertEqual(
			frappe.db.count(
				"Job Card", {"work_order": self.work_order, "is_corrective_job_card": 1}
			),
			1,
		)

	def test_the_same_piece_is_never_counted_twice(self):
		"""Split, recovered and walked through: every stage ends at five, and
		not one of them at six."""
		self.send()
		self.finish(SECOND_OP)
		self.rework("исправлено")
		for operation in (SECOND_OP, "ЧПУ обработка", "Сверление", "Покраска", "Сборка"):
			self.finish(operation)

		frappe.set_user("Administrator")
		for row in frappe.get_all(
			"Work Order Operation",
			filters={"parent": self.work_order},
			fields=["operation", "completed_qty", "process_loss_qty"],
		):
			if row["operation"] == INSPECTED_OP:
				continue
			self.assertLessEqual(
				flt(row["completed_qty"]) + flt(row["process_loss_qty"]),
				5.0,
				f"{row['operation']} accounted for more pieces than were started",
			)

	def test_the_recovered_piece_reaches_finished_goods(self):
		"""produced_qty and the Manufacture ledger, after a split and a rework."""
		self.send()
		self.finish(SECOND_OP)
		self.rework("исправлено")
		for operation in (SECOND_OP, "ЧПУ обработка", "Сверление", "Покраска", "Сборка"):
			self.finish(operation)
		self.sign_off()
		self.finish(INSPECTED_OP)

		result = self.as_user(PLANNER, RELEASE, {"work_order": self.work_order})

		self.assertTrue(result["ok"], result.get("error"))
		frappe.set_user("Administrator")
		row = self.job()
		self.assertEqual(row["produced_qty"], 5.0)
		self.assertEqual(row["process_loss_qty"], 0.0)
		ledger = flt(
			frappe.db.sql(
				"""
				select sum(detail.transfer_qty)
				from `tabStock Entry` entry
				join `tabStock Entry Detail` detail on detail.parent = entry.name
				where entry.work_order = %s
				  and entry.docstatus = 1
				  and entry.purpose = 'Manufacture'
				  and detail.is_finished_item = 1
				""",
				self.work_order,
			)[0][0]
		)
		self.assertEqual(ledger, row["produced_qty"])

	def test_a_written_off_piece_never_reaches_the_shelf(self):
		self.send()
		self.finish(SECOND_OP)
		self.rework("не удалось")
		self.rework("списать в брак")
		for operation in ("ЧПУ обработка", "Сверление", "Покраска", "Сборка"):
			self.finish(operation)
		self.sign_off()
		self.finish(INSPECTED_OP)

		self.as_user(PLANNER, RELEASE, {"work_order": self.work_order})

		frappe.set_user("Administrator")
		row = self.job()
		self.assertEqual(row["produced_qty"], 4.0)
		self.assertEqual(row["process_loss_qty"], 1.0)

	def test_another_companys_job_is_still_refused(self):
		frappe.set_user("Administrator")
		foreign = frappe.db.get_value("Work Order", {"company": ["!=", "KORKEM"]}, "name")
		if not foreign:
			self.skipTest("no other company's work order on this bench")

		result = self.as_user(
			PLANNER, FINISH_OP, {"work_order": foreign, "operation": FIRST_OP, "rework_qty": 1}
		)

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"].lower())


class TestTheWriteOffAfterAFailedRepair(_ScrapTestCase):
	"""The sequence the device run stalled on.

	Four good, one damaged, one repair that fails, then the piece written off —
	and only four cabinets on the shelf at the end.
	"""

	def send(self):
		result = self.finish(FIRST_OP, qty=4, rework_qty=1)
		self.assertTrue(result["ok"], result.get("error"))
		return result

	def rework(self, result, **args):
		return self.as_user(PLANNER, REWORK, {"work_order": self.work_order, "result": result, **args})

	def test_the_stage_can_be_named_when_writing_a_piece_off(self):
		"""What actually broke on the phone. Every other shop-floor tool takes
		`operation`, so the model sends it here too — and a closed schema
		rejected the call, which reached the user as no answer at all."""
		self.send()
		self.rework("не удалось")

		result = self.rework("списать в брак", operation=FIRST_OP)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "scrapped")

	def test_naming_a_stage_that_holds_nothing_says_so(self):
		self.send()

		result = self.rework("списать в брак", operation=SECOND_OP)

		self.assertTrue(result["ok"])
		self.assertEqual(result["data"]["status"], "nothing_in_rework")

	def test_a_failed_repair_then_a_write_off_leaves_four_on_the_shelf(self):
		self.send()
		self.finish(SECOND_OP)
		self.assertEqual(self.rework("не удалось")["data"]["status"], "unresolved")

		self.assertEqual(self.rework("списать в брак")["data"]["status"], "scrapped")

		for operation in ("ЧПУ обработка", "Сверление", "Покраска", "Сборка"):
			done = self.finish(operation)
			self.assertTrue(done["ok"], done.get("error"))
			self.assertEqual(done["data"]["carried_forward_loss"], 1.0)
		self.sign_off()
		self.finish(INSPECTED_OP)

		released = self.as_user(PLANNER, RELEASE, {"work_order": self.work_order})

		self.assertTrue(released["ok"], released.get("error"))
		frappe.set_user("Administrator")
		row = self.job()
		self.assertEqual(row["produced_qty"], 4.0, "the written-off piece reached the shelf")
		self.assertEqual(row["process_loss_qty"], 1.0)
		ledger = flt(
			frappe.db.sql(
				"""
				select sum(detail.transfer_qty)
				from `tabStock Entry` entry
				join `tabStock Entry Detail` detail on detail.parent = entry.name
				where entry.work_order = %s
				  and entry.docstatus = 1
				  and entry.purpose = 'Manufacture'
				  and detail.is_finished_item = 1
				""",
				self.work_order,
			)[0][0]
		)
		self.assertEqual(ledger, 4.0)

	def test_writing_off_twice_changes_nothing(self):
		self.send()
		self.rework("не удалось")
		self.rework("списать в брак")

		again = self.rework("списать в брак")

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "nothing_in_rework")


STOP = "manufacturing.stop_production"


class _StopTestCase(_ProductionTestCase):
	"""The overdue Караганда job: submitted, part-built, material reserved."""

	def setUp(self):
		super().setUp()
		self.overdue = _order("Караганда Мебель")
		if not self.overdue:
			self.skipTest("seed_demo has not been run on this site")
		self.job = frappe.get_all(
			"Work Order", filters={"sales_order": self.overdue, "docstatus": 1}, pluck="name"
		)[0]
		self.addCleanup(self._restart)

	def _restart(self):
		"""Leave the seeded job running whatever a test did to it."""
		frappe.set_user("Administrator")
		if frappe.db.get_value("Work Order", self.job, "status") == "Stopped":
			from erpnext.manufacturing.doctype.work_order.work_order import stop_unstop

			stop_unstop(self.job, "Resumed")
		frappe.db.commit()

	def stop(self, action="останови", **args):
		return self.as_user(PLANNER, STOP, {"work_order": self.job, "action": action, **args})

	def status(self):
		frappe.set_user("Administrator")
		return frappe.db.get_value("Work Order", self.job, "status")

	def reserved(self):
		frappe.set_user("Administrator")
		return {
			row["item_code"]: flt(row["reserved_qty_for_production"])
			for row in frappe.get_all(
				"Bin",
				filters={"warehouse": "Stores - KRK", "item_code": ["in", ("ЛДСП 18мм", "Ручка")]},
				fields=["item_code", "reserved_qty_for_production"],
			)
		}


class TestStoppingAJob(_StopTestCase):
	def test_a_running_job_can_be_stopped(self):
		result = self.stop(reason="клиент перенёс")

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "stopped")
		self.assertEqual(result["data"]["work_order_status"], "Stopped")
		self.assertEqual(self.status(), "Stopped", "ERPNext did not stop the job")

	def test_stopping_releases_the_material_it_was_holding(self):
		"""The point of stopping. `stop_unstop` calls `update_planned_qty`, and
		board a halted job is sitting on is board another order cannot use."""
		before = self.reserved()
		self.assertGreater(sum(before.values()), 0, "the seeded job reserves nothing")

		self.stop()

		self.assertEqual(sum(self.reserved().values()), 0.0)

	def test_resuming_takes_the_material_back(self):
		before = self.reserved()
		self.stop()

		result = self.stop("возобнови")

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "resumed")
		self.assertEqual(self.status(), "In Process")
		self.assertEqual(self.reserved(), before)

	def test_stopping_unmakes_nothing(self):
		"""Halting a job stops it going further; it does not undo what was
		already built or consumed."""
		frappe.set_user("Administrator")
		before = frappe.db.get_value(
			"Work Order", self.job, ["produced_qty", "material_transferred_for_manufacturing"],
			as_dict=True,
		)

		self.stop()

		frappe.set_user("Administrator")
		after = frappe.db.get_value(
			"Work Order", self.job, ["produced_qty", "material_transferred_for_manufacturing"],
			as_dict=True,
		)
		self.assertEqual(dict(after), dict(before))

	def test_stopping_twice_moves_nothing_twice(self):
		self.stop()
		reserved = self.reserved()

		again = self.stop()

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "already_stopped")
		self.assertEqual(self.reserved(), reserved)

	def test_resuming_a_running_job_says_so(self):
		again = self.stop("возобнови")

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "already_running")
		self.assertEqual(self.status(), "In Process")

	def test_a_stopped_job_cannot_be_produced(self):
		self.stop()

		result = self.as_user(PLANNER, RELEASE, {"work_order": self.job})

		self.assertFalse(result["ok"])
		self.assertIn("Stopped", result["error"]["message"])

	def test_a_stopped_job_leaves_the_priority_queue(self):
		"""A halted job must stop competing for a slot on the floor."""
		self.stop()

		queue = self.as_user(PLANNER, "manufacturing.production_priority")["data"]["queue"]

		self.assertNotIn(self.job, [row["work_order"] for row in queue])

	def test_the_shortage_stays_truthful_after_a_stop(self):
		"""Invariant J. A stopped job releases its claim, so the board it held
		is available again — and no figure may go negative or double-count."""
		self.stop()

		frappe.set_user(PLANNER)
		items = registry.execute("inventory.factory_shortage", {})["data"]["items"]
		frappe.set_user("Administrator")

		for row in items:
			self.assertGreaterEqual(row["shortage_qty"], 0)
			self.assertGreaterEqual(row["physical_shortage_qty"], 0)


class TestStoppingIsGuarded(_StopTestCase):
	def test_it_is_a_write_needing_confirmation_and_takes_no_company(self):
		spec = registry.get(STOP)

		self.assertIs(spec.risk, registry.Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)
		self.assertNotIn("company", spec.input_schema["properties"])

	def test_an_unreadable_intent_is_refused(self):
		result = self.stop("может быть")

		self.assertFalse(result["ok"])
		self.assertIn("stopped or resumed", result["error"]["message"])

	def test_an_unknown_work_order_is_a_sentence(self):
		result = self.as_user(
			PLANNER, STOP, {"work_order": "MFG-WO-9999-99999", "action": "останови"}
		)

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"].lower())

	def test_another_companys_job_cannot_be_stopped(self):
		frappe.set_user("Administrator")
		foreign = frappe.db.get_value("Work Order", {"company": ["!=", "KORKEM"]}, "name")
		if not foreign:
			self.skipTest("no other company's work order on this bench")

		result = self.as_user(PLANNER, STOP, {"work_order": foreign, "action": "останови"})

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"].lower())

	def test_a_job_belonging_to_another_order_is_refused(self):
		other = _order("Мебель Астана")

		result = self.as_user(
			PLANNER, STOP, {"sales_order": other, "work_order": self.job, "action": "останови"}
		)

		self.assertFalse(result["ok"])
		self.assertIn("not", result["error"]["message"].lower())

	def test_naming_only_the_order_works_when_it_has_one_job(self):
		result = self.as_user(
			PLANNER, STOP, {"sales_order": self.overdue, "action": "останови"}
		)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["work_order"], self.job)

	def test_two_jobs_on_one_order_are_never_chosen_silently(self):
		frappe.set_user("Administrator")
		kept = frappe.db.get_single_value(
			"Manufacturing Settings", "overproduction_percentage_for_sales_order"
		)
		frappe.db.set_single_value(
			"Manufacturing Settings", "overproduction_percentage_for_sales_order", 100
		)
		self.addCleanup(
			frappe.db.set_single_value,
			"Manufacturing Settings",
			"overproduction_percentage_for_sales_order",
			kept,
		)
		first = frappe.get_doc("Work Order", self.job)
		extra = frappe.get_doc(
			{
				"doctype": "Work Order",
				"production_item": first.production_item,
				"bom_no": first.bom_no,
				"company": first.company,
				"qty": 1,
				"sales_order": first.sales_order,
				"wip_warehouse": first.wip_warehouse,
				"fg_warehouse": first.fg_warehouse,
				"source_warehouse": first.source_warehouse,
			}
		)
		extra.insert(ignore_permissions=True)
		extra.submit()

		result = self.as_user(
			PLANNER, STOP, {"sales_order": self.overdue, "action": "останови"}
		)

		self.assertFalse(result["ok"])
		self.assertIn("which one", result["error"]["message"].lower())
		self.assertIn(extra.name, result["error"]["message"])
		self.assertEqual(self.status(), "In Process", "a job was stopped despite the ambiguity")
