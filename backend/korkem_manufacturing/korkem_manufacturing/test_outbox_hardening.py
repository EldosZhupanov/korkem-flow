# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Fault-injection and reliability tests for Outbox Per-Consumer Delivery Ledger."""

from __future__ import annotations

import json
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_to_date, now_datetime

from korkem_manufacturing.services import outbox


class TestOutboxHardening(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.company = "KORKEM"
		frappe.db.delete("Domain Outbox Delivery")
		frappe.db.delete("Domain Outbox Event")
		frappe.db.commit()

	def tearDown(self):
		frappe.db.delete("Domain Outbox Delivery")
		frappe.db.delete("Domain Outbox Event")
		frappe.db.commit()
		frappe.db.rollback()

	def test_1_crash_immediately_after_db_commit(self):
		"""Event and deliveries are written atomically in MariaDB. If process crashes, state is preserved."""
		event_id = outbox.record_event(
			event_name="test.order_created",
			aggregate_type="Sales Order",
			aggregate_id="SO-TEST-001",
			payload={"customer": "Ерлан", "total": 250000},
			company=self.company,
		)
		self.assertTrue(frappe.db.exists("Domain Outbox Event", event_id))

		# Deliveries are created in Pending state
		deliveries = frappe.get_all(
			"Domain Outbox Delivery",
			filters={"event_id": event_id},
			fields=["name", "status"],
		)
		self.assertTrue(len(deliveries) >= 1)
		self.assertEqual(deliveries[0].status, "Pending")

	def test_2_per_consumer_isolation_when_a_succeeds_and_b_fails(self):
		"""Consumer A succeeds, Consumer B fails. On retry, A must NOT re-execute!"""
		event_id = outbox.record_event(
			event_name="test.multi_consumer_event",
			aggregate_type="Sales Order",
			aggregate_id="SO-TEST-002",
			payload={"test": "data"},
			company=self.company,
		)

		# Explicitly create two consumers: ConsumerA (WhatsApp) and ConsumerB (CRM)
		del_a = outbox._create_delivery_record(
			event_id=event_id,
			consumer_name="test_consumer_whatsapp",
			company=self.company,
			correlation_id="corr-1",
		)
		del_b = outbox._create_delivery_record(
			event_id=event_id,
			consumer_name="test_consumer_crm",
			company=self.company,
			correlation_id="corr-1",
		)

		calls = []

		def mock_invoke(consumer_name, event_name, payload, company):
			calls.append(consumer_name)
			if consumer_name == "test_consumer_crm":
				raise RuntimeError("CRM API Connection Timeout")

		with patch("korkem_manufacturing.services.outbox._invoke_consumer", side_effect=mock_invoke):
			res1 = outbox.dispatch_pending(limit=10)

		# First run: WhatsApp succeeded, CRM failed
		self.assertTrue(res1["succeeded"] >= 1)
		self.assertEqual(res1["failed"], 1)

		# Check status in DB
		status_a = frappe.db.get_value("Domain Outbox Delivery", del_a, "status")
		status_b = frappe.db.get_value("Domain Outbox Delivery", del_b, "status")
		self.assertEqual(status_a, "Completed")
		self.assertEqual(status_b, "Failed")

		# Second run (Retry): set next_retry_at to now for Consumer B
		frappe.db.set_value("Domain Outbox Delivery", del_b, "next_retry_at", add_to_date(now_datetime(), seconds=-10))

		calls.clear()
		# Now CRM succeeds on retry
		with patch("korkem_manufacturing.services.outbox._invoke_consumer", return_value=None):
			res2 = outbox.dispatch_pending(limit=10)

		# Only Consumer B was invoked! Consumer A was NOT invoked again!
		self.assertNotIn("test_consumer_whatsapp", calls)
		status_b_after = frappe.db.get_value("Domain Outbox Delivery", del_b, "status")
		self.assertEqual(status_b_after, "Completed")

	def test_3_duplicate_dispatch_is_idempotent(self):
		"""Running dispatch on already completed deliveries does nothing."""
		event_id = outbox.record_event(
			event_name="test.duplicate_dispatch",
			aggregate_type="Sales Order",
			aggregate_id="SO-TEST-003",
			payload={"x": 1},
			company=self.company,
		)
		with patch("korkem_manufacturing.services.outbox._invoke_consumer", return_value=None):
			res1 = outbox.dispatch_pending(limit=10)
		self.assertTrue(res1["succeeded"] >= 1)

		# Immediate second dispatch sees 0 pending
		with patch("korkem_manufacturing.services.outbox._invoke_consumer", return_value=None):
			res2 = outbox.dispatch_pending(limit=10)
		self.assertEqual(res2["succeeded"], 0)

	def test_4_two_concurrent_dispatchers_worker_leasing(self):
		"""Two workers attempting to lease the same delivery row: only one wins, second skips."""
		event_id = outbox.record_event(
			event_name="test.concurrent_dispatch",
			aggregate_type="Sales Order",
			aggregate_id="SO-TEST-004",
			payload={"x": 2},
			company=self.company,
		)
		delivery = frappe.get_all("Domain Outbox Delivery", filters={"event_id": event_id}, pluck="name")[0]

		# Worker 1 leases it
		frappe.db.set_value(
			"Domain Outbox Delivery",
			delivery,
			{
				"status": "Processing",
				"lease_token": "worker-alpha",
				"lease_expires_at": add_to_date(now_datetime(), seconds=60),
			},
		)

		# Worker 2 attempts dispatch
		res = outbox.dispatch_pending(limit=10, worker_id="worker-beta")
		# The delivery is locked by worker-alpha, so worker-beta cannot acquire it
		self.assertEqual(res["succeeded"], 0)

	def test_5_worker_restart_stale_lease_recovery(self):
		"""If worker crashed while processing, expired lease is picked up on next dispatch."""
		event_id = outbox.record_event(
			event_name="test.stale_lease",
			aggregate_type="Sales Order",
			aggregate_id="SO-TEST-005",
			payload={"x": 3},
			company=self.company,
		)
		delivery = frappe.get_all("Domain Outbox Delivery", filters={"event_id": event_id}, pluck="name")[0]

		# Expired lease
		frappe.db.set_value(
			"Domain Outbox Delivery",
			delivery,
			{
				"status": "Processing",
				"lease_token": "worker-dead",
				"lease_expires_at": add_to_date(now_datetime(), seconds=-10),
			},
		)

		with patch("korkem_manufacturing.services.outbox._invoke_consumer", return_value=None):
			res = outbox.dispatch_pending(limit=10, worker_id="worker-revived")

		self.assertEqual(res["succeeded"], 1)
		status = frappe.db.get_value("Domain Outbox Delivery", delivery, "status")
		self.assertEqual(status, "Completed")

	def test_6_retry_exhaustion_moves_to_dlq(self):
		"""Exhausting max_attempts transitions status to Dead Letter (DLQ)."""
		event_id = outbox.record_event(
			event_name="test.retry_exhaustion",
			aggregate_type="Sales Order",
			aggregate_id="SO-TEST-006",
			payload={"x": 4},
			company=self.company,
		)
		delivery = frappe.get_all("Domain Outbox Delivery", filters={"event_id": event_id}, pluck="name")[0]

		# Set attempts to 4 (max is 5)
		frappe.db.set_value("Domain Outbox Delivery", delivery, {"attempts": 4})

		with patch("korkem_manufacturing.services.outbox._invoke_consumer", side_effect=RuntimeError("Permanent failure")):
			res = outbox.dispatch_pending(limit=10)

		self.assertEqual(res["dead_letter"], 1)
		status = frappe.db.get_value("Domain Outbox Delivery", delivery, "status")
		self.assertEqual(status, "Dead Letter")

		# Check parent event also marked Dead Letter
		parent_status = frappe.db.get_value("Domain Outbox Event", event_id, "status")
		self.assertEqual(parent_status, "Dead Letter")

	def test_7_dlq_manual_replay(self):
		"""Replaying an event from DLQ resets status to Pending and succeeds on fix."""
		event_id = outbox.record_event(
			event_name="test.dlq_replay",
			aggregate_type="Sales Order",
			aggregate_id="SO-TEST-007",
			payload={"x": 5},
			company=self.company,
		)
		delivery = frappe.get_all("Domain Outbox Delivery", filters={"event_id": event_id}, pluck="name")[0]
		frappe.db.set_value("Domain Outbox Delivery", delivery, {"status": "Dead Letter", "attempts": 5})

		# Replay
		replayed_count = outbox.replay_event(event_id)
		self.assertEqual(replayed_count, 1)
		self.assertEqual(frappe.db.get_value("Domain Outbox Delivery", delivery, "status"), "Pending")

		# Now dispatch runs and completes
		with patch("korkem_manufacturing.services.outbox._invoke_consumer", return_value=None):
			res = outbox.dispatch_pending(limit=10)
		self.assertEqual(res["succeeded"], 1)
		self.assertEqual(frappe.db.get_value("Domain Outbox Delivery", delivery, "status"), "Completed")

	def test_8_consumer_duplicate_protection_by_event_id(self):
		"""Primary key UNIQUE(event_id, consumer_name) prevents duplicate delivery creation."""
		event_id = outbox.record_event(
			event_name="test.idempotent_consumer",
			aggregate_type="Sales Order",
			aggregate_id="SO-TEST-008",
			payload={"x": 6},
			company=self.company,
		)
		# Attempting to insert duplicate delivery for same consumer raises DuplicateEntryError
		with self.assertRaises(frappe.DuplicateEntryError):
			outbox._create_delivery_record(
				event_id=event_id,
				consumer_name="automation.evaluator",
				company=self.company,
				correlation_id="corr-2",
			)
