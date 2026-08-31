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


class TestApiLayerHasNoAiDependency(IntegrationTestCase):
	def test_api_modules_do_not_import_korkem_ai(self):
		api_dir = Path(__file__).with_name("api")
		violations = []
		for path in sorted(api_dir.glob("*.py")):
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

		self.assertEqual(violations, [], "API layer imports AI: " + ", ".join(violations))
