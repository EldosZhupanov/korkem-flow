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


# --------------------------------------------------------------------------
# Дальше по цепочке: КП, договор, дизайн, монтаж, гарантия, счёт
#
# До этих сервисов ассистент не доставал вовсе. Владелец мог спросить «сколько
# заказов», но после замера немел: «отправь предложение», «поручи чертёж»,
# «клиент звонит, отвалилась петля» — ни на что из этого не было инструмента,
# хотя сервисы под ними работают и покрыты тестами.
# --------------------------------------------------------------------------

from korkem_manufacturing.services import acceptance as acceptance_service
from korkem_manufacturing.services import catalogue as catalogue_service
from korkem_manufacturing.services import design as design_service
from korkem_manufacturing.services import installation as installation_service
from korkem_manufacturing.services import invoicing as invoicing_service
from korkem_manufacturing.services import proposal as proposal_service
from korkem_manufacturing.services import warranty as warranty_service


def draft_proposal(enquiry: str, items: list | None = None, valid_days: int = 14):
	"""Собрать КП по заявке."""
	return proposal_service.draft(enquiry=enquiry, items=items, valid_days=valid_days)


def accept_proposal(quotation: str, deliver_on: str):
	"""Превратить согласованное КП в заказ."""
	return acceptance_service.accept(quotation=quotation, deliver_on=deliver_on)


def draft_contract(sales_order: str, terms: str | None = None):
	"""Собрать договор по заказу."""
	return contract_service.draft(sales_order=sales_order, terms=terms)


def sign_contract(contract: str, signee: str, signed_on: str | None = None):
	"""Отметить, что договор подписан — кем и когда."""
	return contract_service.sign(contract=contract, signee=signee, signed_on=signed_on)


def assign_design(sales_order: str, designer: str, due_on: str):
	"""Поручить дизайн по заказу, со сроком."""
	return design_service.assign(sales_order=sales_order, designer=designer, due_on=due_on)


def deliver_design(sales_order: str):
	"""Принять дизайн — сервис откажет, если чертежа нет."""
	return design_service.deliver(sales_order=sales_order)


def schedule_installation(sales_order: str, installer: str, install_on: str):
	"""Назначить монтаж — сервис откажет, если ещё не отгружено."""
	return installation_service.schedule(
		sales_order=sales_order, installer=installer, install_on=install_on
	)


def complete_installation(sales_order: str, notes: str | None = None):
	"""Закрыть монтаж, с заметками, если они есть."""
	return installation_service.complete(sales_order=sales_order, notes=notes)


def warranty_status(sales_order: str):
	"""Что с гарантией по заказу: с какого дня, по какой, действует ли."""
	return warranty_service.status(sales_order=sales_order)


def warranty_claim(sales_order: str, item_code: str, complaint: str):
	"""Принять рекламацию — сервис откажет, если гарантия истекла, и назовёт дату."""
	return warranty_service.claim(
		sales_order=sales_order, item_code=item_code, complaint=complaint
	)


def draft_invoice(sales_order: str):
	"""Собрать счёт — сервис откажет, если ничего не отгружено."""
	return invoicing_service.draft(sales_order=sales_order)


def catalogue_units():
	"""Единицы измерения, которые имеет смысл предлагать."""
	return {"units": catalogue_service.units()}


def catalogue_items(query: str | None = None, limit: int = 50):
	"""Номенклатура с ценами; поиск идёт по коду и названию."""
	return {"items": catalogue_service.items(query=query, limit=limit)}


def create_item(
	name: str,
	unit: str,
	code: str | None = None,
	description: str | None = None,
	price: float | None = None,
):
	"""Завести позицию каталога. Цена необязательна."""
	return catalogue_service.create(
		name=name, unit=unit, code=code, description=description, price=price
	)


def set_item_price(code: str, price: float):
	"""Назвать цену позиции — в том прайс-листе, из которого её читает КП."""
	return catalogue_service.set_price(code=code, price=price)


def enquiry_candidates(name_said: str):
	"""Клиенты, на которых похоже названное имя — чтобы выбрал человек."""
	return {"candidates": enquiry_service.candidates(name_said)}


def capture_stats(days: int = 30):
	"""Сколько сказанного поймано, передано, доведено до заказа и потеряно."""
	return capture_service.stats(days=days)


_ORDER = {"type": "object", "properties": {"sales_order": {"type": "string"}}, "required": ["sales_order"]}


register(
	ToolSpec(
		name="chain.draft_proposal",
		description=(
			"Draft a quotation for an enquiry. Items are required — an empty "
			"quotation is refused. Each item is {item_code, qty, rate}; find "
			"item_code with chain.catalogue_items. The user must confirm."
		),
		input_schema={
			"type": "object",
			"properties": {
				"enquiry": {"type": "string", "description": "Enquiry (Opportunity) id."},
				"items": {
					"type": "array",
					"description": "Lines: item_code, qty, and rate when it differs from the price list.",
					"items": {"type": "object"},
				},
				"valid_days": {"type": "integer", "description": "How long the price holds."},
			},
			"required": ["enquiry", "items"],
		},
		risk=Risk.WRITE,
		handler=draft_proposal,
		doctypes=("Quotation", "Opportunity"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.accept_proposal",
		description=(
			"Turn a quotation the customer agreed to into a sales order. The "
			"delivery date is required: an order without a date is a promise "
			"nobody made. The user must confirm."
		),
		input_schema={
			"type": "object",
			"properties": {
				"quotation": {"type": "string"},
				"deliver_on": {"type": "string", "description": "Delivery date, YYYY-MM-DD."},
			},
			"required": ["quotation", "deliver_on"],
		},
		risk=Risk.WRITE,
		handler=accept_proposal,
		doctypes=("Quotation", "Sales Order"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.draft_contract",
		description=(
			"Draft the contract for a sales order. Without terms, it lists what "
			"was agreed — the legal wording is the company's own. The user must "
			"confirm."
		),
		input_schema={
			"type": "object",
			"properties": {"sales_order": {"type": "string"}, "terms": {"type": "string"}},
			"required": ["sales_order"],
		},
		risk=Risk.WRITE,
		handler=draft_contract,
		doctypes=("Contract", "Sales Order"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.sign_contract",
		description=(
			"Record that a contract was signed, by whom and when. A signature "
			"without a name is refused. The user must confirm."
		),
		input_schema={
			"type": "object",
			"properties": {
				"contract": {"type": "string"},
				"signee": {"type": "string", "description": "Who signed, as a person's name."},
				"signed_on": {"type": "string", "description": "YYYY-MM-DD; today if omitted."},
			},
			"required": ["contract", "signee"],
		},
		risk=Risk.WRITE,
		handler=sign_contract,
		doctypes=("Contract",),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.assign_design",
		description=(
			"Assign the drawing for an order, with a deadline. A task without a "
			"date is a wish. The designer is a user id — find it with "
			"crm.search_users. The user must confirm."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {"type": "string"},
				"designer": {"type": "string", "description": "User id, from crm.search_users."},
				"due_on": {"type": "string", "description": "YYYY-MM-DD."},
			},
			"required": ["sales_order", "designer", "due_on"],
		},
		risk=Risk.WRITE,
		handler=assign_design,
		doctypes=("CRM Task", "Sales Order"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.deliver_design",
		description=(
			"Accept the design as done. Refused unless a file is attached to the "
			"order: a drawing that was spoken about is not a drawing. The user "
			"must confirm."
		),
		input_schema=_ORDER,
		risk=Risk.WRITE,
		handler=deliver_design,
		doctypes=("CRM Task", "File", "Sales Order"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.schedule_installation",
		description=(
			"Schedule the installation crew. Refused until something has "
			"shipped — a crew arriving without the furniture loses a day and the "
			"customer's trust. The user must confirm."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {"type": "string"},
				"installer": {"type": "string", "description": "User id of the fitter or crew."},
				"install_on": {"type": "string", "description": "YYYY-MM-DD."},
			},
			"required": ["sales_order", "installer", "install_on"],
		},
		risk=Risk.WRITE,
		handler=schedule_installation,
		doctypes=("CRM Task", "Sales Order"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.complete_installation",
		description=(
			"Close the installation. Notes are optional but stay on the order — "
			"a year later, during a warranty claim, they are worth more than the "
			"fact that it was closed. The user must confirm."
		),
		input_schema={
			"type": "object",
			"properties": {"sales_order": {"type": "string"}, "notes": {"type": "string"}},
			"required": ["sales_order"],
		},
		risk=Risk.WRITE,
		handler=complete_installation,
		doctypes=("CRM Task", "Sales Order"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.warranty_status",
		description=(
			"Warranty on an order: from which day, until which, and whether it "
			"still holds. Counted from the first shipment, not from the order."
		),
		input_schema=_ORDER,
		risk=Risk.READ,
		handler=warranty_status,
		doctypes=("Sales Order", "Delivery Note", "Item"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.warranty_claim",
		description=(
			"Accept a warranty claim — the customer calls, a hinge came off. "
			"Refused with the expiry date when the warranty has run out. The "
			"complaint text is required. The user must confirm."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {"type": "string"},
				"item_code": {"type": "string", "description": "Which item, from chain.warranty_status."},
				"complaint": {"type": "string", "description": "What happened, in the customer's words."},
			},
			"required": ["sales_order", "item_code", "complaint"],
		},
		risk=Risk.WRITE,
		handler=warranty_claim,
		doctypes=("Warranty Claim", "Sales Order"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.draft_invoice",
		description=(
			"Draft the invoice for an order. Refused unless something has "
			"shipped: invoicing furniture that has not arrived is the fastest "
			"way to lose a happy customer. The user must confirm."
		),
		input_schema=_ORDER,
		risk=Risk.WRITE,
		handler=draft_invoice,
		doctypes=("Sales Invoice", "Sales Order"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.catalogue_units",
		description=(
			"Units of measure worth offering for furniture — seven, not the two "
			"hundred and forty ERPNext knows. Call this before creating an item."
		),
		input_schema={"type": "object", "properties": {}},
		risk=Risk.READ,
		handler=catalogue_units,
		doctypes=("UOM",),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.catalogue_items",
		description=(
			"Catalogue items with their prices. A null price means the price has "
			"not been worked out yet, which is normal for made-to-order furniture."
		),
		input_schema={
			"type": "object",
			"properties": {
				"query": {"type": "string", "description": "Searches code and name."},
				"limit": {"type": "integer"},
			},
		},
		risk=Risk.READ,
		handler=catalogue_items,
		doctypes=("Item", "Item Price"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.create_item",
		description=(
			"Add a catalogue item. The unit must come from chain.catalogue_units "
			"— it is printed on the delivery note and the customer reads it. "
			"Price is optional. The user must confirm."
		),
		input_schema={
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"unit": {"type": "string", "description": "From chain.catalogue_units."},
				"code": {"type": "string", "description": "Defaults to the name."},
				"description": {"type": "string"},
				"price": {"type": "number"},
			},
			"required": ["name", "unit"],
		},
		risk=Risk.WRITE,
		handler=create_item,
		doctypes=("Item", "Item Price"),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.set_item_price",
		description=(
			"Name the price of a catalogue item, in the price list a quotation "
			"reads from. The user must confirm."
		),
		input_schema={
			"type": "object",
			"properties": {"code": {"type": "string"}, "price": {"type": "number"}},
			"required": ["code", "price"],
		},
		risk=Risk.WRITE,
		handler=set_item_price,
		doctypes=("Item Price",),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.enquiry_candidates",
		description=(
			"Customers a spoken name could mean, for a person to choose between. "
			"Call this when converting a note refused because the name was "
			"ambiguous."
		),
		input_schema={
			"type": "object",
			"properties": {"name_said": {"type": "string"}},
			"required": ["name_said"],
		},
		risk=Risk.READ,
		handler=enquiry_candidates,
		doctypes=("Customer",),
		audit_category="chain",
	)
)

register(
	ToolSpec(
		name="chain.capture_stats",
		description=(
			"How much of what was said got caught, handed over, turned into an "
			"order, dismissed — and how much went stale. The numbers that show "
			"whether the owner still needs an administrator."
		),
		input_schema={
			"type": "object",
			"properties": {"days": {"type": "integer", "description": "Window, 30 by default."}},
		},
		risk=Risk.READ,
		handler=capture_stats,
		doctypes=("Capture",),
		audit_category="chain",
	)
)
