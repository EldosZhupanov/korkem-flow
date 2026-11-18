# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The general search — one line for the whole company (owner, 18.11.2026, variant Б).

One request answers «найди» across what a person may see: customers with
what they owe, facade and CNC orders, payments, films and the makers'
decors, and — for whoever ERPNext lets see them — other orders, work orders
and stock. How the text is read (the wrong layout, Latin spelling, a typo,
a phone, an order's number) is `search_text`; this module only decides
where to look and who may look there.

Nothing is written. Each part asks its own module's door — the facade
editors' (`facade_prices.can_edit`), the film staff's
(`material_stock.is_staff`), ERPNext's own permissions for the rest — so a
person sees here exactly what he would see in that section, and a part he
may not open is simply absent, never an error.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_manufacturing.services import (
	cnc_orders,
	directions,
	facade_prices,
	film_catalog,
	film_decors,
	film_dept,
	material_stock,
	mdf_customers,
	mdf_orders,
	search_text,
)
from korkem_manufacturing.services.scope import current_company

#: Rows per part — a palette, not a list to scroll.
LIMIT = 5
MAX_LIMIT = 20

#: How far back a payment is still worth showing.
PAYMENT_DAYS = 180

#: The parts, in the order the window shows them.
PARTS = ("customers", "facade_orders", "cnc_orders", "payments", "films", "decors",
		 "orders", "work_orders", "stock")


def find(query: str | None, limit: int | None = None) -> dict:
	"""Everything this person may see that matches what was typed."""
	limit = max(1, min(int(limit or LIMIT), MAX_LIMIT))
	text = " ".join(str(query or "").split())[:100]
	readings = search_text.variants(text)
	phone = search_text.phone_of(text)
	number = search_text.number_of(text)
	editor = facade_prices.can_edit()
	film = material_stock.is_staff()
	result = {
		"query": text,
		"readings": readings,
		"kind": "phone" if phone else "number" if number else "text",
		"allowed": {"facades": editor, "cnc": editor, "film": film, "film_edit": film and material_stock.can_edit()},
		"parts": {},
	}
	if not readings or (len(readings[0]) < 2 and not number):
		return result
	company = current_company()
	parts = result["parts"]

	customers: list[dict] = []
	if editor or film:
		customers = _customers(company, readings, phone, editor=editor, film=film, limit=limit)
		parts["customers"] = customers
	if editor:
		names = [c["customer"] for c in customers]
		parts["facade_orders"] = _orders(company, directions.FACADES, readings, number, phone, names, limit)
		parts["cnc_orders"] = _orders(company, directions.CNC, readings, number, phone, names, limit)
		parts["payments"] = _payments(company, names, limit)
	if film and not phone:
		parts["films"] = _films(readings, limit)
		parts["decors"] = _decors(company, readings, limit)
	if not phone:
		parts.update(_erpnext(text, readings, limit))
	return result


# --- customers -------------------------------------------------------------


def _customers(company: str, readings: list[str], phone: str | None, *, editor: bool, film: bool,
			   limit: int) -> list[dict]:
	filters = {"disabled": 0} if editor else {"disabled": 0, "korkem_film_customer": 1}
	rows = frappe.get_all(
		"Customer", filters=filters,
		fields=[*film_dept.CUSTOMER_FIELDS, "korkem_organization", "korkem_film_customer"],
		limit_page_length=mdf_customers.MAX,
	)
	scored = []
	for row in rows:
		if phone:
			own = search_text.digits(row.mobile_no)
			points = 10.0 if own and phone in own else 0.0
		else:
			points = search_text.score(readings, row.customer_name, row.korkem_organization)
		if points:
			scored.append((points, row))
	scored.sort(key=lambda p: (-p[0], search_text.fold(p[1].customer_name)))
	allowed = mdf_customers._allowed([r.name for _, r in scored], company) if scored else set()
	found = [r for _, r in scored if r.name in allowed][:limit]
	if not found:
		return []
	money = _facade_money(company, [r.name for r in found]) if editor else {}
	cards = {}
	if film:
		cards = {c["customer"]: c for c in film_dept.customers_of([r for r in found if r.korkem_film_customer])}
	return [
		{
			"customer": r.name,
			"name": r.customer_name or r.name,
			"phone": r.mobile_no,
			"organization": r.korkem_organization,
			"orders": money.get(r.name, {}).get("orders", 0),
			"debt": float(money.get(r.name, {}).get("debt", 0)),
			"film": cards.get(r.name),
		}
		for r in found
	]


def _facade_money(company: str, customers: list[str]) -> dict:
	"""Each customer's facade and CNC orders: how many, and what is owed."""
	out: dict[str, dict] = {}
	for row in frappe.get_all(
		"Sales Order",
		filters={"company": company, "customer": ["in", customers], "docstatus": ["<", 2],
				 "korkem_direction": ["in", [directions.FACADES, directions.CNC]]},
		fields=["customer", "docstatus", "grand_total", "advance_paid", "korkem_tags"],
		limit_page_length=0,
	):
		entry = out.setdefault(row.customer, {"orders": 0, "debt": Decimal(0)})
		entry["orders"] += 1
		entry["debt"] += mdf_orders._debt(row)
	return out


# --- orders ----------------------------------------------------------------

_FACADE_FIELDS = ["name", "docstatus", "transaction_date", "delivery_date", "customer", "customer_name",
				  "grand_total", "advance_paid", "korkem_tags", "korkem_decor_top", "korkem_ready_on",
				  "korkem_handed_over_on", "korkem_hold_reason", "contact_mobile", *mdf_orders.STAGES.values()]
_CNC_FIELDS = ["name", "docstatus", "transaction_date", "delivery_date", "customer", "customer_name",
			   "grand_total", "advance_paid", "korkem_tags", "korkem_ready_on", "korkem_handed_over_on",
			   "korkem_cnc_started_on", "korkem_hold_reason", "contact_mobile"]


def _orders(company: str, direction: str, readings: list[str], number: int | None, phone: str | None,
			customers: list[str], limit: int) -> list[dict]:
	cnc = direction == directions.CNC
	fields = _CNC_FIELDS if cnc else _FACADE_FIELDS
	base = {"company": company, "korkem_direction": direction}
	found: dict[str, tuple[float, object]] = {}

	def take(rows, points):
		for row in rows:
			if row.name not in found or found[row.name][0] < points:
				found[row.name] = (points, row)

	if number:
		rows = frappe.get_all("Sales Order", filters={**base, "name": ["like", f"%{number}"]}, fields=fields,
							  order_by="creation desc", limit_page_length=50)
		take([r for r in rows if search_text.number_in(r.name) == number], 20.0)
	if customers:
		rows = frappe.get_all("Sales Order", filters={**base, "customer": ["in", customers]}, fields=fields,
							  order_by="creation desc", limit_page_length=limit * 4)
		# The customer's best match first, his newest order first within it.
		rank = {c: len(customers) - i for i, c in enumerate(customers)}
		take(rows, 0)
		for row in rows:
			found[row.name] = (max(found[row.name][0], 5.0 + rank.get(row.customer, 0) / 100), row)
	if not phone:
		or_filters = []
		for reading in readings:
			like = f"%{reading}%"
			or_filters += [["Sales Order", "customer_name", "like", like], ["Sales Order", "name", "like", like]]
			if not cnc:
				or_filters.append(["Sales Order", "korkem_decor_top", "like", like])
		rows = frappe.get_all("Sales Order", filters=base, or_filters=or_filters, fields=fields,
							  order_by="creation desc", limit_page_length=limit * 6)
		for row in rows:
			points = search_text.score(readings, row.name, row.customer_name, row.get("korkem_decor_top"))
			if points:
				take([row], points)
	else:
		rows = frappe.get_all("Sales Order", filters={**base, "contact_mobile": ["is", "set"]}, fields=fields,
							  order_by="creation desc", limit_page_length=500)
		take([r for r in rows if phone in search_text.digits(r.contact_mobile)], 8.0)
	ordered = sorted(found.values(), key=lambda p: (-p[0], -_created(p[1])))
	return [_order_row(row, cnc) for _, row in ordered[:limit]]


def _created(row) -> int:
	return getdate(row.transaction_date).toordinal() if row.transaction_date else 0


def _order_row(row, cnc: bool) -> dict:
	status = cnc_orders.status_of(row) if cnc else mdf_orders.status_of(row)
	open_ = status in (("queued", "on_machine") if cnc else ("accepted", "in_shop"))
	return {
		"name": row.name,
		"number": search_text.number_in(row.name),
		"customer": row.customer,
		"customer_name": row.customer_name,
		"status": status,
		"decor": row.get("korkem_decor_top"),
		"created_on": str(row.transaction_date) if row.transaction_date else None,
		"due": str(row.delivery_date) if row.delivery_date else None,
		"overdue": bool(open_ and row.delivery_date and getdate(row.delivery_date) < getdate(nowdate())),
		"total": flt(row.grand_total),
		"debt": float((cnc_orders._debt if cnc else mdf_orders._debt)(row)),
	}


# --- money -----------------------------------------------------------------


def _payments(company: str, customers: list[str], limit: int) -> list[dict]:
	"""The latest payments of the customers found — «Ерлан платил?»."""
	if not customers:
		return []
	rows = frappe.db.sql(
		"""
		select pe.posting_date as date, pe.mode_of_payment as method, per.reference_name as order_name,
			   so.customer, so.customer_name, so.korkem_direction as direction, per.allocated_amount as amount
		from `tabPayment Entry Reference` per
		join `tabPayment Entry` pe on pe.name = per.parent
		join `tabSales Order` so on so.name = per.reference_name
		where per.reference_doctype = 'Sales Order' and pe.docstatus = 1 and pe.company = %(company)s
		  and so.customer in %(customers)s and so.korkem_direction in %(directions)s
		  and pe.posting_date >= %(since)s
		order by pe.posting_date desc, pe.creation desc
		limit %(limit)s
		""",
		{"company": company, "customers": tuple(customers), "directions": (directions.FACADES, directions.CNC),
		 "since": add_days(nowdate(), -PAYMENT_DAYS), "limit": limit},
		as_dict=True,
	)
	return [{"date": str(r.date), "method": r.method, "order": r.order_name, "customer": r.customer,
			 "customer_name": r.customer_name, "cnc": r.direction == directions.CNC, "amount": flt(r.amount)}
			for r in rows]


# --- film ------------------------------------------------------------------


def _films(readings: list[str], limit: int) -> list[dict]:
	scored = []
	for f in film_catalog.catalog()["films"]:
		points = search_text.score(readings, f.get("label"), f.get("maker"), f.get("colour"), f.get("code"),
								   f.get("type"), f.get("collection"))
		if points:
			# A film in work before one in the archive, then what is on hand.
			scored.append((points + (0 if f.get("archived") else 0.5), f))
	scored.sort(key=lambda p: (-p[0], -flt(p[1].get("on_hand"))))
	return [f for _, f in scored[:limit]]


def _decors(company: str, readings: list[str], limit: int) -> list[dict]:
	scored = []
	for r in film_decors._rows(company):
		points = search_text.score(readings, r.decor_name, r.code, r.maker, r.collection)
		if points:
			scored.append((points, r))
	scored.sort(key=lambda p: (-p[0], search_text.fold(p[1].maker), search_text.fold(p[1].decor_name)))
	# The catalogue's own shape (`film_decors.decors`), so the window opens the same card.
	return [{"decor": r.name, "maker": r.maker, "name": r.decor_name, "collection": r.collection,
			 "code": r.code, "thickness": r.thickness, "hex": r.hex, "image": r.image, "films": []}
			for _, r in scored[:limit]]


# --- what ERPNext itself lets this person see ---------------------------------


def _erpnext(text: str, readings: list[str], limit: int) -> dict:
	"""Other orders, work orders and stock — through `api.queries`, whose
	`frappe.get_list` applies ERPNext's own permissions. The typed text
	first; another reading only when it found nothing."""
	from korkem_manufacturing.api import queries

	sources = {
		"orders": (lambda q: queries.sales_orders(search=q, limit=limit, direction=directions.FURNITURE), "orders"),
		"work_orders": (lambda q: queries.work_orders(search=q, limit=limit), "orders"),
		"stock": (lambda q: queries.stock(search=q, limit=limit), "items"),
	}
	out = {}
	for part, (fetch, key) in sources.items():
		try:
			rows = []
			for reading in dict.fromkeys([text, *readings[1:]]):
				rows = fetch(reading).get(key) or []
				if rows:
					break
		except frappe.PermissionError:
			continue
		out[part] = rows
	return out
