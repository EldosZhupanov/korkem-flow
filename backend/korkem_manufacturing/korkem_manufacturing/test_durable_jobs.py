# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Unit and integration tests for Durable Background Jobs and Step Checkpointing."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_to_date, now_datetime

from korkem_manufacturing import setup
from korkem_manufacturing.services import durable_jobs
from korkem_manufacturing.services.scope import current_company


class TestDurableJobs(IntegrationTestCase):
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

	def test_step_checkpointing_and_crash_recovery(self):
		"""При сбое на шаге N повторный запуск восстанавливает шаги 1..N-1 без их повторного исполнения."""
		execution_counts = {"step_1": 0, "step_2": 0, "step_3": 0}

		def crash_prone_job(ctx: durable_jobs.DurableJobContext):
			def _step1():
				execution_counts["step_1"] += 1
				return {"parsed_panels": 12}

			p1 = ctx.step("parse_geometry", _step1)

			def _step2():
				execution_counts["step_2"] += 1
				return {"materials_matched": 4}

			p2 = ctx.step("resolve_materials", _step2)

			def _step3():
				execution_counts["step_3"] += 1
				if ctx.job_doc.attempt == 1:
					# Имитируем падение (OOM / Crash) на первой попытке
					raise RuntimeError("Simulated OOM crash during BOM generation")
				return {"bom_id": "BOM-SUCCESS-001"}

			p3 = ctx.step("generate_bom", _step3)
			return {"panels": p1["parsed_panels"], "bom": p3["bom_id"]}

		# Регистрируем тестовый тип задачи
		job_type = f"test.crash_recovery_{frappe.generate_hash(length=6)}"
		durable_jobs.register_durable_job(job_type, crash_prone_job)

		# 1. Первая попытка — должна упасть на шаге 3
		job_name = durable_jobs.submit_durable_job(
			job_type=job_type,
			payload={"file": "test.xml"},
			company=self.company,
		)

		with self.assertRaises(RuntimeError):
			durable_jobs.execute_durable_job(job_name, worker_id="worker-1")

		self.assertEqual(execution_counts["step_1"], 1)
		self.assertEqual(execution_counts["step_2"], 1)
		self.assertEqual(execution_counts["step_3"], 1)

		# Проверяем, что в БД зафиксированы чекпоинты шагов 1 и 2 в статусе Completed
		s1 = frappe.db.get_value(
			"Durable Step Run",
			{"parent_job": job_name, "step_name": "parse_geometry"},
			"status",
		)
		s2 = frappe.db.get_value(
			"Durable Step Run",
			{"parent_job": job_name, "step_name": "resolve_materials"},
			"status",
		)
		self.assertEqual(s1, "Completed")
		self.assertEqual(s2, "Completed")

		# 2. Вторая попытка (восстановление после сбоя)
		# Шаг 1 и Шаг 2 НЕ ДОЛЖНЫ выполняться повторно!
		result = durable_jobs.execute_durable_job(job_name, worker_id="worker-2")

		# Счетчики шагов 1 и 2 не увеличились!
		self.assertEqual(execution_counts["step_1"], 1, "Шаг 1 был повторно исполнен вместо загрузки из чекпоинта!")
		self.assertEqual(execution_counts["step_2"], 1, "Шаг 2 был повторно исполнен вместо загрузки из чекпоинта!")
		self.assertEqual(execution_counts["step_3"], 2, "Шаг 3 должен был повторно выполниться на 2-й попытке!")

		self.assertEqual(result["bom"], "BOM-SUCCESS-001")
		job_status = frappe.db.get_value("Durable Job Run", job_name, "status")
		self.assertEqual(job_status, "Completed")

	def test_idempotency_prevents_duplicate_job_submission(self):
		"""Повторная отправка с тем же ключом идемпотентности возвращает существующую задачу."""
		idem_key = f"idem-job-{frappe.generate_hash(length=8)}"
		j1 = durable_jobs.submit_durable_job(
			job_type="bazis.import_xml",
			payload={"xml": "<test/>"},
			company=self.company,
			idempotency_key=idem_key,
		)
		j2 = durable_jobs.submit_durable_job(
			job_type="bazis.import_xml",
			payload={"xml": "<test/>"},
			company=self.company,
			idempotency_key=idem_key,
		)
		self.assertEqual(j1, j2)

	def test_worker_leasing_prevents_concurrent_execution(self):
		"""Воркер Б не может захватить задачу, пока лизинг удерживается воркером А."""
		job_type = f"test.lease_{frappe.generate_hash(length=6)}"
		durable_jobs.register_durable_job(job_type, lambda ctx: {"ok": 1})

		job_name = durable_jobs.submit_durable_job(
			job_type=job_type,
			payload={},
			company=self.company,
		)

		# Имитируем, что воркер-1 держит лизинг
		frappe.db.set_value(
			"Durable Job Run",
			job_name,
			{
				"status": "Running",
				"lease_token": "worker-1",
				"lease_expires_at": add_to_date(now_datetime(), minutes=5),
			},
			update_modified=True,
		)
		frappe.db.commit()

		# Воркер-2 пытается выполнить эту задачу
		with self.assertRaises(frappe.ValidationError) as ctx:
			durable_jobs.execute_durable_job(job_name, worker_id="worker-2")
		self.assertIn("уже исполняется воркером worker-1", str(ctx.exception))

	def test_retry_exhaustion_transitions_to_dead_letter(self):
		"""При исчерпании всех попыток (max_attempts) задача переходит в Dead Letter Queue (DLQ)."""
		job_type = f"test.fail_{frappe.generate_hash(length=6)}"

		def failing_job(ctx):
			raise ValueError("Persistent unrecoverable defect")

		durable_jobs.register_durable_job(job_type, failing_job)

		job_name = durable_jobs.submit_durable_job(
			job_type=job_type,
			payload={},
			company=self.company,
		)

		# Задаем 4 совершенные попытки при максимуме 5
		frappe.db.set_value("Durable Job Run", job_name, {"attempt": 4, "max_attempts": 5}, update_modified=True)
		frappe.db.commit()

		with self.assertRaises(ValueError):
			durable_jobs.execute_durable_job(job_name)

		status = frappe.db.get_value("Durable Job Run", job_name, "status")
		self.assertEqual(status, "Dead Letter")

	def test_bazis_import_xml_durable_workflow(self):
		"""Встроенная долговечная задача импорта БАЗИС XML отрабатывает все 4 чекпоинта."""
		xml_data = "<Файл><Изделие Название='Кухня Модерн'/></Файл>"
		job_name = durable_jobs.submit_durable_job(
			job_type="bazis.import_xml",
			payload={"xml_content": xml_data, "sales_order": "SO-TEST-BAZIS-01"},
			company=self.company,
		)

		res = durable_jobs.execute_durable_job(job_name)
		self.assertEqual(res["status"], "success")
		self.assertEqual(res["job_cards_created"], 3)

		# Все 4 шага зафиксированы в tabDurable Step Run
		steps = frappe.db.get_all(
			"Durable Step Run",
			filters={"parent_job": job_name, "status": "Completed"},
			pluck="step_name",
		)
		self.assertIn("validate_xml", steps)
		self.assertIn("match_materials", steps)
		self.assertIn("generate_bom", steps)
		self.assertIn("create_job_cards", steps)
