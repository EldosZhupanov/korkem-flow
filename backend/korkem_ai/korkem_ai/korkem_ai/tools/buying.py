# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""From "we need it" to "it is on order" — and knowing when it lands.

The tools here are named `procurement.*`; the module is `buying` because that
is what ERPNext calls the domain, and the doctypes read like ERPNext's rather
than like ours.

## Ordered is not received, and neither is stock

The one distinction this whole module exists to keep straight. A submitted
Purchase Order raises `Bin.ordered_qty` and leaves `actual_qty` exactly where it
was. Material that is on order cannot be cut, and a shop told "you have it"
because somebody bought it will find out on the saw. So four quantities are
reported separately and never collapsed:

* **required** — what production needs
* **available** — `actual_qty`, physically on the shelf
* **ordered** — on a submitted purchase order, not yet here
* **received** — arrived, and therefore now part of available

`inventory.factory_shortage` answers "do we need to buy more" and so counts what
is already on order; `manufacturing.production_readiness` answers "can we cut
today" and counts only what is on the shelf. Both are right, and they are
different questions.

## Statuses are ERPNext's, not ours

`Material Request.status` already knows Pending, Partially Ordered, Ordered,
Partially Received, Received; `Purchase Order` knows To Receive and Bill, To
Bill, To Receive, Completed, Closed. Inventing a parallel vocabulary would mean
two sources of truth about the same document, so these are passed through and
only *derived* facts — how much is still pending, how many days late — are
computed here.

## Creating the order

`erpnext.stock.doctype.material_request.mapper.make_purchase_order` is
ERPNext's own mapper. It validates the request is submitted and of the right
type, skips lines already fully ordered, carries the `material_request` and
`material_request_item` links that make the trace work in both directions, and
resolves rates through `set_missing_values`. None of that is reimplemented.
"""

from __future__ import annotations

import frappe
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register
from korkem_ai.korkem_ai.tools.scope import current_company, ensure_company, scoped

#: Material Requests still worth acting on.
OPEN_REQUEST_STATUSES = ("Pending", "Partially Ordered", "Partially Received", "Ordered")

#: Purchase Orders still expecting goods.
OPEN_ORDER_STATUSES = ("To Receive and Bill", "To Receive", "To Bill")

MAX_ROWS = 20

#: How far a material has got along the chain. Machine-readable on purpose: the
#: model reads these back to a person, and «заказано» and «пришло» are the two
#: words a shop most needs kept apart.
NOT_REQUESTED = "NOT_REQUESTED"
REQUESTED = "REQUESTED"
ORDERED = "ORDERED"
PARTIALLY_RECEIVED = "PARTIALLY_RECEIVED"
RECEIVED = "RECEIVED"


def _days_late(due, today) -> int | None:
	if not due:
		return None
	late = (today - getdate(due)).days
	return late if late > 0 else 0


# --------------------------------------------------------------------------
# Material requests
# --------------------------------------------------------------------------


def _request_rows(names: list[str]) -> dict[str, list[dict]]:
	if not names:
		return {}
	found: dict[str, list[dict]] = {}
	for row in frappe.get_all(
		"Material Request Item",
		filters={"parent": ["in", names]},
		fields=[
			"parent",
			"name",
			"item_code",
			"item_name",
			"qty",
			"stock_qty",
			"ordered_qty",
			"received_qty",
			"uom",
			"warehouse",
			"schedule_date",
			"sales_order",
		],
		order_by="idx asc",
	):
		found.setdefault(row["parent"], []).append(row)
	return found


def _purchase_orders_for(request_names: list[str]) -> dict[str, list[str]]:
	"""Which purchase orders were raised against each request."""
	if not request_names:
		return {}
	links: dict[str, set[str]] = {}
	for row in frappe.get_all(
		"Purchase Order Item",
		filters={"material_request": ["in", request_names], "docstatus": ["<", 2]},
		fields=["parent", "material_request"],
	):
		links.setdefault(row["material_request"], set()).add(row["parent"])
	return {key: sorted(value) for key, value in links.items()}


def search_material_requests(
	only_unordered: bool | None = None, status: str | None = None, limit: int | None = None
):
	"""Purchase requests and how far along they are.

	`ordered_qty` and `received_qty` are ERPNext's own running totals, kept up
	to date as purchase orders and receipts are submitted — so "how much is
	still pending" is arithmetic over the ERP's numbers rather than a second
	tally that can drift away from them.
	"""
	today = getdate(nowdate())
	cap = min(int(limit or MAX_ROWS), MAX_ROWS)

	filters = {"docstatus": 1, "material_request_type": "Purchase"}
	filters["status"] = status if status else ["in", OPEN_REQUEST_STATUSES]

	headers = frappe.get_list(
		"Material Request",
		filters=scoped(filters),
		fields=["name", "status", "transaction_date", "schedule_date", "owner", "company"],
		order_by="schedule_date asc",
		limit_page_length=cap,
	)
	names = [row["name"] for row in headers]
	rows = _request_rows(names)
	linked = _purchase_orders_for(names)

	requests = []
	for header in headers:
		items = []
		for row in rows.get(header["name"], []):
			pending = round(max(0.0, flt(row["stock_qty"]) - flt(row["ordered_qty"])), 3)
			items.append(
				{
					"item_code": row["item_code"],
					"item_name": row["item_name"],
					"qty": flt(row["qty"]),
					"uom": row["uom"],
					"ordered_qty": flt(row["ordered_qty"]),
					"received_qty": flt(row["received_qty"]),
					"pending_qty": pending,
					"warehouse": row["warehouse"],
					"required_by": str(row["schedule_date"]) if row["schedule_date"] else None,
					"sales_order": row["sales_order"],
				}
			)

		pending_total = sum(item["pending_qty"] for item in items)
		if only_unordered and pending_total <= 0:
			continue

		requests.append(
			{
				"material_request": header["name"],
				"status": header["status"],
				"raised_on": str(header["transaction_date"]),
				"required_by": str(header["schedule_date"]) if header["schedule_date"] else None,
				"raised_by": header["owner"],
				"items": items,
				"purchase_orders": linked.get(header["name"], []),
				"fully_ordered": pending_total <= 0,
				"days_late": _days_late(header["schedule_date"], today),
			}
		)

	return {
		"as_of": str(today),
		"count": len(requests),
		"material_requests": requests,
	}


# --------------------------------------------------------------------------
# Purchase orders
# --------------------------------------------------------------------------


def search_purchase_orders(
	arriving_within_days: int | None = None,
	overdue_only: bool | None = None,
	status: str | None = None,
	limit: int | None = None,
):
	"""What is on order, from whom, and when it is due.

	"Overdue" here means the goods are late, not the paperwork: the promised
	date has passed and something is still outstanding. A purchase order that
	was fully received last week is not a problem, whatever its dates say.
	"""
	today = getdate(nowdate())
	cap = min(int(limit or MAX_ROWS), MAX_ROWS)

	filters = {"docstatus": 1}
	filters["status"] = status if status else ["in", OPEN_ORDER_STATUSES]

	headers = frappe.get_list(
		"Purchase Order",
		filters=scoped(filters),
		fields=[
			"name",
			"supplier",
			"status",
			"transaction_date",
			"schedule_date",
			"per_received",
			"grand_total",
			"currency",
			"company",
		],
		order_by="schedule_date asc",
		limit_page_length=cap,
	)
	names = [row["name"] for row in headers]

	rows: dict[str, list[dict]] = {}
	if names:
		for row in frappe.get_all(
			"Purchase Order Item",
			filters={"parent": ["in", names]},
			fields=[
				"parent",
				"item_code",
				"item_name",
				"qty",
				"received_qty",
				"rate",
				"amount",
				"uom",
				"warehouse",
				"schedule_date",
				"material_request",
				"sales_order",
			],
			order_by="idx asc",
		):
			rows.setdefault(row["parent"], []).append(row)

	orders = []
	for header in headers:
		items = [
			{
				"item_code": row["item_code"],
				"item_name": row["item_name"],
				"ordered_qty": flt(row["qty"]),
				"received_qty": flt(row["received_qty"]),
				"pending_qty": round(max(0.0, flt(row["qty"]) - flt(row["received_qty"])), 3),
				"uom": row["uom"],
				"rate": flt(row["rate"]),
				"amount": flt(row["amount"]),
				"warehouse": row["warehouse"],
				"expected_on": str(row["schedule_date"]) if row["schedule_date"] else None,
				"material_request": row["material_request"],
				"sales_order": row["sales_order"],
			}
			for row in rows.get(header["name"], [])
		]

		outstanding = sum(item["pending_qty"] for item in items)
		late = _days_late(header["schedule_date"], today) if outstanding > 0 else 0
		due = getdate(header["schedule_date"]) if header["schedule_date"] else None

		order = {
			"purchase_order": header["name"],
			"supplier": header["supplier"],
			"status": header["status"],
			"ordered_on": str(header["transaction_date"]),
			# ERPNext leaves this blank when nobody promised a date. Reported as
			# unknown rather than filled in with a guess.
			"expected_on": str(due) if due else None,
			"days_until_expected": (due - today).days if due else None,
			"received_percent": flt(header["per_received"]),
			"pending_qty": round(outstanding, 3),
			"overdue": bool(late),
			"days_overdue": late,
			"total": flt(header["grand_total"]),
			"currency": header["currency"],
			"items": items,
			"material_requests": sorted({i["material_request"] for i in items if i["material_request"]}),
		}

		if overdue_only and not order["overdue"]:
			continue
		if arriving_within_days is not None:
			within = order["days_until_expected"]
			if within is None or within > int(arriving_within_days):
				continue
		orders.append(order)

	return {"as_of": str(today), "count": len(orders), "purchase_orders": orders}


# --------------------------------------------------------------------------
# The aggregate
# --------------------------------------------------------------------------


def procurement_status(arriving_within_days: int | None = None):
	"""One answer to «что происходит с закупками».

	Also the trace behind «почему производство ждёт»: every material that is
	short is followed to the request that asked for it and the order that was
	placed for it, so the chain is read out of ERPNext rather than inferred by
	a model from three separate answers.
	"""
	from korkem_ai.korkem_ai.tools.procurement import factory_shortage

	today = getdate(nowdate())
	horizon = 7 if arriving_within_days is None else int(arriving_within_days)

	requests = search_material_requests()["material_requests"]
	orders = search_purchase_orders()["purchase_orders"]
	shortage = factory_shortage()

	unordered = [r for r in requests if not r["fully_ordered"]]
	overdue = [o for o in orders if o["overdue"]]
	arriving = [
		{
			"item_code": item["item_code"],
			"pending_qty": item["pending_qty"],
			"uom": item["uom"],
			"purchase_order": order["purchase_order"],
			"supplier": order["supplier"],
			"expected_on": order["expected_on"],
			"sales_order": item["sales_order"],
		}
		for order in orders
		if order["days_until_expected"] is not None and order["days_until_expected"] <= horizon
		for item in order["items"]
		if item["pending_qty"] > 0
	]

	# Shortage → request → order, followed per item. This is the whole point of
	# the slice: "заблокировано" with the reason attached and no guessing.
	requested_for = {
		item["item_code"]: request
		for request in requests
		for item in request["items"]
	}
	ordered_for: dict[str, list[dict]] = {}
	for order in orders:
		for item in order["items"]:
			if item["pending_qty"] > 0 or item["received_qty"] > 0:
				ordered_for.setdefault(item["item_code"], []).append(
					{
						"purchase_order": order["purchase_order"],
						"supplier": order["supplier"],
						"ordered_qty": item["ordered_qty"],
						"received_qty": item["received_qty"],
						"pending_qty": item["pending_qty"],
						"expected_on": order["expected_on"],
						"overdue": order["overdue"],
					}
				)

	blocking = []
	for item in shortage["items"]:
		# The *physical* gap, not the procurement one. Raising a request closes
		# the second and changes nothing on the shop floor — an aggregator built
		# on it reports "nothing is blocking production" the moment somebody
		# asks to buy the board, which was measured and is exactly backwards.
		if item["physical_shortage_qty"] <= 0:
			continue
		request = requested_for.get(item["item_code"])
		on_order = ordered_for.get(item["item_code"], [])
		arrived = sum(row["received_qty"] for row in on_order)
		outstanding = sum(row["pending_qty"] for row in on_order)
		if on_order and outstanding <= 0:
			stage = RECEIVED
		elif arrived > 0:
			stage = PARTIALLY_RECEIVED
		elif on_order:
			stage = ORDERED
		elif request:
			stage = REQUESTED
		else:
			stage = NOT_REQUESTED
		blocking.append(
			{
				"item_code": item["item_code"],
				"shortage_qty": item["physical_shortage_qty"],
				"on_order_qty": item["on_order_qty"],
				"uom": item["uom"],
				"severity": item["severity"],
				"stage": stage,
				"received_qty": round(arrived, 3),
				"awaiting_qty": round(outstanding, 3),
				"material_request": request["material_request"] if request else None,
				"purchase_orders": on_order,
				"orders_blocked": [o["sales_order"] for o in item["orders_blocked"]],
				"needed_by": item["earliest_required_date"],
			}
		)

	return {
		"as_of": str(today),
		"horizon_days": horizon,
		"summary": {
			"open_material_requests": len(requests),
			"requests_not_fully_ordered": len(unordered),
			"open_purchase_orders": len(orders),
			"overdue_purchase_orders": len(overdue),
			"items_arriving_within_horizon": len(arriving),
			"materials_blocking_production": len(blocking),
		},
		"material_requests": requests,
		"purchase_orders": orders,
		"arriving": arriving,
		"blocking_production": blocking,
	}


# --------------------------------------------------------------------------
# What arrived
# --------------------------------------------------------------------------


def search_receipts(
	received_within_days: int | None = None,
	supplier: str | None = None,
	item_code: str | None = None,
	limit: int | None = None,
):
	"""Goods that have actually arrived.

	Deliberately a separate reading from `search_purchase_orders`, which says
	what is *expected*. «Что пришло сегодня» and «что мы ждём» are opposite
	questions, and answering them from one list is how a shop ends up cutting
	board that is still on a lorry.
	"""
	today = getdate(nowdate())
	cap = min(int(limit or MAX_ROWS), MAX_ROWS)

	filters = {"docstatus": 1, "is_return": 0}
	if supplier:
		filters["supplier"] = supplier
	if received_within_days is not None:
		filters["posting_date"] = [">=", add_days(nowdate(), -int(received_within_days))]

	headers = frappe.get_list(
		"Purchase Receipt",
		filters=scoped(filters),
		fields=["name", "supplier", "status", "posting_date", "company"],
		order_by="posting_date desc, creation desc",
		limit_page_length=cap,
	)
	names = [row["name"] for row in headers]

	rows: dict[str, list[dict]] = {}
	if names:
		item_filters = {"parent": ["in", names]}
		if item_code:
			item_filters["item_code"] = item_code
		for row in frappe.get_all(
			"Purchase Receipt Item",
			filters=item_filters,
			fields=[
				"parent",
				"item_code",
				"item_name",
				"received_qty",
				"rejected_qty",
				"qty",
				"uom",
				"warehouse",
				"purchase_order",
				"material_request",
			],
			order_by="idx asc",
		):
			rows.setdefault(row["parent"], []).append(row)

	receipts = []
	for header in headers:
		lines = rows.get(header["name"], [])
		if item_code and not lines:
			continue
		receipts.append(
			{
				"purchase_receipt": header["name"],
				"supplier": header["supplier"],
				"status": header["status"],
				"received_on": str(header["posting_date"]),
				"days_ago": (today - getdate(header["posting_date"])).days,
				"items": [
					{
						"item_code": line["item_code"],
						"item_name": line["item_name"],
						"received_qty": flt(line["received_qty"]),
						"accepted_qty": flt(line["qty"]),
						"rejected_qty": flt(line["rejected_qty"]),
						"uom": line["uom"],
						"warehouse": line["warehouse"],
						"purchase_order": line["purchase_order"],
						"material_request": line["material_request"],
					}
					for line in lines
				],
			}
		)

	return {"as_of": str(today), "count": len(receipts), "receipts": receipts}


# --------------------------------------------------------------------------
# Booking it in
# --------------------------------------------------------------------------


# --------------------------------------------------------------------------
# Placing the order
# --------------------------------------------------------------------------


# --------------------------------------------------------------------------
# Registration
# --------------------------------------------------------------------------


def _api():
	"""The published endpoint the receiving tool is an alias for.

	Lazy, so registering tools does not depend on app load order.
	"""
	from korkem_manufacturing.api import purchasing

	return purchasing


register(
	ToolSpec(
		name="procurement.search_material_requests",
		description=(
			"Purchase requests and how much of each is still not ordered. Use for "
			"«какие заявки на закупку открыты», «что ещё не заказано», «по каким "
			"материалам нет заказа поставщику». For what is already on order use "
			"procurement.search_purchase_orders."
		),
		input_schema={
			"type": "object",
			"properties": {
				"only_unordered": {
					"type": "boolean",
					"description": "Only requests with something still to order.",
				},
				"status": {"type": "string", "description": "An exact ERPNext status, if asked for."},
				"limit": {"type": "integer", "minimum": 1, "maximum": MAX_ROWS},
			},
			"required": [],
		},
		handler=search_material_requests,
		risk=Risk.READ,
		doctypes=("Material Request",),
		audit_category="procurement",
	)
)

register(
	ToolSpec(
		name="procurement.search_purchase_orders",
		description=(
			"What is on order from suppliers, what has arrived, and when the rest "
			"is due. Use for «что заказано», «что придёт на этой неделе», «покажи "
			"просроченные закупки». Ordered is not the same as received — report "
			"both as given."
		),
		input_schema={
			"type": "object",
			"properties": {
				"arriving_within_days": {
					"type": "integer",
					"minimum": 1,
					"maximum": 365,
					"description": "Only orders expected within this many days. Use 7 for «на этой неделе».",
				},
				"overdue_only": {"type": "boolean", "description": "Only orders past their promised date."},
				"status": {"type": "string", "description": "An exact ERPNext status, if asked for."},
				"limit": {"type": "integer", "minimum": 1, "maximum": MAX_ROWS},
			},
			"required": [],
		},
		handler=search_purchase_orders,
		risk=Risk.READ,
		doctypes=("Purchase Order",),
		audit_category="procurement",
	)
)

register(
	ToolSpec(
		name="procurement.procurement_status",
		description=(
			"The whole purchasing picture at once: open requests, what is on order, "
			"what is overdue, what arrives soon, and which shortages are holding "
			"production up with the stage each one has reached. Use for «что "
			"происходит с закупками», «что блокирует производство», «что требует "
			"внимания в закупках». Prefer this over calling several procurement "
			"tools in a row."
		),
		input_schema={
			"type": "object",
			"properties": {
				"arriving_within_days": {
					"type": "integer",
					"minimum": 1,
					"maximum": 365,
					"description": "Horizon for what counts as arriving soon. Defaults to 7.",
				},
			},
			"required": [],
		},
		handler=procurement_status,
		risk=Risk.READ,
		doctypes=("Material Request", "Purchase Order", "Sales Order", "BOM", "Bin"),
		audit_category="procurement",
		timeout=60,
	)
)

register(
	ToolSpec(
		name="procurement.search_receipts",
		description=(
			"Deliveries that have actually arrived, with what was received into "
			"which warehouse. Use for «что пришло сегодня», «пришла ли ДСП 16мм», "
			"«пришёл ли заказ от поставщика X». For what is still expected use "
			"procurement.search_purchase_orders instead — arrived and expected "
			"are opposite questions."
		),
		input_schema={
			"type": "object",
			"properties": {
				"received_within_days": {
					"type": "integer",
					"minimum": 1,
					"maximum": 365,
					"description": "Only deliveries booked in within this many days. Use 1 for «сегодня».",
				},
				"supplier": {"type": "string", "description": "Only this supplier's deliveries."},
				"item_code": {"type": "string", "description": "Only deliveries containing this material."},
				"limit": {"type": "integer", "minimum": 1, "maximum": MAX_ROWS},
			},
			"required": [],
		},
		handler=search_receipts,
		risk=Risk.READ,
		doctypes=("Purchase Receipt",),
		audit_category="procurement",
	)
)

register(
	ToolSpec(
		name="inventory.receive_purchase_order",
		description=(
			"Book a delivery in against a purchase order, which puts the material "
			"on the shelf and unblocks production. Use when the user says the "
			"goods have arrived — «прими поставку», «материал пришёл». Quantities "
			"come from the order; pass items only for a partial delivery, and "
			"never a number the user did not give you. Requires confirmation."
		),
		input_schema={
			"type": "object",
			"properties": {
				"purchase_order": {"type": "string", "description": "The order the goods came against"},
				"items": {
					"type": "array",
					"description": "Only for a partial delivery. Omit to receive everything outstanding.",
					"items": {
						"type": "object",
						"properties": {
							"item_code": {"type": "string"},
							"qty": {"type": "number", "description": "How much actually arrived"},
						},
						"required": ["item_code", "qty"],
					},
				},
			},
			"required": ["purchase_order"],
		},
		handler=_api().receive_purchase_order,
		risk=Risk.WRITE,
		doctypes=("Purchase Receipt",),
		audit_category="inventory",
		timeout=60,
	)
)

register(
	ToolSpec(
		name="procurement.create_purchase_order",
		description=(
			"Place a purchase order with a supplier for what a material request "
			"still needs. Supplier and price come from ERPNext — never invent "
			"either; if the tool reports one is missing, tell the user and stop. "
			"Requires the user to confirm before anything is sent."
		),
		input_schema={
			"type": "object",
			"properties": {
				"material_request": {"type": "string", "description": "The request to order against"},
				"supplier": {
					"type": "string",
					"description": (
						"Only when the user names one. Leave it out to use the "
						"supplier configured on the items."
					),
				},
				"schedule_date": {"type": "string", "description": "Required-by date, YYYY-MM-DD"},
			},
			"required": ["material_request"],
		},
		handler=_api().create_purchase_order,
		risk=Risk.WRITE,
		doctypes=("Purchase Order",),
		audit_category="procurement",
		timeout=60,
	)
)
