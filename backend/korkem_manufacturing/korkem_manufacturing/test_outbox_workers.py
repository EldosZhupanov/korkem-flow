# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Unit and integration tests for Outbox Automation Workers and Event Consumers."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import setup
from korkem_manufacturing.services import durable_jobs, outbox, outbox_workers
from korkem_manufacturing.services.scope import current_company


class TestOutboxWorkers(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		setup.provision()

	def setUp(self):
		frappe.set_user("Administrator")
		self.company = current_company()
		frappe.defaults.set_user_default("Company", self.company)

	def tearDown(self):
		frappe.defaults.set_user_default("Company", self.company)
		frappe.db.rollback()

	def test_shortage_detected_event_triggers_durable_procurement_job(self):
		"""Событие material.shortage_detected автоматически запускает Durable Job закупки дефицита."""
		sales_order = f"SO-SHORT-{frappe.generate_hash(length=6)}"

		# 1. Записываем событие дефицита в Outbox
		evt = outbox.record_event(
			event_name="material.shortage_detected",
			aggregate_type="Sales Order",
			aggregate_id=sales_order,
			payload={
				"sales_order": sales_order,
				"company": self.company,
				"shortages": [
					{"item_code": "LDSP-16-WHT", "shortage_qty": 4.0},
					{"item_code": "EDGE-2MM-WHT", "shortage_qty": 25.0},
				],
			},
			company=self.company,
		)

		# 2. Регистрируем доставку для подписчика ShortageAutomationConsumer
		consumer_name = "ShortageAutomationConsumer"
		delivery = outbox.register_delivery_attempt(
			event_id=evt,
			consumer_name=consumer_name,
			company=self.company,
		)
		frappe.db.commit()

		# 3. Запускаем диспетчеризацию воркера
		metrics = outbox_workers.dispatch_outbox_batch(batch_size=10, delivery_name=delivery.name)
		self.assertGreaterEqual(metrics["succeeded"], 1)

		# Статус доставки стал Completed
		deliv_status = frappe.db.get_value("Domain Outbox Delivery", delivery.name, "status")
		self.assertEqual(deliv_status, "Completed")

		# 4. Проверяем, что в БД создана фоновая долговечная задача закупки
		expected_job_key = f"procure-shortage-{sales_order}"
		job_name = frappe.db.get_value(
			"Durable Job Run",
			{"company": self.company, "idempotency_key": expected_job_key},
			"name",
		)
		self.assertIsNotNone(job_name)

		# 5. Исполняем созданную долговечную задачу
		job_res = durable_jobs.execute_durable_job(job_name)
		self.assertEqual(job_res["sales_order"], sales_order)
		self.assertGreater(len(job_res["requests_created"]), 0)

		# Статус задачи стал Completed
		job_status = frappe.db.get_value("Durable Job Run", job_name, "status")
		self.assertEqual(job_status, "Completed")

	def test_order_event_dispatch_to_audit_consumer(self):
		"""События жизненного цикла заказа успешно диспетчеризируются подписчикам."""
		order_name = f"SO-NOTIF-{frappe.generate_hash(length=6)}"
		evt = outbox.record_event(
			event_name="order.in_production",
			aggregate_type="Sales Order",
			aggregate_id=order_name,
			payload={"sales_order": order_name, "to_state": "In Production"},
			company=self.company,
		)

		delivery = outbox.register_delivery_attempt(
			event_id=evt,
			consumer_name="OrderAuditConsumer",
			company=self.company,
		)
		frappe.db.commit()

		metrics = outbox_workers.dispatch_outbox_batch(batch_size=10, delivery_name=delivery.name)
		self.assertGreaterEqual(metrics["succeeded"], 1)

		deliv_status = frappe.db.get_value("Domain Outbox Delivery", delivery.name, "status")
		self.assertEqual(deliv_status, "Completed")

	def test_failing_consumer_retries_and_moves_to_dlq(self):
		"""Сбойный подписчик изолирован, повторяется по политике и переходит в Dead Letter."""
		def bad_consumer(payload, comp):
			raise ConnectionError("ERP Supplier API timeout")

		outbox_workers.register_consumer("test.failing_event", bad_consumer)

		evt = outbox.record_event(
			event_name="test.failing_event",
			aggregate_type="TestEntity",
			aggregate_id="TEST-001",
			payload={"msg": "fail"},
			company=self.company,
		)

		delivery = outbox.register_delivery_attempt(
			event_id=evt,
			consumer_name="BadConsumer",
			company=self.company,
		)
		# Имитируем 4 предыдущих сбоя
		frappe.db.set_value(
			"Domain Outbox Delivery",
			delivery.name,
			{"attempts": 4, "max_attempts": 5},
			update_modified=True,
		)
		frappe.db.commit()

		metrics = outbox_workers.dispatch_outbox_batch(batch_size=10, delivery_name=delivery.name)
		self.assertEqual(metrics["dead_letter"], 1)

		deliv_status = frappe.db.get_value("Domain Outbox Delivery", delivery.name, "status")
		self.assertEqual(deliv_status, "Dead Letter")
