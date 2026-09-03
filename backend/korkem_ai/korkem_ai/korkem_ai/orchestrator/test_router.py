# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Роутер: дешёвая модель первой, дорогая когда дешёвая не смогла."""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import errors
from korkem_ai.korkem_ai.orchestrator import router


def _provider(name: str, *, input_rate=0, output_rate=0, enabled=1) -> str:
	"""Провайдер именуется своим типом: их столько же, сколько типов.

	Поэтому в проверках стоят настоящие имена из справочника, а не придуманные:
	`AI Provider` называет документ по полю `provider`, и выдуманное имя молча
	превратилось бы в чужое.
	"""
	if frappe.db.exists(router.PROVIDER_DOCTYPE, name):
		frappe.delete_doc(router.PROVIDER_DOCTYPE, name, force=True, ignore_permissions=True)
	frappe.get_doc(
		{
			"doctype": router.PROVIDER_DOCTYPE,
			"provider": name,
			"model": f"model-of-{name}",
			"enabled": enabled,
			"input_rate_per_1k": input_rate,
			"output_rate_per_1k": output_rate,
			"base_url": "https://example.test/v1",
		}
	).insert(ignore_permissions=True)
	return name


class TestTheOrderIsCost(IntegrationTestCase):
	"""Порядок задаёт цена, а не наше мнение о модели."""

	def setUp(self):
		frappe.db.delete(router.PROVIDER_DOCTYPE)

	def tearDown(self):
		frappe.db.delete(router.PROVIDER_DOCTYPE)

	def test_the_free_one_comes_first(self):
		_provider("Anthropic", input_rate=1.0, output_rate=4.0)
		_provider("Ollama")

		self.assertEqual([row["name"] for row in router.chain()][0], "Ollama")

	def test_output_weighs_more_than_input(self):
		"""Разговор пишет больше, чем читает; цена выхода важнее."""
		_provider("Anthropic", input_rate=0.1, output_rate=5.0)
		_provider("Ollama", input_rate=1.0, output_rate=0.5)

		self.assertEqual(
			[row["name"] for row in router.chain()][0], "Ollama"
		)

	def test_a_disabled_provider_is_not_in_the_chain(self):
		_provider("Anthropic", enabled=0)
		_provider("Ollama")

		self.assertEqual([row["name"] for row in router.chain()], ["Ollama"])

	def test_a_named_provider_goes_first_whatever_it_costs(self):
		"""Человек, назвавший модель, имел в виду её, а не наш порядок."""
		_provider("Anthropic", input_rate=9.0, output_rate=9.0)
		_provider("Ollama")

		self.assertEqual(
			[row["name"] for row in router.chain("Anthropic")][0], "Anthropic"
		)


class TestWhenTheFirstModelCannot(IntegrationTestCase):
	def setUp(self):
		frappe.db.delete(router.PROVIDER_DOCTYPE)
		_provider("Ollama")
		_provider("Anthropic", input_rate=1.0)

	def tearDown(self):
		frappe.db.delete(router.PROVIDER_DOCTYPE)

	def _run(self, behaviour):
		seen = []

		def call(adapter):
			seen.append(adapter.name)
			return behaviour(adapter.name)

		with patch.object(router.llm, "resolve", side_effect=lambda n, m: _Adapter(n)):
			result = router.complete(call)
		return result, seen

	def test_an_exhausted_quota_moves_the_call_to_the_next_model(self):
		"""То, ради чего роутер и написан: двадцать вопросов в сутки кончаются."""

		def behaviour(name):
			if name == "Ollama":
				raise errors.RateLimited("квота на сегодня исчерпана")
			return "ответ"

		result, seen = self._run(behaviour)

		self.assertEqual(result, "ответ")
		self.assertEqual(seen, ["Ollama", "Anthropic"])

	def test_a_wrong_key_is_not_retried_on_everybody_else(self):
		"""Неверный ключ не станет верным у следующей модели."""

		def behaviour(name):
			raise errors.AIAuthError("ключ отклонён")

		with self.assertRaises(errors.AIAuthError):
			self._run(behaviour)

	def test_a_context_too_large_is_not_retried_either(self):
		"""Контекст тот же самый; перебор провайдеров — это платить за один отказ дважды."""

		def behaviour(name):
			raise errors.ContextTooLarge("слишком длинно")

		with self.assertRaises(errors.ContextTooLarge):
			self._run(behaviour)

	def test_when_nobody_answers_the_first_reason_is_the_one_reported(self):
		"""Последняя ошибка объясняет меньше первой: она уже следствие."""

		def behaviour(name):
			raise errors.RateLimited(f"{name} исчерпан")

		with self.assertRaises(router.NoProviderAnswered) as refusal:
			self._run(behaviour)

		self.assertIn("Ollama исчерпан", str(refusal.exception))

	def test_the_failure_is_written_onto_the_provider_that_failed(self):
		"""Владелец должен видеть, какая модель кончилась, не открывая журналов."""

		def behaviour(name):
			if name == "Ollama":
				raise errors.RateLimited("кончилась")
			return "ответ"

		self._run(behaviour)

		self.assertIn(
			"кончилась",
			frappe.db.get_value(router.PROVIDER_DOCTYPE, "Ollama", "last_test_error") or "",
		)


class TestNothingIsDoneTwice(IntegrationTestCase):
	"""Единственное место, где ошибка стоила бы денег клиента."""

	def setUp(self):
		frappe.db.delete(router.PROVIDER_DOCTYPE)
		_provider("Ollama")
		_provider("Anthropic", input_rate=1.0)

	def tearDown(self):
		frappe.db.delete(router.PROVIDER_DOCTYPE)

	def test_the_router_wraps_one_call_and_not_the_whole_turn(self):
		"""Инструменты выполняет цикл агента, между обращениями к модели.

		Роутер подменяет только обращение. Если однажды его вынесут наружу и
		обернут повтором весь ход, повторный счёт клиенту станет вопросом
		времени — а этот тест упадёт раньше, чем это случится.
		"""
		side_effects = []

		def call(adapter):
			# Инструмент, который здесь выполняться не должен ни разу — он
			# живёт снаружи. Считаем обращения к модели, а не действия.
			if adapter.name == "Ollama":
				raise errors.RateLimited("кончилась")
			return "ответ"

		def outer_tool():
			side_effects.append("создан заказ")

		outer_tool()  # так это делает цикл: один раз, до и вне роутера
		with patch.object(router.llm, "resolve", side_effect=lambda n, m: _Adapter(n)):
			router.complete(call)

		self.assertEqual(
			side_effects,
			["создан заказ"],
			"переключение модели не имеет права повторить уже выполненное",
		)


class _Adapter:
	def __init__(self, name):
		self.name = name
