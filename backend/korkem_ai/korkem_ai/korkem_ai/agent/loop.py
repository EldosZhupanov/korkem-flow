# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The agent loop: ask the model, run what it asks for, ask again.

    user message
      -> model
      -> wants a tool?  no  -> answer
                        yes -> is it a write?  yes and unapproved -> STOP, ask
                                               no or approved     -> execute
      -> feed the result back
      -> model
      -> ...

## The property that matters most

A tool whose risk requires confirmation is **not executed** unless its call id
appears in `approved_calls`. The loop stops and reports what it wants to do,
and nothing has happened yet. This is checked by a test that asserts the
handler was never invoked — not merely that the loop reported a pause, because
"asked, then did it anyway" is exactly the failure that would be invisible from
the outside until it deleted something.

Read tools carry no such gate, deliberately: making someone confirm a search is
how confirmation dialogs become a thing people click through without reading,
which is worse than not having them.

## Why the loop is bounded

A model can ask for a tool, receive a result it does not like, and ask again
forever. `MAX_ITERATIONS` bounds one turn. Reaching it is not an error to hide
— the turn ends with whatever prose the model produced plus a note that it
stopped, because silently truncating an agent's reasoning produces answers that
look complete and are not.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field

import frappe

from korkem_ai.korkem_ai.agent import prompt as prompt_module
from korkem_ai.korkem_ai.context import tools as context_tools
from korkem_ai.korkem_ai.orchestrator import llm, router
from korkem_ai.korkem_ai.orchestrator.protocol import (
	AIMessage,
	AIResponse,
	AIToolCall,
	AIToolResult,
	AIUsage,
)
from korkem_ai.korkem_ai.tools import catalog, policy, registry  # noqa: F401 - registers tools

#: How many model round trips one user message may cost.
#:
#: Five is enough for "find the customer, then find their deals, then answer"
#: with room to recover from one bad call, and small enough that a loop cannot
#: quietly spend a fortune.
MAX_ITERATIONS = 5


@dataclass
class TurnResult:
	"""What one user message produced."""

	#: "answered" | "needs_confirmation" | "exhausted"
	status: str
	text: str | None = None

	#: The full exchange, including the assistant's tool requests and their
	#: results, so a caller can persist it and resume the conversation.
	messages: list[AIMessage] = field(default_factory=list)

	#: Set when `status == "needs_confirmation"`: the calls waiting on a human.
	pending: tuple[AIToolCall, ...] = ()

	#: What ran, in order — for the activity trail the UI shows.
	executed: list[dict] = field(default_factory=list)

	usage: AIUsage | None = None


def run_turn(
	history: list[AIMessage],
	*,
	provider=None,
	approved_calls: set[str] | None = None,
	on_event=None,
	run_id: str | None = None,
) -> TurnResult:
	"""Run one turn to completion, a pause for confirmation, or the cap.

	`history` is the conversation so far, ending with the user's new message.
	`approved_calls` are call ids a human has explicitly agreed to; anything
	requiring confirmation and absent from it stops the turn.

	`run_id` — этот ход. Через него пишущие инструменты получают ключ
	однократного выполнения: перезапущенный ход не создаст второй заказ, даже
	если первый успел выполниться и результат до истории не дошёл. Без него
	защиты нет, поэтому вызывающие обязаны его передавать — а те, кто не
	передаёт, платят дубликатом при первом же обрыве.
	"""
	# `provider` передают только тогда, когда вызывающий имел в виду именно его:
	# проверка соединения, тест, разбор одного случая. Обычный ход модель себе
	# не выбирает — её выбирает роутер, и он же меняет её, когда у первой
	# кончилась квота.
	pinned = provider
	approved_calls = approved_calls or set()
	messages = list(history)
	executed: list[dict] = []
	usage_total = AIUsage()

	system = prompt_module.build(
		user_full_name=frappe.utils.get_fullname(frappe.session.user),
		today=frappe.utils.nowdate(),
		role=policy.role_of(),
	)
	# Не весь каталог, а то, о чём спросили. Измерено 4 сентября: схемы
	# 65 инструментов — 93% запроса, ещё до того как человек что-то сказал.
	# Вопрос про склад не нуждается в схемах договоров и рабочих мест.
	#
	# Отбор правилами, а не отдельным вызовом модели: такой вызов стоил бы
	# того же, что мы экономим, и добавил бы задержку к каждому вопросу.
	# Незнакомый вопрос получает весь каталог — молчащий ассистент хуже
	# дорогого.
	tools, tool_context = context_tools.offered(
		_last_question(history), all_specs=registry.offered_to()
	)

	# Из чего сложился этот запрос. Считается здесь, где всё собрано, и
	# записывается один раз за ход: человек должен видеть не сумму, а что
	# именно её создало. Без разбивки «почему так дорого» остаётся догадкой.
	breakdown = _breakdown(system, messages, tool_context)

	def complete_once():
		"""Одно обращение к модели — своей или выбранной роутером.

		Инструменты выполняются ниже, между обращениями. Поэтому смена модели
		внутри хода не может выполнить действие дважды: всё уже сделанное лежит
		в `messages` и уходит следующей модели как факт. Это свойство держится
		на том, что роутер стоит здесь, а не оборачивает весь ход.
		"""
		if pinned is not None:
			return _complete(pinned, system, messages, tools, on_event)
		return router.complete(
			lambda adapter: _complete(adapter, system, messages, tools, on_event),
			turn_id=run_id,
			breakdown=breakdown,
		)

	for _ in range(MAX_ITERATIONS):
		response = complete_once()
		usage_total = _add_usage(usage_total, response.usage)

		if not response.wants_tools:
			if response.text:
				messages.append(AIMessage.assistant(text=response.text))
			return TurnResult(
				status="answered",
				text=response.text,
				messages=messages,
				executed=executed,
				usage=usage_total,
			)

		messages.append(AIMessage.assistant(text=response.text, tool_calls=response.tool_calls))

		blocked = [
			call
			for call in response.tool_calls
			if _needs_approval(call) and call.id not in approved_calls
		]
		if blocked:
			# Nothing has run. The caller shows these to a human, and calls
			# back with their ids in `approved_calls` if the answer is yes.
			return TurnResult(
				status="needs_confirmation",
				text=response.text,
				messages=messages,
				pending=tuple(blocked),
				executed=executed,
				usage=usage_total,
			)

		for call in response.tool_calls:
			result = _run(call, run_id)
			executed.append(result)
			messages.append(
				AIMessage.tool(
					AIToolResult(
						call_id=call.id,
						name=call.name,
						content=json.dumps(result["payload"], default=str),
						is_error=not result["ok"],
					)
				)
			)
			if on_event:
				on_event(_activity(result))

	return TurnResult(
		status="exhausted",
		text=None,
		messages=messages,
		executed=executed,
		usage=usage_total,
	)


def _complete(provider, system, messages, tools, on_event):
	"""One model call, streamed when that buys the user something.

	A provider that streams is consumed incrementally *only* when there is
	somewhere for the fragments to go. With no `on_event` the pieces would be
	joined back together and the difference would be a slower path to the same
	string — so the plain call is used instead.
	"""
	if on_event is None or not getattr(provider, "streams_natively", False):
		return provider.chat(system, messages, tools=tools)

	text_parts: list[str] = []
	calls: tuple[AIToolCall, ...] = ()
	usage = None
	stop_reason = None

	for event in provider.stream(system, messages, tools=tools):
		if event.kind == "text" and event.text:
			text_parts.append(event.text)
			on_event({"type": "delta", "text": event.text})
		elif event.kind == "tool_calls":
			calls = event.tool_calls
		elif event.kind == "done":
			usage = event.usage
			stop_reason = event.stop_reason

	return AIResponse(
		text="".join(text_parts) or None,
		tool_calls=calls,
		usage=usage,
		stop_reason=stop_reason,
	)


def _activity(result: dict) -> dict:
	"""What the user's screen is told a tool did — and nothing more.

	This used to be `{"type": "tool", **result}`, which spread the *entire*
	outcome onto a realtime event, `payload` included. Observed on a live
	socket: a single `crm.search_deals` published fifty complete deal rows to
	the client, which reads only the tool's name and whether it worked.

	Three things were wrong with that. It contradicted the rule
	`registry._log` exists to enforce — tool results carry customer data and do
	not belong in transport that is not the answer itself. It put an unbounded
	result set on every tool call. And none of it was ever used.

	The results still reach the *model*: they are appended to `messages` above,
	which is the only place they are needed.
	"""
	return {
		"type": "tool",
		"tool": result["tool"],
		"ok": result["ok"],
		"call_id": result["call_id"],
	}


def _needs_approval(call: AIToolCall) -> bool:
	"""Unknown tools do not need approval — they need refusing, which the
	registry does when the call is executed. Treating an unknown name as
	"requires confirmation" would put a nonexistent action in front of a user
	to approve, which is worse than an error."""
	spec = registry.find(call.name)
	return bool(spec and spec.requires_confirmation)


def _run(call: AIToolCall, run_id: str | None = None) -> dict:
	if call.malformed:
		# The provider gave us arguments that would not parse. Telling the model
		# so lets it retry; raising would lose the conversation over a stray
		# brace it could have fixed itself.
		return {
			"ok": False,
			"tool": call.name,
			"call_id": call.id,
			"payload": {
				"ok": False,
				"error": {
					"code": "malformed_arguments",
					"message": "Your tool arguments were not valid JSON. Send them again.",
				},
			},
		}

	outcome = registry.execute(call.name, call.arguments, run_id=run_id)
	return {
		"ok": outcome["ok"],
		"tool": call.name,
		"call_id": call.id,
		"payload": outcome,
	}


def _breakdown(system: str, messages, tool_context: dict) -> dict:
	"""Оценка по разделам, а не измерение.

	Токенизатор у каждого провайдера свой, и точное число известно только после
	ответа. Четыре символа на токен — грубое правило, одинаковое для всех
	строк, поэтому сравнивать разделы между собой оно позволяет, а обещать
	точную цену — нет.
	"""
	conversation = sum(len(getattr(m, "text", None) or "") for m in messages)
	return {
		"instruction": len(system or "") // 4,
		"tools": tool_context.get("tokens", 0),
		"conversation": conversation // 4,
		# Память в контекст пока не попадает: Этап 1 её хранит, Этап 2 ещё не
		# подаёт. Ноль здесь — правда, а не заглушка.
		"company_memory": 0,
		"user_memory": 0,
		"tools_offered": tool_context.get("offered"),
		"tools_total": tool_context.get("total"),
		"tools_unmatched": tool_context.get("unmatched"),
	}


def _last_question(history) -> str:
	"""Последнее, что сказал человек.

	По нему выбираются области инструментов. Берётся именно последнее, а не вся
	переписка: разговор мог начаться со склада и перейти к счетам, и отбор
	должен следовать за человеком, а не за тем, с чего он начал.
	"""
	for message in reversed(list(history or ())):
		if getattr(message, "role", None) == "user":
			text = getattr(message, "text", None) or getattr(message, "content", None)
			if isinstance(text, str) and text.strip():
				return text
	return ""


def _add_usage(total: AIUsage, addition: AIUsage | None) -> AIUsage:
	if addition is None:
		return total
	return AIUsage(
		input_tokens=(total.input_tokens or 0) + (addition.input_tokens or 0),
		output_tokens=(total.output_tokens or 0) + (addition.output_tokens or 0),
	)
