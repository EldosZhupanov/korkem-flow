# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Ассистент должен доставать до цепочки, а не только до отчётов.

Найдено замером живого хода: в каталоге было 43 инструмента и ни одного для
того, ради чего продукт делается — записать сказанное. Владелец мог спросить
«сколько заказов», но не мог сказать «запиши: звонил Данияр, кухня, замерить».
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401
from korkem_ai.korkem_ai.tools.registry import Risk


class TestTheChainIsReachable(IntegrationTestCase):
	def test_the_owner_can_say_write_this_down(self):
		"""Тот самый вопрос, ради которого всё."""
		self.assertIsNotNone(registry.find("chain.record_capture"))

	def test_the_morning_question_has_a_tool(self):
		"""«Что застряло сегодня» — то, что владелец спрашивает голосом."""
		self.assertIsNotNone(registry.find("chain.what_needs_attention"))

	def test_writing_waits_for_a_person(self):
		"""R10: ассистент мог не расслышать имя клиента."""
		for name in (
			"chain.record_capture",
			"chain.convert_capture",
			"chain.record_measurement",
		):
			with self.subTest(tool=name):
				self.assertEqual(registry.get(name).risk, Risk.WRITE)

	def test_looking_does_not_wait(self):
		"""Спрашивать разрешение на взгляд — сделать взгляд дороже, чем он стоит."""
		for name in ("chain.what_needs_attention", "chain.contract_status"):
			with self.subTest(tool=name):
				self.assertEqual(registry.get(name).risk, Risk.READ)

	def test_recording_what_was_said_actually_records_it(self):
		said = f"Звонил клиент, кухня 3200. Проверка {frappe.generate_hash(length=6)}"
		result = registry.execute(
			"chain.record_capture",
			{"text": said, "customer_hint": "Данияр", "assign_to": "Administrator"},
		)

		self.assertTrue(result["ok"], result)
		capture = result["data"]["capture"]
		self.assertEqual(frappe.db.get_value("Capture", capture, "spoken_text"), said)
		# Задача замерщику ставится тем же действием — человек делает это одним.
		self.assertTrue(frappe.db.get_value("Capture", capture, "task"))

	def test_the_morning_question_answers_in_four_lists(self):
		result = registry.execute("chain.what_needs_attention", {})

		self.assertTrue(result["ok"], result)
		self.assertEqual(
			set(result["data"]),
			{
				"unassigned_captures",
				"overdue_tasks",
				"orders_without_design",
				"delivered_not_invoiced",
			},
		)

	def test_a_tool_holds_no_business_rule_of_its_own(self):
		"""R1: правило живёт в сервисе, инструмент только зовёт.

		Два места с одним правилом однажды разойдутся, и разойдутся молча.
		"""
		import inspect

		from korkem_ai.korkem_ai.tools import chain

		source = inspect.getsource(chain)
		for forbidden in ("frappe.throw", "frappe.get_list", "frappe.db."):
			self.assertNotIn(
				forbidden,
				source,
				f"{forbidden} в обёртке означает правило, продублированное мимо сервиса",
			)
