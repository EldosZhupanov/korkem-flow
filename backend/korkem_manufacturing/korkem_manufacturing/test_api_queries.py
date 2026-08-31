# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The scoped query boundary used by application order lists."""

from __future__ import annotations

import inspect
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.api import queries as api


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
