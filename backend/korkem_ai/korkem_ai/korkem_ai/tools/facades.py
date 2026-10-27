# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The facade line and the order marks, reachable by voice.

Thin wrappers only (R1): every handler is the same API function the app's
buttons call, so the assistant cannot price, queue or mark an order any
differently from a person. «Сколько стоят десять фасадов 500 на 400»,
«что сейчас в цеху фасадов», «сделай заказ Нура срочным».
"""

from __future__ import annotations

from korkem_manufacturing.api import directions as directions_api
from korkem_manufacturing.api import facade_jobs as facade_jobs_api
from korkem_manufacturing.api import facade_prices as facade_prices_api

from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register

_LINE = {
	"type": "object",
	"properties": {
		"width_mm": {"type": "number", "exclusiveMinimum": 0, "description": "Ширина, мм."},
		"height_mm": {"type": "number", "exclusiveMinimum": 0, "description": "Высота, мм."},
		"qty": {"type": "integer", "minimum": 1, "description": "Штук."},
		"milling": {"type": "string", "minLength": 1, "description": "Фрезеровка, как в таблице цен."},
		"finish": {"type": "string", "minLength": 1, "description": "Отделка, как в таблице цен."},
		"double_sided": {"type": "boolean"},
		"customer_material": {"type": "boolean"},
		"thickness_mm": {"type": "integer", "minimum": 3, "maximum": 60},
		"decor_top": {"type": "string", "description": "Декор лицевой стороны, из списка «Цвет плёнки»."},
		"decor_bottom": {"type": "string", "description": "Декор обратной стороны, из того же списка."},
		"edge_profile": {"type": "string", "description": "Профиль кромки, из списка «Профиль кромки»."},
		"color_group": {"type": "string", "maxLength": 40},
	},
	"required": ["width_mm", "height_mm", "qty", "milling", "finish"],
}


def _quote(lines: list, demolition: bool = False, prepayment_amount: float | None = None) -> dict:
	return facade_prices_api.quote(
		lines=lines, demolition=1 if demolition else 0, prepayment_amount=prepayment_amount
	)


register(
	ToolSpec(
		name="sales.facade_quote",
		description=(
			"Price a facade order before it is placed: pieces, square metres, sum, "
			"prepayment and balance, from this company's own price table. Writes "
			"nothing. Milling and finish must be names from the price table; an "
			"unknown one is refused, not guessed."
		),
		input_schema={
			"type": "object",
			"properties": {
				"lines": {"type": "array", "minItems": 1, "maxItems": 200, "items": _LINE},
				"demolition": {"type": "boolean", "description": "Добавить демонтаж."},
				"prepayment_amount": {"type": "number", "minimum": 0},
			},
			"required": ["lines"],
		},
		risk=Risk.READ,
		handler=_quote,
		doctypes=("Facade Price",),
		audit_category="sales",
	)
)


def _queue(status: str | None = None, limit: int = 100) -> dict:
	return facade_jobs_api.jobs(status=status, limit=limit)


register(
	ToolSpec(
		name="manufacturing.facade_queue",
		description=(
			"The facade shop's queue: each facade to make with its size, area, "
			"milling, finish and status (В очереди, В работе, Готово). Urgent "
			"orders come first, then the soonest due. No prices."
		),
		input_schema={
			"type": "object",
			"properties": {
				"status": {"type": "string", "enum": ["В очереди", "В работе", "Готово"]},
				"limit": {"type": "integer", "minimum": 1, "maximum": 200},
			},
		},
		risk=Risk.READ,
		handler=_queue,
		doctypes=("Sales Order",),
		audit_category="production",
	)
)


def _set_urgent(sales_order: str, urgent: bool) -> dict:
	return directions_api.set_urgent(sales_order=sales_order, urgent=1 if urgent else 0)


register(
	ToolSpec(
		name="sales.set_order_urgent",
		description=(
			"Mark an order urgent, or take the mark off. An urgent order goes to "
			"the head of the shop's queue. The user must confirm before this runs."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {"type": "string", "minLength": 1},
				"urgent": {"type": "boolean"},
			},
			"required": ["sales_order", "urgent"],
		},
		risk=Risk.WRITE,
		handler=_set_urgent,
		doctypes=("Sales Order",),
		permission="write",
		audit_category="sales",
		summarise=lambda sales_order, urgent, **_: (
			f"Отметить заказ {sales_order} срочным" if urgent else f"Снять срочность с заказа {sales_order}"
		),
	)
)


def _set_tier(customer: str, tier: str | None = None) -> dict:
	return directions_api.set_customer_tier(customer=customer, tier=tier)


register(
	ToolSpec(
		name="sales.set_customer_tier",
		description=(
			"Put a customer in a tier: New, Regular or VIP — or clear it. Only the "
			"head of sales may. The user must confirm before this runs."
		),
		input_schema={
			"type": "object",
			"properties": {
				"customer": {"type": "string", "minLength": 1},
				"tier": {"type": "string", "enum": ["New", "Regular", "VIP"]},
			},
			"required": ["customer"],
		},
		risk=Risk.WRITE,
		handler=_set_tier,
		doctypes=("Customer",),
		permission="write",
		audit_category="sales",
		summarise=lambda customer, tier=None, **_: (
			f"Клиенту {customer} поставить категорию {tier}"
			if tier
			else f"Снять категорию с клиента {customer}"
		),
	)
)


def _group(lines: list, group: str | None = None) -> dict:
	return facade_jobs_api.set_color_group(lines=lines, group=group)


register(
	ToolSpec(
		name="manufacturing.set_color_group",
		description=(
			"Put facade positions in one colour group — the label the shop sorts a "
			"batch by — or clear it. Positions are line ids from "
			"manufacturing.facade_queue and need not be next to each other. The "
			"user must confirm before this runs."
		),
		input_schema={
			"type": "object",
			"properties": {
				"lines": {"type": "array", "minItems": 1, "maxItems": 200, "items": {"type": "string"}},
				"group": {"type": "string", "maxLength": 40},
			},
			"required": ["lines"],
		},
		risk=Risk.WRITE,
		handler=_group,
		doctypes=("Sales Order",),
		permission="write",
		audit_category="production",
		summarise=lambda lines, group=None, **_: (
			f"Позиции ({len(lines)}) — в цветовую группу «{group}»"
			if group
			else f"Снять цветовую группу с позиций ({len(lines)})"
		),
	)
)
