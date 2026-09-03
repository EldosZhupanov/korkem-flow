# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Страница должна говорить, что она страница.

Найдено живым ходом ассистента: на вопрос «сколько заказов в работе» он ответил
«из 20 активных», когда их было 24. Инструмент вернул `count: 20` — длину
страницы, — а модель прочитала это как итог. Так прочитал бы и человек.
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import catalog, paging, registry  # noqa: F401


class TestAPageSaysItIsAPage(IntegrationTestCase):
	def test_a_full_page_admits_there_is_more(self):
		"""Двадцать показанных из двадцати девяти — не двадцать заказов.

		Итог не сверяется с посчитанным здесь: инструмент считает по своим
		условиям, включая компанию, и повторять их в тесте значило бы проверять
		мою копию условий, а не инструмент. Проверяется то, ради чего поле и
		появилось: страница признаётся страницей.
		"""
		data = registry.execute("sales.search_sales_orders", {})["data"]
		if not data["truncated"]:
			self.skipTest("на этом стенде заказы умещаются на одну страницу")

		self.assertEqual(data["count"], 20)
		self.assertGreater(data["total"], data["count"])

	def test_a_short_page_is_not_truncated(self):
		rows = [{"name": "x"}]
		page = paging.page(rows, "Sales Order", {"name": "x-нет-такого"})

		self.assertEqual(page["count"], 1)
		self.assertEqual(page["total"], 0)
		self.assertFalse(page["total"] > page["count"])

	def test_every_listing_tool_reports_a_total(self):
		"""Иначе останется тот, у которого модель снова прочитает длину страницы."""
		listing = (
			"sales.search_sales_orders",
			"manufacturing.search_work_orders",
			"inventory.get_stock",
			"crm.search_deals",
			"crm.search_leads",
			"crm.search_organizations",
			"crm.search_users",
			"tasks.list",
		)
		for name in listing:
			with self.subTest(tool=name):
				data = registry.execute(name, {})["data"]
				self.assertIn("total", data, f"{name} не говорит, сколько всего")
				self.assertIn("truncated", data, f"{name} не говорит, всё ли показал")

	def test_a_failed_count_says_it_does_not_know(self):
		"""«Не знаю, сколько всего» — честный ответ. Длина страницы на его месте — нет."""
		page = paging.page([{"name": "x"}], "Доктайпа-Нет", {})

		self.assertEqual(page["count"], 1)
		self.assertIsNone(page["total"])
		self.assertIsNone(page["truncated"])
