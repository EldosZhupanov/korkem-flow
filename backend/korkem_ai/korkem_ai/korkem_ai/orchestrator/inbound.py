# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Куда девать сообщение от того, кого мы не знаем.

## Почему этот модуль отдельно, и почему он вернулся

Он назывался `orchestrator/router.py` и был снесён 4 сентября в 02:11 коммитом
`8ac8707`: на его место лёг каскад провайдеров, тоже названный роутером. Два
разных «роутера» — один выбирает модель, другой решает, кому отдать входящее
сообщение, — не могут жить под одним именем, и одно из них молча потеряло сто
восемь строк.

Заметить это было некому: Telegram без токена, WhatsApp без договора, и
`gateway.accept` вызывал функцию, которой больше не существует, — падая
`AttributeError` там, куда никто не писал. Девятнадцать тестов держали границу и
падали с 02:11 до 10:15, а я в ту ночь назвал коммит зелёным, прогнав тесты
одного модуля вместо набора.

## Что он делает

ADR-0003: только маршрут. Определить намерение, отдать умению, которое им
владеет, записать на разговоре, что произошло. Никаких бизнес-правил и никакой
записи в бизнес-данные: умения создают `Pending Action`, а исполняет их
доменный слой после согласия человека (ADR-0015).

ADR-0016: умения — логические роли в этом же процессе, не отдельные службы.

## Кто сюда попадает

Только тот, за кем нет пользователя: неизвестный отправитель в мессенджере.
У связанного человека есть компания и права, и его ведёт настоящий ассистент
через `channels.gateway`. У неизвестного нет ни того, ни другого, и запускать
для него ассистента значило бы показать ему отказ каждого инструмента.
"""

import frappe

from korkem_ai.korkem_ai import budget, usage
from korkem_ai.korkem_ai.agents import sales_agent
from korkem_ai.korkem_ai.orchestrator import intent as intent_module, llm

# intent -> handler. Sprint 1 implements the sales path end to end; the other
# intents are recognised (so they aren't misrouted into it) and answered with a
# holding reply until their own skills land.
SKILL_ROUTES = {
	"new_order_inquiry": sales_agent.handle_inquiry,
}

FALLBACK_REPLIES = {
	"order_status": "Thanks! Let me check on your order and get back to you shortly.",
	"general_question": "Thanks for your message! Someone from our team will reply shortly.",
	"other": "Thanks for reaching out to KORKEM! How can we help you today?",
}


def handle_message(
	conversation_name: str,
	message_text: str,
	request_id: str | None = None,
	channel: str = "App",
) -> dict:
	"""Route one inbound customer message. Returns a summary of what was done."""
	conversation = frappe.get_doc("Agent Conversation", conversation_name)
	try:
		budget.check("Guest")
	except budget.BudgetExceeded as exc:
		reply = str(exc)
		conversation.add_message("Agent", reply)
		return {"status": "refused", "handled": False, "reply": reply}

	# Resolved here only so the spend can be attributed to a provider and a
	# model. That is an accounting need, and accounting must never break the
	# work it accounts for — the same rule `usage.record_turn` exists to hold.
	#
	# Raising here turned a configuration problem into an unexplained routing
	# failure: `AINotConfigured` escaped the whole sales path even when the
	# caller had supplied its own classifier and no provider was needed at all.
	# With `None`, `classify` falls back to `llm.get_provider()` exactly as it
	# did before, and says so in its own words if there is nothing to fall back
	# to.
	adapter = None
	try:
		adapter = llm.resolve(None, None)
	except Exception:
		pass

	try:
		classified = intent_module.classify(message_text, provider=adapter)
	except Exception:
		usage.record_failure(
			adapter=adapter,
			turn_id=request_id,
			request_id=request_id,
			conversation=conversation_name,
			channel=channel,
			user="Guest",
		)
		raise

	usage.record_turn(
		adapter,
		adapter=adapter,
		turn_id=request_id,
		request_id=request_id,
		conversation=conversation_name,
		channel=channel,
		user="Guest",
	)
	intent = classified["intent"]

	conversation.add_message("System", f"Classified intent: {intent}")

	handler = SKILL_ROUTES.get(intent)
	if not handler:
		reply = FALLBACK_REPLIES.get(intent, FALLBACK_REPLIES["other"])
		conversation.add_message("Agent", reply)
		return {"intent": intent, "handled": False, "reply": reply}

	action = handler(conversation_name, classified)
	conversation.add_message(
		"Agent",
		"Thanks! I've prepared a quote for our team to review — we'll confirm shortly.",
	)
	return {"intent": intent, "handled": True, "pending_action": action.name}


def handle_message_async(
	conversation_name: str,
	message_text: str,
	request_id: str | None = None,
	channel: str = "App",
):
	"""Queue routing as a background job.

	Per ADR-0009 an LLM call is a third-party call with unbounded latency and must
	never block a request handler -- the WhatsApp webhook returns immediately and
	the orchestrator runs here.
	"""
	frappe.enqueue(
		"korkem_ai.korkem_ai.orchestrator.inbound.handle_message",
		queue="long",
		conversation_name=conversation_name,
		message_text=message_text,
		request_id=request_id,
		channel=channel,
		job_id=request_id,
		deduplicate=bool(request_id),
	)
