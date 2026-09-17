# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Chaos and Fault-Tolerance Integration Test Suite (Phase 5).

Verifies resilience of the KORKEM Flow manufacturing operating system under fault conditions:
1. BASIS-Мебельщик XML Durable Job Crash & Step-Checkpoint Recovery
2. Duplicate Webhook / Payment Gateway Retry Idempotency
3. Optimistic Concurrency Conflict on State Transitions
4. Duplicate Job Card Completion & Payout Idempotency
5. Outbox Retry Exhaustion & Dead Letter Queue (DLQ) Quarantine
"""

from __future__ import annotations

import json
from decimal import Decimal
from typing import Any

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, nowdate

from korkem_manufacturing import setup
from korkem_manufacturing.fixtures.demo_order import create_demo_furniture_order, get_demo_bazis_xml
from korkem_manufacturing.services import (
	acceptance,
	audit,
	capture,
	durable_jobs,
	enquiry,
	manufacturing_flow,
	order_state,
	outbox,
	outbox_workers,
	payments,
	piece_work,
	proposal,
	stock_movement,
	stock_reservation,
)
from korkem_manufacturing.services.scope import current_company


class TestChaosLifecycle(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		setup.provision()

	def setUp(self):
		frappe.set_user("Administrator")
		self.company = current_company()
		frappe.defaults.set_user_default("Company", self.company)
		self.demo_data = create_demo_furniture_order()
		self.warehouse = frappe.db.get_value(
			"Warehouse", {"company": self.company, "warehouse_name": ["in", ["Stores", "Stores - KRK"]]}, "name"
		) or "Stores"
		self.wip_warehouse = frappe.db.get_value(
			"Warehouse", {"company": self.company, "warehouse_name": ["in", ["Work In Progress", "Work In Progress - KRK"]]}, "name"
		) or "Work In Progress - KRK"

		# Ensure Finished Good Item exists
		if not frappe.db.exists("Item", "KIT-3600-MOD"):
			item = frappe.get_doc(
				{
					"doctype": "Item",
					"item_code": "KIT-3600-MOD",
					"item_name": "Кухня 3.6м Модульная",
					"item_group": "Products",
					"stock_uom": "Nos",
					"is_stock_item": 1,
					"is_sales_item": 1,
				}
			)
			item.insert(ignore_permissions=True)

		for m in self.demo_data["materials"]:
			code = m["item_code"]
			uom = m.get("stock_uom", "Nos")
			if not frappe.db.exists("UOM", uom):
				frappe.get_doc({"doctype": "UOM", "uom_name": uom}).insert(ignore_permissions=True)
			if not frappe.db.exists("Item", code):
				frappe.get_doc(
					{
						"doctype": "Item",
						"item_code": code,
						"item_name": m["item_name"],
						"item_group": m["item_group"],
						"stock_uom": uom,
						"is_stock_item": 1,
						"standard_rate": m.get("rate", 1000),
					}
				).insert(ignore_permissions=True)

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def _create_sample_order(self, customer_name: str = "Chaos Test Customer") -> str:
		cap = capture.record(text=f"Заказ для {customer_name}", source="Text")
		enq = enquiry.convert(capture=cap["capture"], customer_name=customer_name)
		prop = proposal.draft(
			enquiry=enq["enquiry"],
			items=[{"item_code": "KIT-3600-MOD", "qty": 1.0, "rate": 500000.0}],
		)
		acc = acceptance.accept(quotation=prop["quotation"], deliver_on=add_days(nowdate(), 14))
		return acc["sales_order"]

	def test_01_basis_xml_crash_recovery_step_checkpoints(self):
		"""1. Сбой в процессе импорта БАЗИС XML: сохранение чекпоинтов шагов и повторное восстановление."""
		so_id = self._create_sample_order("Chaos Bazis Customer")
		bazis_xml = get_demo_bazis_xml(so_id)

		# Шаг 1: Запуск задачи с симулированным падением на шаге match_materials
		job_id = durable_jobs.submit_durable_job(
			job_type="bazis_import_xml",
			payload={
				"sales_order": so_id,
				"xml_content": bazis_xml,
				"item_code": "KIT-3600-MOD",
				"fail_at_step": "match_materials",
			},
			company=self.company,
		)

		with self.assertRaises(RuntimeError):
			durable_jobs.execute_durable_job(job_id)

		# Проверяем, что задача зарегистрирована как Failed
		job_status = frappe.db.get_value("Durable Job Run", job_id, "status")
		self.assertEqual(job_status, "Failed")

		# Проверяем, что шаг 1 (validate_xml) был успешно сохранен как чекпоинт
		step1 = frappe.db.get_value(
			"Durable Step Run",
			{"parent_job": job_id, "step_name": "validate_xml", "status": "Completed"},
			["name", "result_json"],
			as_dict=True,
		)
		self.assertIsNotNone(step1)

		# Шаг 2: Устраняем причину сбоя (убираем fail_at_step) и возобновляем задачу
		job_doc = frappe.get_doc("Durable Job Run", job_id)
		payload = json.loads(job_doc.payload_json)
		payload.pop("fail_at_step", None)
		job_doc.payload_json = json.dumps(payload)
		job_doc.status = "Pending"
		job_doc.save(ignore_permissions=True)
		frappe.db.commit()

		# Повторный запуск задачи восстанавливает validate_xml из чекпоинта и доходит до конца
		success_res = durable_jobs.execute_durable_job(job_id)
		self.assertEqual(success_res["status"], "success")
		self.assertTrue(success_res.get("bom_id"))

		# Проверяем, что шаг 1 не был продублирован, а шаги 2 и 3 добавились
		completed_steps = frappe.get_all(
			"Durable Step Run",
			filters={"parent_job": job_id, "status": "Completed"},
			fields=["step_name"],
		)
		step_names = [s.step_name for s in completed_steps]
		self.assertEqual(step_names.count("validate_xml"), 1)
		self.assertIn("match_materials", step_names)
		self.assertIn("generate_bom", step_names)

	def test_02_duplicate_payment_webhook_idempotency(self):
		"""2. Дублирование вебхука эквайринга: повтор с тем же ключом идемпотентности не удваивает платеж."""
		so_id = self._create_sample_order("Chaos Payment Customer")
		idempotency_key = f"kaspi-pay-webhook-{frappe.generate_hash(length=12)}"

		# Первый вызов вебхука
		pay1 = payments.record_payment(
			sales_order=so_id,
			amount=250000.0,
			payment_type="Deposit",
			idempotency_key=idempotency_key,
			actor="PaymentWebhook",
		)
		self.assertEqual(pay1["status"], "success")
		self.assertEqual(pay1["advance_paid"], 250000.0)

		# Второй вызов вебхука с тем же ключом (сетевой повтор)
		pay2 = payments.record_payment(
			sales_order=so_id,
			amount=250000.0,
			payment_type="Deposit",
			idempotency_key=idempotency_key,
			actor="PaymentWebhook",
		)
		self.assertEqual(pay2["status"], "already_recorded")

		# Проверяем, что в Sales Order не произошло двойного начисления
		so_doc = frappe.get_doc("Sales Order", so_id)
		self.assertEqual(flt(so_doc.advance_paid), 250000.0)

	def test_03_concurrent_order_state_transition_conflict(self):
		"""3. Конкурентная смена статуса двумя менеджерами: optimistic locking отклоняет второй запрос."""
		so_id = self._create_sample_order("Chaos Concurrency Customer")

		# Начальное состояние заказа
		initial_state = order_state.get_order_state(so_id)["current_state"]
		self.assertEqual(initial_state, "Draft")

		# Клиент A переводит в 'Lead' с ожиданием 'Draft'
		res_a = order_state.transition(
			sales_order=so_id,
			target_state="Lead",
			expected_state="Draft",
			user="Administrator",
		)
		self.assertEqual(res_a["new_state"], "Lead")

		# Клиент B параллельно пытается отменить заказ, полагая, что он еще 'Draft'
		with self.assertRaises(frappe.ValidationError) as ctx:
			order_state.transition(
				sales_order=so_id,
				target_state="Cancelled",
				expected_state="Draft",
				user="Administrator",
			)
		self.assertIn("Конфликт конкурентного обновления", str(ctx.exception))

	def test_04_duplicate_job_card_completion_idempotency(self):
		"""4. Повторное нажатие кнопки завершения Job Card: возврат already_completed без двойного начисления."""
		so_id = self._create_sample_order("Chaos ShopFloor Customer")

		ws = frappe.db.get_value("Workstation", {}, "name")
		if not ws:
			ws_doc = frappe.get_doc({"doctype": "Workstation", "workstation_name": "Тестовый станок"}).insert(ignore_permissions=True)
			ws = ws_doc.name

		if not frappe.db.exists("Operation", "Раскрой на ЧПУ"):
			frappe.get_doc({"doctype": "Operation", "operation": "Раскрой на ЧПУ"}).insert(ignore_permissions=True)

		wo = frappe.get_doc(
			{
				"doctype": "Work Order",
				"production_item": "KIT-3600-MOD",
				"company": self.company,
				"qty": 1.0,
				"wip_warehouse": self.wip_warehouse,
				"fg_warehouse": self.warehouse,
				"planned_start_date": nowdate(),
			}
		)
		wo.flags.ignore_mandatory = True
		wo.insert(ignore_permissions=True)

		jc = frappe.get_doc(
			{
				"doctype": "Job Card",
				"work_order": wo.name,
				"operation": "Раскрой на ЧПУ",
				"workstation": ws,
				"company": self.company,
				"for_quantity": 10.0,
				"status": "Open",
			}
		)
		jc.insert(ignore_permissions=True)

		# Первое завершение операции
		flow1 = manufacturing_flow.complete_operation_flow(
			job_card=jc.name,
			operator="Administrator",
			employee="EMP-KITCHEN-001",
			completed_qty=10.0,
			rate_type="KZT_PER_PART",
			rate=350.0,
			company=self.company,
		)
		self.assertIn(flow1["status"], ("Completed", "completed"))
		pwe_name = flow1["piece_work_entry"]

		# Повторное завершение той же Job Card
		flow2 = manufacturing_flow.complete_operation_flow(
			job_card=jc.name,
			operator="Administrator",
			employee="EMP-KITCHEN-001",
			completed_qty=10.0,
			rate_type="KZT_PER_PART",
			rate=350.0,
			company=self.company,
		)
		self.assertEqual(flow2["status"], "already_completed")
		self.assertEqual(flow2["piece_work_entry"], pwe_name)

		# Проверяем, что в Piece Work Entry создана ровно 1 запись
		pwe_count = frappe.db.count(
			"Piece Work Entry",
			{"job_card": jc.name, "company": self.company},
		)
		self.assertEqual(pwe_count, 1)

	def test_05_outbox_retry_exhaustion_dead_letter_queue(self):
		"""5. Исчерпание попыток Outbox воркера: переход доставки в Dead Letter Queue."""
		# Регистрируем заведомо падающий обработчик события
		failing_pattern = f"chaos.fault_{frappe.generate_hash(length=6)}"
		def _always_fails_consumer(payload: dict, comp: str):
			raise RuntimeError("Simulated external API timeout / 503 Service Unavailable")

		outbox_workers.register_consumer(failing_pattern, _always_fails_consumer)

		# Записываем событие в Outbox
		evt_id = outbox.record_event(
			event_name=failing_pattern,
			aggregate_type="Sales Order",
			aggregate_id="CHAOS-ORD-001",
			payload={"data": "test"},
			company=self.company,
		)

		# Находим созданную доставку
		deliveries = frappe.get_all(
			"Domain Outbox Delivery",
			filters={"event_id": evt_id},
			fields=["name", "attempts", "max_attempts"],
		)
		self.assertGreaterEqual(len(deliveries), 1)
		deliv_name = deliveries[0].name

		# Устанавливаем max_attempts = 3
		frappe.db.set_value(
			"Domain Outbox Delivery",
			deliv_name,
			{"max_attempts": 3, "attempts": 0},
			update_modified=False,
		)
		frappe.db.commit()

		# Попытка 1: Ошибка
		outbox.mark_delivery_failure(deliv_name, "Error 1")
		st1 = frappe.db.get_value("Domain Outbox Delivery", deliv_name, "status")
		self.assertEqual(st1, "Failed")

		# Попытка 2: Ошибка
		outbox.mark_delivery_failure(deliv_name, "Error 2")
		st2 = frappe.db.get_value("Domain Outbox Delivery", deliv_name, "status")
		self.assertEqual(st2, "Failed")

		# Попытка 3: Исчерпание попыток -> Переход в Dead Letter
		status_3, _ = outbox.mark_delivery_failure(deliv_name, "Error 3 (Final)")
		self.assertEqual(status_3, "Dead Letter")

		final_deliv = frappe.get_doc("Domain Outbox Delivery", deliv_name)
		self.assertEqual(final_deliv.status, "Dead Letter")
		self.assertEqual(final_deliv.attempts, 3)
		self.assertIn("Error 3", final_deliv.error_message)
