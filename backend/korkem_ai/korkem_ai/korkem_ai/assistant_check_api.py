# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Проверка ассистента — то, что видит владелец перед сменой модели.

## Зачем

Модель меняется одним полем в настройках, а ломается от этого поведение: другая
модель иначе выбирает инструменты, иначе понимает «заведи заявку», иначе ведёт
себя, когда её просят сделать запись без подтверждения. До сих пор мы узнавали
об этом от владельца — то есть после того, как ассистент подвёл его при людях.

Здесь набор сценариев цеха, который можно прогнать по кнопке и увидеть, какие
прошли. Что именно проверяется и почему — в `evaluation/scenarios.py`.

## Почему System Manager

Прогон тратит чужие деньги: это до десятка обращений к модели. Тем же
`frappe.only_for("System Manager")`, что и остальные настройки ИИ, — пользоваться
ассистентом может каждый, проверять и настраивать его не каждый.

## Почему `run_check` возвращает «идёт», а не результат

ADR-0009. Держать HTTP-запрос на времени чужого сервиса нельзя, а пять сценариев
— это до минуты. Ставится задача, экран опрашивает `get_last_run`.
"""

from __future__ import annotations

import json

import frappe

from korkem_ai.korkem_ai.evaluation import runner
from korkem_ai.korkem_ai.orchestrator import llm
from korkem_ai.korkem_ai.tools import scope


@frappe.whitelist()
def get_last_run() -> dict:
	"""Последний прогон этой компании — или «не запускалась»."""
	frappe.only_for("System Manager")
	doc = _latest(scope.current_company())
	return _report(doc)


@frappe.whitelist()
def run_check() -> dict:
	"""Ставит прогон в очередь и возвращает его как идущий.

	Провайдер проверяется до очереди, по той же причине, что и в `chat.send`:
	самая частая причина «ничего не работает» — ненастроенная модель, и об этом
	надо сказать сразу и словами, а не уронить прогон внутри воркера.
	"""
	frappe.only_for("System Manager")
	llm.ensure_configured()

	company = scope.current_company()
	previous = _latest(company)
	if previous and previous.status == runner.RUNNING:
		# Второе нажатие не заводит второй прогон: он стоит денег, и два
		# одновременных ответили бы на один вопрос дважды.
		return _report(previous)

	runner.start(company=company, user=frappe.session.user)
	return {
		"status": runner.RUNNING,
		"last_run_at": _finished_at(previous),
		"scenarios": [],
	}


def _latest(company: str):
	names = frappe.get_all(
		runner.DOCTYPE,
		filters={"company": company},
		order_by="creation desc",
		limit=1,
		pluck="name",
	)
	return frappe.get_doc(runner.DOCTYPE, names[0]) if names else None


def _report(doc) -> dict:
	if doc is None:
		return {"status": "not_run", "scenarios": []}

	report = {
		"status": doc.status,
		"last_run_at": _finished_at(doc),
		"scenarios": _scenarios(doc),
	}
	if doc.failure_reason:
		report["failure_reason"] = doc.failure_reason
	return report


def _scenarios(doc) -> list:
	try:
		rows = json.loads(doc.scenarios or "[]")
	except ValueError:
		# Испорченная строка — это отсутствие результата, а не повод уронить
		# экран настроек целиком.
		return []
	return rows if isinstance(rows, list) else []


def _finished_at(doc) -> str | None:
	if doc is None or not doc.finished_at:
		return None
	return str(doc.finished_at)
