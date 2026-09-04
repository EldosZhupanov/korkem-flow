# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Экран «из чего сложился запрос»: числа и названия разделов, и ничего больше."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import usage, usage_api


def _row(breakdown: dict) -> str:
	doc = frappe.get_doc(
		{
			"doctype": usage.DOCTYPE,
			"user": frappe.session.user,
			"channel": "App",
			"status": "answered",
			"provider": "Ollama",
			"model": "m",
			"credential_scope": "user",
			"attempt": 1,
			"latency_ms": 10,
			"context_breakdown": frappe.as_json(breakdown),
		}
	)
	doc.insert(ignore_permissions=True)
	return doc.name


class TestWhatTheOwnerSees(IntegrationTestCase):
	def setUp(self):
		frappe.db.delete(usage.DOCTYPE)

	def tearDown(self):
		frappe.db.delete(usage.DOCTYPE)

	def test_an_empty_history_says_so_instead_of_showing_zeroes(self):
		"""Ноль токенов и «запросов не было» — разные вещи."""
		answer = usage_api.get_prompt_breakdown()

		self.assertTrue(answer["is_empty"])
		self.assertIsNone(answer["last_prompt"])

	def test_the_sections_add_up_to_the_total(self):
		_row({"instruction": 682, "tools": 942, "conversation": 300})

		last = usage_api.get_prompt_breakdown()["last_prompt"]

		self.assertEqual(last["total_tokens"], 682 + 942 + 300)
		self.assertEqual({item["id"] for item in last["items"]},
			{"instruction", "tools", "conversation"})

	def test_an_empty_section_is_not_shown(self):
		"""Строка «память компании: 0» ничего не объясняет и занимает место."""
		_row({"instruction": 682, "tools": 942, "company_memory": 0})

		ids = {item["id"] for item in usage_api.get_prompt_breakdown()["last_prompt"]["items"]}

		self.assertNotIn("company_memory", ids)

	def test_it_says_how_many_tools_were_offered_out_of_how_many(self):
		"""Единственное число, по которому видно, работает ли отбор."""
		_row({"instruction": 682, "tools": 942, "tools_offered": 6, "tools_total": 65})

		last = usage_api.get_prompt_breakdown()["last_prompt"]

		self.assertEqual(last["tools_offered"], 6)
		self.assertEqual(last["tools_total"], 65)

	def test_nothing_of_the_conversation_itself_reaches_the_screen(self):
		"""Экран показывает, из чего сложился запрос, а не что в нём было."""
		_row({"instruction": 682, "tools": 942, "conversation": 300})

		payload = str(usage_api.get_prompt_breakdown())

		for word in ("Ерлан", "кухня", "650000", "привет"):
			self.assertNotIn(word, payload)

	def test_a_broken_row_does_not_break_the_screen(self):
		"""Битая строка — наша недоделка, а не повод показать ошибку человеку."""
		doc = frappe.get_doc(
			{
				"doctype": usage.DOCTYPE, "user": frappe.session.user, "channel": "App",
				"status": "answered", "provider": "Ollama", "model": "m",
				"attempt": 1, "context_breakdown": "не json",
			}
		)
		doc.insert(ignore_permissions=True)

		answer = usage_api.get_prompt_breakdown()

		self.assertTrue(answer["is_empty"])
