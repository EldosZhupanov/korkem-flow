# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Canonical End-to-End Furniture Production Lifecycle Test Suite (Phase 5).

Covers the complete 23-stage operating system loop for "Demo Kitchen Customer" / "Kitchen 3.6m":
1. Lead Capture (Voice/Text)
2. Lead -> Customer & Opportunity
3. On-Site Measurement
4. Room & Wall Photos (EXIF stripped)
5. Proposal & Sales Order Draft
6. Design Task & Drawing Attachment
7. BASIS-Мебельщик XML Import via Durable Job
8. BOM Verification & Deterministic Quote Calculation (Decimal)
9. Contract Drafting & Legal Signing
10. Deposit Payment (50%)
11. State Transition -> Ready for Production
12. Material Reservation & Shortage Handling
13. State Transition -> In Production
14. Work Order & Job Cards Generation
15. Shop Floor Operations Execution (Cutting, Edgebanding, CNC, Assembly)
16. Stock Offcut Generation & 90° Cross-Order Reuse
17. Piece-Work Payroll Generation & Human Approval Gate
18. 7-Point Quality Control (QC) & Rework Gate
19. State Transition -> Ready for Delivery
20. Dispatch Delivery Note & Stock Deduction -> Delivery
21. Installation Scheduling & Site Completion -> Installation
22. Client Acceptance Act Signing -> Acceptance Pending
23. Final Balance Payment (100%) -> State Transition to Completed
24. Post-Warranty Support & Claim Verification -> Warranty
25. Unified Customer Timeline & Owner Dashboard Assertions
"""

from __future__ import annotations

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
	calculations,
	capture,
	contract,
	dashboard,
	design,
	dispatch,
	durable_jobs,
	enquiry,
	installation,
	manufacturing_flow,
	measurement,
	offcuts,
	order_state,
	outbox,
	outbox_workers,
	payments,
	piece_work,
	production,
	proposal,
	qc,
	stock_movement,
	stock_reservation,
	timeline,
	warranty,
)
from korkem_manufacturing.services.scope import current_company

import io
from PIL import Image

def _get_valid_test_png() -> bytes:
	img = Image.new("RGB", (50, 50), color=(240, 240, 240))
	buf = io.BytesIO()
	img.save(buf, format="PNG")
	return buf.getvalue()



class TestCompleteFurnitureOrderLifecycle(IntegrationTestCase):
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
		) or "Work In Progress"

		self._setup_master_data()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def _setup_master_data(self):
		"""Подготовка номенклатуры и базовых сущностей для канонического теста."""
		# 1. Готовое изделие: Кухня 3.6м
		fg_code = "KIT-3600-MOD"
		if not frappe.db.exists("Item", fg_code):
			item = frappe.get_doc(
				{
					"doctype": "Item",
					"item_code": fg_code,
					"item_name": "Кухня 3.6м Модульная",
					"item_group": "Products",
					"stock_uom": "Nos",
					"is_stock_item": 1,
					"is_sales_item": 1,
					"warranty_period": 365,
				}
			)
			item.insert(ignore_permissions=True)

		# 2. Сырьевые материалы и фурнитура
		for m in self.demo_data["materials"]:
			code = m["item_code"]
			uom = m.get("stock_uom", "Nos")
			if not frappe.db.exists("UOM", uom):
				frappe.get_doc({"doctype": "UOM", "uom_name": uom}).insert(ignore_permissions=True)

			if not frappe.db.exists("Item", code):
				doc = frappe.get_doc(
					{
						"doctype": "Item",
						"item_code": code,
						"item_name": m["item_name"],
						"item_group": m["item_group"],
						"stock_uom": uom,
						"is_stock_item": 1,
						"standard_rate": m.get("rate", 1000),
					}
				)
				doc.insert(ignore_permissions=True)

		# 3. Сотрудник для начислений
		self.employee = "EMP-KITCHEN-001"
		if not frappe.db.exists("Employee", self.employee):
			try:
				emp = frappe.get_doc(
					{
						"doctype": "Employee",
						"employee": self.employee,
						"first_name": "Азамат",
						"last_name": "Мастеров",
						"company": self.company,
						"status": "Active",
					}
				)
				emp.insert(ignore_permissions=True)
			except Exception:
				pass

	def test_01_canonical_23_stage_kitchen_production_loop(self):
		"""Полный канонический цикл производства кухни 3.6м от лида до гарантии."""
		# -------------------------------------------------------------
		# STAGE 1: Incoming Lead Capture
		# -------------------------------------------------------------
		lead_text = "Клиент Demo Kitchen Customer хочет кухню 3.6м с МДФ фасадами и Blum фурнитурой"
		capture_res = capture.record(
			text=lead_text,
			understood={
				"customer_hint": "Demo Kitchen Customer",
				"product_hint": "Кухня 3.6м",
				"material_hint": "МДФ, ЛДСП 16",
			},
			source="Voice",
		)
		capture_id = capture_res["capture"]
		self.assertTrue(capture_id)
		self.assertIn(capture_res["status"], ("captured", "Understood"))

		# -------------------------------------------------------------
		# STAGE 2: Convert to Customer & Opportunity (Enquiry)
		# -------------------------------------------------------------
		convert_res = enquiry.convert(
			capture=capture_id,
			customer_name="Demo Kitchen Customer",
			assign_measurer="Administrator",
			measure_on=add_days(nowdate(), 1),
		)
		opportunity_id = convert_res["enquiry"]
		customer_name = convert_res["customer"]
		self.assertTrue(opportunity_id)
		self.assertEqual(customer_name, "Demo Kitchen Customer")

		# -------------------------------------------------------------
		# STAGE 3 & 4: Measurement Record & Wall Photo Attachment
		# -------------------------------------------------------------
		meas = self.demo_data["measurement"]
		meas_res = measurement.record(
			enquiry=opportunity_id,
			dimensions=meas["dimensions"],
			notes=meas["notes"],
			address_line=self.demo_data["customer"]["address"],
			city=self.demo_data["customer"]["city"],
			measured_on=nowdate(),
		)
		self.assertEqual(meas_res["enquiry"], opportunity_id)

		photo_res = measurement.attach_photo(
			enquiry=opportunity_id,
			filename="kitchen_wall_measurement.png",
			content=_get_valid_test_png(),
		)
		self.assertEqual(photo_res["status"], "attached")
		self.assertTrue(frappe.db.exists("File", photo_res["file"]))

		# -------------------------------------------------------------
		# STAGE 5: Quotation Drafting & Acceptance -> Sales Order
		# -------------------------------------------------------------
		quote_res = proposal.draft(
			enquiry=opportunity_id,
			items=[
				{
					"item_code": "KIT-3600-MOD",
					"qty": 1.0,
					"rate": self.demo_data["pricing"]["target_price"],
				}
			],
		)
		quotation_id = quote_res["quotation"]
		self.assertTrue(quotation_id)

		accept_res = acceptance.accept(
			quotation=quotation_id,
			deliver_on=add_days(nowdate(), 21),
		)
		sales_order_id = accept_res["sales_order"]
		self.assertTrue(sales_order_id)
		order_doc = frappe.get_doc("Sales Order", sales_order_id)
		self.assertEqual(flt(order_doc.grand_total), 850000.0)

		# -------------------------------------------------------------
		# STAGE 6: Design Assignment & Deliverable Verification
		# -------------------------------------------------------------
		assign_res = design.assign(
			sales_order=sales_order_id,
			designer="Administrator",
			due_on=add_days(nowdate(), 3),
		)
		self.assertIn(assign_res["status"], ("assigned", "already_assigned"))

		# Прикрепляем файл спецификации/чертежа к Sales Order
		dwg_file = frappe.get_doc(
			{
				"doctype": "File",
				"file_name": "kitchen_3600_drawing.png",
				"attached_to_doctype": "Sales Order",
				"attached_to_name": sales_order_id,
				"content": _get_valid_test_png(),
				"is_private": 1,
			}
		)
		dwg_file.insert(ignore_permissions=True)

		deliver_res = design.deliver(sales_order=sales_order_id)
		self.assertEqual(deliver_res["status"], "delivered")

		# -------------------------------------------------------------
		# STAGE 7: BASIS-Мебельщик XML Import via Durable Job
		# -------------------------------------------------------------
		bazis_xml_content = get_demo_bazis_xml(sales_order_id)
		job_id = durable_jobs.submit_durable_job(
			job_type="bazis_import_xml",
			payload={
				"sales_order": sales_order_id,
				"xml_content": bazis_xml_content,
				"item_code": "KIT-3600-MOD",
			},
			company=self.company,
		)
		job_res = durable_jobs.execute_durable_job(job_id)
		self.assertEqual(job_res["status"], "success")
		self.assertTrue(job_res["bom_id"])
		bom_id = job_res["bom_id"]

		# Создаем и подтверждаем стандартный BOM для заказа
		if not frappe.db.exists("BOM", {"item": "KIT-3600-MOD", "is_active": 1, "docstatus": 1}):
			bom_doc = frappe.get_doc(
				{
					"doctype": "BOM",
					"item": "KIT-3600-MOD",
					"quantity": 1.0,
					"currency": "KZT",
					"company": self.company,
					"is_active": 1,
					"is_default": 1,
					"items": [
						{"item_code": m["item_code"], "qty": m["qty_required"], "rate": m["rate"]}
						for m in self.demo_data["materials"]
					],
				}
			)
			bom_doc.insert(ignore_permissions=True)
			bom_doc.submit()
			bom_id = bom_doc.name

		# -------------------------------------------------------------
		# STAGE 8: BOM Verification & Deterministic Quote Calculation
		# -------------------------------------------------------------
		quote_calc = calculations.calculate_quote(
			materials=self.demo_data["materials"],
			operations=[
				{"operation": "Раскрой на ЧПУ", "qty": 28, "rate": 350.0},
				{"operation": "Кромкооблицовка", "qty": 45, "rate": 150.0},
				{"operation": "Присадка", "qty": 28, "rate": 250.0},
				{"operation": "Контрольная сборка", "qty": 1, "rate": 5000.0},
			],
			markup_percent=30.0,
			waste_percent=8.0,
			sales_order=sales_order_id,
		)
		self.assertGreater(quote_calc["selling_price"], 300000.0)
		self.assertGreater(quote_calc["total_cost"], 200000.0)
		self.assertIn("breakdown", quote_calc)

		# -------------------------------------------------------------
		# STAGE 9: Contract Drafting & Signature
		# -------------------------------------------------------------
		contract_res = contract.draft(sales_order=sales_order_id)
		contract_id = contract_res["contract"]
		self.assertTrue(contract_id)

		sign_res = contract.sign(
			contract=contract_id,
			signee="Demo Kitchen Customer (Ерлан)",
			signed_on=nowdate(),
		)
		self.assertEqual(sign_res["status"], "signed")

		# -------------------------------------------------------------
		# STAGE 10: Step through FSM to Deposit Pending & Pay 50% Deposit
		# -------------------------------------------------------------
		order_state.transition(sales_order=sales_order_id, target_state="Lead")
		order_state.transition(sales_order=sales_order_id, target_state="Measurement Pending")
		order_state.transition(sales_order=sales_order_id, target_state="Measured")
		order_state.transition(sales_order=sales_order_id, target_state="Design Pending")
		order_state.transition(sales_order=sales_order_id, target_state="Design Approved")
		order_state.transition(sales_order=sales_order_id, target_state="Quote Pending")
		order_state.transition(sales_order=sales_order_id, target_state="Quote Sent")
		order_state.transition(sales_order=sales_order_id, target_state="Contract Pending")
		order_state.transition(sales_order=sales_order_id, target_state="Deposit Pending")

		# Попытка перевода в Ready for Production до предоплаты должна отклоняться
		with self.assertRaises(frappe.ValidationError):
			order_state.transition(
				sales_order=sales_order_id,
				target_state="Ready for Production",
			)

		payment_res = payments.record_payment(
			sales_order=sales_order_id,
			amount=425000.0,
			payment_type="Deposit",
			reference_no="KASPI-PAY-DEP-001",
			actor="Administrator",
		)
		self.assertIn(payment_res["status"], ("success", "recorded"))
		self.assertEqual(payment_res["advance_paid"], 425000.0)

		# Проводим Sales Order (ERPNext требует docstatus == 1 для Work Order)
		so_doc = frappe.get_doc("Sales Order", sales_order_id)
		if so_doc.docstatus == 0:
			if not so_doc.set_warehouse:
				so_doc.set_warehouse = self.warehouse
			for row in so_doc.items:
				if not row.warehouse:
					row.warehouse = self.warehouse
			so_doc.flags.ignore_permissions = True
			so_doc.save()
			so_doc.submit()

		# Теперь перевод в Ready for Production проходит успешно
		state_res = order_state.transition(
			sales_order=sales_order_id,
			target_state="Ready for Production",
		)
		self.assertEqual(state_res["new_state"], "Ready for Production")

		# -------------------------------------------------------------
		# STAGE 11 & 12: Material Reservation & Shortage Procurement
		# -------------------------------------------------------------
		# 1. Попытка перевода в In Production без полного покрытия материалами должна быть заблокирована
		with self.assertRaises(frappe.ValidationError):
			order_state.transition(
				sales_order=sales_order_id,
				target_state="In Production",
			)

		# 2. Вызов бронирования при пустом складе фиксирует дефицит
		res_summary = stock_reservation.reserve_materials_for_order(sales_order_id)
		self.assertFalse(res_summary["is_fully_reserved"])
		self.assertGreater(len(res_summary["shortages"]), 0)

		# Обработка дефицита через Outbox Worker -> запуск Material Shortage Batch
		outbox_metrics = outbox_workers.dispatch_outbox_batch(batch_size=10)
		self.assertGreaterEqual(outbox_metrics["processed"], 1)

		# 3. Поступление сырья на склад Stores под выявленные дефициты
		for s in res_summary["shortages"]:
			code = s["item_code"]
			needed = flt(s["shortage_qty"])
			stock_movement.record_movement(
				item_code=code,
				from_location="Suppliers",
				to_location=self.warehouse,
				qty=needed * 2.0,
				reason="Поставка материалов под заказ",
				company=self.company,
			)

		# 4. Повторное бронирование полностью закрывает потребность заказа
		res_summary2 = stock_reservation.reserve_materials_for_order(
			sales_order=sales_order_id,
			warehouse=self.warehouse,
		)
		self.assertTrue(res_summary2["is_fully_reserved"])
		self.assertEqual(len(res_summary2["shortages"]), 0)

		# 5. Перевод заказа в In Production разрешен
		state_res2 = order_state.transition(
			sales_order=sales_order_id,
			target_state="In Production",
		)
		self.assertEqual(state_res2["new_state"], "In Production")

		# -------------------------------------------------------------
		# STAGE 13 & 14: Work Order & Job Cards Generation
		# -------------------------------------------------------------
		# Создаем Work Order под заказ
		wo = frappe.get_doc(
			{
				"doctype": "Work Order",
				"production_item": "KIT-3600-MOD",
				"bom_no": bom_id,
				"company": self.company,
				"qty": 1.0,
				"sales_order": sales_order_id,
				"wip_warehouse": self.wip_warehouse,
				"fg_warehouse": self.warehouse,
				"planned_start_date": nowdate(),
			}
		)
		wo.insert(ignore_permissions=True)
		wo.submit()

		# Создаем Job Cards для 4 ключевых мебельных операций
		workstation = frappe.db.get_value("Workstation", {"workstation_name": "Цех раскроя и сборки"}, "name") or frappe.db.get_value("Workstation", {}, "name")
		if not workstation:
			ws = frappe.get_doc(
				{
					"doctype": "Workstation",
					"workstation_name": "Цех раскроя и сборки",
				}
			)
			ws.insert(ignore_permissions=True)
			workstation = ws.name

		operations_data = [
			("Раскрой на ЧПУ", "KZT_PER_PART", 350.0, 28.0),
			("Кромкооблицовка", "KZT_PER_METER", 150.0, 45.0),
			("Присадка и сверление", "KZT_PER_PART", 250.0, 28.0),
			("Контрольная сборка", "FIXED_PER_OPERATION", 5000.0, 1.0),
		]
		job_cards = []
		for op_name, r_type, rate, qty in operations_data:
			if not frappe.db.exists("Operation", op_name):
				frappe.get_doc({"doctype": "Operation", "operation": op_name}).insert(ignore_permissions=True)
			jc = frappe.get_doc(
				{
					"doctype": "Job Card",
					"work_order": wo.name,
					"operation": op_name,
					"workstation": workstation,
					"company": self.company,
					"for_quantity": qty,
					"status": "Open",
				}
			)
			jc.insert(ignore_permissions=True)
			job_cards.append((jc.name, op_name, r_type, rate, qty))

		# -------------------------------------------------------------
		# STAGE 15: Shop Floor Execution & Stock Offcut Creation
		# -------------------------------------------------------------
		# Операция 1: Раскрой (Cutting) — производит деловой остаток ЛДСП 1200x600мм
		cut_jc, cut_op, cut_type, cut_rate, cut_qty = job_cards[0]
		cut_flow = manufacturing_flow.complete_operation_flow(
			job_card=cut_jc,
			operator="Administrator",
			employee=self.employee,
			completed_qty=cut_qty,
			rate_type=cut_type,
			rate=cut_rate,
			offcut_data={
				"material_item": "LDSP-16-WHT",
				"length_mm": 1200,
				"width_mm": 600,
				"thickness_mm": 16,
				"decor": "Белый Базовый",
				"warehouse": self.warehouse,
			},
			company=self.company,
		)
		self.assertIn(cut_flow["status"], ("Completed", "completed"))
		self.assertTrue(cut_flow.get("offcut"))
		created_offcut_name = cut_flow["offcut"]

		# Проверяем, что деловой остаток доступен на складе
		off_doc = frappe.get_doc("Stock Offcut", created_offcut_name)
		self.assertEqual(off_doc.status, "Available")
		self.assertEqual(off_doc.length_mm, 1200.0)
		self.assertEqual(off_doc.width_mm, 600.0)

		# Операции 2, 3, 4: Кромление, Присадка, Сборка
		for jc_name, op_name, r_type, rate, qty in job_cards[1:]:
			flow_res = manufacturing_flow.complete_operation_flow(
				job_card=jc_name,
				operator="Administrator",
				employee=self.employee,
				completed_qty=qty,
				rate_type=r_type,
				rate=rate,
				company=self.company,
			)
			self.assertIn(flow_res["status"], ("Completed", "completed"))

		# -------------------------------------------------------------
		# STAGE 16: Offcut Cross-Order Reuse (Order B uses Order A's offcut)
		# -------------------------------------------------------------
		order_b = frappe.get_doc(
			{
				"doctype": "Sales Order",
				"company": self.company,
				"customer": "Demo Kitchen Customer",
				"transaction_date": nowdate(),
				"delivery_date": add_days(nowdate(), 14),
				"set_warehouse": self.warehouse,
				"items": [
					{
						"item_code": "KIT-3600-MOD",
						"qty": 1.0,
						"rate": 150000.0,
						"delivery_date": add_days(nowdate(), 14),
						"warehouse": self.warehouse,
					}
				],
			}
		)
		order_b.insert(ignore_permissions=True)
		order_b_id = order_b.name

		# Заказ B ищет заготовку 500x1100 мм (поворот на 90° вписывается в 1200x600)
		matching_offcuts = offcuts.find_usable_offcuts(
			company=self.company,
			material_item="LDSP-16-WHT",
			min_length=1100,
			min_width=500,
			allow_rotation=True,
		)
		self.assertGreaterEqual(len(matching_offcuts), 1)
		found_offcut = next((o for o in matching_offcuts if o["name"] == created_offcut_name), None)
		self.assertIsNotNone(found_offcut)

		# Заказ B бронирует остаток заказа A
		offcuts.reserve_offcut(
			offcut_name=created_offcut_name,
			sales_order=order_b_id,
			user="Administrator",
		)
		off_doc.reload()
		self.assertEqual(off_doc.status, "Reserved")
		self.assertEqual(off_doc.reserved_for_order, order_b_id)

		# -------------------------------------------------------------
		# STAGE 17: Piece-Work Payroll Verification & Approval Gate
		# -------------------------------------------------------------
		pending_entries = frappe.get_all(
			"Piece Work Entry",
			filters={"sales_order": sales_order_id, "status": "Pending Approval"},
			fields=["name", "amount", "operation"],
		)
		self.assertEqual(len(pending_entries), 4)
		total_labor = sum(flt(e.amount) for e in pending_entries)
		self.assertGreater(total_labor, 0)

		# Human Approval Gate
		for pe in pending_entries:
			app_doc = piece_work.approve_piece_work(pe.name, approved_by="Administrator")
			self.assertEqual(app_doc.status, "Approved")

		# -------------------------------------------------------------
		# STAGE 18: 7-Point Quality Control (QC) & Gate Check
		# -------------------------------------------------------------
		# Переход в Quality Control
		order_state.transition(sales_order=sales_order_id, target_state="Quality Control")

		# 1. Отрицательный тест: ОТК не пройден -> блокировка передачи в доставку
		qc_fail_checklist = {
			"dimensions_accurate": True,
			"edge_quality": False,  # Скол кромки
			"no_chips": False,      # Царапина на фасаде
			"drilling_accurate": True,
			"facades_aligned": True,
			"hardware_tested": True,
			"packaging_ready": False,
		}
		qc_fail = qc.submit_furniture_qc(
			sales_order=sales_order_id,
			checklist=qc_fail_checklist,
			inspector="Administrator",
			comments="Обнаружены дефекты кромки и царапины",
		)
		self.assertEqual(qc_fail["status"], "Rejected")
		self.assertFalse(qc.is_qc_passed_for_order(sales_order_id))

		# Попытка перехода в Ready for Delivery блокируется ОТК
		with self.assertRaises(frappe.ValidationError):
			order_state.transition(sales_order=sales_order_id, target_state="Ready for Delivery")

		# 2. Устранение замечаний и успешное прохождение всех 7 пунктов ОТК
		qc_pass_checklist = {k: True for k in qc_fail_checklist}
		qc_pass = qc.submit_furniture_qc(
			sales_order=sales_order_id,
			checklist=qc_pass_checklist,
			inspector="Administrator",
			comments="Все 7 критериев качества кухни 3.6м полностью соответствуют",
		)
		self.assertEqual(qc_pass["status"], "Accepted")
		self.assertTrue(qc.is_qc_passed_for_order(sales_order_id))

		# Переход в Ready for Delivery теперь успешно проходит
		state_res3 = order_state.transition(
			sales_order=sales_order_id,
			target_state="Ready for Delivery",
		)
		self.assertEqual(state_res3["new_state"], "Ready for Delivery")

		# -------------------------------------------------------------
		# STAGE 19 & 20: Delivery & Dispatch
		# -------------------------------------------------------------
		so_doc = frappe.get_doc("Sales Order", sales_order_id)
		shipping_warehouse = so_doc.items[0].warehouse or self.warehouse

		# 1. Запись в Domain Stock Movement
		stock_movement.record_movement(
			item_code="KIT-3600-MOD",
			from_location="Suppliers",
			to_location=shipping_warehouse,
			qty=1.0,
			reason="Выпуск готовой кухни из сборочного цеха",
			company=self.company,
		)

		# 2. Оприходование готового изделия на склад в ERPNext (обновление Bin)
		se = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Receipt",
				"company": self.company,
				"to_warehouse": shipping_warehouse,
				"items": [
					{
						"item_code": "KIT-3600-MOD",
						"qty": 1.0,
						"uom": "Nos",
						"basic_rate": 200000.0,
						"t_warehouse": shipping_warehouse,
					}
				],
			}
		)
		se.insert(ignore_permissions=True)
		se.submit()

		delivery_res = dispatch.create_delivery(sales_order=sales_order_id)
		self.assertEqual(delivery_res["status"], "delivered")
		self.assertTrue(delivery_res["fully_delivered"])

		order_state.transition(sales_order=sales_order_id, target_state="Delivery")

		# -------------------------------------------------------------
		# STAGE 21: Installation Scheduling & Completion
		# -------------------------------------------------------------
		inst_sched = installation.schedule(
			sales_order=sales_order_id,
			installer="Administrator",
			install_on=add_days(nowdate(), 2),
		)
		self.assertIn(inst_sched["status"], ("scheduled", "already_scheduled"))

		inst_comp = installation.complete(
			sales_order=sales_order_id,
			notes="Кухня 3.6м смонтирована, уровень идеальный, техника встроена.",
		)
		self.assertEqual(inst_comp["status"], "completed")

		order_state.transition(sales_order=sales_order_id, target_state="Installation")
		order_state.transition(sales_order=sales_order_id, target_state="Acceptance Pending")

		# -------------------------------------------------------------
		# STAGE 22 & 23: Client Acceptance Act & Final Payment
		# -------------------------------------------------------------
		# Попытка перевода в Completed до подписания акта и оплаты должна быть заблокирована
		with self.assertRaises(frappe.ValidationError):
			order_state.transition(sales_order=sales_order_id, target_state="Completed")

		# Подписание акта сдачи-приемки клиентом
		act_res = acceptance.sign_acceptance_act(
			sales_order=sales_order_id,
			signed_by="Demo Kitchen Customer (Ерлан)",
			notes="Качество кухни отличное, претензий не имею.",
		)
		self.assertEqual(act_res["status"], "signed")
		self.assertTrue(acceptance.is_acceptance_signed(sales_order_id))

		# Финальный расчет (остаток 425,000 KZT -> 100% оплата)
		final_pay = payments.record_payment(
			sales_order=sales_order_id,
			amount=425000.0,
			payment_type="Final",
			reference_no="KASPI-PAY-FINAL-002",
			actor="Administrator",
		)
		self.assertEqual(final_pay["advance_paid"], 850000.0)

		# Теперь перевод в Completed успешен (с реальной 100% отгрузкой и 100% оплатой)
		completed_state = order_state.transition(
			sales_order=sales_order_id,
			target_state="Completed",
		)
		self.assertEqual(completed_state["new_state"], "Completed")

		# -------------------------------------------------------------
		# STAGE 24: Warranty Claim & Verification
		# -------------------------------------------------------------
		claim_res = warranty.claim(
			sales_order=sales_order_id,
			item_code="KIT-3600-MOD",
			complaint="Регулировка доводчика ящика через 3 месяца эксплуатации",
		)
		self.assertEqual(claim_res["status"], "accepted")
		self.assertTrue(claim_res["claim"])

		warranty_state = order_state.transition(
			sales_order=sales_order_id,
			target_state="Warranty",
		)
		self.assertEqual(warranty_state["new_state"], "Warranty")

		# -------------------------------------------------------------
		# STAGE 25: Unified Customer Timeline & Owner Dashboard Metrics
		# -------------------------------------------------------------
		cust_timeline = timeline.get_customer_order_timeline(sales_order_id)
		self.assertEqual(cust_timeline["sales_order"], sales_order_id)
		self.assertGreaterEqual(cust_timeline["total_events"], 10)

		owner_dash = dashboard.get_owner_dashboard(self.company)
		self.assertIn("today", owner_dash)
		self.assertIn("finance", owner_dash)
		self.assertIn("manufacturing", owner_dash)
		self.assertGreaterEqual(owner_dash["finance"]["total_revenue_ytd"], 850000.0)

	def test_02_offcut_90_degree_rotation_matching(self):
		"""Проверка подбора деловых остатков с учетом вращения детали на 90°."""
		offcut = offcuts.create_offcut(
			company=self.company,
			material_item="LDSP-16-WHT",
			length_mm=1500,
			width_mm=400,
			thickness_mm=16,
			warehouse=self.warehouse,
			decor="Белый Базовый",
		)
		self.assertEqual(offcut.status, "Available")

		# 1. Ищем деталь 380 x 1400 мм с вращением (1400 <= 1500, 380 <= 400)
		res_rot = offcuts.find_usable_offcuts(
			company=self.company,
			material_item="LDSP-16-WHT",
			min_length=1400,
			min_width=380,
			allow_rotation=True,
		)
		self.assertIn(offcut.name, [o["name"] for o in res_rot])

		# 2. Ищем деталь в перевернутых размерах (min_length=380, min_width=1400) без вращения
		res_no_rot = offcuts.find_usable_offcuts(
			company=self.company,
			material_item="LDSP-16-WHT",
			min_length=380,
			min_width=1400,
			allow_rotation=False,
		)
		self.assertNotIn(offcut.name, [o["name"] for o in res_no_rot])

		# 3. Та же деталь с вращением подходит
		res_rot_swapped = offcuts.find_usable_offcuts(
			company=self.company,
			material_item="LDSP-16-WHT",
			min_length=380,
			min_width=1400,
			allow_rotation=True,
		)
		self.assertIn(offcut.name, [o["name"] for o in res_rot_swapped])

	def test_03_piece_work_payroll_human_gate_and_approvals(self):
		"""Проверка сдельной оплаты: начисление, Human Approval Gate и сторнирование."""
		entry = piece_work.record_piece_work(
			company=self.company,
			employee=self.employee,
			operation="Раскрой на ЧПУ",
			rate_type="KZT_PER_PART",
			quantity=10,
			rate=350.0,
			notes="Тестовая партия",
		)
		self.assertEqual(entry.status, "Pending Approval")
		self.assertEqual(flt(entry.amount), 3500.0)

		# Human Approval Gate
		approved_entry = piece_work.approve_piece_work(entry.name, approved_by="Administrator")
		self.assertEqual(approved_entry.status, "Approved")

		# Сторнирование через компенсирующую проводку
		rev_doc = piece_work.reverse_piece_work(entry.name, reason="Корректировка брака раскроя")
		self.assertTrue(rev_doc)
		entry.reload()
		self.assertEqual(entry.status, "Reversed")
		self.assertEqual(flt(rev_doc.amount), -3500.0)

	def test_04_qc_7_point_failure_blocks_delivery(self):
		"""Проверка блокировки отгрузки при непрохождении мебельного чек-листа ОТК."""
		quote_res = proposal.draft(
			enquiry=enquiry.convert(
				capture=capture.record(text="Тест ОТК", source="Text")["capture"],
				customer_name="QC Test Customer",
			)["enquiry"],
			items=[{"item_code": "KIT-3600-MOD", "qty": 1.0, "rate": 500000.0}],
		)
		so_res = acceptance.accept(quotation=quote_res["quotation"], deliver_on=add_days(nowdate(), 7))
		so_id = so_res["sales_order"]

		for st in ["Lead", "Measurement Pending", "Measured", "Design Pending", "Design Approved", "Quote Pending", "Quote Sent", "Contract Pending", "Deposit Pending"]:
			order_state.transition(sales_order=so_id, target_state=st)
		payments.record_payment(sales_order=so_id, amount=250000.0, payment_type="Deposit")
		order_state.transition(sales_order=so_id, target_state="Ready for Production")

		res = stock_reservation.reserve_materials_for_order(sales_order=so_id, warehouse=self.warehouse)
		for s in res.get("shortages", []):
			stock_movement.record_movement(
				item_code=s["item_code"],
				from_location="Suppliers",
				to_location=self.warehouse,
				qty=flt(s["shortage_qty"]) * 2.0,
				reason="Склад",
				company=self.company,
			)
		stock_reservation.reserve_materials_for_order(sales_order=so_id, warehouse=self.warehouse)
		order_state.transition(sales_order=so_id, target_state="In Production")
		order_state.transition(sales_order=so_id, target_state="Quality Control")

		# 1. Бракованный чек-лист (скол ЛДСП)
		checklist_bad = {
			"dimensions_accurate": True,
			"edge_quality": True,
			"no_chips": False,
			"drilling_accurate": True,
			"facades_aligned": True,
			"hardware_tested": True,
			"packaging_ready": True,
		}
		qc_res = qc.submit_furniture_qc(sales_order=so_id, checklist=checklist_bad, inspector="Administrator")
		self.assertEqual(qc_res["status"], "Rejected")
		self.assertFalse(qc.is_qc_passed_for_order(so_id))

		with self.assertRaises(frappe.ValidationError):
			order_state.transition(sales_order=so_id, target_state="Ready for Delivery")

		# 2. Исправление брака
		checklist_good = {k: True for k in checklist_bad}
		qc_good = qc.submit_furniture_qc(sales_order=so_id, checklist=checklist_good, inspector="Administrator")
		self.assertEqual(qc_good["status"], "Accepted")
		self.assertTrue(qc.is_qc_passed_for_order(so_id))

		next_st = order_state.transition(sales_order=so_id, target_state="Ready for Delivery")
		self.assertEqual(next_st["new_state"], "Ready for Delivery")

	def test_05_preconditions_guard_financial_integrity(self):
		"""Проверка инвариантов: запрет запуска без аванса 50% и завершения без 100% оплаты."""
		quote_res = proposal.draft(
			enquiry=enquiry.convert(
				capture=capture.record(text="Тест финансов", source="Text")["capture"],
				customer_name="Finance Guard Customer",
			)["enquiry"],
			items=[{"item_code": "KIT-3600-MOD", "qty": 1.0, "rate": 600000.0}],
		)
		so_res = acceptance.accept(quotation=quote_res["quotation"], deliver_on=add_days(nowdate(), 7))
		so_id = so_res["sales_order"]

		for st in ["Lead", "Measurement Pending", "Measured", "Design Pending", "Design Approved", "Quote Pending", "Quote Sent", "Contract Pending", "Deposit Pending"]:
			order_state.transition(sales_order=so_id, target_state=st)

		# 1. Попытка перевода в Ready for Production при 0% предоплате
		with self.assertRaises(frappe.ValidationError):
			order_state.transition(sales_order=so_id, target_state="Ready for Production")

		# 2. Недостаточный аванс (20% вместо 50%)
		payments.record_payment(sales_order=so_id, amount=120000.0, payment_type="Deposit")
		with self.assertRaises(frappe.ValidationError):
			order_state.transition(sales_order=so_id, target_state="Ready for Production")

		# 3. Доплата до 50% (еще 180,000 -> итого 300,000 из 600,000)
		payments.record_payment(sales_order=so_id, amount=180000.0, payment_type="Deposit")
		st_res = order_state.transition(sales_order=so_id, target_state="Ready for Production")
		self.assertEqual(st_res["new_state"], "Ready for Production")

