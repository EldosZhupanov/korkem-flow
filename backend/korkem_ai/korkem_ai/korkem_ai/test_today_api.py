# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Что сегодня важно» — одно число на каждый утренний вопрос."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import today_api


class TestTheAnswerHasEveryQuestionTheOwnerAsks(IntegrationTestCase):
	def test_the_shape_is_the_one_the_screen_expects(self):
		"""Имена полей — договор с приложением, а не деталь реализации."""
		answer = today_api.get_summary()

		self.assertEqual(
			set(answer),
			{
				"overdue_orders",
				"due_today_orders",
				"due_this_week_orders",
				"unpaid_amount",
				"material_deficit_count",
				"installations_today",
				"pending_approvals",
			},
		)

	def test_every_value_is_a_number(self):
		for key, value in today_api.get_summary().items():
			with self.subTest(key=key):
				self.assertIsInstance(value, (int, float))


class TestOneBrokenNumberDoesNotBreakTheMorning(IntegrationTestCase):
	"""Остальные шесть чисел человеку по-прежнему нужны.

	Расчёт дефицита тяжёлый и зависит от спецификаций. Уронить из-за него весь
	экран значит оставить владельца без просрочек и долгов, которые посчитались
	нормально.
	"""

	def test_a_failing_deficit_leaves_the_rest_intact(self):
		from korkem_ai.korkem_ai.tools import procurement

		with patch.object(procurement, "factory_shortage", side_effect=RuntimeError("упало")):
			answer = today_api.get_summary()

		self.assertEqual(answer["material_deficit_count"], 0)
		self.assertIn("unpaid_amount", answer)

	def test_a_failing_order_count_is_zero_not_an_exception(self):
		with patch.object(frappe.db, "count", side_effect=RuntimeError("упало")):
			answer = today_api.get_summary()

		self.assertEqual(answer["overdue_orders"], 0)


class TestWhatCountsAsOverdue(IntegrationTestCase):
	"""Закрытый заказ со вчерашним сроком не просрочен — он сделан.

	Считать его просрочкой значит показывать тревогу там, где всё хорошо, и
	владелец перестанет смотреть на это число.
	"""

	def test_closed_and_cancelled_orders_are_not_counted(self):
		seen = {}

		def spy(doctype, filters=None):
			if doctype == "Sales Order":
				seen["filters"] = filters
			return 0

		with patch.object(frappe.db, "count", side_effect=spy):
			today_api.get_summary()

		excluded = seen["filters"]["status"][1]
		self.assertIn("Closed", excluded)
		self.assertIn("Cancelled", excluded)
		self.assertIn("Completed", excluded)


class TestDebtIsWhatTheyOweUs(IntegrationTestCase):
	def test_only_issued_invoices_count_as_unpaid(self):
		"""Невыставленный счёт — наша недоработка, а не долг клиента.

		Смешивать их в одном числе значит не понимать ни того, ни другого.
		"""
		seen = {}

		def spy(doctype, **kwargs):
			# Свободная подпись: `get_all` зовут по-разному в разных местах, и
			# шпион, требующий конкретных аргументов, ловит не то, что проверяет.
			seen[doctype] = kwargs.get("filters")
			return []

		with patch.object(frappe, "get_all", side_effect=spy):
			today_api.get_summary()

		self.assertEqual(seen["Sales Invoice"]["docstatus"], 1)
		self.assertEqual(seen["Sales Invoice"]["outstanding_amount"], [">", 0])
