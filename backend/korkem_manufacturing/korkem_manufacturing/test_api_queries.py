# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The scoped query boundary used by application order lists."""

from __future__ import annotations

import inspect
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import foreign_fixture
from korkem_manufacturing import seed_demo
from korkem_manufacturing.api import queries as api

PLANNER = "korkem.planner@example.com"


class TestSalesOrderQuery(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		self.assertEqual(
			set(inspect.signature(api.sales_orders).parameters),
			{"status", "search", "limit", "offset"},
		)

	def test_another_companys_order_is_not_visible(self):
		rows = [
			{"name": "SO-OURS", "company": "KORKEM"},
			{"name": "SO-THEIRS", "company": "OTHER"},
		]

		def permission_aware_list(_doctype, **kwargs):
			company = kwargs["filters"]["company"]
			return [
				{"name": row["name"]}
				for row in rows
				if row["company"] == company
			]

		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM"}),
			patch.object(api.frappe, "get_list", side_effect=permission_aware_list),
			patch.object(api, "_total", return_value=1),
		):
			result = api.sales_orders()

		self.assertEqual([row["name"] for row in result["orders"]], ["SO-OURS"])

	def test_limit_is_capped_at_one_hundred(self):
		def page(_doctype, **kwargs):
			return [
				{"name": f"SO-{index:03d}"}
				for index in range(kwargs["limit_page_length"])
			]

		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM"}),
			patch.object(api.frappe, "get_list", side_effect=page) as get_list,
			patch.object(api, "_total", return_value=100),
		):
			result = api.sales_orders(limit=500)

		self.assertEqual(result["limit"], 100)
		self.assertEqual(len(result["orders"]), 100)
		self.assertEqual(get_list.call_args.kwargs["limit_page_length"], 100)

	def test_malformed_offset_is_refused(self):
		with self.assertRaises(frappe.ValidationError) as caught:
			api.sales_orders(offset="next page")
		self.assertIn("offset", str(caught.exception))

	def test_it_requests_only_the_screen_fields(self):
		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM"}),
			patch.object(api.frappe, "get_list", return_value=[]) as get_list,
			patch.object(api, "_total", return_value=0),
		):
			api.sales_orders(status="To Deliver", search="SO-24")

		call = get_list.call_args
		self.assertEqual(call.args, ("Sales Order",))
		self.assertEqual(call.kwargs["fields"], list(api.SALES_ORDER_FIELDS))
		self.assertEqual(call.kwargs["filters"]["status"], "To Deliver")
		self.assertEqual(
			call.kwargs["or_filters"],
			[
				["Sales Order", "name", "like", "%SO-24%"],
				["Sales Order", "customer", "like", "%SO-24%"],
			],
		)


def _work_order(name: str, company: str = "KORKEM") -> dict:
	return {
		"name": name,
		"company": company,
		"production_item": "CHAIR",
		"item_name": "Chair",
		"qty": "10",
		"produced_qty": "4",
		"status": "In Process",
		"planned_end_date": "2026-09-10T12:00:00",
		"actual_end_date": None,
		"sales_order": "SO-1",
		"bom_no": "BOM-CHAIR-001",
	}


class TestWorkOrderQuery(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		self.assertEqual(
			set(inspect.signature(api.work_orders).parameters),
			{"status", "search", "limit", "offset"},
		)

	def test_another_companys_work_order_is_not_visible(self):
		rows = [_work_order("WO-OURS"), _work_order("WO-THEIRS", company="OTHER")]

		def permission_aware_list(_doctype, **kwargs):
			return [row for row in rows if row["company"] == kwargs["filters"]["company"]]

		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM"}),
			patch.object(api.frappe, "get_list", side_effect=permission_aware_list),
			patch.object(api, "_total", return_value=1),
		):
			result = api.work_orders()

		self.assertEqual([row["name"] for row in result["orders"]], ["WO-OURS"])
		self.assertEqual(
			set(result["orders"][0]),
			{
				"name",
				"production_item",
				"item_name",
				"qty",
				"produced_qty",
				"status",
				"planned_end_date",
				"actual_end_date",
				"sales_order",
				"bom_no",
			},
		)

	def test_limit_is_capped_at_one_hundred(self):
		def page(_doctype, **kwargs):
			return [
				_work_order(f"WO-{index:03d}")
				for index in range(kwargs["limit_page_length"])
			]

		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM"}),
			patch.object(api.frappe, "get_list", side_effect=page) as get_list,
			patch.object(api, "_total", return_value=100),
		):
			result = api.work_orders(limit="500")

		self.assertEqual(result["limit"], 100)
		self.assertEqual(len(result["orders"]), 100)
		self.assertEqual(get_list.call_args.kwargs["limit_page_length"], 100)

	def test_total_uses_the_search_filter(self):
		def lists(_doctype, **kwargs):
			if kwargs.get("pluck") == "name":
				return ["WO-MATCH-1", "WO-MATCH-2"]
			return []

		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM"}),
			patch.object(api.frappe, "get_list", side_effect=lists) as get_list,
		):
			result = api.work_orders(search="chair")

		self.assertEqual(result["total"], 2)
		count_call = get_list.call_args_list[-1]
		self.assertEqual(count_call.kwargs["limit_page_length"], 0)
		self.assertTrue(count_call.kwargs["or_filters"])


class TestRealWorkOrderCompanyScope(foreign_fixture.UsesForeignCompany, IntegrationTestCase):
	def test_employee_cannot_see_another_companys_work_order(self):
		frappe.set_user("Administrator")
		seed_demo.seed_users()
		foreign = foreign_fixture.ensure()["work_order"]

		frappe.set_user(PLANNER)
		try:
			result = api.work_orders(search=foreign, limit=100)
		finally:
			frappe.set_user("Administrator")

		self.assertNotIn(foreign, [row["name"] for row in result["orders"]])


class TestOperationQuery(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		self.assertEqual(
			set(inspect.signature(api.operations).parameters),
			{"work_order", "limit", "offset"},
		)

	def test_foreign_work_order_does_not_unlock_its_operations(self):
		with (
			patch.object(
				api,
				"scoped",
				return_value={"company": "KORKEM", "name": "WO-THEIRS"},
			),
			patch.object(api.frappe, "get_list", return_value=[]) as get_list,
		):
			result = api.operations("WO-THEIRS")

		self.assertEqual(
			result,
			{"operations": [], "total": 0, "limit": 20, "offset": 0},
		)
		get_list.assert_called_once_with(
			"Work Order",
			filters={"company": "KORKEM", "name": "WO-THEIRS"},
			pluck="name",
			limit_start=0,
			limit_page_length=1,
		)

	def test_visible_operations_are_permission_aware_and_paginated(self):
		row = {
			"name": "ROW-2",
			"operation": "Edge banding",
			"workstation": "Edge bander",
			"status": "Pending",
			"completed_qty": "3",
			"process_loss_qty": "0.5",
			"time_in_mins": "12",
			"sequence_id": 2,
		}

		def lists(doctype, **kwargs):
			if doctype == "Work Order":
				return ["WO-OURS"]
			if doctype == "Work Order Operation":
				return [row]
			raise AssertionError(doctype)

		with (
			patch.object(
				api,
				"scoped",
				return_value={"company": "KORKEM", "name": "WO-OURS"},
			),
			patch.object(api.frappe, "get_list", side_effect=lists) as get_list,
			patch.object(api, "_total", return_value=3),
		):
			result = api.operations("WO-OURS", limit=1, offset=1)

		operation_call = get_list.call_args_list[1]
		self.assertEqual(operation_call.args, ("Work Order Operation",))
		self.assertEqual(operation_call.kwargs["limit_page_length"], 1)
		self.assertEqual(operation_call.kwargs["limit_start"], 1)
		self.assertEqual(
			result,
			{
				"operations": [
					{
						"name": "ROW-2",
						"operation": "Edge banding",
						"workstation": "Edge bander",
						"status": "Pending",
						"completed_qty": 3.0,
						"scrap_qty": 0.5,
						"planned_minutes": 12.0,
						"sequence": 2,
					}
				],
				"total": 3,
				"limit": 1,
				"offset": 1,
			},
		)


def _bin(item_code: str, warehouse: str) -> dict:
	return {
		"item_code": item_code,
		"warehouse": warehouse,
		"actual_qty": "12.5",
		"reserved_qty": "2",
		"projected_qty": "15",
		"stock_uom": "Nos",
	}


class TestStockQuery(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		self.assertEqual(
			set(inspect.signature(api.stock).parameters),
			{"warehouse", "search", "limit", "offset"},
		)

	def test_another_companys_warehouse_is_not_visible(self):
		bins = [_bin("CHAIR", "KORKEM-WH"), _bin("TABLE", "OTHER-WH")]

		def permission_aware_list(doctype, **kwargs):
			if doctype == "Warehouse":
				return ["KORKEM-WH"]
			if doctype == "Bin":
				allowed = kwargs["filters"]["warehouse"][1]
				return [row for row in bins if row["warehouse"] in allowed]
			if doctype == "Item":
				return [{"name": "CHAIR", "item_name": "Chair"}]
			raise AssertionError(doctype)

		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM", "is_group": 0}),
			patch.object(api.frappe, "get_list", side_effect=permission_aware_list),
			patch.object(api, "_total", return_value=1),
		):
			result = api.stock()

		self.assertEqual(
			result["items"],
			[
				{
					"item_code": "CHAIR",
					"item_name": "Chair",
					"warehouse": "KORKEM-WH",
					"actual_qty": 12.5,
					"reserved_qty": 2.0,
					"projected_qty": 15.0,
					"stock_uom": "Nos",
				}
			],
		)

	def test_limit_is_capped_and_items_are_loaded_once(self):
		def lists(doctype, **kwargs):
			if doctype == "Warehouse":
				return ["KORKEM-WH"]
			if doctype == "Bin":
				return [
					_bin(f"ITEM-{index:03d}", "KORKEM-WH")
					for index in range(kwargs["limit_page_length"])
				]
			if doctype == "Item":
				return [
					{"name": name, "item_name": name.title()}
					for name in kwargs["filters"]["name"][1]
				]
			raise AssertionError(doctype)

		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM", "is_group": 0}),
			patch.object(api.frappe, "get_list", side_effect=lists) as get_list,
			patch.object(api, "_total", return_value=100),
		):
			result = api.stock(limit=500)

		self.assertEqual(result["limit"], 100)
		self.assertEqual(len(result["items"]), 100)
		item_calls = [call for call in get_list.call_args_list if call.args == ("Item",)]
		self.assertEqual(len(item_calls), 1, "Item names must be loaded in one query")

	def test_total_uses_the_search_filter(self):
		def lists(doctype, **kwargs):
			if doctype == "Warehouse":
				return ["KORKEM-WH"]
			if doctype == "Item":
				return [
					{"name": "CHAIR", "item_name": "Oak Chair"},
					{"name": "CHAIR-2", "item_name": "Small Chair"},
				]
			if doctype == "Bin":
				return []
			raise AssertionError(doctype)

		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM", "is_group": 0}),
			patch.object(api.frappe, "get_list", side_effect=lists),
			patch.object(api.frappe.client, "get_count", return_value=2) as get_count,
		):
			result = api.stock(search="chair")

		self.assertEqual(result["total"], 2)
		filters = get_count.call_args.kwargs["filters"]
		self.assertEqual(filters["item_code"], ["in", ["CHAIR", "CHAIR-2"]])


class TestDeliveryQuery(IntegrationTestCase):
	def test_company_scope_and_submitted_delivery_are_required(self):
		def lists(doctype, **kwargs):
			if doctype == "Delivery Note Item" and kwargs.get("pluck") == "parent":
				return ["DN-OURS", "DN-THEIRS", "DN-DRAFT"]
			if doctype == "Delivery Note":
				self.assertEqual(kwargs["filters"]["company"], "KORKEM")
				self.assertEqual(kwargs["filters"]["docstatus"], 1)
				return [{"name": "DN-OURS", "posting_date": "2026-09-01", "status": "To Bill", "grand_total": "100"}]
			if doctype == "Delivery Note Item":
				return [{"parent": "DN-OURS", "item_code": "CHAIR", "item_name": "Chair", "qty": "2", "uom": "Nos"}]
			raise AssertionError(doctype)

		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM", "docstatus": 1, "name": ["in", ["DN-OURS", "DN-THEIRS", "DN-DRAFT"]]}),
			patch.object(api.frappe, "get_list", side_effect=lists),
			patch.object(api, "_total", return_value=1),
		):
			result = api.deliveries("SO-1")

		self.assertEqual(result["total"], 1)
		self.assertEqual(result["deliveries"], [{"name": "DN-OURS", "posting_date": "2026-09-01", "status": "To Bill", "grand_total": 100.0, "items": [{"item_code": "CHAIR", "item_name": "Chair", "qty": 2.0, "uom": "Nos"}]}])

	def test_order_without_deliveries_is_empty(self):
		with patch.object(api.frappe, "get_list", return_value=[]):
			result = api.deliveries("SO-EMPTY")
		self.assertEqual(result, {"deliveries": [], "total": 0, "limit": 20, "offset": 0})


class TestReceivableAndOrderableQueries(IntegrationTestCase):
	"""These two lists exist so nobody types a document id from memory.

	Both carry one rule beyond scope: their filters must mirror what the
	corresponding action refuses.  A list that offers a closed purchase order
	sends a warehouse worker to a button that will decline — which reads as the
	app being broken, not as the order being closed.
	"""

	def test_company_is_not_a_caller_argument(self):
		for query in (api.receivable_purchase_orders, api.orderable_material_requests):
			with self.subTest(query=query.__name__):
				self.assertEqual(
					set(inspect.signature(query).parameters), {"limit", "offset"}
				)

	def test_receivable_orders_exclude_what_the_action_would_refuse(self):
		seen = {}

		def lists(doctype, **kwargs):
			seen["doctype"] = doctype
			seen["filters"] = kwargs["filters"]
			return [
				{
					"name": "PUR-ORD-1",
					"supplier": "Wood Co",
					"transaction_date": "2026-09-01",
					"schedule_date": "2026-09-10",
					"status": "To Receive and Bill",
					"per_received": "40",
					"grand_total": "1000",
				}
			]

		with (
			patch.object(api, "scoped", side_effect=lambda f=None: dict(f or {}, company="KORKEM")),
			patch.object(api.frappe, "get_list", side_effect=lists),
			patch.object(api, "_total", return_value=1),
		):
			result = api.receivable_purchase_orders()

		self.assertEqual(seen["doctype"], "Purchase Order")
		self.assertEqual(seen["filters"]["company"], "KORKEM")
		self.assertEqual(seen["filters"]["docstatus"], 1)
		self.assertEqual(seen["filters"]["per_received"], ["<", 100])
		self.assertEqual(
			seen["filters"]["status"], ["not in", ["Closed", "Cancelled", "On Hold"]]
		)
		self.assertEqual(
			result["orders"],
			[
				{
					"name": "PUR-ORD-1",
					"supplier": "Wood Co",
					"ordered_on": "2026-09-01",
					"expected_on": "2026-09-10",
					"status": "To Receive and Bill",
					"received_percent": 40.0,
					"total": 1000.0,
				}
			],
		)

	def test_orderable_requests_are_purchases_only(self):
		seen = {}

		def lists(doctype, **kwargs):
			seen["doctype"] = doctype
			seen["filters"] = kwargs["filters"]
			return []

		with (
			patch.object(api, "scoped", side_effect=lambda f=None: dict(f or {}, company="KORKEM")),
			patch.object(api.frappe, "get_list", side_effect=lists),
			patch.object(api, "_total", return_value=0),
		):
			result = api.orderable_material_requests()

		self.assertEqual(seen["doctype"], "Material Request")
		self.assertEqual(seen["filters"]["material_request_type"], "Purchase")
		self.assertEqual(seen["filters"]["per_ordered"], ["<", 100])
		self.assertEqual(seen["filters"]["status"], ["not in", ["Stopped", "Cancelled"]])
		self.assertEqual(result, {"requests": [], "total": 0, "limit": 20, "offset": 0})

	def test_limit_is_capped(self):
		with (
			patch.object(api, "scoped", return_value={"company": "KORKEM"}),
			patch.object(api.frappe, "get_list", return_value=[]) as get_list,
			patch.object(api, "_total", return_value=0),
		):
			api.receivable_purchase_orders(limit=10_000)
		self.assertEqual(get_list.call_args.kwargs["limit_page_length"], api.MAX_LIMIT)
