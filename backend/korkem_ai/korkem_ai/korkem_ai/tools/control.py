# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Что сейчас происходит в производстве?» — answered from the database.

One composite read. The model can already chain sales, work-order and shortage
tools itself, and if it does the *counting* happens in a language model: "how
many orders are overdue" becomes a token prediction over a list it was shown.
This does the counting in Python, over rows, and hands back a structure whose
every number the model only has to read aloud.

## Where the numbers come from

Nothing here re-derives availability. Shortages come from
`procurement.material_shortage`, which wraps ERPNext's own Production Plan
requirement engine — so the shortage this overview reports is, by construction,
the same quantity `inventory.create_material_request` will order. Two paths to
one number is how an overview and an action come to disagree in front of a
customer.

ERPNext's `Production Planning Report` was considered for this and not used. It
answers a similar question, but it returns display columns rather than a stable
contract, and it reaches for `frappe.get_all` internally — which bypasses the
permission query conditions that make "the assistant can see what you can see"
true. A tool built on it would have shown a planner rows they cannot open.

## What "overdue" and "blocked" mean here

Definitions are choices, so they are written down rather than implied:

* **active** — submitted, and not Completed, Closed or Cancelled.
* **overdue** — the delivery date has passed and the order is not fully
  delivered. A delivered order that closed late is history, not a problem.
* **in production** — at least one submitted work order that is not finished.
* **not started** — no submitted work order at all.
* **blocked** — material is short. Being blocked is about material, not about
  lateness: an order can be both, and the two counts overlap on purpose.
* **ready to start** — nobody has started it and nothing is missing. The only
  category here that is an invitation to act.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, getdate, nowdate

from korkem_ai.korkem_ai.tools.erp import active_sales_orders
from korkem_ai.korkem_ai.tools.procurement import material_shortage
from korkem_ai.korkem_ai.tools.production import _current_card, work_order_stages
from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register
from korkem_ai.korkem_ai.tools.scope import scoped

#: Work Order statuses that mean the job is no longer running.
FINISHED_WORK = ("Completed", "Stopped", "Closed", "Cancelled")

#: How many orders one call will look at.
#:
#: Each order costs a BOM explosion and a `Bin` read, so this is not free.
#: Twenty is a shop floor's worth of attention; the cap is reported in the
#: result rather than silently applied, because an overview that quietly
#: truncates is worse than no overview.
MAX_ORDERS = 20


def _work_orders(order_names: list[str]) -> dict[str, list[dict]]:
	if not order_names:
		return {}

	found: dict[str, list[dict]] = {}
	for row in frappe.get_list(
		"Work Order",
		filters=scoped({"sales_order": ["in", order_names], "docstatus": 1}),
		fields=[
			"name",
			"sales_order",
			"production_item",
			"qty",
			"produced_qty",
			"material_transferred_for_manufacturing",
			"status",
			"planned_start_date",
			"expected_delivery_date",
		],
		limit_page_length=0,
	):
		found.setdefault(row["sales_order"], []).append(
			{
				"work_order": row["name"],
				"item_code": row["production_item"],
				"qty": flt(row["qty"]),
				"produced_qty": flt(row["produced_qty"]),
				"remaining_qty": round(flt(row["qty"]) - flt(row["produced_qty"]), 3),
				"transferred_qty": flt(row["material_transferred_for_manufacturing"]),
				"status": row["status"],
				"running": row["status"] not in FINISHED_WORK,
				# Which stage the job is on, from its own operations rather
				# than guessed from a progress percentage.
				**work_order_stages(row["name"]),
				# The job card the floor is actually on, when the job has
				# reached the shop floor at all.
				**_job_card_summary(row["name"]),
			}
		)
	return found


def _job_card_summary(work_order: str) -> dict:
	"""The live job card for a work order, or nothing if it has none."""
	card = _current_card(work_order)
	if not card:
		return {"job_card": None, "job_card_status": None}
	return {
		"job_card": card["name"],
		"job_card_status": card["status"],
		"job_card_completed_qty": flt(card["total_completed_qty"]),
		"job_card_for_quantity": flt(card["for_quantity"]),
	}


def _named(row: dict, quantity: str) -> dict:
	"""Строка дефицита в обзоре: что не хватает, сколько, и всё.

	Полная строка несёт тринадцать чисел — требуется, израсходовано, осталось,
	зарезервировано, доступно, ожидается, заказано, и так далее. В обзоре по
	двадцати заказам это тридцать тысяч символов, которые уезжают в модель и
	оплачиваются на каждом шаге хода: обзор стоил 16 800 токенов, больше, чем
	весь каталог инструментов.

	Обзор отвечает на вопрос «что мешает», а не «объясни по каждому числу». На
	второй отвечает `inventory.material_shortage` — он для того и есть, и его
	зовут, когда спросили именно про один заказ.

	**У каждого списка своё число, и подставлять одно вместо другого нельзя.**
	`shortages` считает, чего надо докупить; `blocking_materials` — чего нет на
	полке. На пустом складе они совпадают, и первая версия этой обрезки
	поставила закупочное количество в оба. Поймал CI на тесте, который читает
	`physical_shortage_qty` — и правильно сделал: цифра «нечем пилить» и цифра
	«надо заказать» это разные ответы разным людям.
	"""
	return {
		"item_code": row.get("item_code"),
		"item_name": row.get("item_name"),
		quantity: row.get(quantity),
		"uom": row.get("uom"),
	}


def production_control(sales_order: str | None = None, limit: int | None = None):
	"""Everything live on the floor, counted rather than described.

	Given a `sales_order`, the same reading narrowed to one order — which is
	what "can this be built, and why not" is. It used to be a second tool.
	"""
	today = getdate(nowdate())
	cap = min(int(limit or MAX_ORDERS), MAX_ORDERS)

	# One definition of "active", shared with the factory shortage. Two copies
	# of this filter is how an overview and a purchase list come to disagree
	# about which orders exist.
	orders = active_sales_orders(limit=cap + 1)
	if sales_order:
		orders = [order for order in orders if order["name"] == sales_order]
		if not orders:
			frappe.throw(f"Sales order {sales_order} not found.")
	truncated = len(orders) > cap
	orders = orders[:cap]

	jobs = _work_orders([order["name"] for order in orders])

	reported = []
	for order in orders:
		due = getdate(order["delivery_date"]) if order["delivery_date"] else None
		running = jobs.get(order["name"], [])

		# The shortage is the expensive part, and it is also the answer to
		# "why is this one blocked" — so it is computed, not guessed at from
		# whether a work order exists.
		shortage = material_shortage(order["name"])
		blocking = shortage["shortages"]
		# "Can we start" is about the shelf, not about paperwork. Raising a
		# purchase request closes the procurement shortage and moves no board,
		# so answering from `shortages` would say yes to a floor with nothing
		# to cut.
		missing = shortage["not_on_the_shelf"]

		started = bool(running)
		unfinished = [job for job in running if job["running"]]

		reported.append(
			{
				"sales_order": order["name"],
				"customer": order["customer"],
				"status": order["status"],
				"delivery_date": str(order["delivery_date"]) if due else None,
				"days_to_delivery": (due - today).days if due else None,
				"overdue": bool(due and due < today and flt(order["per_delivered"]) < 100),
				"delivered_percent": flt(order["per_delivered"]),
				"work_orders": running,
				"in_production": bool(unfinished),
				"started": started,
				"material_status": "shortage" if blocking else "ok",
				"shortages": [_named(row, "shortage_qty") for row in blocking],
				# «Можно ли запускать» — about material only, so it stays true
				# for a job already running that has everything it needs.
				"can_start": not missing,
				"blocking_materials": [_named(row, "physical_shortage_qty") for row in missing],
				"ready_to_start": not started and not missing,
			}
		)

	overdue = [o for o in reported if o["overdue"]]
	blocked = [o for o in reported if o["material_status"] == "shortage"]

	return {
		"as_of": str(today),
		"summary": {
			"active_orders": len(reported),
			"overdue_orders": len(overdue),
			"orders_in_production": len([o for o in reported if o["in_production"]]),
			"orders_not_started": len([o for o in reported if not o["started"]]),
			"orders_with_material_shortage": len(blocked),
			"orders_ready_to_start": len([o for o in reported if o["ready_to_start"]]),
			"truncated": truncated,
			"limit": cap,
		},
		"orders": reported,
		# Named separately so "какой заказ самый проблемный" has an answer that
		# does not depend on the model re-sorting the list correctly. Overdue
		# first, then soonest due.
		"attention": [
			o["sales_order"]
			for o in sorted(
				(o for o in reported if o["overdue"] or o["material_status"] == "shortage"),
				key=lambda o: (not o["overdue"], o["days_to_delivery"] if o["days_to_delivery"] is not None else 9999),
			)
		],
	}


register(
	ToolSpec(
		name="manufacturing.production_control",
		description=(
			"What is happening in production right now: every active sales order "
			"with its work orders, progress, delivery date, whether it is overdue, "
			"and whether material is short. Use this for questions like «что "
			"сейчас происходит в производстве», «какие заказы просрочены» or "
			"«какой заказ заблокирован». Report its numbers as given — do not "
			"recount or re-derive them."
		),
		input_schema={
			"type": "object",
			"properties": {
				"sales_order": {
					"type": "string",
					"description": (
						"Narrow to one order — use for «можно ли запускать этот "
						"заказ» or «почему нельзя». Omit for the whole floor."
					),
				},
				"limit": {
					"type": "integer",
					"minimum": 1,
					"maximum": MAX_ORDERS,
					"description": f"How many orders to examine, at most {MAX_ORDERS}.",
				},
			},
			"required": [],
		},
		handler=production_control,
		risk=Risk.READ,
		doctypes=("Sales Order", "Work Order", "BOM", "Bin", "Production Plan"),
		audit_category="manufacturing",
		timeout=60,
	)
)
