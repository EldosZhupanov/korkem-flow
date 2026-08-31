# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Load, bottleneck and what to start first.

The interesting assertions are about restraint: a station with no working hours
must produce no utilisation figure, an order with no delivery date must not be
called late, and an order that cannot start must not appear in a queue of things
to start. A capacity tool that always returns a number is the failure mode here.
"""

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing import seed_demo

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401

CAPACITY = "manufacturing.capacity"
PRIORITY = "manufacturing.production_priority"
PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"


class _CapacityTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		if not frappe.db.exists("Workstation", "ЧПУ"):
			self.skipTest("seed_demo has not been run on this site")
		seed_demo.seed_users()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def as_user(self, user, tool):
		frappe.set_user(user)
		try:
			return registry.execute(tool, {})
		finally:
			frappe.set_user("Administrator")

	def load(self):
		result = self.as_user(PLANNER, CAPACITY)
		self.assertTrue(result["ok"], result.get("error"))
		return result["data"]

	def queue(self):
		result = self.as_user(PLANNER, PRIORITY)
		self.assertTrue(result["ok"], result.get("error"))
		return result["data"]


class TestLoadComesFromTheStationsOwnConfiguration(_CapacityTestCase):
	def test_available_hours_are_the_shift_times_the_parallel_jobs(self):
		"""Two benches on the edgebander are two benches, not one."""
		stations = {row["workstation"]: row for row in self.load()["workstations"]}

		edging = stations["Кромка и сверловка"]
		self.assertEqual(edging["shift_hours"], 8.0)
		self.assertEqual(edging["parallel_jobs"], 2)
		self.assertEqual(edging["available_hours_per_day"], 16.0)

	def test_utilisation_is_queued_hours_over_a_days_capacity(self):
		for station in self.load()["workstations"]:
			with self.subTest(workstation=station["workstation"]):
				if station["available_hours_per_day"] is None:
					continue
				self.assertAlmostEqual(
					station["utilisation"],
					station["queued_hours"] / station["available_hours_per_day"],
					places=2,
				)

	def test_a_station_carrying_more_than_a_day_of_work_is_overloaded(self):
		stations = self.load()["workstations"]

		for station in stations:
			if station["utilisation"] is None:
				continue
			self.assertEqual(station["overloaded"], station["utilisation"] > 1.0)

	def test_the_bottleneck_is_the_busiest_measurable_station(self):
		floor = self.load()
		measurable = [row for row in floor["workstations"] if row["utilisation"] is not None]

		self.assertEqual(
			floor["bottleneck"]["workstation"],
			max(measurable, key=lambda row: row["utilisation"])["workstation"],
		)

	def test_finished_operations_carry_no_load(self):
		"""Queued hours are what is left, not what was planned."""
		before = {row["workstation"]: row["queued_hours"] for row in self.load()["workstations"]}

		frappe.set_user("Administrator")
		operation = frappe.get_all(
			"Work Order Operation",
			filters={"status": "Pending", "workstation": "Раскрой"},
			fields=["name", "parent", "time_in_mins"],
			limit=1,
		)
		if not operation:
			self.skipTest("no pending saw operation to finish")
		frappe.db.set_value("Work Order Operation", operation[0]["name"], "status", "Completed")
		frappe.db.commit()
		self.addCleanup(self._restore, operation[0]["name"])

		after = {row["workstation"]: row["queued_hours"] for row in self.load()["workstations"]}

		self.assertLess(after.get("Раскрой", 0), before["Раскрой"])

	def _restore(self, operation):
		frappe.set_user("Administrator")
		frappe.db.set_value("Work Order Operation", operation, "status", "Pending")
		frappe.db.commit()


class TestMissingDataIsReportedNotInvented(_CapacityTestCase):
	def test_a_station_with_no_working_hours_gets_no_utilisation(self):
		"""The failure mode this whole module guards against: a confident
		percentage with nothing behind it."""
		frappe.set_user("Administrator")
		station = frappe.get_doc("Workstation", "ЧПУ")
		kept = [(row.start_time, row.end_time, row.enabled) for row in station.working_hours]
		station.set("working_hours", [])
		station.save(ignore_permissions=True)
		frappe.db.commit()
		self.addCleanup(self._restore_hours, "ЧПУ", kept)

		found = {row["workstation"]: row for row in self.load()["workstations"]}

		if "ЧПУ" in found:
			self.assertIsNone(found["ЧПУ"]["utilisation"])
			self.assertIsNone(found["ЧПУ"]["available_hours_per_day"])
			self.assertIn("working hours", found["ЧПУ"]["reason_unknown"])
			self.assertGreater(found["ЧПУ"]["queued_hours"], 0, "the work did not vanish")

	def test_that_station_is_not_named_the_bottleneck(self):
		"""An unmeasurable station cannot be the busiest — there is no number
		to compare."""
		frappe.set_user("Administrator")
		station = frappe.get_doc("Workstation", "ЧПУ")
		kept = [(row.start_time, row.end_time, row.enabled) for row in station.working_hours]
		station.set("working_hours", [])
		station.save(ignore_permissions=True)
		frappe.db.commit()
		self.addCleanup(self._restore_hours, "ЧПУ", kept)

		bottleneck = self.load()["bottleneck"]

		if bottleneck:
			self.assertNotEqual(bottleneck["workstation"], "ЧПУ")

	def test_an_order_with_no_delivery_date_is_not_called_late(self):
		frappe.set_user("Administrator")
		job = frappe.get_all(
			"Work Order", filters={"docstatus": 1, "status": "In Process"}, pluck="name"
		)[0]
		kept = frappe.db.get_value("Work Order", job, "expected_delivery_date")
		frappe.db.set_value("Work Order", job, "expected_delivery_date", None)
		frappe.db.commit()
		self.addCleanup(self._restore_due, job, kept)

		rows = {row["work_order"]: row for row in self.queue()["queue"]}

		if job in rows:
			self.assertEqual(rows[job]["risk"], "UNKNOWN")
			self.assertIn("no delivery date", rows[job]["reason"])

	def _restore_hours(self, name, kept):
		frappe.set_user("Administrator")
		station = frappe.get_doc("Workstation", name)
		station.set("working_hours", [])
		for start, end, enabled in kept:
			station.append("working_hours", {"start_time": start, "end_time": end, "enabled": enabled})
		station.save(ignore_permissions=True)
		frappe.db.commit()

	def _restore_due(self, job, kept):
		frappe.set_user("Administrator")
		frappe.db.set_value("Work Order", job, "expected_delivery_date", kept)
		frappe.db.commit()


class TestThePriorityIsOrderedConstraints(_CapacityTestCase):
	def test_an_order_that_cannot_start_is_kept_out_of_the_queue(self):
		"""It is a purchasing problem, not a sequencing one — sorting it to the
		bottom would still put it on a list of things to start."""
		result = self.queue()

		blocked = {row["work_order"] for row in result["blocked"]}
		queued = {row["work_order"] for row in result["queue"]}

		self.assertTrue(blocked, "the fixture no longer has a materially blocked order")
		self.assertFalse(blocked & queued)
		for row in result["blocked"]:
			self.assertTrue(row["blocking_materials"])
			self.assertIn("cannot start", row["reason"])

	def test_an_overdue_order_is_at_risk_and_says_by_how_much(self):
		rows = [row for row in self.queue()["queue"] if row["days_to_delivery"] is not None]
		overdue = [row for row in rows if row["days_to_delivery"] < 0]
		if not overdue:
			self.skipTest("nothing overdue in the fixture")

		for row in overdue:
			self.assertEqual(row["risk"], "AT_RISK")
			self.assertIn("past its delivery date", row["reason"])

	def test_at_risk_orders_come_before_the_rest(self):
		queue = self.queue()["queue"]
		ranks = {"AT_RISK": 0, "UNKNOWN": 1, "ON_TRACK": 2}

		positions = [ranks[row["risk"]] for row in queue]

		self.assertEqual(positions, sorted(positions), f"queue out of order: {positions}")

	def test_every_position_carries_a_reason_and_no_score(self):
		"""«Почему этот заказ первый» must be answerable in a sentence."""
		for row in self.queue()["queue"]:
			with self.subTest(order=row["work_order"]):
				self.assertTrue(row["reason"])
				self.assertNotIn("score", row)
				self.assertEqual(row["position"], self.queue()["queue"].index(row) + 1)

	def test_lateness_is_only_claimed_when_the_optimistic_case_fails(self):
		"""On track means "not provably late", and the reason says so by
		quoting both numbers."""
		for row in self.queue()["queue"]:
			if row["risk"] != "ON_TRACK":
				continue
			with self.subTest(order=row["work_order"]):
				self.assertIn("h of work left", row["reason"])

	def test_the_bottleneck_is_named_when_an_order_frees_it(self):
		result = self.queue()
		bottleneck = result["summary"]["bottleneck"]
		if not bottleneck:
			self.skipTest("nothing overloaded in the fixture")

		freeing = [row for row in result["queue"] if row["frees_bottleneck"]]
		for row in freeing:
			self.assertEqual(row["bottleneck"], bottleneck)
			self.assertIn(bottleneck, row["reason"])


class TestScopeAndPermissions(_CapacityTestCase):
	def test_neither_tool_takes_a_company(self):
		for name in (CAPACITY, PRIORITY):
			with self.subTest(tool=name):
				self.assertEqual(registry.get(name).input_schema["properties"], {})

	def test_both_are_reads_needing_no_confirmation(self):
		for name in (CAPACITY, PRIORITY):
			with self.subTest(tool=name):
				spec = registry.get(name)
				self.assertIs(spec.risk, registry.Risk.READ)
				self.assertFalse(spec.requires_confirmation)

	def test_another_companys_work_never_reaches_the_load(self):
		"""A foreign work order must not add hours to this factory's stations."""
		frappe.set_user("Administrator")
		foreign = frappe.get_all(
			"Work Order",
			filters={"company": ["!=", "KORKEM"], "docstatus": 1},
			pluck="name",
		)
		queued = {row["work_order"] for row in self.queue()["queue"]}
		blocked = {row["work_order"] for row in self.queue()["blocked"]}

		self.assertFalse(set(foreign) & (queued | blocked))

	def test_a_viewer_may_read_the_load(self):
		"""Both demo users hold Manufacturing User, so reading the floor is
		theirs. Recorded rather than assumed."""
		result = self.as_user(VIEWER, CAPACITY)

		self.assertTrue(result["ok"], result.get("error"))
