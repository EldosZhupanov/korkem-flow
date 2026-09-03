# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Цепочка цифрового администратора — глазами и руками ассистента.

Всё, что здесь есть, уже работало: сервисы `korkem_manufacturing` строились
неделю и покрыты тестами. Не работало другое — **ассистент до них не доставал**.
Владелец мог спросить «сколько заказов», но не мог сказать «запиши: звонил
Данияр, кухня 3200, замерить в четверг», а ровно это и есть продукт.

Найдено замером живого хода: в каталоге 43 инструмента, и ни одного для захвата
сказанного, заявки, замера, КП, договора, дизайна, монтажа, гарантии, счёта — и
для экрана «что застряло», самого полезного вопроса, который задают голосом.

**Каждый инструмент здесь — обёртка над доменным сервисом и ничего больше**
(R1). Правило «монтаж не раньше отгрузки» живёт в `installation.py`, а не тут, и
не должно быть повторено здесь другими словами: два места с одним правилом
однажды разойдутся, и разойдутся молча.

**Запись ждёт человека** (R10). `Risk.WRITE` означает, что вызов не выполнится,
пока владелец не согласится с конкретной фразой. Для «запиши сказанное» это не
формальность: ассистент мог не расслышать, и лучше переспросить, чем завести
заявку на несуществующего клиента.

Чтение — `Risk.READ`: «что застряло сегодня» ничего не меняет, и спрашивать
разрешение на взгляд значило бы сделать взгляд дороже, чем он стоит.
"""

from __future__ import annotations

from korkem_manufacturing.services import attention as attention_service
from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import contract as contract_service
from korkem_manufacturing.services import enquiry as enquiry_service
from korkem_manufacturing.services import measurement as measurement_service

from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register


def record_capture(
	text: str,
	customer_hint: str | None = None,
	assign_to: str | None = None,
	due_on: str | None = None,
):
	"""Записать сказанное. Та самая потеря из блокнота, только теперь её видно."""
	understood = {"customer_hint": customer_hint} if customer_hint else None
	return capture_service.record(
		text=text,
		understood=understood,
		assign_to=assign_to,
		due_on=due_on,
	)


def convert_capture(capture: str, customer: str | None = None, measure_on: str | None = None):
	"""Превратить сказанное в заявку с клиентом."""
	return enquiry_service.convert(
		capture=capture, customer=customer, measure_on=measure_on
	)


def record_measurement(
	enquiry: str,
	dimensions: str | None = None,
	notes: str | None = None,
	address_line: str | None = None,
	city: str | None = None,
):
	"""Записать результат замера на заявку и закрыть задачу замерщика."""
	return measurement_service.record(
		enquiry=enquiry,
		dimensions=dimensions,
		notes=notes,
		address_line=address_line,
		city=city,
	)


def contract_status(sales_order: str):
	"""Что с договором по заказу: есть ли, подписан ли, кем."""
	return contract_service.status(sales_order=sales_order)


def what_needs_attention():
	"""Что застряло: сказанное без исполнителя, просрочки, заказы без дизайна,
	отгруженное без счёта."""
	return attention_service.today()


register(
	ToolSpec(
		name="chain.record_capture",
		description=(
			"Write down what the owner just said, before it is lost — a call, a "
			"walk-in, a message. This is the note that used to live in a paper "
			"notebook. Give the words as spoken; add customer_hint if a name was "
			"said, assign_to (a user id) if somebody should measure, and due_on "
			"as YYYY-MM-DD if a day was named. The user must confirm before this "
			"runs."
		),
		input_schema={
			"type": "object",
			"properties": {
				"text": {
					"type": "string",
					"description": "What was said, in the words it was said in.",
				},
				"customer_hint": {"type": "string", "description": "Customer name, if named."},
				"assign_to": {
					"type": "string",
					"description": "User id of the measurer, from crm.search_users.",
				},
				"due_on": {"type": "string", "description": "When it is due, YYYY-MM-DD."},
			},
			"required": ["text"],
		},
		risk=Risk.WRITE,
		handler=record_capture,
		doctypes=("Capture", "CRM Task"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.convert_capture",
		description=(
			"Turn a written-down note into an enquiry with a customer. Names an "
			"existing customer if one matches, or creates one. Refuses when more "
			"than one customer matches — an ambiguous customer is a question for "
			"the owner, not a guess. The user must confirm before this runs."
		),
		input_schema={
			"type": "object",
			"properties": {
				"capture": {"type": "string", "description": "Id of the note."},
				"customer": {
					"type": "string",
					"description": "Exact customer, when the owner has resolved the ambiguity.",
				},
				"measure_on": {"type": "string", "description": "Measuring day, YYYY-MM-DD."},
			},
			"required": ["capture"],
		},
		risk=Risk.WRITE,
		handler=convert_capture,
		doctypes=("Capture", "Opportunity", "Customer"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.record_measurement",
		description=(
			"Record what the measurer found on site: dimensions as spoken, notes, "
			"and the address. The address becomes a real address on the customer, "
			"because delivery and installation will look for it there. Closes the "
			"measurer's task. The user must confirm before this runs."
		),
		input_schema={
			"type": "object",
			"properties": {
				"enquiry": {"type": "string", "description": "The enquiry (Opportunity) id."},
				"dimensions": {
					"type": "string",
					"description": "Sizes as the measurer says them, e.g. 3200x600, высота 2100.",
				},
				"notes": {"type": "string", "description": "What was seen on site."},
				"address_line": {"type": "string"},
				"city": {"type": "string"},
			},
			"required": ["enquiry"],
		},
		risk=Risk.WRITE,
		handler=record_measurement,
		doctypes=("Opportunity", "Address", "CRM Task"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.contract_status",
		description=(
			"Whether the contract for a sales order exists, is signed, by whom "
			"and when."
		),
		input_schema={
			"type": "object",
			"properties": {"sales_order": {"type": "string"}},
			"required": ["sales_order"],
		},
		risk=Risk.READ,
		handler=contract_status,
		doctypes=("Contract",),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.what_needs_attention",
		description=(
			"What is stuck today, in four lists: things said and handed to "
			"nobody, overdue measurements and installations, submitted orders "
			"with no design assigned, and furniture delivered but not invoiced. "
			"This is the question a factory owner asks every morning."
		),
		input_schema={"type": "object", "properties": {}},
		risk=Risk.READ,
		handler=what_needs_attention,
		doctypes=("Capture", "CRM Task", "Sales Order"),
		audit_category="chain",
	)
)
