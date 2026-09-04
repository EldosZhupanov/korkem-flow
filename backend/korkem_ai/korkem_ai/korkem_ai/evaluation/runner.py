# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Прогон проверок: как их считают, где хранят и почему не в запросе.

## Почему прогон уходит в очередь

Один сценарий — это обращение к модели, иногда два. Пять сценариев — до десятка
обращений с неограниченной задержкой у чужого сервиса. Держать на них
gunicorn-воркера значит занять одного из тридцати трёх на минуту (ADR-0009).
Поэтому `run_check` заводит строку со статусом «идёт» и ставит задачу, а экран
опрашивает `get_last_run`, пока статус не сменится.

## Почему прогон не может ничего записать

`run_turn` получает пустой список одобренных вызовов. Инструмент, требующий
подтверждения, останавливает ход и попадает в предложения — не в выполнение.
Единственный способ что-то записать при таком прогоне — чтобы заслон
подтверждения перестал держать, и тогда прогон скажет об этом словами
«выполнил запись без подтверждения» вместо того, чтобы промолчать.

## Почему модель выбирает роутер, а не проверка

Смысл экрана — «работает ли ассистент так, как он настроен сейчас». Прогон с
закреплённой моделью отвечает на другой вопрос и в норме не нужен; параметр
оставлен для тестов и разбора одного случая, но наружу не вынесен.
"""

from __future__ import annotations

import json
import time

import frappe

from korkem_ai.korkem_ai import errors
from korkem_ai.korkem_ai.agent import loop
from korkem_ai.korkem_ai.evaluation import scenarios as catalogue
from korkem_ai.korkem_ai.evaluation.scenarios import Scenario, TurnFacts, judge
from korkem_ai.korkem_ai.orchestrator.protocol import AIMessage
from korkem_ai.korkem_ai.tools import registry

DOCTYPE = "Assistant Check Run"

RUNNING = "running"
COMPLETED = "completed"
FAILED = "failed"


def start(company: str | None = None, user: str | None = None) -> str:
	"""Заводит строку прогона и ставит задачу. Возвращает её имя."""
	doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"company": company,
			"status": RUNNING,
			"started_at": frappe.utils.now_datetime(),
			"total_count": len(catalogue.CATALOGUE),
			"passed_count": 0,
			"scenarios": "[]",
		}
	)
	doc.insert(ignore_permissions=True)

	# `enqueue_after_commit`, а не `frappe.db.commit()` здесь. Строка обязана
	# быть видна воркеру до того, как он за неё возьмётся, — но коммит посреди
	# запроса закрывает чужую транзакцию, и в тестах это отменяет откат, на
	# котором держится их изоляция. Сначала здесь стоял именно коммит, и после
	# первого же прогона тестов его строка осталась в базе стенда — то есть
	# откат её уже не покрывал. Фиксирует Frappe, в конце запроса; задача
	# уходит в очередь после этого.
	frappe.enqueue(
		"korkem_ai.korkem_ai.evaluation.runner.run_job",
		queue="long",
		timeout=900,
		run_name=doc.name,
		user=user or frappe.session.user,
		job_id=f"assistant-check:{doc.name}",
		deduplicate=True,
		enqueue_after_commit=True,
	)
	return doc.name


def run_job(run_name: str, user: str):
	"""Фоновая половина. Работает от лица человека, не от Administrator.

	Иначе проверка ходила бы по базе с правами админа и отвечала бы «прошло»
	там, где у самого человека прав нет, — то есть отвечала бы не на тот вопрос.

	Ни одного коммита здесь нет намеренно: падение прогона мы ловим сами, и
	обёртка задачи видит успех — значит фиксирует Frappe, как и у всякой другой
	задачи. Свой коммит нужен был бы только чтобы закрыть чужую транзакцию.
	"""
	frappe.set_user(user)
	doc = frappe.get_doc(DOCTYPE, run_name)
	try:
		results = run_all(run_id=run_name)
	except Exception as exc:  # noqa: BLE001 — причина уходит человеку словами
		frappe.log_error(title="Assistant check failed", message=frappe.get_traceback())
		doc.status = FAILED
		doc.failure_reason = errors.message_for(errors.classify(exc))
		doc.finished_at = frappe.utils.now_datetime()
		doc.save(ignore_permissions=True)
		return

	doc.status = COMPLETED
	doc.scenarios = json.dumps(results, ensure_ascii=False)
	doc.passed_count = sum(1 for row in results if row["passed"])
	doc.total_count = len(results)
	doc.finished_at = frappe.utils.now_datetime()
	doc.save(ignore_permissions=True)


def run_all(*, run_id: str | None = None, provider=None) -> list[dict]:
	"""Прогоняет весь набор и возвращает строки для экрана."""
	return [
		run_one(scenario, run_id=run_id, provider=provider)
		for scenario in catalogue.CATALOGUE
	]


def run_one(scenario: Scenario, *, run_id: str | None = None, provider=None) -> dict:
	"""Один сценарий. Его падение — результат сценария, а не всего прогона.

	Кончившаяся квота на третьем сценарии не должна стирать первые два: то, что
	успело проверить себя, владелец должен увидеть.
	"""
	started = time.monotonic()
	try:
		facts = _observe(scenario, run_id=run_id, provider=provider)
	except Exception as exc:  # noqa: BLE001 — причина уходит человеку словами
		return {
			"id": scenario.id,
			"name": scenario.name,
			"passed": False,
			"duration_seconds": round(time.monotonic() - started, 1),
			"failure_reason": errors.message_for(errors.classify(exc)),
		}

	reason = judge(scenario, facts)
	row = {
		"id": scenario.id,
		"name": scenario.name,
		"passed": reason is None,
		"duration_seconds": round(time.monotonic() - started, 1),
	}
	if reason is not None:
		row["failure_reason"] = reason
	return row


def _observe(scenario: Scenario, *, run_id: str | None, provider=None) -> TurnFacts:
	"""Один ход ассистента, сведённый к тому, что он сделал."""
	result = loop.run_turn(
		[AIMessage.user(scenario.message)],
		provider=provider,
		run_id=f"{run_id or 'check'}:{scenario.id}",
	)

	executed = tuple(call["tool"] for call in result.executed)
	proposed = tuple(call.name for call in result.pending)
	return TurnFacts(
		status=result.status,
		executed=executed,
		wrote=tuple(name for name in executed if _writes(name)),
		proposed=proposed,
		tools_used=frozenset(executed) | frozenset(proposed),
	)


def _writes(tool_name: str) -> bool:
	spec = registry.find(tool_name)
	return bool(spec and spec.requires_confirmation)
