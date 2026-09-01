# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Server-side half of the mobile outbox contract."""

from __future__ import annotations

import inspect
import threading
import time
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.api import dispatch, production, purchasing
from korkem_manufacturing.korkem_manufacturing.doctype.idempotency_record.idempotency_record import (
	IdempotencyRecord,
)
from korkem_manufacturing.services import dispatch as dispatch_service
from korkem_manufacturing.services import idempotency
from korkem_manufacturing.services import purchasing as purchasing_service
from korkem_manufacturing.services import production as production_service
from korkem_manufacturing.services import shop_floor


class TestWritingEndpointsAcceptAnIdempotencyKey(IntegrationTestCase):
	def test_all_five_keep_the_old_signature_and_add_one_optional_key(self):
		for endpoint in (
			production.start_production,
			production.complete_operation,
			purchasing.receive_purchase_order,
			purchasing.create_purchase_order,
			dispatch.create_delivery,
		):
			with self.subTest(endpoint=endpoint.__name__):
				parameter = inspect.signature(endpoint).parameters.get("idempotency_key")
				self.assertIsNotNone(parameter)
				self.assertIsNone(parameter.default)


class TestARepeatedCommand(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def test_same_key_returns_the_first_result_without_running_again(self):
		calls = []

		def start_once(*_args, **_kwargs):
			calls.append(1)
			return {"status": "started", "work_order": "WO-IDEMPOTENT"}

		with (
			patch.object(production, "ensure_company"),
			patch.object(production, "_audit"),
			patch.object(production_service, "start_production", side_effect=start_once),
		):
			first = production.start_production("SO-IDEMPOTENT", idempotency_key="mobile-1")
			second = production.start_production("SO-IDEMPOTENT", idempotency_key="mobile-1")

		self.assertEqual(second, first)
		self.assertEqual(len(calls), 1, "a retry must not execute the command twice")

	def test_a_business_refusal_is_replayed_even_if_the_world_changes(self):
		calls = []

		def material_changes(*_args, **_kwargs):
			calls.append(1)
			if len(calls) == 1:
				return {
					"status": "blocked",
					"blocking_materials": [{"item_code": "BOARD", "short_by": 2}],
				}
			return {"status": "started", "work_order": "WO-TOO-LATE"}

		with (
			patch.object(production, "ensure_company"),
			patch.object(production, "_audit"),
			patch.object(production_service, "start_production", side_effect=material_changes),
		):
			first = production.start_production("SO-BLOCKED", idempotency_key="mobile-blocked")
			second = production.start_production("SO-BLOCKED", idempotency_key="mobile-blocked")

		self.assertEqual(first["status"], "blocked")
		self.assertEqual(second, first)
		self.assertEqual(len(calls), 1)

	def test_different_keys_execute_independently(self):
		calls = []

		def start(*_args, **_kwargs):
			calls.append(1)
			return {"status": "started", "attempt": len(calls)}

		with (
			patch.object(production, "ensure_company"),
			patch.object(production, "_audit"),
			patch.object(production_service, "start_production", side_effect=start),
		):
			first = production.start_production("SO-TWO", idempotency_key="mobile-a")
			second = production.start_production("SO-TWO", idempotency_key="mobile-b")

		self.assertEqual(first["attempt"], 1)
		self.assertEqual(second["attempt"], 2)
		self.assertEqual(len(calls), 2)

	def test_an_old_client_without_a_key_keeps_working(self):
		calls = []

		with (
			patch.object(production, "ensure_company"),
			patch.object(production, "_audit"),
			patch.object(
				production_service,
				"start_production",
				side_effect=lambda *_args, **_kwargs: calls.append(1) or {"status": "ok"},
			),
		):
			production.start_production("SO-OLD")
			production.start_production("SO-OLD")

		self.assertEqual(len(calls), 2)


class TestEveryWritingEndpointUsesTheSameGuard(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def test_complete_operation_runs_once(self):
		calls = []
		with (
			patch.object(production, "ensure_company"),
			patch.object(production, "_audit_operation"),
			patch.object(
				shop_floor,
				"complete_operation",
				side_effect=lambda **_kwargs: calls.append(1)
				or {"status": "completed", "job_card": "JC-1"},
			),
		):
			first = production.complete_operation(
				work_order="WO-1", idempotency_key="complete-1"
			)
			second = production.complete_operation(
				work_order="WO-1", idempotency_key="complete-1"
			)
		self.assertEqual(second, first)
		self.assertEqual(len(calls), 1)

	def test_receive_purchase_order_runs_once(self):
		calls = []
		with (
			patch.object(purchasing, "ensure_company"),
			patch.object(purchasing, "_audit"),
			patch.object(
				purchasing_service,
				"receive_purchase_order",
				side_effect=lambda *_args, **_kwargs: calls.append(1)
				or {"status": "received", "purchase_receipt": "PR-1"},
			),
		):
			first = purchasing.receive_purchase_order("PO-1", idempotency_key="receive-1")
			second = purchasing.receive_purchase_order("PO-1", idempotency_key="receive-1")
		self.assertEqual(second, first)
		self.assertEqual(len(calls), 1)

	def test_create_purchase_order_runs_once(self):
		calls = []
		with (
			patch.object(purchasing, "ensure_company"),
			patch.object(purchasing, "_audit_order"),
			patch.object(
				purchasing_service,
				"create_purchase_order",
				side_effect=lambda *_args, **_kwargs: calls.append(1)
				or {"status": "ordered", "purchase_order": "PO-1"},
			),
		):
			first = purchasing.create_purchase_order("MR-1", idempotency_key="order-1")
			second = purchasing.create_purchase_order("MR-1", idempotency_key="order-1")
		self.assertEqual(second, first)
		self.assertEqual(len(calls), 1)

	def test_create_delivery_runs_once(self):
		calls = []
		with (
			patch.object(dispatch, "ensure_company"),
			patch.object(dispatch, "_audit"),
			patch.object(
				dispatch_service,
				"create_delivery",
				side_effect=lambda *_args, **_kwargs: calls.append(1)
				or {"status": "shipped", "delivery_note": "DN-1"},
			),
		):
			first = dispatch.create_delivery("SO-1", idempotency_key="delivery-1")
			second = dispatch.create_delivery("SO-1", idempotency_key="delivery-1")
		self.assertEqual(second, first)
		self.assertEqual(len(calls), 1)


class TestKeysAreScopedAndBoundToOneCommand(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def _user(self, email: str) -> str:
		if not frappe.db.exists("User", email):
			frappe.get_doc(
				{
					"doctype": "User",
					"email": email,
					"first_name": email.split("@")[0],
					"send_welcome_email": 0,
				}
			).insert(ignore_permissions=True)
		return email

	def test_the_same_key_is_private_to_each_user(self):
		first_user = self._user("idempotency-a@korkem.local")
		second_user = self._user("idempotency-b@korkem.local")
		calls = []

		def answer():
			calls.append(frappe.session.user)
			return {"for_user": frappe.session.user}

		frappe.set_user(first_user)
		first = idempotency.execute("test.user-scope", "same-key", {}, answer)
		frappe.set_user(second_user)
		second = idempotency.execute("test.user-scope", "same-key", {}, answer)
		frappe.set_user(first_user)
		replayed = idempotency.execute("test.user-scope", "same-key", {}, answer)

		self.assertEqual(first, replayed)
		self.assertNotEqual(first, second)
		self.assertEqual(calls, [first_user, second_user])
		self.assertFalse(
			frappe.has_permission("Idempotency Record", "read", user=first_user),
			"ordinary users must not browse stored command responses",
		)

	def test_reusing_a_key_for_different_data_is_refused(self):
		calls = []
		idempotency.execute(
			"test.payload",
			"one-command",
			{"qty": 1},
			lambda: calls.append(1) or {"status": "done"},
		)

		with self.assertRaises(frappe.ValidationError) as caught:
			idempotency.execute(
				"test.payload",
				"one-command",
				{"qty": 2},
				lambda: calls.append(2) or {"status": "done"},
			)

		self.assertIn("different command data", str(caught.exception))
		self.assertEqual(calls, [1])

class TestTheRecordSharesTheBusinessTransaction(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def test_a_failed_callback_leaves_neither_business_write_nor_record(self):
		marker = "idempotency-half-write-" + frappe.generate_hash(length=8)
		key = "failed-" + frappe.generate_hash(length=8)
		name = idempotency._record_name(frappe.session.user, "test.atomicity", key)

		def half_write():
			frappe.get_doc({"doctype": "ToDo", "description": marker}).insert()
			raise RuntimeError("failed after the business write")

		with self.assertRaises(RuntimeError):
			idempotency.execute("test.atomicity", key, {}, half_write)

		self.assertFalse(frappe.db.exists("ToDo", {"description": marker}))
		self.assertFalse(frappe.db.exists("Idempotency Record", name))

	def test_rolling_back_the_request_removes_both_business_write_and_result(self):
		marker = "idempotency-same-transaction-" + frappe.generate_hash(length=8)
		key = "transaction-" + frappe.generate_hash(length=8)
		name = idempotency._record_name(frappe.session.user, "test.same-transaction", key)

		def write():
			doc = frappe.get_doc({"doctype": "ToDo", "description": marker}).insert()
			return {"status": "created", "document": doc.name}

		idempotency.execute("test.same-transaction", key, {}, write)
		self.assertTrue(frappe.db.exists("ToDo", {"description": marker}))
		self.assertTrue(frappe.db.exists("Idempotency Record", name))

		frappe.db.rollback()

		self.assertFalse(frappe.db.exists("ToDo", {"description": marker}))
		self.assertFalse(frappe.db.exists("Idempotency Record", name))

	def test_a_validation_error_does_not_commit_the_outer_request(self):
		marker = "idempotency-outer-write-" + frappe.generate_hash(length=8)
		frappe.get_doc({"doctype": "ToDo", "description": marker}).insert()

		with self.assertRaises(frappe.ValidationError):
			idempotency.execute(
				"test.validation-error",
				"validation-" + frappe.generate_hash(length=8),
				{},
				lambda: frappe.throw("The command was refused."),
			)

		frappe.db.rollback()
		self.assertFalse(
			frappe.db.exists("ToDo", {"description": marker}),
			"idempotency must never commit unrelated writes from the request",
		)


class TestConcurrentRetries(IntegrationTestCase):
	def test_two_database_transactions_create_one_document(self):
		"""Exercise the real MariaDB unique-key wait, not a mocked lock."""
		site = frappe.local.site
		sites_path = frappe.local.sites_path
		marker = "idempotency-race-" + frappe.generate_hash(length=8)
		key = "race-" + frappe.generate_hash(length=8)
		barrier = threading.Barrier(2)
		results = []
		errors = []

		# Each worker needs its own committed DB transaction. Starting from a
		# clean boundary also makes its eventual writes visible to this connection.
		frappe.db.commit()

		def worker():
			try:
				frappe.init(site, sites_path=sites_path)
				frappe.connect()
				frappe.db.sql("SET SESSION innodb_lock_wait_timeout = 10")
				frappe.set_user("Administrator")
				# Real endpoints read user roles and company scope before reaching
				# idempotency. Establish the same REPEATABLE READ snapshot here; the
				# replay path must use a locking read to see the winner afterwards.
				frappe.db.get_value("User", "Administrator", "name")
				barrier.wait(timeout=5)

				def create_document():
					doc = frappe.get_doc({"doctype": "ToDo", "description": marker}).insert()
					# Keep the winning transaction open long enough for the other INSERT
					# to contend on the Idempotency Record primary key.
					time.sleep(0.4)
					return {"status": "created", "document": doc.name}

				result = idempotency.execute("test.concurrent", key, {}, create_document)
				frappe.db.commit()
				results.append(result)
			except BaseException as exc:
				errors.append(exc)
				try:
					frappe.db.rollback()
				except Exception:
					pass
			finally:
				frappe.destroy()

		threads = [threading.Thread(target=worker, daemon=True) for _ in range(2)]
		for thread in threads:
			thread.start()
		for thread in threads:
			thread.join(timeout=15)

		try:
			self.assertFalse(any(thread.is_alive() for thread in threads), "race test deadlocked")
			self.assertEqual(errors, [])
			self.assertEqual(len(results), 2)
			self.assertEqual(results[0], results[1])
			self.assertEqual(
				frappe.db.count("ToDo", {"description": marker}),
				1,
				"both callbacks ran and created duplicate documents",
			)
		finally:
			frappe.db.delete("ToDo", {"description": marker})
			frappe.db.delete("Idempotency Record", {"action": "test.concurrent"})
			frappe.db.commit()


class TestRetention(IntegrationTestCase):
	def tearDown(self):
		frappe.db.rollback()

	def test_records_older_than_thirty_days_are_cleaned_by_frappe(self):
		old_key = "old-" + frappe.generate_hash(length=8)
		new_key = "new-" + frappe.generate_hash(length=8)
		old_name = idempotency._record_name(frappe.session.user, "test.retention", old_key)
		new_name = idempotency._record_name(frappe.session.user, "test.retention", new_key)

		idempotency.execute("test.retention", old_key, {}, lambda: {"status": "old"})
		idempotency.execute("test.retention", new_key, {}, lambda: {"status": "new"})
		frappe.db.set_value(
			"Idempotency Record",
			old_name,
			"creation",
			"2020-01-01 00:00:00",
			update_modified=False,
		)

		IdempotencyRecord.clear_old_logs(days=30)

		self.assertFalse(frappe.db.exists("Idempotency Record", old_name))
		self.assertTrue(frappe.db.exists("Idempotency Record", new_name))
