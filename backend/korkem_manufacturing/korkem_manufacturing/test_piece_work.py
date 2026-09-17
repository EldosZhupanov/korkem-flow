# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Unit and integration tests for Piece-rate Payroll Domain Service."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import setup
from korkem_manufacturing.services import piece_work
from korkem_manufacturing.services.scope import current_company


class TestPieceWork(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		setup.provision()

	def setUp(self):
		frappe.set_user("Administrator")
		self.company = current_company()
		frappe.defaults.set_user_default("Company", self.company)
		self.employee = "EMP-TEST-001"
		self.employee_name = "Айбек Сейткалиев"

	def tearDown(self):
		frappe.defaults.set_user_default("Company", self.company)
		frappe.db.rollback()

	def test_rate_types_and_amount_calculations(self):
		"""Проверка всех четырех типов тарифов и корректности расчета начислений."""
		# 1. KZT_PER_PART: 50 деталей по 120 KZT = 6000 KZT
		e1 = piece_work.record_piece_work(
			company=self.company,
			employee=self.employee,
			employee_name=self.employee_name,
			operation="Присадка отверстий",
			rate_type="KZT_PER_PART",
			quantity=50.0,
			rate=120.0,
			unit="pcs",
		)
		self.assertEqual(e1.amount, 6000.0)
		self.assertEqual(e1.status, "Pending Approval")

		# 2. KZT_PER_M2: 12.5 м2 по 800 KZT = 10000 KZT
		e2 = piece_work.record_piece_work(
			company=self.company,
			employee=self.employee,
			employee_name=self.employee_name,
			operation="Раскрой на ЧПУ",
			rate_type="KZT_PER_M2",
			quantity=12.5,
			rate=800.0,
			unit="m2",
		)
		self.assertEqual(e2.amount, 10000.0)

		# 3. KZT_PER_METER: 40 м по 150 KZT = 6000 KZT
		e3 = piece_work.record_piece_work(
			company=self.company,
			employee=self.employee,
			employee_name=self.employee_name,
			operation="Кромкооблицовка 2мм",
			rate_type="KZT_PER_METER",
			quantity=40.0,
			rate=150.0,
			unit="m",
		)
		self.assertEqual(e3.amount, 6000.0)

		# 4. FIXED_PER_OPERATION: 1 операция по 3500 KZT = 3500 KZT
		e4 = piece_work.record_piece_work(
			company=self.company,
			employee=self.employee,
			employee_name=self.employee_name,
			operation="Контрольная сборка тумбы",
			rate_type="FIXED_PER_OPERATION",
			quantity=1.0,
			rate=3500.0,
			unit="op",
		)
		self.assertEqual(e4.amount, 3500.0)

	def test_invalid_rate_type_rejected(self):
		"""Недопустимый тип тарифа отклоняется валидацией."""
		with self.assertRaises(frappe.ValidationError):
			piece_work.record_piece_work(
				company=self.company,
				employee=self.employee,
				operation="Сборка",
				rate_type="UNKNOWN_RATE_TYPE",
				quantity=1.0,
				rate=1000.0,
			)

	def test_idempotency_key_prevents_duplicate_payout(self):
		"""Повторное завершение JobCard с тем же ключом идемпотентности не дублирует оплату."""
		idem_key = f"jobcard-complete-{frappe.generate_hash(length=10)}"
		e1 = piece_work.record_piece_work(
			company=self.company,
			employee=self.employee,
			operation="Раскрой",
			rate_type="KZT_PER_M2",
			quantity=10.0,
			rate=500.0,
			idempotency_key=idem_key,
		)
		e2 = piece_work.record_piece_work(
			company=self.company,
			employee=self.employee,
			operation="Раскрой",
			rate_type="KZT_PER_M2",
			quantity=10.0,
			rate=500.0,
			idempotency_key=idem_key,
		)
		self.assertEqual(e1.name, e2.name)

	def test_approval_and_payment_workflow(self):
		"""Одобрение руководителем (Human Gate) и последующая выплата."""
		entry = piece_work.record_piece_work(
			company=self.company,
			employee=self.employee,
			operation="Фрезеровка фасадов",
			rate_type="KZT_PER_M2",
			quantity=8.0,
			rate=1200.0,
		)
		self.assertEqual(entry.status, "Pending Approval")

		# Нельзя оплатить не утвержденную
		with self.assertRaises(frappe.ValidationError):
			piece_work.mark_paid(entry.name)

		# Утверждаем
		appr = piece_work.approve_piece_work(entry.name, approved_by="supervisor@korkem.kz")
		self.assertEqual(appr.status, "Approved")
		self.assertEqual(appr.approved_by, "supervisor@korkem.kz")
		self.assertIsNotNone(appr.approved_at)

		# Выплачиваем
		paid = piece_work.mark_paid(entry.name)
		self.assertEqual(paid.status, "Paid")

	def test_financial_immutability_and_delete_blocked(self):
		"""После утверждения запись защищена от изменения суммы и физического удаления."""
		entry = piece_work.record_piece_work(
			company=self.company,
			employee=self.employee,
			operation="Кромка",
			rate_type="KZT_PER_METER",
			quantity=20.0,
			rate=100.0,
		)
		piece_work.approve_piece_work(entry.name)

		# Попытка изменить количество/сумму
		entry_doc = frappe.get_doc("Piece Work Entry", entry.name)
		entry_doc.quantity = 50.0
		entry_doc.amount = 5000.0
		with self.assertRaises(frappe.ValidationError):
			entry_doc.save()

		# Попытка удалить
		with self.assertRaises(frappe.PermissionError):
			entry_doc.delete()

	def test_reversal_creates_compensating_negative_entry(self):
		"""Сторнирование создает зеркальную отрицательную запись и отменяет начисление."""
		entry = piece_work.record_piece_work(
			company=self.company,
			employee=self.employee,
			operation="Бракованная сборка",
			rate_type="FIXED_PER_OPERATION",
			quantity=1.0,
			rate=4000.0,
		)
		piece_work.approve_piece_work(entry.name)

		# Сторнируем
		comp = piece_work.reverse_piece_work(
			entry.name,
			reason="Брак детали, переделка сборки",
			actor="qa_manager@korkem.kz",
		)
		self.assertEqual(comp.status, "Reversed")
		self.assertEqual(comp.quantity, -1.0)
		self.assertEqual(comp.amount, -4000.0)
		self.assertEqual(comp.reversed_entry, entry.name)

		# Исходная запись помечена как Reversed
		orig_doc = frappe.get_doc("Piece Work Entry", entry.name)
		self.assertEqual(orig_doc.status, "Reversed")

	def test_employee_payroll_summary(self):
		"""Сводка начислений по сотруднику агрегирует суммы по статусам."""
		emp_id = f"EMP-SUMM-{frappe.generate_hash(length=4)}"

		# 1 pending: 2000
		piece_work.record_piece_work(
			company=self.company,
			employee=emp_id,
			operation="Оп 1",
			rate_type="FIXED_PER_OPERATION",
			quantity=1.0,
			rate=2000.0,
		)
		# 1 approved: 3000
		e2 = piece_work.record_piece_work(
			company=self.company,
			employee=emp_id,
			operation="Оп 2",
			rate_type="FIXED_PER_OPERATION",
			quantity=1.0,
			rate=3000.0,
		)
		piece_work.approve_piece_work(e2.name)

		# 1 paid: 5000
		e3 = piece_work.record_piece_work(
			company=self.company,
			employee=emp_id,
			operation="Оп 3",
			rate_type="FIXED_PER_OPERATION",
			quantity=1.0,
			rate=5000.0,
		)
		piece_work.approve_piece_work(e3.name)
		piece_work.mark_paid(e3.name)

		summary = piece_work.get_employee_payroll_summary(self.company, emp_id)
		self.assertEqual(summary["Pending Approval"], 2000.0)
		self.assertEqual(summary["Approved"], 3000.0)
		self.assertEqual(summary["Paid"], 5000.0)
		self.assertEqual(summary["total_earned"], 8000.0)  # Approved + Paid
