# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Horizon 1 mutations remain usable when the AI provider is unavailable."""

from __future__ import annotations

import ast
from pathlib import Path
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import errors
from korkem_ai.korkem_ai.orchestrator import llm
from korkem_manufacturing.api import dispatch, production, purchasing


class TestEveryMutationWorksWithoutLlm(IntegrationTestCase):
	def setUp(self):
		super().setUp()
		self.previous_enabled = frappe.db.get_single_value("AI Settings", "enabled")
		frappe.db.set_single_value("AI Settings", "enabled", 0)
		self.addCleanup(
			frappe.db.set_single_value,
			"AI Settings",
			"enabled",
			self.previous_enabled or 0,
		)

		failure = errors.AINotConfigured("AI is disabled for this acceptance test")
		resolve_patcher = patch.object(llm, "resolve", side_effect=failure)
		provider_patcher = patch.object(llm, "get_provider", side_effect=failure)
		self.resolve = resolve_patcher.start()
		self.get_provider = provider_patcher.start()
		self.addCleanup(resolve_patcher.stop)
		self.addCleanup(provider_patcher.stop)

	def _assert_ai_was_not_needed(self):
		self.assertEqual(frappe.db.get_single_value("AI Settings", "enabled"), 0)
		self.resolve.assert_not_called()
		self.get_provider.assert_not_called()

	def test_start_production_reaches_the_domain_service(self):
		with (
			patch.object(production, "ensure_company"),
			patch.object(production.frappe, "get_roles", return_value=["System Manager"]),
			patch.object(
				production.service,
				"start_production",
				return_value={"status": "started"},
			) as service,
			patch.object(production, "_audit"),
		):
			result = production.start_production("SO-1")

		service.assert_called_once_with("SO-1", None)
		self.assertEqual(result["status"], "started")
		self._assert_ai_was_not_needed()

	def test_complete_operation_reaches_the_domain_service(self):
		with (
			patch.object(production, "ensure_company"),
			patch.object(production.frappe, "get_roles", return_value=["System Manager"]),
			patch.object(
				production.shop_floor,
				"complete_operation",
				return_value={"status": "completed"},
			) as service,
			patch.object(production, "_audit_operation"),
		):
			result = production.complete_operation(work_order="WO-1")

		service.assert_called_once_with(
			operation=None,
			sales_order=None,
			work_order="WO-1",
			qty=None,
			scrap_qty=None,
			rework_qty=None,
		)
		self.assertEqual(result["status"], "completed")
		self._assert_ai_was_not_needed()

	def test_receive_purchase_reaches_the_domain_service(self):
		with (
			patch.object(purchasing, "ensure_company"),
			patch.object(purchasing.frappe, "get_roles", return_value=["System Manager"]),
			patch.object(
				purchasing.service,
				"receive_purchase_order",
				return_value={"status": "received"},
			) as service,
			patch.object(purchasing, "_audit"),
		):
			result = purchasing.receive_purchase_order("PO-1")

		service.assert_called_once_with("PO-1", None)
		self.assertEqual(result["status"], "received")
		self._assert_ai_was_not_needed()

	def test_create_purchase_order_reaches_the_domain_service(self):
		with (
			patch.object(purchasing, "ensure_company"),
			patch.object(purchasing.frappe, "get_roles", return_value=["System Manager"]),
			patch.object(
				purchasing.service,
				"create_purchase_order",
				return_value={"status": "ordered"},
			) as service,
			patch.object(purchasing, "_audit_order"),
		):
			result = purchasing.create_purchase_order("MR-1")

		service.assert_called_once_with("MR-1", supplier=None, schedule_date=None)
		self.assertEqual(result["status"], "ordered")
		self._assert_ai_was_not_needed()

	def test_create_delivery_reaches_the_domain_service(self):
		with (
			patch.object(dispatch, "ensure_company"),
			patch.object(dispatch.frappe, "get_roles", return_value=["System Manager"]),
			patch.object(
				dispatch.service,
				"create_delivery",
				return_value={"status": "created"},
			) as service,
			patch.object(dispatch, "_audit"),
		):
			result = dispatch.create_delivery("SO-1")

		service.assert_called_once_with("SO-1", None)
		self.assertEqual(result["status"], "created")
		self._assert_ai_was_not_needed()


class TestRealErpMutationsWithoutLlm(IntegrationTestCase):
	"""Spec Kit pilot: prove ERP effects, not just forwarding to a mock.

	The seed is committed once before test transactions. Each test owns copied
	documents, never calls a committing seed helper, and rolls everything back.
	Only the unavailable LLM and a commit tripwire are mocked.
	"""

	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		from korkem_manufacturing import seed_demo

		frappe.set_user("Administrator")
		seed_demo.seed()

	def setUp(self):
		super().setUp()
		frappe.set_user("Administrator")
		self.addCleanup(frappe.db.rollback)
		self.addCleanup(frappe.set_user, "Administrator")
		frappe.db.set_single_value("AI Settings", "enabled", 0)
		failure = errors.AINotConfigured("R7: provider deliberately unavailable")
		self.resolve = self.enterContext(patch.object(llm, "resolve", side_effect=failure))
		self.provider = self.enterContext(patch.object(llm, "get_provider", side_effect=failure))
		self.commit = self.enterContext(
			patch.object(frappe.db, "commit", side_effect=AssertionError("R7 fixture must not commit"))
		)
		self.actor = "korkem.planner@example.com"

	def tearDown(self):
		self.commit.assert_not_called()
		super().tearDown()

	def _order(self, customer="Павлодар Уют"):
		from frappe.utils import add_days, nowdate

		frappe.set_user("Administrator")
		name = frappe.db.get_value(
			"Sales Order", {"company": "KORKEM", "customer": customer, "docstatus": 1}, "name"
		)
		self.assertTrue(name, f"R7 requires seeded order for {customer}; no silent skip")
		doc = frappe.copy_doc(frappe.get_doc("Sales Order", name))
		doc.docstatus = 0
		doc.transaction_date = nowdate()
		doc.delivery_date = add_days(nowdate(), 7)
		# Recalculate terms for this new order, rather than copying a past due date.
		doc.set("payment_schedule", [])
		for row in doc.items:
			row.qty = 1
			row.delivery_date = doc.delivery_date
			row.delivered_qty = 0
			row.billed_amt = 0
		doc.insert()
		doc.submit()
		frappe.set_user(self.actor)
		return doc

	def _request(self):
		from frappe.utils import add_days, nowdate

		frappe.set_user("Administrator")
		doc = frappe.get_doc({
			"doctype": "Material Request", "material_request_type": "Purchase",
			"company": "KORKEM", "schedule_date": add_days(nowdate(), 2),
			"items": [{"item_code": "ДСП 16мм", "qty": 2, "warehouse": "Stores - KRK"}],
		}).insert()
		doc.submit()
		frappe.set_user(self.actor)
		return doc

	def _stock(self, item, warehouse):
		return float(frappe.db.get_value("Bin", {"item_code": item, "warehouse": warehouse}, "actual_qty") or 0)

	def _snapshot(self):
		counts = {
			dt: frappe.db.count(dt) for dt in (
				"Work Order", "Job Card", "Stock Entry", "Stock Ledger Entry",
				"Purchase Order", "Purchase Receipt", "Delivery Note", "Comment", "Idempotency Record",
			)
		}
		for dt, fields in (
			("Bin", ["name", "actual_qty"]),
			("Work Order Operation", ["name", "completed_qty", "status"]),
			("Sales Order Item", ["name", "delivered_qty"]),
			("Purchase Order Item", ["name", "received_qty"]),
			("Material Request Item", ["name", "ordered_qty"]),
		):
			counts[dt] = frappe.get_all(dt, fields=fields, order_by="name")
		return counts

	def _run_and_repeat(self, endpoint, **kwargs):
		key = "r7-" + frappe.generate_hash(length=16)
		first = endpoint(**kwargs, idempotency_key=key)
		before_retry = self._snapshot()
		second = endpoint(**kwargs, idempotency_key=key)
		self.assertEqual(second, first)
		self.assertEqual(self._snapshot(), before_retry, "retry changed ERP state")
		self.assertEqual(frappe.db.get_single_value("AI Settings", "enabled"), 0)
		self.resolve.assert_not_called()
		self.provider.assert_not_called()
		return first

	def _audit(self, doctype, name, evidence):
		comments = frappe.get_all("Comment", filters={
			"reference_doctype": doctype, "reference_name": name, "comment_type": "Info",
		}, pluck="content")
		self.assertTrue(any(self.actor in c and evidence in c for c in comments), comments)

	def _ledger(self, voucher, expected_qty):
		rows = frappe.get_all("Stock Ledger Entry", filters={
			"voucher_no": voucher, "is_cancelled": 0,
		}, fields=["actual_qty", "company"])
		self.assertTrue(rows, "no real stock ledger entries")
		self.assertEqual({row.company for row in rows}, {"KORKEM"})
		self.assertAlmostEqual(sum(row.actual_qty for row in rows), expected_qty)

	def test_start_creates_work_order_and_moves_stock_without_llm(self):
		order = self._order()
		before = {(row.item_code, row.warehouse): row.actual_qty for row in frappe.get_all(
			"Bin", fields=["item_code", "warehouse", "actual_qty"]
		)}
		result = self._run_and_repeat(production.start_production, sales_order=order.name)
		self.assertEqual(result["status"], "started")
		job = frappe.get_doc("Work Order", result["work_order"])
		self.assertEqual((job.docstatus, job.company, job.sales_order), (1, "KORKEM", order.name))
		self.assertEqual(job.status, "In Process")
		self.assertGreater(job.material_transferred_for_manufacturing, 0)
		self.assertTrue(job.operations)
		transfer = frappe.get_doc("Stock Entry", result["material_transfer"])
		self.assertEqual((transfer.docstatus, transfer.work_order), (1, job.name))
		self.assertTrue(transfer.items)
		for row in transfer.items:
			self.assertGreater(row.transfer_qty, 0)
			self.assertAlmostEqual(self._stock(row.item_code, row.s_warehouse),
				before.get((row.item_code, row.s_warehouse), 0) - row.transfer_qty)
			self.assertAlmostEqual(self._stock(row.item_code, row.t_warehouse),
				before.get((row.item_code, row.t_warehouse), 0) + row.transfer_qty)
		self._ledger(transfer.name, 0)
		self._audit("Sales Order", order.name, job.name)

	def test_completion_submits_card_and_updates_progress_without_llm(self):
		order = self._order()
		started = production.start_production(order.name)
		job = frappe.get_doc("Work Order", started["work_order"])
		operation = job.operations[0].operation
		result = self._run_and_repeat(production.complete_operation, work_order=job.name, operation=operation)
		self.assertEqual(result["status"], "completed")
		card = frappe.get_doc("Job Card", result["job_card"])
		self.assertEqual((card.docstatus, card.status, card.work_order), (1, "Completed", job.name))
		self.assertEqual(card.total_completed_qty, 1)
		job.reload()
		self.assertEqual(job.operations[0].completed_qty, 1)
		self.assertEqual(job.operations[0].status, "Completed")
		self._audit("Work Order", job.name, card.name)

	def test_purchase_creates_priced_order_without_llm(self):
		request = self._request()
		result = self._run_and_repeat(purchasing.create_purchase_order, material_request=request.name)
		self.assertEqual(result["status"], "created")
		order = frappe.get_doc("Purchase Order", result["purchase_order"])
		self.assertEqual((order.docstatus, order.company), (1, "KORKEM"))
		self.assertEqual(order.items[0].material_request, request.name)
		self.assertEqual(order.items[0].qty, 2)
		self.assertGreater(order.items[0].rate, 0)
		request.reload()
		self.assertEqual(request.items[0].ordered_qty, 2)
		self._audit("Material Request", request.name, order.name)

	def test_receipt_moves_stock_and_received_quantity_without_llm(self):
		request = self._request()
		ordered = purchasing.create_purchase_order(request.name)
		self.assertEqual(ordered["status"], "created")
		before = self._stock("ДСП 16мм", "Stores - KRK")
		result = self._run_and_repeat(purchasing.receive_purchase_order, purchase_order=ordered["purchase_order"])
		self.assertEqual(result["status"], "created")
		receipt = frappe.get_doc("Purchase Receipt", result["purchase_receipt"])
		self.assertEqual((receipt.docstatus, receipt.company), (1, "KORKEM"))
		self.assertEqual(receipt.items[0].purchase_order, ordered["purchase_order"])
		self.assertEqual(receipt.items[0].qty, 2)
		self.assertAlmostEqual(self._stock("ДСП 16мм", "Stores - KRK"), before + 2)
		order = frappe.get_doc("Purchase Order", ordered["purchase_order"])
		self.assertEqual(order.items[0].received_qty, 2)
		self._ledger(receipt.name, 2)
		self._audit("Purchase Order", order.name, receipt.name)

	def test_delivery_moves_stock_and_delivered_quantity_without_llm(self):
		order = self._order("Мебель Астана")
		item = order.items[0].item_code
		before = self._stock(item, "Finished Goods - KRK")
		self.assertGreaterEqual(before, 1)
		result = self._run_and_repeat(dispatch.create_delivery, sales_order=order.name)
		self.assertEqual(result["status"], "delivered")
		note = frappe.get_doc("Delivery Note", result["delivery_note"])
		self.assertEqual((note.docstatus, note.company), (1, "KORKEM"))
		self.assertEqual(note.items[0].against_sales_order, order.name)
		self.assertEqual(note.items[0].qty, 1)
		order.reload()
		self.assertEqual(order.items[0].delivered_qty, 1)
		self.assertAlmostEqual(self._stock(item, "Finished Goods - KRK"), before - 1)
		self._ledger(note.name, -1)
		self._audit("Sales Order", order.name, note.name)

	def _actions(self):
		order = self._order()
		started = production.start_production(order.name)
		request = self._request()
		ordered = purchasing.create_purchase_order(request.name)
		self.assertEqual(ordered["status"], "created")
		return (
			(production.start_production, {"sales_order": order.name}),
			(production.complete_operation, {"work_order": started["work_order"]}),
			(purchasing.create_purchase_order, {"material_request": request.name}),
			(purchasing.receive_purchase_order, {"purchase_order": ordered["purchase_order"]}),
			(dispatch.create_delivery, {"sales_order": order.name}),
		)

	def test_all_five_still_refuse_a_user_without_rights(self):
		actions = self._actions()
		# The demo viewer has Manufacturing User; its name is not its policy.
		frappe.set_user("Administrator")
		user = frappe.get_doc({
			"doctype": "User", "email": "r7-reader-" + frappe.generate_hash(length=8) + "@example.com",
			"first_name": "R7 reader", "send_welcome_email": 0,
			"roles": [{"role": "Sales User"}],
		}).insert()
		frappe.get_doc({"doctype": "User Permission", "user": user.name,
			"allow": "Company", "for_value": "KORKEM"}).insert()
		frappe.set_user(user.name)
		before = self._snapshot()
		for endpoint, arguments in actions:
			with self.subTest(endpoint=endpoint.__name__):
				with self.assertRaises(frappe.PermissionError):
					endpoint(**arguments)
		self.assertEqual(self._snapshot(), before)
		self.resolve.assert_not_called()
		self.provider.assert_not_called()

	def test_all_five_still_refuse_another_company(self):
		actions = self._actions()
		frappe.set_user("Administrator")
		company = frappe.get_doc({
			"doctype": "Company", "company_name": "R7 Other " + frappe.generate_hash(length=6),
			"abbr": "R7" + frappe.generate_hash(length=3), "default_currency": "KZT", "country": "Kazakhstan",
		}).insert()
		user = frappe.get_doc({
			"doctype": "User", "email": "r7-" + frappe.generate_hash(length=8) + "@example.com",
			"first_name": "R7 foreign", "send_welcome_email": 0,
			"roles": [{"role": "System Manager"}],
		}).insert()
		frappe.get_doc({"doctype": "User Permission", "user": user.name,
			"allow": "Company", "for_value": company.name}).insert()
		frappe.set_user(user.name)
		before = self._snapshot()
		for endpoint, arguments in actions:
			with self.subTest(endpoint=endpoint.__name__):
				with self.assertRaises(frappe.ValidationError) as caught:
					endpoint(**arguments)
				self.assertIn("not found", str(caught.exception))
		self.assertEqual(self._snapshot(), before)
		self.resolve.assert_not_called()
		self.provider.assert_not_called()

	def test_tripwire_rejects_an_injected_llm_dependency(self):
		order = self._order()
		before = self._snapshot()
		with patch.object(production.service, "start_production", side_effect=lambda *_: llm.resolve()):
			with self.assertRaises(errors.AINotConfigured):
				production.start_production(order.name)
		self.resolve.assert_called_once()
		self.assertEqual(self._snapshot(), before)


class TestApiLayerHasNoAiDependency(IntegrationTestCase):
	def test_api_modules_do_not_import_korkem_ai(self):
		root = Path(__file__).parent
		self._assert_no_ai_imports(sorted((root / "api").rglob("*.py")))

	def test_the_five_actions_services_do_not_import_korkem_ai(self):
		root = Path(__file__).with_name("services")
		# Entire-domain audit separately found invitations/provisioning debt.
		# This gate is explicitly for the five R7 actions and their shared access.
		self._assert_no_ai_imports([root / (name + ".py") for name in (
			"production", "shop_floor", "purchasing", "dispatch", "idempotency", "scope", "identity",
		)])

	def _assert_no_ai_imports(self, paths):
		violations = []
		for path in paths:
			tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
			for node in ast.walk(tree):
				modules = []
				if isinstance(node, ast.Import):
					modules = [alias.name for alias in node.names]
				elif isinstance(node, ast.ImportFrom) and node.module:
					modules = [node.module]
				for module in modules:
					if module == "korkem_ai" or module.startswith("korkem_ai."):
						violations.append(f"{path.name}:{node.lineno}: {module}")

		self.assertEqual(violations, [], "Selected path imports AI: " + ", ".join(violations))
