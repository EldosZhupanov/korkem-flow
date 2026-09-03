# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Учёт попыток: кто отвечал, почему переключились и сколько это стоило нам."""

from __future__ import annotations

import time
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import errors, usage
from korkem_ai.korkem_ai.orchestrator import router
from korkem_ai.korkem_ai.orchestrator.protocol import AIUsage


class _Adapter:
	def __init__(self, name):
		self.name = name


def _provider(name: str, *, input_rate=0, output_rate=0) -> str:
	if frappe.db.exists(router.PROVIDER_DOCTYPE, name):
		frappe.delete_doc(router.PROVIDER_DOCTYPE, name, force=True, ignore_permissions=True)
	frappe.get_doc(
		{
			"doctype": router.PROVIDER_DOCTYPE,
			"provider": name,
			"model": f"model-of-{name}",
			"enabled": 1,
			"input_rate_per_1k": input_rate,
			"output_rate_per_1k": output_rate,
			"base_url": "https://example.test/v1",
		}
	).insert(ignore_permissions=True)
	return name


def _server(provider: str, model: str, *, priority=100) -> str:
	name = f"{provider}-{model}"
	if frappe.db.exists(router.SERVER_DOCTYPE, name):
		frappe.delete_doc(router.SERVER_DOCTYPE, name, force=True, ignore_permissions=True)
	frappe.get_doc(
		{
			"doctype": router.SERVER_DOCTYPE,
			"provider": provider,
			"model": model,
			"enabled": 1,
			"priority": priority,
			"api_key": "ключ-korkem",
			"base_url": "https://example.test/v1",
		}
	).insert(ignore_permissions=True)
	return name


class TestEveryAttemptLeavesATrace(IntegrationTestCase):
	"""Журнал завершённых ходов не отвечает на вопрос «почему стало медленно».

	Ход, ответивший с третьей попытки, выглядит в нём как обычный: не видно ни
	что два провайдера отказали, ни сколько ходов дошло до нашего оплачиваемого
	резерва. Строка на попытку отвечает ровно на это, и она же основа счёта.
	"""

	def setUp(self):
		frappe.db.delete(router.PROVIDER_DOCTYPE)
		frappe.db.delete(router.SERVER_DOCTYPE)
		frappe.db.delete(usage.DOCTYPE)

	def tearDown(self):
		frappe.db.delete(router.PROVIDER_DOCTYPE)
		frappe.db.delete(router.SERVER_DOCTYPE)
		frappe.db.delete(usage.DOCTYPE)

	def _rows(self):
		return frappe.get_all(
			usage.DOCTYPE,
			fields=["provider", "credential_scope", "attempt", "status", "fallback_from", "fallback_reason"],
			order_by="attempt asc",
		)

	def test_a_single_success_is_one_row_on_the_first_attempt(self):
		_provider("Ollama")

		with patch.object(router, "_adapter", side_effect=lambda row: _Adapter(row["name"])):
			router.complete(lambda a: "ответ", turn_id="t1")

		rows = self._rows()
		self.assertEqual(len(rows), 1)
		self.assertEqual(rows[0]["attempt"], 1)
		self.assertEqual(rows[0]["status"], "answered")
		self.assertEqual(rows[0]["credential_scope"], router.USER)

	def test_a_fallback_records_both_the_refusal_and_who_answered(self):
		_provider("Ollama")
		_server("Google Gemini", "gemini-3.5-flash")

		def behaviour(adapter):
			if adapter.name == "Ollama":
				raise errors.RateLimited("кончилась")
			return "ответ"

		with patch.object(router, "_adapter", side_effect=lambda row: _Adapter(row["name"])):
			router.complete(behaviour, turn_id="t2")

		rows = self._rows()
		self.assertEqual(len(rows), 2)
		self.assertEqual(rows[0]["status"], "failed")
		self.assertEqual(rows[0]["credential_scope"], router.USER)
		self.assertEqual(rows[1]["status"], "answered")
		self.assertEqual(
			rows[1]["credential_scope"],
			router.SERVER,
			"переход на наш резерв обязан быть виден: за него платим мы",
		)
		self.assertEqual(rows[1]["fallback_from"], "Ollama")

	def test_the_reason_is_a_class_not_the_providers_words(self):
		"""Текст провайдера может содержать обрывки запроса человека."""
		_provider("Ollama")
		_server("Google Gemini", "gemini-3.5-flash")

		def behaviour(adapter):
			if adapter.name == "Ollama":
				raise errors.RateLimited("клиент Ерлан, кухня 650000")
			return "ответ"

		with patch.object(router, "_adapter", side_effect=lambda row: _Adapter(row["name"])):
			router.complete(behaviour, turn_id="t3")

		reasons = [r["fallback_reason"] for r in self._rows() if r["fallback_reason"]]
		self.assertEqual(reasons, ["RateLimited"])
		self.assertNotIn("Ерлан", str(self._rows()))

	def test_a_broken_ledger_never_breaks_the_answer(self):
		"""Журнал, уронивший ход, хуже отсутствующего журнала."""
		_provider("Ollama")

		with (
			patch.object(router, "_adapter", side_effect=lambda row: _Adapter(row["name"])),
			patch.object(usage, "record_attempt", side_effect=RuntimeError("журнал упал")),
		):
			self.assertEqual(router.complete(lambda a: "ответ", turn_id="t4"), "ответ")


class TestWhatTheNumbersAnswer(IntegrationTestCase):
	def setUp(self):
		frappe.db.delete(router.PROVIDER_DOCTYPE)
		frappe.db.delete(router.SERVER_DOCTYPE)
		frappe.db.delete(usage.DOCTYPE)
		_provider("Ollama")
		_server("Google Gemini", "gemini-3.5-flash")

	def tearDown(self):
		frappe.db.delete(router.PROVIDER_DOCTYPE)
		frappe.db.delete(router.SERVER_DOCTYPE)
		frappe.db.delete(usage.DOCTYPE)

	def _turn(self, fail_user: bool, turn_id: str):
		def behaviour(adapter):
			if fail_user and adapter.name == "Ollama":
				raise errors.RateLimited("кончилась")
			return "ответ"

		with patch.object(router, "_adapter", side_effect=lambda row: _Adapter(row["name"])):
			router.complete(behaviour, turn_id=turn_id)

	def test_it_says_how_many_reached_the_paid_reserve(self):
		"""И заодно показывает, что отдых меняет смысл слова «первая попытка».

		После первого отказа клиентский провайдер уходит отдыхать, и на
		следующем ходу резерв KORKEM становится **первым** в цепочке, а не
		вторым. То есть «ответили с первой попытки» перестаёт означать «ответил
		клиентский ключ» — за этим и нужна отдельная колонка `credential_scope`.
		"""
		self._turn(False, "a")
		self._turn(True, "b")
		self._turn(True, "c")

		numbers = usage.metrics(days=1)

		self.assertEqual(numbers["reached_korkem_reserve"], 2)
		self.assertEqual(
			numbers["answered_first_try"],
			2,
			"второй раз резерв отвечает первым: клиентский уже отдыхает",
		)
		self.assertEqual(numbers["fallbacks"], 1)

	def test_it_says_which_failure_happens_most(self):
		self._turn(True, "d")

		self.assertEqual(usage.metrics(days=1)["by_failure"], {"RateLimited": 1})

	def test_the_share_we_pay_for_is_a_number_not_a_feeling(self):
		self._turn(False, "e")
		self._turn(True, "f")

		numbers = usage.metrics(days=1)

		# Три попытки: одна успешная клиентская, одна отказавшая клиентская,
		# одна успешная серверная.
		self.assertEqual(numbers["attempts"], 3)
		self.assertAlmostEqual(numbers["server_share"], 1 / 3, places=3)
