# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""What is to be ordered from the suppliers, and a delivery of several films
(owner, 12.11.2026: «с утра записал одну плёнку, к 12:00 набил 4 заказа…
одним кликом итоговым отчётом за день отправить поставщику»).

**«К заказу»** is one list that fills up over the day. A line is a film, so
many metres, for a customer or for the shelf. It gets there three ways: put
in by hand; from a sale that wanted more than there was; and by itself, when
a film runs below its minimum — such a line is offered, not stored, until it
is sent or struck off. The list is laid out by supplier: whom a film was
bought from last, else the one its card names.

A supplier's lines go out in one WhatsApp message (`sent`); when he confirms,
the delivery is entered with `receive_many` — the lines come in as rolls on
their way, and when a roll comes (`film_dept.arrived`), the metres wanted
for a customer are put by for him (`fulfil`).

**A delivery of several films** (`receive_many`) is one supplier, one day,
one car: a roll per film, tied by a batch. What the bringing cost is carried
by the first roll — one payment, one debt to the carrier — and every roll
says who paid, so logistics per metre counts all of their metres.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, get_fullname, getdate, now_datetime, nowdate

from korkem_manufacturing.services import audit, film_catalog, film_dept, material_stock, price_visibility
from korkem_manufacturing.services.scope import current_company

OPEN, SENT, ORDERED, RECEIVED, DROPPED = "Open", "Sent", "Ordered", "Received", "Dropped"
#: The lines still to be ordered: on the list.
WANTED = (OPEN, SENT)
#: A delivery of more films than this is two deliveries.
MAX_LINES = 60
_DOC = "Film Order Line"
_FIELDS = ["name", "item", "supplier", "metres", "customer", "status", "added_by", "sent_at", "creation", "note",
		   "receipt"]


# --------------------------------------------------------------------------
# «К заказу»
# --------------------------------------------------------------------------


def wanted() -> dict:
	"""The list, by supplier: what is to be ordered, and what was sent and
	waits for an answer. Films that ran low and are on nobody's line are
	offered at the end of their supplier's lines."""
	material_stock._ensure_staff()
	company = current_company()
	money = price_visibility.can_see_prices()
	films = {f["item"]: f for f in film_dept.stock()["films"]}
	rows = frappe.get_all(_DOC, filters={"company": company, "status": ["in", list(WANTED)]},
						  fields=_FIELDS, order_by="creation asc", limit_page_length=2000)
	# A film struck off today is not offered again today.
	dropped = set(frappe.get_all(_DOC, filters={"company": company, "status": DROPPED,
												"creation": [">=", f"{nowdate()} 00:00:00"]}, pluck="item"))
	listed = {r.item for r in rows}
	lines = [_line(r, films, money) for r in rows]
	for f in films.values():
		order = f.get("reorder")
		if order and f["item"] not in listed and f["item"] not in dropped:
			lines.append({
				"id": None, "item": f["item"], "title": _title(f), "metres": order["metres"],
				"supplier": order.get("supplier"), "customer": None, "customer_name": None,
				"status": OPEN, "auto": True, "at": None, "by": None, "sent_at": None,
				"free": round(flt(f.get("free")), 2), "price_m": order.get("price_m") if money else None,
			})
	groups: dict[str | None, dict] = {}
	for line in lines:
		g = groups.get(line["supplier"])
		if g is None:
			g = groups[line["supplier"]] = _group(line["supplier"])
		g["sent" if line["status"] == SENT else "open"].append(line)
	out = sorted(groups.values(), key=lambda g: (g["supplier"] is None, not g["open"], g["name"].casefold()))
	for g in out:
		for key in ("open", "sent"):
			g[f"{key}_m"] = round(sum(x["metres"] for x in g[key]), 2)
		sent = [x["sent_at"] for x in g["sent"] if x["sent_at"]]
		g["sent_at"] = max(sent) if sent else None
	return {
		"suppliers": out,
		"count": sum(len(g["open"]) for g in out),
		"metres": round(sum(g["open_m"] for g in out), 2),
		"waiting": sum(1 for g in out if g["sent"]),
		"can_edit": material_stock.can_edit(),
	}


def counts(films: list[dict]) -> tuple[int, int]:
	"""(films on the list to be ordered, suppliers waited on) — for the
	stock's own button, without laying the list out."""
	company = current_company()
	rows = frappe.get_all(_DOC, filters={"company": company, "status": ["in", list(WANTED)]},
						  fields=["item", "status", "supplier"], limit_page_length=2000)
	dropped = set(frappe.get_all(_DOC, filters={"company": company, "status": DROPPED,
												"creation": [">=", f"{nowdate()} 00:00:00"]}, pluck="item"))
	listed = {r.item for r in rows}
	offered = sum(1 for f in films if f.get("reorder") and f["item"] not in listed and f["item"] not in dropped)
	wanted = len({r.item for r in rows if r.status == OPEN}) + offered
	return wanted, len({r.supplier for r in rows if r.status == SENT})


def _group(supplier: str | None) -> dict:
	card = frappe.db.get_value(
		"Supplier", supplier,
		["supplier_name", "korkem_src_city", "korkem_src_contact", "korkem_src_phone", "korkem_src_whatsapp",
		 "korkem_src_order_until"], as_dict=True,
	) if supplier else None
	card = card or {}
	return {
		"supplier": supplier,
		"name": card.get("supplier_name") or supplier or "",
		"city": card.get("korkem_src_city"),
		"contact": card.get("korkem_src_contact"),
		"phone": card.get("korkem_src_phone"),
		"whatsapp": card.get("korkem_src_whatsapp"),
		"order_until": card.get("korkem_src_order_until"),
		"open": [],
		"sent": [],
	}


def _line(r, films: dict, money: bool) -> dict:
	f = films.get(r.item) or film_catalog.film(r.item)
	return {
		"id": r.name,
		"item": r.item,
		"title": _title(f),
		"metres": flt(r.metres),
		"supplier": r.supplier,
		"customer": r.customer,
		"customer_name": frappe.db.get_value("Customer", r.customer, "customer_name") if r.customer else None,
		"status": r.status,
		"auto": False,
		"at": str(r.creation)[11:16] if str(getdate(r.creation)) == nowdate() else str(getdate(r.creation)),
		"by": get_fullname(r.added_by) if r.added_by else None,
		"sent_at": str(r.sent_at)[:16] if r.sent_at else None,
		"free": round(flt(f.get("free", flt(f.get("on_hand")))), 2),
		"price_m": (flt(f.get("price_m")) or None) if money else None,
		"note": r.note,
	}


def _title(f: dict) -> str:
	return f.get("label") or f"{f.get('maker') or ''} · {f.get('colour') or ''}".strip(" ·")


def _supplier_of(item: str) -> str | None:
	"""Whom a film is ordered from: whom it was bought from last, else the
	one its card names."""
	last = frappe.db.sql(
		"""select e.korkem_supplier from `tabStock Entry Detail` d join `tabStock Entry` e on e.name = d.parent
		where d.item_code = %s and e.docstatus in (0, 1) and e.korkem_material_receipt = 1
			and e.korkem_supplier is not null and e.korkem_supplier != ''
		order by e.creation desc limit 1""",
		(item,),
	)
	return (last[0][0] if last else None) or film_catalog.film(item).get("supplier") or None


def _supplier(supplier: str | None) -> str | None:
	supplier = (supplier or "").strip()
	if not supplier:
		return None
	if not frappe.db.exists("Supplier", {"name": supplier, "disabled": 0}):
		frappe.throw("Такого поставщика нет.", frappe.DoesNotExistError)
	return supplier


def _customer(customer: str | None) -> str | None:
	customer = (customer or "").strip()
	if not customer:
		return None
	if not frappe.db.exists("Customer", {"name": customer, "disabled": 0}):
		frappe.throw("Такого клиента нет.", frappe.DoesNotExistError)
	return customer


def add(item: str, metres, customer: str | None = None, supplier: str | None = None,
		note: str | None = None) -> dict:
	"""A film to order: so many metres, for a customer or for the shelf."""
	material_stock._ensure_editor()
	film_dept._film(item)
	qty = float(film_dept._metres(metres, "Метров"))
	doc = frappe.get_doc({
		"doctype": _DOC, "company": current_company(), "item": item, "metres": qty,
		"customer": _customer(customer), "supplier": _supplier(supplier) or _supplier_of(item),
		"status": OPEN, "added_by": frappe.session.user,
		"note": " ".join(str(note or "").split())[:140] or None,
	}).insert(ignore_permissions=True)
	audit.record_audit(action="film.order_added", entity_type=_DOC, entity_id=doc.name,
					   diff={"item": item, "metres": qty, "customer": doc.customer, "supplier": doc.supplier})
	return {"id": doc.name, "supplier": doc.supplier}


def _wanted_line(line: str):
	material_stock._ensure_editor()
	row = frappe.db.get_value(_DOC, line, ["company", "status"], as_dict=True)
	if not row or row.company != current_company() or row.status not in WANTED:
		frappe.throw("Такой строки в заказе нет.", frappe.DoesNotExistError)
	return row


def update(line: str, metres=None, supplier: str | None = None, customer: str | None = None) -> dict:
	"""Another number of metres, another supplier, another customer. A
	field left out stays; an empty customer means for the shelf."""
	_wanted_line(line)
	values = {}
	if metres not in (None, ""):
		values["metres"] = float(film_dept._metres(metres, "Метров"))
	if supplier is not None:
		values["supplier"] = _supplier(supplier)
	if customer is not None:
		values["customer"] = _customer(customer)
	if values:
		frappe.db.set_value(_DOC, line, values)
		audit.record_audit(action="film.order_changed", entity_type=_DOC, entity_id=line, diff=values)
	return {"id": line, **values}


def drop(line: str | None = None, item: str | None = None) -> dict:
	"""Off the list. A film offered by itself (no line yet) is struck off
	for today by its `item`."""
	if line:
		_wanted_line(line)
		frappe.db.set_value(_DOC, line, "status", DROPPED)
		audit.record_audit(action="film.order_dropped", entity_type=_DOC, entity_id=line)
		return {"id": line, "status": DROPPED}
	material_stock._ensure_editor()
	film_dept._film(item)
	doc = frappe.get_doc({
		"doctype": _DOC, "company": current_company(), "item": item, "metres": 1, "status": DROPPED,
		"supplier": _supplier_of(item), "added_by": frappe.session.user, "note": "не заказывать сегодня",
	}).insert(ignore_permissions=True)
	audit.record_audit(action="film.order_dropped", entity_type=_DOC, entity_id=doc.name, diff={"item": item})
	return {"id": doc.name, "status": DROPPED}


def sent(supplier: str | None) -> dict:
	"""The supplier's list went out: its lines wait for his answer. The
	films offered by themselves go with them and are on the list now."""
	material_stock._ensure_editor()
	company = current_company()
	supplier = _supplier(supplier)
	now = now_datetime()
	group = next((g for g in wanted()["suppliers"] if g["supplier"] == supplier), None)
	if not group or not group["open"]:
		frappe.throw("Отправлять нечего.")
	ids = []
	for line in group["open"]:
		if line["id"]:
			frappe.db.set_value(_DOC, line["id"], {"status": SENT, "sent_at": now})
			ids.append(line["id"])
		else:
			doc = frappe.get_doc({
				"doctype": _DOC, "company": company, "item": line["item"], "metres": line["metres"],
				"supplier": supplier, "status": SENT, "sent_at": now, "added_by": frappe.session.user,
				"note": "кончилась",
			}).insert(ignore_permissions=True)
			ids.append(doc.name)
	audit.record_audit(action="film.order_sent", entity_type="Supplier", entity_id=supplier or "—",
					   diff={"lines": ids})
	return {"supplier": supplier, "lines": ids, "sent_at": str(now)[:16]}


# --------------------------------------------------------------------------
# A delivery of several films
# --------------------------------------------------------------------------


def receive_many(supplier: str, lines, arrives_on: str | None = None, delivery=None,
				 received_by: str | None = None, note: str | None = None) -> dict:
	"""One supplier, several films: a roll each, one delivery, one day.

	A line: `item`, `metres`, `price_m`; `customer` — bought for him; `orders`
	— the «К заказу» lines it answers; `update_price` off for a one-off price.
	"""
	material_stock._ensure_editor()
	supplier = _supplier(supplier)
	if not supplier:
		frappe.throw("Выберите поставщика.")
	if isinstance(lines, str):
		lines = frappe.parse_json(lines)
	if not isinstance(lines, list) or not lines:
		frappe.throw("Добавьте хотя бы одну плёнку.")
	if len(lines) > MAX_LINES:
		frappe.throw(f"Не больше {MAX_LINES} плёнок в одной поставке.")
	if isinstance(delivery, str):
		delivery = frappe.parse_json(delivery) if delivery.strip() else None
	delivery = dict(delivery or {})
	company = current_company()
	# Every line is checked before anything is written.
	checked = []
	for n, line in enumerate(lines, 1):
		if not isinstance(line, dict):
			frappe.throw(f"Строка {n}: не плёнка.")
		item = line.get("item")
		film_dept._film(item)
		metres = film_dept._metres(line.get("metres"), f"Строка {n}")
		price = film_dept._money(line.get("price_m"), f"Строка {n}: цена за метр")
		if price <= 0:
			frappe.throw(f"Строка {n}: цена за метр — больше нуля.")
		orders = line.get("orders") or []
		if isinstance(orders, str):
			orders = [orders]
		for o in orders:
			row = frappe.db.get_value(_DOC, o, ["company", "status", "item"], as_dict=True)
			if not row or row.company != company or row.status not in WANTED or row.item != item:
				frappe.throw(f"Строка {n}: такой строки в заказе нет.", frappe.DoesNotExistError)
		checked.append({
			"item": item, "metres": metres, "price": price, "customer": _customer(line.get("customer")),
			"orders": list(orders), "update_price": line.get("update_price", True),
		})
	batch = f"FB-{frappe.generate_hash(length=10)}"
	receipts = []
	first = None
	for n, line in enumerate(checked):
		got = film_dept.receive(
			line["item"], line["metres"], line["price"], supplier, note=note,
			update_price=line["update_price"],
			# The bringing is paid once: the first roll carries it.
			delivery=delivery if n == 0 else {**delivery, "amount": 0},
			received_by=received_by, arrives_on=arrives_on,
		)
		entry = got["receipt"]
		receipts.append(entry)
		values = {"korkem_film_batch": batch}
		if n == 0:
			first = frappe.db.get_value("Stock Entry", entry, ["korkem_delivery_payer", "korkem_delivery_paid_by",
															   "korkem_delivery_method"], as_dict=True)
		elif first and first.korkem_delivery_payer:
			# Who paid — on every roll, so logistics per metre counts them all.
			values.update({"korkem_delivery_payer": first.korkem_delivery_payer,
						   "korkem_delivery_paid_by": first.korkem_delivery_paid_by,
						   "korkem_delivery_method": first.korkem_delivery_method})
		frappe.db.set_value("Stock Entry", entry, values, update_modified=False)
		# What it answers on the list, and a customer of the delivery's own.
		ids = list(line["orders"])
		if line["customer"] and not any(frappe.db.get_value(_DOC, o, "customer") == line["customer"] for o in ids):
			ids.append(frappe.get_doc({
				"doctype": _DOC, "company": company, "item": line["item"], "metres": float(line["metres"]),
				"customer": line["customer"], "supplier": supplier, "status": SENT,
				"added_by": frappe.session.user,
			}).insert(ignore_permissions=True).name)
		for o in ids:
			frappe.db.set_value(_DOC, o, {"status": ORDERED, "receipt": entry, "supplier": supplier})
		if frappe.db.get_value("Stock Entry", entry, "docstatus") == 1:
			fulfil(entry)
	audit.record_audit(action="film.delivery_received", entity_type="Supplier", entity_id=supplier,
					   diff={"batch": batch, "receipts": receipts, "arrives_on": arrives_on})
	return {"batch": batch, "receipts": receipts}


def fulfil(entry: str) -> list[str]:
	"""A roll is on the shelf: what was wanted of it for a customer is put by
	for him — as much as came. The lines it answered are done."""
	holds = []
	item = frappe.db.get_value("Stock Entry Detail", {"parent": entry}, "item_code")
	for r in frappe.get_all(_DOC, filters={"receipt": entry, "status": ORDERED},
							fields=["name", "customer", "metres"], order_by="creation asc"):
		if r.customer:
			film = film_catalog.film(item)
			put_by = sum(h["metres"] for h in film_dept._holds([item]).get(item, []))
			free = flt(film.get("on_hand")) - flt(film.get("held")) - put_by
			metres = min(flt(r.metres), free)
			if metres > 0:
				holds.append(film_dept.hold(item, r.customer, metres, note="пришла под заказ")["hold"])
		frappe.db.set_value(_DOC, r.name, "status", RECEIVED)
	return holds


def arrived_batch(batch: str) -> dict:
	"""The whole delivery is here: every roll of it still on its way."""
	material_stock._ensure_editor()
	entries = frappe.get_all("Stock Entry", filters={"company": current_company(), "korkem_film_batch": batch,
													 "docstatus": 0, "korkem_film_due": ["is", "set"]},
							 pluck="name", order_by="creation asc")
	if not entries:
		frappe.throw("Такой поставки в пути нет.", frappe.DoesNotExistError)
	for entry in entries:
		film_dept.arrived(entry)
	return {"batch": batch, "receipts": entries}
