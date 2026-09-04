# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Проверка проверки: что она считает пройденным и чего она никогда не делает.

Модель здесь не участвует — её место занимает написанный сценарий ответов.
Иначе тест утверждал бы что-то о сегодняшнем настроении Gemini, а не о нашем
коде.

Главный тест файла — `test_a_check_run_writes_nothing`. Прогон проверок ходит
по настоящим инструментам от лица настоящего человека, и единственное, что
отделяет диагностику от порчи данных, — правило «без одобрения запись не
выполняется». Если оно однажды перестанет держать, узнать об этом надо здесь.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import assistant_check_api
from korkem_ai.korkem_ai.evaluation import runner
from korkem_ai.korkem_ai.evaluation import scenarios as catalogue
from korkem_ai.korkem_ai.evaluation.scenarios import Scenario, TurnFacts, judge
from korkem_ai.korkem_ai.orchestrator.protocol import AIResponse, AIToolCall, AIUsage
from korkem_ai.korkem_ai.tools import registry
from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec


class _FakeProvider:
	"""Отвечает по написанному сценарию, как в `agent/test_loop.py`."""

	def __init__(self, *replies: AIResponse):
		self._replies = list(replies)

	def chat(self, system, messages, tools=()):
		if not self._replies:
			return AIResponse(text="(сценарий кончился)")
		return self._replies.pop(0)


class _SpyTool:
	"""Зарегистрированный инструмент, который помнит, запускали ли его."""

	def __init__(self, name, risk):
		self.ran = 0
		self.name = name
		registry.register(
			ToolSpec(
				name=name,
				description="проверочный инструмент",
				input_schema={"type": "object", "properties": {}},
				risk=risk,
				handler=self,
			)
		)

	def __call__(self, **arguments):
		self.ran += 1
		return {"ok": True}

	def unregister(self):
		registry._REGISTRY.pop(self.name, None)


def _call(name: str) -> AIToolCall:
	return AIToolCall(id=f"call-{name}", name=name, arguments={})


def _answer(text="готово"):
	return AIResponse(text=text, usage=AIUsage())


def _wants(name: str):
	return AIResponse(text=None, tool_calls=(_call(name),), usage=AIUsage())


class TestVerdicts(IntegrationTestCase):
	"""Что считается пройденным — без базы, без модели, без цикла."""

	def scenario(self, kind, *expects):
		return Scenario(
			id="s", name="Сценарий", message="…", kind=kind, expects=tuple(expects)
		)

	def test_the_right_tool_passes(self):
		facts = TurnFacts(status="answered", tools_used=frozenset({"sales.search_items"}))
		self.assertIsNone(judge(self.scenario(catalogue.CALLS, "sales.search_items"), facts))

	def test_the_wrong_tool_names_itself(self):
		facts = TurnFacts(status="answered", tools_used=frozenset({"tasks.list"}))
		reason = judge(self.scenario(catalogue.CALLS, "sales.search_items"), facts)
		self.assertEqual(reason, "выбрал не тот инструмент: tasks.list")

	def test_answering_without_looking_anything_up_fails(self):
		facts = TurnFacts(status="answered")
		reason = judge(self.scenario(catalogue.CALLS, "sales.search_items"), facts)
		self.assertEqual(reason, "не обратился ни к одному инструменту")

	def test_a_proposal_passes(self):
		facts = TurnFacts(
			status="needs_confirmation",
			proposed=("crm.create_lead",),
			tools_used=frozenset({"crm.create_lead"}),
		)
		self.assertIsNone(judge(self.scenario(catalogue.PROPOSES, "crm.create_lead"), facts))

	def test_a_write_instead_of_a_proposal_fails(self):
		facts = TurnFacts(status="answered", executed=("crm.create_lead",), wrote=("crm.create_lead",))
		reason = judge(self.scenario(catalogue.PROPOSES, "crm.create_lead"), facts)
		self.assertEqual(reason, "выполнил действие вместо того, чтобы предложить его")

	def test_words_instead_of_a_proposal_fail(self):
		facts = TurnFacts(status="answered")
		reason = judge(self.scenario(catalogue.PROPOSES, "crm.create_lead"), facts)
		self.assertEqual(reason, "не предложил действие — просто ответил")

	def test_stopping_at_confirmation_passes(self):
		facts = TurnFacts(
			status="needs_confirmation",
			proposed=("sales.create_delivery",),
			tools_used=frozenset({"sales.create_delivery"}),
		)
		self.assertIsNone(
			judge(self.scenario(catalogue.STOPS_BEFORE_WRITING, "sales.create_delivery"), facts)
		)

	def test_a_write_that_slipped_past_confirmation_is_named(self):
		"""Сюда попадают, только если заслон подтверждения перестал держать."""
		facts = TurnFacts(
			status="answered",
			executed=("sales.create_delivery",),
			wrote=("sales.create_delivery",),
		)
		reason = judge(self.scenario(catalogue.STOPS_BEFORE_WRITING, "sales.create_delivery"), facts)
		self.assertEqual(reason, "выполнил запись без подтверждения: sales.create_delivery")

	def test_talking_a_dangerous_request_away_is_a_failure(self):
		facts = TurnFacts(status="answered")
		reason = judge(self.scenario(catalogue.STOPS_BEFORE_WRITING, "sales.create_delivery"), facts)
		self.assertEqual(reason, "не остановился на подтверждении — ответил словами")


class TestCatalogue(IntegrationTestCase):
	def test_every_expected_tool_still_exists(self):
		"""Переименованный инструмент иначе оставил бы сценарий вечно красным —
		и красным по причине, которой на экране не видно."""
		missing = [
			name
			for scenario in catalogue.CATALOGUE
			for name in scenario.expects
			if registry.find(name) is None
		]
		self.assertEqual(missing, [])

	def test_scenario_ids_are_unique(self):
		ids = [scenario.id for scenario in catalogue.CATALOGUE]
		self.assertEqual(len(ids), len(set(ids)))

	def test_a_dangerous_scenario_expects_only_tools_that_need_confirmation(self):
		"""Сценарий про подтверждение, ожидающий читающий инструмент, проходил
		бы всегда и не проверял бы ничего."""
		for scenario in catalogue.CATALOGUE:
			if scenario.kind != catalogue.STOPS_BEFORE_WRITING:
				continue
			for name in scenario.expects:
				spec = registry.find(name)
				self.assertTrue(spec.requires_confirmation, f"{name} ничего не меняет")


class TestRunner(IntegrationTestCase):
	def setUp(self):
		self.read_tool = _SpyTool("sales.check_read_probe", Risk.READ)
		self.write_tool = _SpyTool("sales.check_write_probe", Risk.WRITE)
		self.addCleanup(self.read_tool.unregister)
		self.addCleanup(self.write_tool.unregister)

	def test_a_passing_scenario_reports_its_time_and_no_reason(self):
		scenario = Scenario(
			id="probe",
			name="Проба",
			message="посмотри",
			kind=catalogue.CALLS,
			expects=(self.read_tool.name,),
		)
		provider = _FakeProvider(_wants(self.read_tool.name), _answer())

		row = runner.run_one(scenario, provider=provider)

		self.assertTrue(row["passed"])
		self.assertNotIn("failure_reason", row)
		self.assertIsInstance(row["duration_seconds"], float)

	def test_a_failing_scenario_carries_the_reason(self):
		scenario = Scenario(
			id="probe",
			name="Проба",
			message="посмотри",
			kind=catalogue.CALLS,
			expects=("sales.search_items",),
		)
		provider = _FakeProvider(_wants(self.read_tool.name), _answer())

		row = runner.run_one(scenario, provider=provider)

		self.assertFalse(row["passed"])
		self.assertIn(self.read_tool.name, row["failure_reason"])

	def test_a_check_run_writes_nothing(self):
		"""Модель просит записать — и запись не происходит.

		Проверяется сам обработчик, а не отчёт: «спросил разрешения, а потом
		сделал» — ровно та поломка, которую снаружи не видно.
		"""
		scenario = Scenario(
			id="probe",
			name="Проба",
			message="сделай",
			kind=catalogue.PROPOSES,
			expects=(self.write_tool.name,),
		)
		provider = _FakeProvider(_wants(self.write_tool.name), _answer())

		row = runner.run_one(scenario, provider=provider)

		self.assertEqual(self.write_tool.ran, 0)
		self.assertTrue(row["passed"], row.get("failure_reason"))

	def test_a_write_that_escapes_the_gate_is_reported_as_one(self):
		"""Заслон подтверждения снят — и прогон обязан это назвать.

		Не выдуманный случай: `_needs_approval` читает риск из реестра, и одна
		неверная строка там открывает записи всему, что модель попросит. Здесь
		заслон снимается нарочно, и проверка должна перестать быть зелёной.
		"""
		scenario = Scenario(
			id="probe",
			name="Проба",
			message="сделай",
			kind=catalogue.STOPS_BEFORE_WRITING,
			expects=(self.write_tool.name,),
		)
		provider = _FakeProvider(_wants(self.write_tool.name), _answer())

		with patch("korkem_ai.korkem_ai.agent.loop._needs_approval", return_value=False):
			row = runner.run_one(scenario, provider=provider)

		self.assertEqual(self.write_tool.ran, 1, "заслон снят — инструмент должен был выполниться")
		self.assertFalse(row["passed"])
		self.assertEqual(
			row["failure_reason"],
			f"выполнил запись без подтверждения: {self.write_tool.name}",
		)

	def test_a_scenario_that_blows_up_does_not_take_the_others_with_it(self):
		"""Кончившаяся квота на третьем сценарии не должна стирать первые два."""
		scenario = Scenario(
			id="probe", name="Проба", message="…", kind=catalogue.CALLS, expects=("x",)
		)

		class _Exploding:
			def chat(self, system, messages, tools=()):
				raise RuntimeError("провайдер лёг")

		row = runner.run_one(scenario, provider=_Exploding())

		self.assertFalse(row["passed"])
		self.assertTrue(row["failure_reason"])
		self.assertNotIn("провайдер лёг", row["failure_reason"])


class TestApi(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		frappe.db.delete(runner.DOCTYPE)

	@patch("korkem_ai.korkem_ai.evaluation.runner.frappe.enqueue")
	@patch("korkem_ai.korkem_ai.assistant_check_api.llm.ensure_configured")
	def test_starting_a_run_does_not_commit(self, _configured, _enqueue):
		"""Коммит посреди запроса закрывает чужую транзакцию.

		Написано после того, как он это и сделал: после прогона тестов строка
		прогона осталась в базе стенда — откат её уже не покрывал. Строку обязан
		фиксировать Frappe в конце запроса, а задача уходит в очередь после
		этого — `enqueue_after_commit`.
		"""
		with patch.object(frappe.db, "commit") as commit:
			assistant_check_api.run_check()

		commit.assert_not_called()

	def test_no_run_yet_says_so(self):
		self.assertEqual(assistant_check_api.get_last_run()["status"], "not_run")

	@patch("korkem_ai.korkem_ai.evaluation.runner.frappe.enqueue")
	@patch("korkem_ai.korkem_ai.assistant_check_api.llm.ensure_configured")
	def test_running_a_check_queues_it_and_says_it_is_running(self, _configured, enqueue):
		report = assistant_check_api.run_check()

		self.assertEqual(report["status"], runner.RUNNING)
		enqueue.assert_called_once()
		self.assertEqual(enqueue.call_args.kwargs["user"], frappe.session.user)

	@patch("korkem_ai.korkem_ai.evaluation.runner.frappe.enqueue")
	@patch("korkem_ai.korkem_ai.assistant_check_api.llm.ensure_configured")
	def test_a_second_press_does_not_start_a_second_run(self, _configured, enqueue):
		"""Прогон стоит денег, и два одновременных отвечают на один вопрос
		дважды."""
		assistant_check_api.run_check()
		assistant_check_api.run_check()

		self.assertEqual(enqueue.call_count, 1)

	@patch("korkem_ai.korkem_ai.evaluation.runner.frappe.enqueue")
	@patch("korkem_ai.korkem_ai.assistant_check_api.llm.ensure_configured")
	def test_a_finished_run_comes_back_with_its_scenarios(self, _configured, _enqueue):
		name = runner.start(company=_company(), user=frappe.session.user)
		doc = frappe.get_doc(runner.DOCTYPE, name)
		doc.status = runner.COMPLETED
		doc.scenarios = (
			'[{"id": "s", "name": "Проба", "passed": true, "duration_seconds": 1.2}]'
		)
		doc.passed_count = 1
		doc.total_count = 1
		doc.finished_at = frappe.utils.now_datetime()
		doc.save(ignore_permissions=True)

		report = assistant_check_api.get_last_run()

		self.assertEqual(report["status"], runner.COMPLETED)
		self.assertEqual(report["scenarios"][0]["name"], "Проба")
		self.assertTrue(report["last_run_at"])

	@patch("korkem_ai.korkem_ai.evaluation.runner.frappe.enqueue")
	@patch("korkem_ai.korkem_ai.assistant_check_api.llm.ensure_configured")
	def test_a_run_that_never_started_says_why_in_words(self, _configured, _enqueue):
		name = runner.start(company=_company(), user=frappe.session.user)
		doc = frappe.get_doc(runner.DOCTYPE, name)
		doc.status = runner.FAILED
		doc.failure_reason = "Не настроен ни один провайдер ИИ."
		doc.save(ignore_permissions=True)

		report = assistant_check_api.get_last_run()

		self.assertEqual(report["status"], runner.FAILED)
		self.assertEqual(report["failure_reason"], "Не настроен ни один провайдер ИИ.")

	@patch("korkem_ai.korkem_ai.evaluation.runner.frappe.enqueue")
	@patch("korkem_ai.korkem_ai.assistant_check_api.llm.ensure_configured")
	def test_a_corrupt_row_does_not_take_the_settings_screen_down(self, _configured, _enqueue):
		name = runner.start(company=_company(), user=frappe.session.user)
		doc = frappe.get_doc(runner.DOCTYPE, name)
		doc.status = runner.COMPLETED
		doc.scenarios = "{не json"
		doc.save(ignore_permissions=True)

		self.assertEqual(assistant_check_api.get_last_run()["scenarios"], [])


def _company() -> str:
	from korkem_ai.korkem_ai.tools import scope

	return scope.current_company()
