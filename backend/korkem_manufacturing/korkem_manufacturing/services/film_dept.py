# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The film department: it buys PVC film from wholesalers and sells it on.

A department of its own (owner, 10.11.2026), apart from the facade shop until
the two are joined: its stock in running metres, its customers, its sales.

**One ledger.** A receipt is the stock's own Material Receipt
(`material_stock.receive`). What leaves — a sale, a hand-over to the shop, a
write-off — is a Material Issue (`Stock Entry`) that says which of the three
it is (`korkem_film_kind`); the metres on hand are ERPNext's figure, and a
movement entered by mistake is cancelled, which puts the metres back.

**The shop is a customer like any other**: film that goes to our own press is
handed over here («в цех»), so the department's count stays true and the
report tells sold from used. Reserving film for a facade order comes when the
two are joined.

**A write-off always says why** — a sample, a damaged roll — so no metre
leaves without a word.

**Prices are per metre**: over the counter («розница») or to the trade
(«опт»), as the customer's card says, less the customer's own discount. The
seller may still type another price; the sale records what was charged.
"""

from __future__ import annotations

from decimal import Decimal, InvalidOperation

import frappe
from frappe.utils import add_days, date_diff, flt, get_fullname, getdate, nowdate

from korkem_manufacturing.services import audit, film_catalog, material_stock, price_visibility
from korkem_manufacturing.services.scope import current_company

SALE, SHOP, WRITE_OFF = "sale", "shop", "write_off"
KINDS = (SALE, SHOP, WRITE_OFF)
RETAIL, WHOLESALE = "retail", "wholesale"
TIERS = (RETAIL, WHOLESALE)
PAYMENT_METHODS = ("Перевод", "Наличные", "Карта")
WITH_BANK = ("Перевод", "Карта")

#: A customer who bought before and has not for this long is «уснул».
ASLEEP_DAYS = 60
MAX_METRES = Decimal("100000")


# --------------------------------------------------------------------------
# Stock
# --------------------------------------------------------------------------


#: Offered while the lists are empty; then they are the owner's own.
TRANSPORTS = ("Привёз поставщик", "Такси", "Газель", "КАМАЗ", "Транспортная компания", "Своя машина")
CITIES = ("Астана", "Алматы", "Караганда", "Семей", "Шымкент")
TRANSPORT_LIST, CITY_LIST = "Способ доставки", "Город доставки"


def delivery_options() -> dict:
	"""What a receipt asks about its delivery, and what a sale asks of its
	seller: the lists, the staff, and — by supplier — how the last roll came."""
	material_stock._ensure_staff()
	company = current_company()
	for kind, start in ((TRANSPORT_LIST, TRANSPORTS), (CITY_LIST, CITIES)):
		if not frappe.db.exists("Material Option", {"company": company, "kind": kind}) and material_stock.can_edit():
			for value in start:
				material_stock.put_option(kind, value)
	last = {}
	for r in frappe.get_all(
		"Stock Entry",
		filters={"company": company, "docstatus": 1, "korkem_material_receipt": 1,
				 "korkem_delivery_transport": ["is", "set"]},
		fields=["korkem_supplier", "korkem_delivery_transport", "korkem_delivery_city"],
		order_by="creation desc",
		limit_page_length=500,
	):
		last.setdefault(r.korkem_supplier, {"transport": r.korkem_delivery_transport, "city": r.korkem_delivery_city})
	cities = {
		s.name: s.korkem_src_city
		for s in frappe.get_all("Supplier", filters={"disabled": 0}, fields=["name", "korkem_src_city"])
		if s.get("korkem_src_city")
	}
	return {
		"transports": sorted(material_stock.enabled_values(TRANSPORT_LIST, company), key=_first(TRANSPORTS)),
		"cities": sorted(material_stock.enabled_values(CITY_LIST, company), key=str.casefold),
		"last": last,
		"supplier_cities": cities,
		"staff": staff(),
		"me": frappe.session.user,
		"drivers": drivers(company),
	}


def drivers(company: str | None = None) -> list[dict]:
	"""The drivers who brought film before, newest first, each once: to be
	picked again rather than typed."""
	seen, out = set(), []
	for r in frappe.get_all(
		"Stock Entry",
		filters={"company": company or current_company(), "korkem_material_receipt": 1, "docstatus": ["!=", 2],
				 "korkem_delivery_driver": ["is", "set"]},
		fields=["korkem_delivery_driver", "korkem_delivery_phone", "korkem_delivery_transport"],
		order_by="creation desc",
		limit_page_length=300,
	):
		key = (r.korkem_delivery_driver.casefold(), r.korkem_delivery_phone or "")
		if key in seen:
			continue
		seen.add(key)
		out.append({"driver": r.korkem_delivery_driver, "phone": r.korkem_delivery_phone,
					"transport": r.korkem_delivery_transport})
	return out[:50]


def _first(order: tuple):
	return lambda v: (order.index(v) if v in order else len(order), v.casefold())


def staff() -> list[dict]:
	"""Who works here: who may take a roll in, who may sell."""
	return [
		{"user": u.name, "name": u.full_name or u.name}
		for u in frappe.get_all(
			"User", filters={"enabled": 1, "user_type": "System User", "name": ["not in", ["Administrator", "Guest"]]},
			fields=["name", "full_name"], order_by="full_name asc", limit_page_length=500,
		)
	]


def _person(user: str | None) -> str | None:
	user = (user or "").strip()
	if not user:
		return None
	if not frappe.db.exists("User", {"name": user, "enabled": 1}):
		frappe.throw("Такого сотрудника нет.")
	return user


def receive(item: str, metres, price_m, supplier: str, received_on: str | None = None,
			note: str | None = None, update_price=True, delivery=None, received_by: str | None = None,
			arrives_on: str | None = None) -> dict:
	"""A roll or a cut bought from a wholesaler: so many metres at so much a metre.

	`arrives_on` after today: bought, on its way — not on the shelf and not
	for sale until it comes (owner, 11.11.2026); see `arrived`.

	The price paid becomes the card's purchase price (owner, 11.11.2026:
	prices change) — unless `update_price` is off, for a one-off discount.
	"""
	_film(item)
	due = _due(arrives_on)
	# How it came (owner, 11.11.2026). Left out: as the last roll of this
	# supplier came, else «привёз поставщик»; from the supplier's city; free;
	# taken in by whoever enters it.
	if isinstance(delivery, str):
		delivery = frappe.parse_json(delivery) if delivery.strip() else None
	delivery = delivery or {}
	company = current_company()
	last = frappe.db.get_value(
		"Stock Entry",
		{"company": company, "docstatus": 1, "korkem_material_receipt": 1, "korkem_supplier": supplier,
		 "korkem_delivery_transport": ["is", "set"]},
		["korkem_delivery_transport", "korkem_delivery_city"], as_dict=True, order_by="creation desc",
	) or {}
	transport = " ".join(str(delivery.get("transport") or last.get("korkem_delivery_transport")
							 or TRANSPORTS[0]).split())[:140]
	city = " ".join(str(delivery.get("from_city") or delivery.get("city") or last.get("korkem_delivery_city")
						or frappe.db.get_value("Supplier", supplier, "korkem_src_city") or "").split())[:140]
	cost = _money(delivery.get("amount") or 0, "За доставку")
	urgent = _yes(delivery.get("urgent"))
	taker = _person(received_by) or frappe.session.user
	# Who paid for the bringing (owner, 11.11.2026): the film department's
	# cash; an employee out of his pocket; nobody yet; or the supplier.
	payer, paid_by, pay_method = _delivery_payer(delivery, cost)
	if payer == PAYER_SUPPLIER:
		cost = Decimal(0)
	for kind, value in ((TRANSPORT_LIST, transport), (CITY_LIST, city)):
		if value and value not in material_stock.enabled_values(kind, company):
			material_stock.put_option(kind, value)
	result = material_stock.receive(
		item, metres, price_m, supplier, received_on=received_on, note=note,
		# What the bringing cost goes to logistics, apart from the price.
		delivery={"amount": cost, "from_city": city or "не указан", "transport": transport, "urgent": urgent}
		if cost > 0 else None,
		post=due is None,
	)
	frappe.db.set_value("Stock Entry", result["receipt"], {
		"korkem_received_by": taker, "korkem_delivery_transport": transport, "korkem_delivery_city": city or None,
		"korkem_delivery_cost": float(cost), "korkem_delivery_urgent": 1 if urgent else 0,
		"korkem_film_due": str(due) if due else None,
		"korkem_delivery_payer": payer, "korkem_delivery_paid_by": paid_by, "korkem_delivery_method": pay_method,
		# Who brought it and how to reach him (owner, 12.11.2026) — optional.
		"korkem_delivery_driver": " ".join(str(delivery.get("driver") or "").split())[:80] or None,
		"korkem_delivery_phone": " ".join(str(delivery.get("phone") or "").split())[:40] or None,
	}, update_modified=False)
	if _yes(update_price) and flt(price_m) > 0:
		film_catalog.set_card(item, via="приход", price_m=flt(price_m))
	return {"receipt": result["receipt"], "film": film_catalog.film(item)}


#: Who paid for bringing a roll.
PAYER_CASH, PAYER_EMPLOYEE, PAYER_UNPAID, PAYER_SUPPLIER = "cash", "employee", "unpaid", "supplier"
PAYERS = (PAYER_CASH, PAYER_EMPLOYEE, PAYER_UNPAID, PAYER_SUPPLIER)
#: How money is paid: the cash book's own words.
METHODS = ("Наличные", "Перевод", "Карта")


def _delivery_payer(delivery: dict, cost) -> tuple[str | None, str | None, str | None]:
	"""(payer, who, how) of a delivery; nothing when it cost nothing."""
	payer = str(delivery.get("payer") or "").strip() or PAYER_CASH
	if payer not in PAYERS:
		frappe.throw("Кто заплатил за доставку — касса, сотрудник, не оплачено или поставщик.")
	if payer == PAYER_SUPPLIER:
		return payer, None, None
	if not cost:
		return None, None, None
	who = None
	if payer == PAYER_EMPLOYEE:
		who = _person(delivery.get("paid_by")) or frappe.session.user
	how = None
	if payer in (PAYER_CASH, PAYER_EMPLOYEE):
		how = str(delivery.get("method") or "").strip() or METHODS[0]
		if how not in METHODS:
			frappe.throw("Как платили — наличные, перевод или карта.")
	return payer, who, how


#: How far ahead a roll may be expected.
MAX_DUE_DAYS = 180


def _due(arrives_on) -> object | None:
	"""The day a roll is expected; None when it is here already."""
	if not arrives_on or not str(arrives_on).strip():
		return None
	day = getdate(arrives_on)
	today = getdate(nowdate())
	if day <= today:
		return None
	if day > getdate(add_days(today, MAX_DUE_DAYS)):
		frappe.throw("Дата прибытия — не дальше чем через полгода.")
	return day


def _coming(entry: str):
	"""A roll on its way: an unposted film receipt of this company."""
	material_stock._ensure_editor()
	doc = frappe.get_doc("Stock Entry", entry) if frappe.db.exists("Stock Entry", entry) else None
	if (not doc or doc.company != current_company() or not doc.korkem_material_receipt
			or doc.docstatus != 0 or not doc.get("korkem_film_due")):
		frappe.throw("Такой плёнки в пути нет.", frappe.DoesNotExistError)
	return doc


def arrived(entry: str, metres=None) -> dict:
	"""The roll on its way is here: on the shelf today. `metres` — when
	fewer (or more) came than were ordered."""
	doc = _coming(entry)
	line = doc.items[0]
	if metres not in (None, ""):
		qty = flt(metres)
		if qty <= 0 or qty > material_stock.MAX_QTY:
			frappe.throw("Метры должны быть больше нуля.")
		line.qty = qty
	today = nowdate()
	doc.posting_date = today
	doc.set_posting_time = 1
	doc.flags.ignore_permissions = True
	doc.save()
	doc.submit()
	audit.record_audit(action="film.arrived", entity_type="Stock Entry", entity_id=entry,
					   diff={"item": line.item_code, "metres": flt(line.qty), "due": str(doc.korkem_film_due)})
	return {"receipt": entry, "film": film_catalog.film(line.item_code)}


def reschedule(entry: str, arrives_on: str) -> dict:
	"""The supplier is late: the roll is now expected another day."""
	doc = _coming(entry)
	day = _due(arrives_on)
	if day is None:
		frappe.throw("Новая дата — позже сегодняшней. Если плёнка уже пришла — «Пришла».")
	old = doc.korkem_film_due
	frappe.db.set_value("Stock Entry", entry, "korkem_film_due", str(day), update_modified=False)
	audit.record_audit(action="film.rescheduled", entity_type="Stock Entry", entity_id=entry,
					   diff={"from": str(old), "to": str(day)})
	return {"receipt": entry, "due": str(day)}


def drop_coming(entry: str, reason: str) -> dict:
	"""The roll on its way will not come: the order is struck off, with why."""
	doc = _coming(entry)
	reason = " ".join(str(reason or "").split())[:140]
	if not reason:
		frappe.throw("Скажите, почему плёнка не придёт.")
	item = doc.items[0].item_code
	audit.record_audit(action="film.order_dropped", entity_type="Stock Entry", entity_id=entry,
					   diff={"item": item, "metres": flt(doc.items[0].qty), "reason": reason})
	for delivery in frappe.get_all("Logistics Delivery", filters={"receipt": entry, "cancelled": 0}, pluck="name"):
		frappe.db.set_value("Logistics Delivery", delivery, {
			"cancelled": 1, "cancelled_by": frappe.session.user, "cancel_reason": f"Плёнка не придёт: {reason}",
		})
	# Kept unposted, no longer due: the order stays on record, out of every
	# count (a draft is in nobody's stock).
	frappe.db.set_value("Stock Entry", entry, {"remarks": f"Не придёт: {reason}", "korkem_film_due": None},
						update_modified=False)
	return {"receipt": entry, "status": "dropped"}


def coming(company: str | None = None) -> dict[str, list[dict]]:
	"""Film by film, what is on its way and when it is due."""
	today = getdate(nowdate())
	out: dict[str, list[dict]] = {}
	for e in frappe.get_all(
		"Stock Entry",
		filters={"company": company or current_company(), "docstatus": 0, "korkem_material_receipt": 1,
				 "korkem_film_due": ["is", "set"]},
		fields=["name", "korkem_film_due", "korkem_supplier"],
		order_by="korkem_film_due asc",
		limit_page_length=500,
	):
		line = frappe.db.get_value("Stock Entry Detail", {"parent": e.name}, ["item_code", "qty"], as_dict=True)
		if not line:
			continue
		late = date_diff(today, e.korkem_film_due)
		out.setdefault(line.item_code, []).append({
			"entry": e.name,
			"metres": flt(line.qty),
			"due": str(e.korkem_film_due),
			"late_days": max(late, 0),
			"supplier": frappe.db.get_value("Supplier", e.korkem_supplier, "supplier_name") or e.korkem_supplier,
		})
	return out


#: A hold lasts this many days unless said.
HOLD_DAYS = 3


def _holds(items: list[str], company: str | None = None) -> dict[str, list[dict]]:
	"""Film by film, the active holds: who, how much, until when."""
	if not items:
		return {}
	today = getdate(nowdate())
	out: dict[str, list[dict]] = {}
	for h in frappe.get_all(
		"Film Hold",
		filters={"company": company or current_company(), "status": "Active", "item": ["in", items]},
		fields=["name", "item", "customer", "metres", "until", "note"],
		order_by="until asc",
		limit_page_length=0,
	):
		out.setdefault(h.item, []).append({
			"hold": h.name, "customer": h.customer,
			"customer_name": frappe.db.get_value("Customer", h.customer, "customer_name") or h.customer,
			"metres": flt(h.metres), "until": str(h.until) if h.until else None,
			"late": bool(h.until and getdate(h.until) < today), "note": h.note,
		})
	return out


def hold(item: str, customer: str, metres, until: str | None = None, note: str | None = None) -> dict:
	"""Put metres of a film by for a customer (owner, 11.11.2026): nobody else
	sells them, the press does not take them, until the day — or the sale."""
	material_stock._ensure_editor()
	_film(item)
	company = current_company()
	if not frappe.db.exists("Customer", {"name": customer, "disabled": 0}):
		frappe.throw("Такого клиента нет.", frappe.DoesNotExistError)
	qty = float(_metres(metres, "Метров"))
	film = film_catalog.film(item)
	held = sum(h["metres"] for h in _holds([item], company).get(item, []))
	free = flt(film.get("on_hand")) - flt(film.get("held")) - held
	if qty > free + 1e-6:
		frappe.throw(f"Свободно только {free:g} м — больше не отложить.")
	day = getdate(until) if until else getdate(add_days(nowdate(), HOLD_DAYS))
	if day < getdate(nowdate()):
		frappe.throw("До какого дня — не раньше сегодняшнего.")
	doc = frappe.get_doc({
		"doctype": "Film Hold", "company": company, "item": item, "customer": customer, "metres": qty,
		"until": str(day), "status": "Active", "note": " ".join(str(note or "").split())[:140] or None,
	}).insert(ignore_permissions=True)
	audit.record_audit(action="film.held", entity_type="Film Hold", entity_id=doc.name,
					   diff={"item": item, "customer": customer, "metres": qty, "until": str(day)})
	return {"hold": doc.name, "until": str(day)}


def release_hold(hold_name: str) -> dict:
	"""The customer will not take it: the metres are free again."""
	material_stock._ensure_editor()
	row = frappe.db.get_value("Film Hold", hold_name, ["company", "status"], as_dict=True)
	if not row or row.company != current_company() or row.status != "Active":
		frappe.throw("Такой брони нет.", frappe.DoesNotExistError)
	frappe.db.set_value("Film Hold", hold_name, "status", "Released")
	audit.record_audit(action="film.hold_released", entity_type="Film Hold", entity_id=hold_name)
	return {"hold": hold_name, "status": "Released"}


def _use_holds(item: str, customer: str, metres: float, company: str) -> None:
	"""A sale to the customer uses up what was put by for him, oldest first."""
	left = metres
	for h in _holds([item], company).get(item, []):
		if left <= 1e-6:
			break
		if h["customer"] != customer:
			continue
		take = min(left, h["metres"])
		rest = h["metres"] - take
		frappe.db.set_value("Film Hold", h["hold"], {"metres": rest} if rest > 1e-6 else {"status": "Sold"})
		left -= take


def _yes(value) -> bool:
	if isinstance(value, str):
		return value.strip().lower() not in ("", "0", "false", "no")
	return bool(value)


def sell(customer: str, lines, paid=0, method: str | None = None, bank: str | None = None,
		 sold_on: str | None = None, note: str | None = None, payments=None, seller: str | None = None,
		 issued_by: str | None = None) -> dict:
	"""Film sold to a customer: one sale, one film or several.

	`lines` — `[{"item", "metres", "price_m"?, "remember"?}]`; a line without
	a price takes the customer's (`price_for`). `paid` less than the sum
	leaves a debt. A typed price with `remember` becomes the card's price for
	the customer's tier, where the card had none (owner, 11.11.2026).
	"""
	material_stock._ensure_editor()
	company = current_company()
	buyer = _customer(customer)
	if isinstance(lines, str):
		lines = frappe.parse_json(lines)
	if not isinstance(lines, list) or not lines:
		frappe.throw("Добавьте в продажу хотя бы одну плёнку.")
	rows, amount, remember = [], Decimal(0), []
	for n, raw in enumerate(lines, start=1):
		item = (raw or {}).get("item")
		_film(item)
		metres = _metres(raw.get("metres"), f"Строка {n}")
		price = raw.get("price_m")
		price = _money(price, f"Строка {n}: цена за метр") if price not in (None, "") else Decimal(
			str(price_for(item, buyer.name)["price_m"] or 0)
		)
		if price <= 0:
			frappe.throw(f"Строка {n}: у плёнки нет цены продажи — укажите цену за метр.")
		rows.append((item, metres, price))
		if _yes(raw.get("remember")) and raw.get("price_m") not in (None, ""):
			remember.append((item, price))
		amount += (metres * price).quantize(Decimal("1"))
	# Several ways at once (owner, 11.11.2026): `payments` — `[{"amount",
	# "method", "bank"?}]`; or one, by `paid`, `method`, `bank`, as before.
	parts = _parts(payments, paid, method, bank)
	paid = sum((p["amount"] for p in parts), Decimal(0))
	if paid > amount:
		frappe.throw(f"Оплачено больше суммы продажи ({amount:,.0f} ₸).".replace(",", " "))
	method, bank = (parts[0]["method"], parts[0]["bank"]) if parts else (None, None)
	entry = _issue(
		company, [(item, metres, price) for item, metres, price in rows], SALE, posted_on=sold_on,
		remarks=note,
		header={
			"korkem_film_customer": buyer.name,
			"korkem_film_amount": float(amount),
			"korkem_film_paid": float(paid),
			"korkem_film_pay_method": method,
			"korkem_film_pay_bank": bank,
			"korkem_film_payments": _dump(parts, sold_on),
			# Who sold it — whoever enters it unless said (owner, 11.11.2026).
			"korkem_film_seller": _person(seller) or frappe.session.user,
			# Who handed it out of the stock — the seller unless said
			# (owner, 12.11.2026).
			"korkem_film_issued_by": _person(issued_by) or _person(seller) or frappe.session.user,
		},
		customer=buyer.name,
	)
	# What was put by for this customer is sold now: the hold is used up.
	for item, metres, _price in rows:
		_use_holds(item, buyer.name, float(metres), company)
	tier = buyer.get("korkem_film_tier") if buyer.get("korkem_film_tier") in TIERS else RETAIL
	key = "wholesale_m" if tier == WHOLESALE else "retail_m"
	for item, price in remember:
		if not flt(frappe.db.get_value("Item", item, film_catalog.CARD[key])):
			film_catalog.set_card(item, via="продажа", **{key: float(price)})
	if not buyer.get("korkem_film_customer"):
		# A facade customer who buys film is a film customer from now on.
		frappe.db.set_value("Customer", buyer.name, "korkem_film_customer", 1)
	audit.record_audit(action="film.sold", entity_type="Stock Entry", entity_id=entry.name,
					   diff={"customer": buyer.name, "amount": float(amount), "paid": float(paid),
							 "payments": [{**p, "amount": float(p["amount"])} for p in parts]})
	return movement(entry.name)


def to_shop(item: str, metres, order: str | None = None, note: str | None = None,
			posted_on: str | None = None) -> dict:
	"""Film handed to our own shop — for an order of facades when one is named."""
	material_stock._ensure_editor()
	_film(item)
	order = " ".join((order or "").split())[:140] or None
	entry = _issue(current_company(), [(item, _metres(metres, "Метров"), None)], SHOP, remarks=note,
				   header={"korkem_film_order": order}, posted_on=posted_on)
	audit.record_audit(action="film.to_shop", entity_type="Stock Entry", entity_id=entry.name,
					   diff={"item": item, "metres": flt(metres), "order": order})
	return movement(entry.name)


def write_off(item: str, metres, reason: str, posted_on: str | None = None) -> dict:
	"""Metres that left neither to a customer nor to the shop, and why."""
	material_stock._ensure_editor()
	_film(item)
	reason = " ".join((reason or "").split())[:500]
	if len(reason) < 3:
		frappe.throw("Укажите причину списания.")
	entry = _issue(current_company(), [(item, _metres(metres, "Метров"), None)], WRITE_OFF,
				   header={"korkem_film_reason": reason}, posted_on=posted_on)
	audit.record_audit(action="film.written_off", entity_type="Stock Entry", entity_id=entry.name,
					   diff={"item": item, "metres": flt(metres), "reason": reason})
	return movement(entry.name)


def pay(entry: str, amount=None, method: str | None = None, bank: str | None = None,
		payments=None) -> dict:
	"""More money against a sale left in debt — one way, or several at once."""
	material_stock._ensure_editor()
	doc = _movement(entry, SALE)
	parts = _parts(payments, amount, method, bank)
	amount = sum((p["amount"] for p in parts), Decimal(0))
	if amount <= 0:
		frappe.throw("Сумма оплаты больше нуля.")
	owed = Decimal(str(flt(doc.korkem_film_amount))) - Decimal(str(flt(doc.korkem_film_paid)))
	if amount > owed:
		frappe.throw(f"Долг по этой продаже — {owed:,.0f} ₸.".replace(",", " "))
	method, bank = parts[0]["method"], parts[0]["bank"]
	before = _payments(doc)
	doc.db_set({
		"korkem_film_paid": flt(doc.korkem_film_paid) + float(amount),
		"korkem_film_pay_method": method, "korkem_film_pay_bank": bank,
		"korkem_film_payments": frappe.as_json(before + _rows(parts, nowdate())),
	}, update_modified=True)
	audit.record_audit(action="film.sale_paid", entity_type="Stock Entry", entity_id=entry,
					   diff={"amount": float(amount), "payments": [{**p, "amount": float(p["amount"])} for p in parts]})
	return movement(entry)


def _parts(payments, paid, method, bank) -> list[dict]:
	"""The ways a sum came, each checked: `payments` when given, else the one."""
	if isinstance(payments, str):
		payments = frappe.parse_json(payments) if payments.strip() else None
	if payments is None:
		paid = _money(paid or 0, "Оплачено")
		if paid <= 0:
			return []
		method, bank = _method(method, bank, paid)
		return [{"amount": paid, "method": method, "bank": bank}]
	if not isinstance(payments, list):
		frappe.throw("Оплата — список частей: сумма, способ, банк.")
	parts = []
	for n, raw in enumerate(payments, start=1):
		raw = raw or {}
		amount = _money(raw.get("amount") or 0, f"Оплата {n}: сумма")
		if amount <= 0:
			continue
		method, bank = _method(raw.get("method"), raw.get("bank"), amount)
		parts.append({"amount": amount, "method": method, "bank": bank})
	return parts


def _rows(parts: list[dict], on: str | None) -> list[dict]:
	return [
		{"date": str(on or nowdate()), "amount": float(p["amount"]), "method": p["method"], "bank": p["bank"]}
		for p in parts
	]


def _dump(parts: list[dict], on: str | None) -> str | None:
	return frappe.as_json(_rows(parts, on)) if parts else None


def _payments(doc) -> list[dict]:
	"""Every payment of a sale. One paid before parts were kept is read from
	the sale's own figures."""
	raw = doc.get("korkem_film_payments")
	if raw:
		try:
			rows = frappe.parse_json(raw)
			if isinstance(rows, list):
				return rows
		except ValueError:
			pass
	if flt(doc.get("korkem_film_paid")) > 0:
		return [{
			"date": str(doc.get("posting_date") or ""), "amount": flt(doc.get("korkem_film_paid")),
			"method": doc.get("korkem_film_pay_method"), "bank": doc.get("korkem_film_pay_bank"),
		}]
	return []


def cancel(entry: str, reason: str) -> dict:
	"""A movement entered by mistake: cancelled, the metres back on the shelf.

	The manager may on the day it was entered; later, only the owner — the
	day's count is closed by then.
	"""
	material_stock._ensure_editor()
	doc = _movement(entry)
	reason = " ".join((reason or "").split())[:500]
	if len(reason) < 3:
		frappe.throw("Укажите, почему запись отменяется.")
	_may_change(doc, "отменить")
	doc.flags.ignore_permissions = True
	doc.cancel()
	doc.add_comment("Comment", f"Отменено: {reason}")
	audit.record_audit(action="film.movement_cancelled", entity_type="Stock Entry", entity_id=entry,
					   diff={"kind": doc.korkem_film_kind, "reason": reason})
	return {"cancelled": entry}


def _may_change(doc, what: str) -> None:
	"""The manager on the day it was entered; later, only the owner — the
	day's count is closed by then."""
	if getdate(doc.creation) != getdate(nowdate()) and "System Manager" not in frappe.get_roles():
		frappe.throw(f"Запись внесена не сегодня — {what} её может только владелец.")


def correct(entry: str, item: str, reason: str, metres=None, price_m=None, supplier: str | None = None,
			order: str | None = None, why: str | None = None) -> dict:
	"""A movement entered wrong, made again right (owner, 11.11.2026: «менеджер
	может затупить»).

	The wrong one is cancelled — not deleted — and points to the right one,
	which is entered on the same day with what was changed: the metres, the
	price, the supplier of a receipt, the order of a hand-over to the shop,
	why a write-off. A sale keeps its customer, its other films and every
	payment made on it. Who may: as for a cancel.
	"""
	material_stock._ensure_editor()
	reason = " ".join((reason or "").split())[:500]
	if len(reason) < 3:
		frappe.throw("Укажите, почему исправляете.")
	if not entry or not frappe.db.exists("Stock Entry", entry):
		frappe.throw("Такой записи нет.", frappe.DoesNotExistError)
	doc = frappe.get_doc("Stock Entry", entry)
	kind = "receipt" if doc.get("korkem_material_receipt") else doc.get("korkem_film_kind")
	if doc.company != current_company() or kind not in ("receipt", *KINDS):
		frappe.throw("Такой записи нет.", frappe.DoesNotExistError)
	if doc.docstatus != 1:
		frappe.throw("Эта запись уже отменена.")
	_may_change(doc, "исправить")
	row = next((r for r in doc.items if r.item_code == item), None)
	if not row:
		frappe.throw("В этой записи нет такой плёнки.")
	day = str(doc.posting_date)
	metres = row.qty if metres in (None, "") else metres

	def cancel_old():
		doc.flags.ignore_permissions = True
		doc.cancel()

	if kind == "receipt":
		price = row.basic_rate if price_m in (None, "") else price_m
		card = flt(frappe.db.get_value("Item", item, film_catalog.CARD["price_m"]))
		# The new receipt first: the metres of the wrong one may be sold
		# already, and the shelf must not go below nothing between the two.
		made = receive(
			item, metres, price, supplier or doc.get("korkem_supplier"), received_on=day,
			note=doc.get("remarks"), received_by=doc.get("korkem_received_by"),
			delivery={"transport": doc.get("korkem_delivery_transport"), "from_city": doc.get("korkem_delivery_city"),
					  "urgent": doc.get("korkem_delivery_urgent")},
			# The card follows a corrected price only if it came from the wrong one.
			update_price=flt(price) != flt(row.basic_rate) and card == flt(row.basic_rate),
		)
		new = made["receipt"]
		# What the old one cost to bring is the new one's: the logistics
		# record moves over, not paid twice.
		frappe.db.set_value("Stock Entry", new, {
			"korkem_delivery_cost": flt(doc.get("korkem_delivery_cost")),
			# Who paid, and whether it was given back, stay with it.
			**{f: doc.get(f) for f in ("korkem_delivery_payer", "korkem_delivery_paid_by", "korkem_delivery_method",
									   "korkem_delivery_settled_on", "korkem_delivery_settled_method",
									   "korkem_delivery_driver", "korkem_delivery_phone")},
		}, update_modified=False)
		for d in frappe.get_all("Logistics Delivery", filters={"receipt": entry}, pluck="name"):
			frappe.db.set_value("Logistics Delivery", d, "receipt", new, update_modified=False)
		cancel_old()
	elif kind == SALE:
		lines = [
			{"item": r.item_code, "metres": flt(r.qty), "price_m": flt(r.get("korkem_film_price_m")) or None}
			for r in doc.items
		]
		for line in lines:
			if line["item"] == item:
				line["metres"] = metres
				if price_m not in (None, ""):
					line["price_m"] = price_m
		paid = _payments(doc)
		cancel_old()
		made = sell(
			doc.korkem_film_customer, lines, sold_on=day, note=doc.get("remarks"),
			payments=[{"amount": p["amount"], "method": p["method"], "bank": p.get("bank")} for p in paid],
			seller=doc.get("korkem_film_seller"), issued_by=doc.get("korkem_film_issued_by"),
		)
		new = made["entry"]
		# The payments keep the days they were made on.
		if paid:
			frappe.db.set_value("Stock Entry", new, "korkem_film_payments", frappe.as_json(paid))
	elif kind == SHOP:
		cancel_old()
		new = to_shop(
			item, metres, order=doc.get("korkem_film_order") if order is None else order,
			note=doc.get("remarks"), posted_on=day,
		)["entry"]
	else:
		cancel_old()
		new = write_off(item, metres, why or doc.get("korkem_film_reason"), posted_on=day)["entry"]
	frappe.db.set_value(
		"Stock Entry", entry, {"korkem_film_replaced_by": new, "korkem_film_fix_reason": reason},
		update_modified=False,
	)
	frappe.db.set_value("Stock Entry", new, "korkem_film_replaces", entry, update_modified=False)
	audit.record_audit(action="film.corrected", entity_type="Stock Entry", entity_id=new,
					   diff={"replaces": entry, "kind": kind, "item": item}, reason=reason)
	return {"entry": new, "replaces": entry}


# --------------------------------------------------------------------------
# Readings
# --------------------------------------------------------------------------


def stock() -> dict:
	"""Every film with what is on hand; the ones that ran low first."""
	catalog = film_catalog.catalog()
	# A film in the archive is shown while metres of it are left: they can
	# still be sold or written off (owner, 11.11.2026).
	on_way = coming()
	holds = _holds([f["item"] for f in catalog["films"]])
	films = [f for f in catalog["films"] if f["enabled"] or f["on_hand"] > 0 or f["item"] in on_way]
	for f in films:
		# On its way, owner 11.11.2026: shown, not counted as free.
		f["coming"] = on_way.get(f["item"], [])
		# Put by for a customer (owner, 11.11.2026): shown, not free.
		f["holds"] = holds.get(f["item"], [])
		free = flt(f["on_hand"]) - flt(f["held"]) - sum(h["metres"] for h in f["holds"])
		f["free"] = free
		f["low"] = bool(f["min_stock"]) and free < flt(f["min_stock"])
		# Time to order (owner, 11.11.2026): low, and not enough on its way.
		f["reorder"] = _reorder(f) if f["enabled"] else None
	films.sort(key=lambda f: (not f["low"], f["maker"].casefold(), f["colour"].casefold()))
	return {
		"films": films,
		"suppliers": catalog["suppliers"],
		"sources_by_maker": catalog["sources_by_maker"],
		"can_edit": catalog["can_edit"],
	}


def _reorder(f: dict) -> dict | None:
	"""What to order of a film that ran low: as many metres as were bought
	last time (else twice the minimum, less what is left), from whom it was
	bought last, at the card's purchase price. None when nothing is needed."""
	minimum = flt(f.get("min_stock"))
	if not minimum:
		return None
	on_way = sum(flt(c["metres"]) for c in f.get("coming") or [])
	if f["free"] + on_way >= minimum:
		return None
	last = frappe.db.sql(
		"""select d.qty, d.basic_rate, e.korkem_supplier
		from `tabStock Entry Detail` d join `tabStock Entry` e on e.name = d.parent
		where d.item_code = %s and e.docstatus = 1 and e.korkem_material_receipt = 1
		order by e.posting_date desc, e.creation desc limit 1""",
		(f["item"],), as_dict=True,
	)
	last = last[0] if last else None
	metres = flt(last.qty) if last else max(2 * minimum - f["free"] - on_way, minimum)
	supplier = (last.korkem_supplier if last else None) or f.get("supplier")
	return {
		"metres": round(metres, 2),
		"supplier": supplier,
		"supplier_name": frappe.db.get_value("Supplier", supplier, "supplier_name") if supplier else None,
		"price_m": flt(f.get("price_m")) or (flt(last.basic_rate) if last else None) or None,
	}


def history(item: str, limit: int = 100) -> list[dict]:
	"""What came and what left, for one film, newest first."""
	material_stock._ensure_staff()
	_film(item)
	rows = frappe.get_all(
		"Stock Entry Detail",
		# A movement made again right shows struck through under the right one.
		filters={"item_code": item, "docstatus": ["in", [1, 2]]},
		fields=["parent", "qty", "basic_rate", "korkem_film_price_m", "t_warehouse", "s_warehouse"],
		order_by="creation desc",
		limit_page_length=min(int(limit or 100), 500),
	)
	money = price_visibility.can_see_prices()
	out = []
	for r in rows:
		head = frappe.db.get_value(
			"Stock Entry", r.parent,
			["posting_date", "posting_time", "creation", "purpose", "korkem_supplier", "korkem_film_kind",
			 "korkem_film_customer", "korkem_film_order", "korkem_film_reason", "owner", "docstatus",
			 "korkem_film_replaced_by", "korkem_film_replaces", "korkem_received_by", "korkem_delivery_transport",
			 "korkem_delivery_city", "korkem_delivery_cost", "korkem_delivery_urgent", "korkem_film_seller",
			 "korkem_delivery_payer", "korkem_delivery_paid_by", "korkem_delivery_settled_on",
			 "korkem_delivery_driver", "korkem_delivery_phone"],
			as_dict=True,
		)
		if not head or (head.docstatus == 2 and not head.korkem_film_replaced_by):
			continue
		fix = None
		if head.korkem_film_replaces:
			old = frappe.db.get_value(
				"Stock Entry", head.korkem_film_replaces, "korkem_film_fix_reason"
			)
			fix = {"reason": old, "by": get_fullname(head.owner) or head.owner, "at": str(head.creation)[:16]}
		coming = bool(r.t_warehouse) and not r.s_warehouse
		kind = "receipt" if coming else (head.korkem_film_kind or "other")
		out.append({
			"entry": r.parent,
			"date": str(head.posting_date),
			"kind": kind,
			"metres": flt(r.qty) if coming else -flt(r.qty),
			"price_m": (flt(r.basic_rate) if coming else flt(r.korkem_film_price_m) or None) if money else None,
			"party": _party(head, kind),
			"reason": head.korkem_film_reason,
			"by": head.owner,
			"struck": head.docstatus == 2,
			"fix": fix,
			"delivery": {
				"transport": head.korkem_delivery_transport, "city": head.korkem_delivery_city,
				"cost": flt(head.korkem_delivery_cost) if money else None,
				"per_m": (flt(head.korkem_delivery_cost) / flt(r.qty)) if money and flt(r.qty) else None,
				"urgent": bool(head.korkem_delivery_urgent),
				"received_by": get_fullname(head.korkem_received_by) if head.korkem_received_by else None,
				# Who paid, and whether it is settled (owner, 11.11.2026).
				"payer": head.korkem_delivery_payer,
				"paid_by": get_fullname(head.korkem_delivery_paid_by) if head.korkem_delivery_paid_by else None,
				"settled": bool(head.korkem_delivery_settled_on),
				"driver": head.korkem_delivery_driver,
				"phone": head.korkem_delivery_phone,
			} if coming and head.korkem_delivery_transport else None,
			"seller": get_fullname(head.korkem_film_seller) if head.korkem_film_seller else None,
			"_at": (str(head.posting_date), str(head.posting_time), str(head.creation), r.parent),
		})
	# Newest first by when it was posted, then entered — and by the entry's
	# own number last: two movements entered in the same second are still in
	# the order they were made (the rows' own `creation` ties there).
	out.sort(key=lambda m: m["_at"], reverse=True)
	for m in out:
		del m["_at"]
	return out


def movement(entry: str) -> dict:
	doc = frappe.get_doc("Stock Entry", entry)
	money = price_visibility.can_see_prices()
	return {
		"entry": doc.name,
		"kind": doc.korkem_film_kind,
		"date": str(doc.posting_date),
		"customer": doc.get("korkem_film_customer"),
		"customer_name": _name(doc.get("korkem_film_customer")),
		"order": doc.get("korkem_film_order"),
		"reason": doc.get("korkem_film_reason"),
		"amount": flt(doc.get("korkem_film_amount")) if money else None,
		"paid": flt(doc.get("korkem_film_paid")) if money else None,
		"debt": (flt(doc.get("korkem_film_amount")) - flt(doc.get("korkem_film_paid"))) if money else None,
		"method": doc.get("korkem_film_pay_method"),
		"bank": doc.get("korkem_film_pay_bank"),
		"payments": _payments(doc) if money else [],
		"lines": _lines(doc, money),
		# Who served the customer — on the receipt (owner, 12.11.2026).
		"seller": get_fullname(doc.get("korkem_film_seller") or doc.owner),
		# The seller answers for the sale: his phone goes on the receipt.
		"seller_phone": _phone(doc.get("korkem_film_seller") or doc.owner),
		"issued_by": get_fullname(doc.get("korkem_film_issued_by")) if doc.get("korkem_film_issued_by") else None,
	}


def _phone(user: str | None) -> str | None:
	if not user:
		return None
	row = frappe.db.get_value("User", user, ["mobile_no", "phone"], as_dict=True) or {}
	return row.get("mobile_no") or row.get("phone") or None


def sales(since: str | None = None, until: str | None = None, customer: str | None = None,
		  limit: int = 200) -> list[dict]:
	"""The department's sales, newest first."""
	material_stock._ensure_staff()
	filters = {"company": current_company(), "docstatus": 1, "korkem_film_kind": SALE}
	if since or until:
		filters["posting_date"] = ["between", [since or "2000-01-01", until or nowdate()]]
	if customer:
		filters["korkem_film_customer"] = customer
	names = frappe.get_all("Stock Entry", filters=filters, pluck="name", order_by="posting_date desc, creation desc",
						   limit_page_length=min(int(limit or 200), 1000))
	return [movement(n) for n in names]


# --------------------------------------------------------------------------
# Customers
# --------------------------------------------------------------------------


def price_for(item: str, customer: str | None = None) -> dict:
	"""What a metre of this film costs this customer: the tier's price less the discount."""
	material_stock._ensure_staff()
	_film(item)
	tier, discount = RETAIL, 0.0
	if customer:
		row = frappe.db.get_value("Customer", customer, ["korkem_film_tier", "korkem_film_discount"], as_dict=True)
		if row:
			tier = row.korkem_film_tier if row.korkem_film_tier in TIERS else RETAIL
			discount = min(max(flt(row.korkem_film_discount), 0.0), 100.0)
	field = film_catalog.CARD["wholesale_m" if tier == WHOLESALE else "retail_m"]
	base = flt(frappe.db.get_value("Item", item, field))
	if not base and tier == WHOLESALE:
		# No trade price set: the counter price stands.
		base = flt(frappe.db.get_value("Item", item, film_catalog.CARD["retail_m"]))
	price = round(base * (100 - discount) / 100) if base else None
	return {"tier": tier, "discount": discount, "base_m": base or None, "price_m": price}


def customers() -> list[dict]:
	"""Who buys film: what this month, what in all, when last — and who fell asleep."""
	material_stock._ensure_staff()
	company = current_company()
	rows = frappe.get_all(
		"Customer", filters={"korkem_film_customer": 1, "disabled": 0},
		fields=["name", "customer_name", "mobile_no", "korkem_film_tier", "korkem_film_discount"],
		order_by="customer_name asc", limit_page_length=2000,
	)
	month_start = getdate(nowdate()).replace(day=1)
	out = []
	for c in rows:
		entries = frappe.get_all(
			"Stock Entry",
			filters={"company": company, "docstatus": 1, "korkem_film_kind": SALE, "korkem_film_customer": c.name},
			fields=["name", "posting_date", "korkem_film_amount", "korkem_film_paid"],
		)
		# Added up here, not in SQL: this Frappe refuses a function in `fields`.
		metres: dict[str, float] = {}
		if entries:
			for r in frappe.get_all("Stock Entry Detail", filters={"parent": ["in", [e.name for e in entries]]},
									fields=["parent", "qty"], limit_page_length=0):
				metres[r.parent] = metres.get(r.parent, 0.0) + flt(r.qty)
		last = max((getdate(e.posting_date) for e in entries), default=None)
		idle = date_diff(nowdate(), last) if last else None
		# How long the oldest unpaid sale has waited (owner, 11.11.2026).
		owing = [getdate(e.posting_date) for e in entries
				 if flt(e.korkem_film_amount) - flt(e.korkem_film_paid) > 0.5]
		debt_days = date_diff(nowdate(), min(owing)) if owing else None
		out.append({
			"customer": c.name,
			"name": c.customer_name or c.name,
			"phone": c.mobile_no,
			"debt_days": debt_days,
			"tier": c.korkem_film_tier if c.korkem_film_tier in TIERS else RETAIL,
			"discount": flt(c.korkem_film_discount),
			"month_m": sum(metres.get(e.name, 0.0) for e in entries if getdate(e.posting_date) >= month_start),
			"total_m": sum(metres.values()),
			"total": sum(flt(e.korkem_film_amount) for e in entries),
			"debt": sum(flt(e.korkem_film_amount) - flt(e.korkem_film_paid) for e in entries),
			"last": str(last) if last else None,
			"idle_days": idle,
			"asleep": idle is not None and idle >= ASLEEP_DAYS,
		})
	out.sort(key=lambda r: (-r["month_m"], -r["total"], r["name"].casefold()))
	return out


def set_customer(customer: str, tier: str | None = None, discount=None, buys_film: bool | int | str = 1) -> dict:
	"""The customer's film terms, on the customer's own card: the price and the discount."""
	material_stock._ensure_editor()
	doc = _customer(customer)
	values = {"korkem_film_customer": 1 if str(buys_film) not in ("0", "false", "False", "") else 0}
	if tier is not None:
		if tier not in TIERS:
			frappe.throw("Цена — розничная или оптовая.")
		values["korkem_film_tier"] = tier
	if discount not in (None, ""):
		value = flt(discount)
		if value < 0 or value > 50:
			frappe.throw("Скидка — от 0 до 50 %.")
		values["korkem_film_discount"] = value
	frappe.db.set_value("Customer", doc.name, values)
	audit.record_audit(action="film.customer_terms", entity_type="Customer", entity_id=doc.name, diff=values)
	return next((c for c in customers() if c["customer"] == doc.name), {"customer": doc.name})


# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------


def _issue(company: str, rows, kind: str, header: dict | None = None, posted_on: str | None = None,
		   remarks: str | None = None, customer: str | None = None):
	"""One Material Issue for `rows` of (item, metres, price or None), off the shelves that hold them."""
	from korkem_manufacturing.services import facade_materials

	day = getdate(posted_on) if posted_on else getdate(nowdate())
	if day > getdate(nowdate()):
		frappe.throw("Дата не может быть в будущем.")
	if day < getdate(add_days(nowdate(), -31)):
		frappe.throw("Дата — не раньше чем месяц назад.")
	items = []
	for item, metres, price in rows:
		free = facade_materials._free_by_warehouse(item, company)
		have = sum(free.values())
		if have + 1e-6 < float(metres):
			title = frappe.db.get_value("Item", item, "item_name") or item
			frappe.throw(f"«{title}»: на складе {have:g} м, нужно {float(metres):g} м.")
		# Put by for other customers (owner, 11.11.2026): not theirs to take.
		others = sum(h["metres"] for h in _holds([item], company).get(item, []) if h["customer"] != customer)
		if have - others + 1e-6 < float(metres):
			title = frappe.db.get_value("Item", item, "item_name") or item
			frappe.throw(f"«{title}»: {others:g} м отложено за другими клиентами — свободно {have - others:g} м.")
		left = float(metres)
		unit = frappe.db.get_value("Item", item, "stock_uom")
		for warehouse, qty in sorted(free.items(), key=lambda kv: -kv[1]):
			take = min(left, qty)
			if take <= 0:
				break
			items.append({
				"item_code": item, "qty": take, "uom": unit, "stock_uom": unit, "conversion_factor": 1,
				"s_warehouse": warehouse, "korkem_film_price_m": float(price) if price is not None else None,
			})
			left -= take
	entry = frappe.get_doc({
		"doctype": "Stock Entry",
		"stock_entry_type": "Material Issue",
		"purpose": "Material Issue",
		"company": company,
		"posting_date": str(day),
		"set_posting_time": 1 if posted_on else 0,
		"korkem_film_kind": kind,
		"remarks": (remarks or "").strip()[:500] or None,
		**(header or {}),
		"items": items,
	})
	# Who may sell or write off is decided by role above; the seller need not
	# be a stock accountant in ERPNext.
	entry.insert(ignore_permissions=True)
	entry.submit()
	from korkem_manufacturing.services import stock_alerts

	stock_alerts.check(company, list({i["item_code"] for i in items}))
	return entry


def _film(item: str | None) -> None:
	if not item or not frappe.db.exists("Item", item):
		frappe.throw("Такой плёнки нет.", frappe.DoesNotExistError)
	material_stock._own_item(item)
	if frappe.db.get_value("Item", item, "korkem_material_kind") != material_stock.FILM:
		frappe.throw("Это не плёнка.")


def _movement(entry: str, kind: str | None = None):
	if not entry or not frappe.db.exists("Stock Entry", entry):
		frappe.throw("Такой записи нет.", frappe.DoesNotExistError)
	doc = frappe.get_doc("Stock Entry", entry)
	if doc.company != current_company() or doc.get("korkem_film_kind") not in KINDS:
		frappe.throw("Такой записи нет.", frappe.DoesNotExistError)
	if doc.docstatus != 1:
		frappe.throw("Эта запись уже отменена.")
	if kind and doc.korkem_film_kind != kind:
		frappe.throw("Это не продажа.")
	return doc


def _customer(customer: str | None):
	if not customer or not frappe.db.exists("Customer", customer):
		frappe.throw("Выберите клиента.", frappe.DoesNotExistError)
	doc = frappe.get_doc("Customer", customer)
	if doc.disabled:
		frappe.throw("Клиент отключён.")
	return doc


def _metres(value, label: str) -> Decimal:
	try:
		metres = Decimal(str(value).replace(",", "."))
	except (InvalidOperation, ValueError, TypeError):
		frappe.throw(f"{label}: метры — число.")
	if not metres.is_finite() or metres <= 0 or metres > MAX_METRES:
		frappe.throw(f"{label}: метров должно быть больше нуля.")
	return metres


def _money(value, label: str) -> Decimal:
	try:
		money = Decimal(str(value).replace(",", ".").replace(" ", ""))
	except (InvalidOperation, ValueError, TypeError):
		frappe.throw(f"{label} — число.")
	if not money.is_finite() or money < 0 or money > Decimal("1000000000"):
		frappe.throw(f"{label} — от нуля.")
	return money


def _method(method: str | None, bank: str | None, paid: Decimal) -> tuple[str | None, str | None]:
	if paid <= 0:
		return None, None
	if method not in PAYMENT_METHODS:
		frappe.throw(f"Способ оплаты — один из: {', '.join(PAYMENT_METHODS)}.")
	bank = " ".join((bank or "").split())[:140] or None
	return method, bank if method in WITH_BANK else None


def _title(item: str, fallback: str) -> str:
	"""«KIRA · Белый», with the thickness when the film has several."""
	row = frappe.db.get_value(
		"Item", item, ["korkem_manufacturer", "korkem_color", "korkem_film_thickness_mm"], as_dict=True
	) or {}
	thickness = (
		(row.get("korkem_film_thickness_mm") or film_catalog.UNKNOWN) if len(film_catalog.siblings(item)) > 1 else None
	)
	return film_catalog.label(row.get("korkem_manufacturer") or "", row.get("korkem_color") or fallback, thickness)


def _lines(doc, money: bool) -> list[dict]:
	out = []
	for r in doc.items:
		# What the film is, for the customer's receipt (owner, 12.11.2026):
		# maker, colour, code, surface, thickness — not where it was bought.
		card = frappe.db.get_value(
			"Item", r.item_code,
			["korkem_manufacturer", "korkem_color", "korkem_film_code", "korkem_film_type",
			 "korkem_film_thickness_mm"],
			as_dict=True,
		) or {}
		out.append({
			"item": r.item_code,
			"title": _title(r.item_code, r.item_name),
			"metres": flt(r.qty),
			"price_m": (flt(r.get("korkem_film_price_m")) or None) if money else None,
			"maker": card.get("korkem_manufacturer"),
			"colour": card.get("korkem_color"),
			"code": card.get("korkem_film_code"),
			"type": card.get("korkem_film_type"),
			"thickness_mm": flt(card.get("korkem_film_thickness_mm")) or None,
		})
	return out


def _party(head, kind: str) -> str | None:
	if kind == "receipt":
		return frappe.db.get_value("Supplier", head.korkem_supplier, "supplier_name") if head.korkem_supplier else None
	if kind == SALE:
		return _name(head.korkem_film_customer)
	if kind == SHOP:
		return head.korkem_film_order
	return None


def _name(customer: str | None) -> str | None:
	if not customer:
		return None
	return frappe.db.get_value("Customer", customer, "customer_name") or customer
