# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Из чего сложился запрос к модели — то, что видит владелец.

Ассистент сегодня чёрный ящик: он отвечает, но нельзя понять, почему ответ
стоил столько и почему иногда медленно. Когда в контекст добавятся память,
сущности и схемы инструментов, вопрос «почему так дорого» станет ежедневным, и
отвечать на него догадкой нельзя.

Наружу уходят **только названия разделов и числа.** Ни вопроса человека, ни
ответа модели, ни имён клиентов: экран показывает, из чего сложился запрос, а
не что в нём было.
"""

from __future__ import annotations

import json

import frappe

from korkem_ai.korkem_ai import usage

#: Порядок разделов на экране. Инструкция первой, разговор последним — от
#: постоянного к переменному, потому что искать глазами будут переменное.
SECTIONS = (
	"instruction",
	"tools",
	"company_memory",
	"user_memory",
	"conversation",
)


@frappe.whitelist()
def get_prompt_breakdown() -> dict:
	"""Последний запрос по разделам и сводка за неделю."""
	frappe.only_for("System Manager")

	rows = frappe.get_all(
		usage.DOCTYPE,
		filters={"context_breakdown": ["is", "set"]},
		fields=["name", "creation", "context_breakdown"],
		order_by="creation desc",
		limit_page_length=1,
	)
	last = _last(rows[0]) if rows else None

	return {"last_prompt": last, "weekly": _weekly(), "is_empty": last is None}


def _last(row: dict) -> dict | None:
	try:
		data = json.loads(row["context_breakdown"])
	except (TypeError, ValueError):
		# Битая строка — это наша недоделка, а не повод показать человеку
		# ошибку вместо экрана.
		return None

	items = [
		{"id": section, "label": section, "tokens": int(data.get(section) or 0)}
		for section in SECTIONS
		if data.get(section)
	]
	return {
		"total_tokens": sum(item["tokens"] for item in items),
		"items": items,
		"timestamp": row["creation"],
		# Сколько инструментов показали из скольких. Это единственное число, по
		# которому видно, работает ли отбор, — и оно же объясняет самую тяжёлую
		# строку.
		"tools_offered": data.get("tools_offered"),
		"tools_total": data.get("tools_total"),
		"tools_unmatched": bool(data.get("tools_unmatched")),
	}


def _weekly() -> dict:
	"""Неделя, а не всё время: цех живёт неделями, и сравнивать нужно с прошлой."""
	numbers = usage.metrics(days=7)
	return {
		"attempts": numbers["attempts"],
		"answered_first_try": numbers["answered_first_try"],
		"reached_korkem_reserve": numbers["reached_korkem_reserve"],
		"latency_avg_ms": numbers["latency_avg_ms"],
		"latency_p95_ms": numbers["latency_p95_ms"],
		"server_cost_month": numbers["server_cost_month"],
	}
