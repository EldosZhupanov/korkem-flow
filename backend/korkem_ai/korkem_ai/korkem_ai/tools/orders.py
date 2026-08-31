# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Taking an order from the person who wants the furniture.

## What a customer may order

What the factory makes. "Sellable" is not a useful filter here — ERPNext marks
almost everything `is_sales_item`, boards and hinges included — so the catalogue
is **items with a default BOM**, which is ERPNext's own statement that this
factory builds the thing. A customer cannot order a sheet of chipboard, and
nobody had to write a list of what they can.

## Nothing about who they are comes from what they say

`customer`, `company`, `warehouse`, the price list, the rate: every one is
resolved server-side. A customer writing «я клиент Караганда Мебель» changes
nothing, because the only customer this tool will ever write is
`scope.customer_scope()` — the `Portal User` binding, from the session.

## Why a customer's order is written by the system

The `Korkem Customer` role is **read-only**, deliberately, and this tool does
not change that. If customers could create Sales Orders under their own
permissions they could also do it straight through the desk API, choosing their
own rate; keeping the permission away means this tool is the only path, and the
price on it comes from ERPNext's price list rather than from the buyer.

It also cannot be done any other way. `Sales Order.set_missing_values` reaches
`erpnext/accounts/party.py:get_party_account`, whose `account_perm_check`
refuses anybody without read on the receivable **Account** — and it asks
`frappe.has_permission` directly, which does not consult `ignore_permissions`.
Measured, not assumed: a customer building the document raises *"User don't have
permissions to select/read this account."* Granting a customer read on the chart
of accounts to place an order would be absurd.

So every decision that says *whose* order this is — the customer, the company,
the item, the price — is made in the customer's own session, and only the
writing of the document happens as the system. ERPNext does the same thing where
it has to: `www/book_appointment/verify/index.py` switches to Administrator to
write a visitor's appointment and switches back. `owner` is the customer's user,
so the audit trail says who asked even though the system is what wrote.

Staff are unaffected: for them the customer is an ordinary argument and the
document is written under their own permissions, which is what it has always
been for a salesperson.

## The catalogue is published, not permitted

A customer cannot be given read on `Item`: ERPNext keeps `valuation_rate` and
`last_purchase_rate` at permlevel 0 on that doctype, so the permission that
shows somebody a cabinet also shows them what the cabinet costs the factory.

The catalogue is therefore a **projection** — the fields a shop puts in a
brochure, for the items it has a BOM for, at the price list the customer buys
from. It is the one place in this codebase where a read does not go through
`frappe.get_list`, and it is that because publishing a price list is a decision,
not a leak.

## The estimate is not the promise

`delivery_forecast` answers "когда будет готов" from the work that actually
remains — planned operation minutes against the workstations' own capacity —
and reports the requested date, the estimate and whether one fits inside the
other as three separate facts. Telling a customer their date is fine because
they asked for it is the one answer this must never give.
"""

from __future__ import annotations

import frappe
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_ai.korkem_ai.notifications import events
from korkem_ai.korkem_ai.tools import scope
from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register
from korkem_ai.korkem_ai.tools.scope import ensure_company, scoped

MAX_CANDIDATES = 10

#: Everything a customer is shown about an item, and nothing else. Written as a
#: list because it is a published projection: adding a field to it is a decision
#: about what the factory tells its customers.
CATALOGUE_FIELDS = ("name as item_code", "item_name", "stock_uom", "description")

#: A working day at the factory, used only when a workstation has no working
#: hours configured of its own. Reported as an assumption wherever it is used
#: rather than folded silently into a date.
FALLBACK_DAY_HOURS = 8.0


# --------------------------------------------------------------------------
# The catalogue
# --------------------------------------------------------------------------


def _makeable() -> list[str]:
	"""Item codes this factory has a default BOM for, in this company."""
	return frappe.get_all(
		"BOM",
		filters={"is_active": 1, "is_default": 1, "docstatus": 1, "company": scope.current_company()},
		pluck="item",
		distinct=True,
	)


def _price_list_for(customer: str | None) -> str | None:
	"""Which selling price list applies, by ERPNext's own rule.

	`erpnext.accounts.party.get_default_price_list` is the function the desk
	uses: the customer's own list, then their customer group's. Only when
	neither answers does Selling Settings' default apply — which is where
	ERPNext itself lands.
	"""
	from erpnext.accounts.party import get_default_price_list

	if customer and frappe.db.exists("Customer", customer):
		chosen = get_default_price_list(frappe.get_cached_doc("Customer", customer))
		if chosen:
			return chosen
	return frappe.db.get_single_value("Selling Settings", "selling_price_list")


def _price_of(item_code: str, customer: str | None = None) -> dict:
	"""What ERPNext says this costs, or nothing at all.

	A missing price is returned as `None` and never filled in with a guess: a
	number on an order is a promise somebody has to honour.
	"""
	price_list = _price_list_for(customer)

	rate = None
	if price_list:
		rate = frappe.db.get_value(
			"Item Price",
			{"item_code": item_code, "price_list": price_list, "selling": 1},
			"price_list_rate",
		)
	currency = frappe.db.get_value("Price List", price_list, "currency") if price_list else None
	return {"price_list": price_list, "rate": flt(rate) if rate else None, "currency": currency}


def search_items(query: str | None = None, limit: int | None = None):
	"""What the factory makes, optionally narrowed by name."""
	codes = _makeable()
	if not codes:
		return {"items": [], "count": 0}

	filters = {"name": ["in", codes], "disabled": 0}
	if query:
		filters["item_name"] = ["like", f"%{query}%"]

	# The published projection — see the module docstring. Four descriptive
	# fields and the selling price, for the things this factory makes.
	rows = frappe.get_all(
		"Item",
		filters=filters,
		fields=list(CATALOGUE_FIELDS),
		limit=min(int(limit or MAX_CANDIDATES), MAX_CANDIDATES),
		order_by="item_name asc",
	)
	buyer = scope.customer_scope()
	for row in rows:
		row.update(_price_of(row["item_code"], buyer))
	return {"items": rows, "count": len(rows)}


def _resolve_item(wanted: str) -> dict:
	"""One item, or an honest refusal to guess between several."""
	codes = _makeable()
	if not codes:
		frappe.throw("В каталоге пока нет изделий, которые фабрика производит.")

	fields = list(CATALOGUE_FIELDS[:3])
	exact = frappe.get_all(
		"Item",
		filters={"name": ["in", codes], "disabled": 0, "item_name": wanted},
		fields=fields,
	) or frappe.get_all(
		"Item",
		filters={"name": ["in", [code for code in codes if code == wanted]], "disabled": 0},
		fields=fields,
	)
	if len(exact) == 1:
		return {"status": "resolved", "item": exact[0]}

	like = frappe.get_all(
		"Item",
		filters={"name": ["in", codes], "disabled": 0, "item_name": ["like", f"%{wanted}%"]},
		fields=fields,
		limit=MAX_CANDIDATES,
	)
	if len(like) == 1:
		return {"status": "resolved", "item": like[0]}
	if not like:
		return {"status": "not_found", "candidates": search_items()["items"]}
	# Two cabinets that both match is a question, not a coin toss.
	return {"status": "ambiguous", "candidates": like}


# --------------------------------------------------------------------------
# Placing the order
# --------------------------------------------------------------------------


def _buyer(requested: str | None) -> str:
	"""Whose order this is. For a customer, never the argument."""
	pinned = scope.customer_scope()
	if pinned:
		return pinned
	if not requested:
		frappe.throw("Назовите клиента, для которого оформляется заказ.")
	if not frappe.db.exists("Customer", requested):
		matches = frappe.get_list(
			"Customer",
			filters={"customer_name": ["like", f"%{requested}%"]},
			pluck="name",
			limit=5,
		)
		if len(matches) != 1:
			frappe.throw(f"Клиент «{requested}» не найден однозначно.")
		return matches[0]
	return requested


def _write_order(*, as_customer: bool, asked_by: str, payload: dict):
	"""Build, price and submit the document — as the system when it must be.

	The session switch is the narrowest it can be: nothing is *decided* inside
	it. The customer, the company, the item and the price list were all resolved
	before it, in the caller's own session, so the elevated context can only
	carry out a decision that was already made under the caller's permissions.
	"""
	original = frappe.session.user
	if as_customer:
		frappe.set_user("Administrator")
	try:
		order = frappe.get_doc(payload)
		# Rate, currency, warehouse, conversion factors: ERPNext's own
		# resolution, from the price list and the company defaults. Nothing here
		# computes money.
		order.set_missing_values()
		order.run_method("calculate_taxes_and_totals")
		order.insert()
		if as_customer:
			# Who asked, even though the system wrote. Stamped after `insert`
			# because Frappe sets `owner` from the session unconditionally
			# (`base_document.db_insert`), so assigning it beforehand is
			# silently discarded — measured, not assumed.
			frappe.db.set_value(
				"Sales Order", order.name, "owner", asked_by, update_modified=False
			)
			order.owner = asked_by
		order.submit()
		return order
	finally:
		if as_customer:
			frappe.set_user(original)


def create_sales_order(
	item_code: str | None = None,
	qty: float | None = None,
	delivery_date: str | None = None,
	customer: str | None = None,
	notes: str | None = None,
):
	"""Record a confirmed request as an ERPNext Sales Order.

	Everything that decides *whose* order this is comes from the session. What
	the caller supplies is what they want and when — and even that is checked
	against ERPNext rather than taken as read.
	"""
	buyer = _buyer(customer)
	company = scope.current_company()

	missing = []
	if not item_code:
		missing.append("item_code")
	if not qty or flt(qty) <= 0:
		missing.append("qty")
	if not delivery_date:
		missing.append("delivery_date")
	if missing:
		return {
			"status": "incomplete",
			"missing": missing,
			"catalogue": search_items()["items"] if "item_code" in missing else None,
			"message": "Не хватает данных для заказа.",
		}

	resolved = _resolve_item(item_code)
	if resolved["status"] != "resolved":
		return {
			"status": resolved["status"],
			"asked_for": item_code,
			"candidates": resolved["candidates"],
			"message": (
				"Такого изделия нет в каталоге."
				if resolved["status"] == "not_found"
				else "Под описание подходит несколько изделий — уточните, какое."
			),
		}

	item = resolved["item"]
	wanted_date = getdate(delivery_date)
	if wanted_date < getdate(nowdate()):
		return {
			"status": "invalid_date",
			"requested_date": str(wanted_date),
			"message": "Дата уже прошла.",
		}

	price = _price_of(item["item_code"], buyer)
	if not price["rate"]:
		# No price, no order. A Sales Order carrying a rate somebody invented is
		# worse than no Sales Order: it is a number the factory has to honour.
		return {
			"status": "no_price",
			"item_code": item["item_code"],
			"message": (
				f"На «{item['item_name']}» ещё нет цены в прайс-листе. "
				"Менеджер подтвердит стоимость."
			),
		}

	# Everything above was decided in the caller's own session. Only the writing
	# happens as the system, and only for a customer — see the module docstring
	# for why ERPNext leaves no other way to do it.
	asked_by = frappe.session.user
	as_customer = bool(scope.customer_scope())
	order = _write_order(
		as_customer=as_customer,
		asked_by=asked_by,
		payload={
			"doctype": "Sales Order",
			"customer": buyer,
			"company": company,
			"transaction_date": nowdate(),
			"delivery_date": str(wanted_date),
			"order_type": "Sales",
			"selling_price_list": price["price_list"],
			"items": [
				{
					"item_code": item["item_code"],
					"qty": flt(qty),
					"delivery_date": str(wanted_date),
				}
			],
			# Stored where ERPNext stores a customer's own words about an order.
			"terms": notes[:2000] if notes else None,
		},
	)

	order.reload()
	# The customer is told their order is on the books, on whichever channel
	# they are linked on. Nothing here knows what a channel is.
	events.order_accepted(order.name)
	return {
		"status": "created",
		"sales_order": order.name,
		"customer": order.customer,
		"company": order.company,
		"items": [
			{
				"item_code": row.item_code,
				"item_name": row.item_name,
				"qty": row.qty,
				"uom": row.uom,
				"rate": row.rate,
				"amount": row.amount,
			}
			for row in order.items
		],
		"requested_date": str(wanted_date),
		"delivery_date": str(order.delivery_date),
		"grand_total": order.grand_total,
		"currency": order.currency,
		"order_status": order.status,
	}


def summarise_order(
	item_code: str | None = None,
	qty: float | None = None,
	delivery_date: str | None = None,
	customer: str | None = None,
	notes: str | None = None,
) -> str | None:
	"""The order as a person should read it before saying yes.

	Built from ERPNext — the item's real name, the price list's real rate — not
	from the model's account of them. Returns nothing when the call could not
	produce an order anyway; the tool itself will say why.
	"""
	if not item_code or not qty or not delivery_date:
		return None
	resolved = _resolve_item(item_code)
	if resolved["status"] != "resolved":
		return None

	item = resolved["item"]
	buyer = scope.customer_scope() or customer
	price = _price_of(item["item_code"], buyer)
	if not price["rate"]:
		return None

	total = flt(qty) * price["rate"]
	buyer = buyer or ""
	lines = [
		"Проверьте заказ:",
		"",
		f"{item['item_name']}",
		f"Количество: {flt(qty):g} {item['stock_uom']}",
		f"Желаемый срок: {getdate(delivery_date).strftime('%d.%m.%Y')}",
		f"Цена: {price['rate']:,.0f} {price['currency']} за единицу".replace(",", " "),
		f"Сумма: {total:,.0f} {price['currency']}".replace(",", " "),
	]
	if buyer:
		lines.append(f"Клиент: {buyer}")
	return "\n".join(lines)


# --------------------------------------------------------------------------
# When will it be ready
# --------------------------------------------------------------------------


def _remaining_minutes(work_orders: list[str]) -> tuple[float, list[str]]:
	"""Planned minutes still to be worked, and the stations that will do them."""
	if not work_orders:
		return 0.0, []

	total = 0.0
	stations = set()
	for name in work_orders:
		job = frappe.get_doc("Work Order", name)
		for operation in job.operations or []:
			pending = max(flt(job.qty) - flt(operation.completed_qty), 0)
			if pending <= 0:
				continue
			per_unit = flt(operation.time_in_mins) / flt(job.qty or 1)
			total += per_unit * pending
			if operation.workstation:
				stations.add(operation.workstation)
	return total, sorted(stations)


def _day_hours(stations: list[str]) -> tuple[float, bool]:
	"""Hours a day the slowest of these stations works, and whether it was known."""
	hours = []
	for name in stations:
		station = frappe.db.get_value("Workstation", name, "hour_rate", as_dict=True)
		if station is None:
			continue
		timings = frappe.get_all(
			"Workstation Working Hour",
			filters={"parent": name},
			fields=["start_time", "end_time"],
		)
		worked = 0.0
		for row in timings:
			if row.start_time and row.end_time:
				worked += (row.end_time.total_seconds() - row.start_time.total_seconds()) / 3600
		if worked:
			hours.append(worked)
	if not hours:
		return FALLBACK_DAY_HOURS, False
	return min(hours), True


def delivery_forecast(sales_order: str | None = None):
	"""When an order can actually be ready, against when it was asked for.

	Three separate facts, never merged: the date on the order, the date the
	remaining work implies, and whether the second fits inside the first.
	"""
	pinned = scope.customer_scope()
	# The boundary is here and it is ERPNext's: `get_list` applies the customer's
	# `User Permission`, so an order that comes back is an order they may see.
	# Everything below is derived from orders that passed through this filter.
	filters = {"docstatus": 1}
	if sales_order:
		ensure_company("Sales Order", sales_order)
		filters["name"] = sales_order
	else:
		filters["status"] = ["not in", ("Completed", "Closed", "Cancelled")]
	if pinned:
		filters["customer"] = pinned
	names = frappe.get_list(
		"Sales Order",
		filters=scoped(filters),
		pluck="name",
		order_by="delivery_date asc",
		limit_page_length=1 if sales_order else 5,
	)
	if sales_order and not names:
		# Worded as absence, in the same words a name that does not exist gets.
		frappe.throw(f"Не удалось найти {sales_order} среди ваших заказов.", frappe.DoesNotExistError)

	reported = []
	for name in names:
		order = frappe.get_doc("Sales Order", name)
		order.check_permission("read")
		# A customer holds no read on `Work Order` and must not: the doctype has
		# no customer field, so a `User Permission` cannot narrow it and the
		# permission that showed them their own job would show them the factory's.
		# What they get instead is *derived* — hours, dates, counts — computed
		# over the jobs of an order that already passed the filter above. The
		# job's own name is staff-only.
		jobs = frappe.get_all(
			"Work Order",
			filters={"sales_order": name, "docstatus": 1, "company": scope.current_company()},
			fields=["name", "status", "qty", "produced_qty", "process_loss_qty"],
		)
		live = [job["name"] for job in jobs if job["status"] not in ("Completed", "Closed", "Stopped")]
		minutes, stations = _remaining_minutes(live)
		day_hours, measured = _day_hours(stations)

		days_needed = round(minutes / 60 / day_hours, 2) if minutes else 0.0
		estimated = add_days(nowdate(), int(days_needed) + (1 if days_needed % 1 else 0))

		if not jobs:
			basis = "производство по заказу ещё не запущено, поэтому срок оценить нельзя"
			estimated = None
		elif not live:
			basis = "всё производство по заказу закончено"
			estimated = nowdate()
		else:
			basis = (
				f"осталось {round(minutes / 60, 1)} ч работы; "
				f"{'рабочий день станка' if measured else 'рабочий день принят за'} "
				f"{day_hours:g} ч"
			)

		reported.append(
			{
				"sales_order": name,
				"customer": order.customer,
				"requested_date": str(order.delivery_date),
				"estimated_ready_date": estimated,
				"meets_requested_date": (
					None if not estimated else getdate(estimated) <= getdate(order.delivery_date)
				),
				"remaining_hours": round(minutes / 60, 1),
				"workstations": stations,
				"basis": basis,
				"produced": sum(flt(job["produced_qty"]) for job in jobs),
				"ordered": sum(flt(job["qty"]) for job in jobs) or None,
				"in_production": bool(jobs),
				"work_orders": None if pinned else [job["name"] for job in jobs],
			}
		)

	return {
		"as_of": nowdate(),
		"note": (
			"requested_date — дата, о которой договорились в заказе. "
			"estimated_ready_date — расчёт по оставшейся работе. "
			"Это разные вещи, и вторая не подтверждена."
		),
		"orders": reported,
		"count": len(reported),
	}


# --------------------------------------------------------------------------
# Registration
# --------------------------------------------------------------------------

register(
	ToolSpec(
		name="sales.search_items",
		description=(
			"What the factory makes and can be ordered — the item catalogue, "
			"optionally narrowed by name. Use before creating an order when the "
			"customer's wording does not match an item exactly."
		),
		input_schema={
			"type": "object",
			"properties": {"query": {"type": "string"}, "limit": {"type": "integer"}},
		},
		risk=Risk.READ,
		handler=search_items,
		# No doctype is declared, and that is the honest statement: this tool
		# does not read `Item` with the caller's permission. It publishes a
		# fixed projection of what the factory makes (see the module docstring),
		# so gating it on `Item` read would hide the catalogue from the only
		# people it exists for.
		doctypes=(),
		audit_category="sales",
	)
)

register(
	ToolSpec(
		name="sales.create_sales_order",
		description=(
			"Place an order for a customer: one item, a quantity and a requested "
			"delivery date (YYYY-MM-DD). The customer is decided by the server for "
			"a customer's own session — never pass one on their behalf. Returns "
			"status 'incomplete' naming what is missing, or 'ambiguous' with "
			"candidates, rather than guessing."
		),
		input_schema={
			"type": "object",
			"properties": {
				"item_code": {"type": "string"},
				"qty": {"type": "number"},
				"delivery_date": {"type": "string"},
				"customer": {"type": "string"},
				"notes": {"type": "string"},
			},
		},
		risk=Risk.WRITE,
		handler=create_sales_order,
		summarise=summarise_order,
		doctypes=("Sales Order",),
		audit_category="sales",
	)
)

register(
	ToolSpec(
		name="sales.delivery_forecast",
		description=(
			"When an order can realistically be ready, from the work that remains, "
			"against the date on the order. Answers «когда будет готов»."
		),
		input_schema={
			"type": "object",
			"properties": {"sales_order": {"type": "string"}},
		},
		risk=Risk.READ,
		handler=delivery_forecast,
		# `Sales Order` only. The work orders behind the estimate are read as a
		# derived projection over orders this caller could already list — see
		# the comment in `delivery_forecast`.
		doctypes=("Sales Order",),
		audit_category="sales",
	)
)
