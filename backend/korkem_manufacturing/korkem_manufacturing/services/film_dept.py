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


def receive(item: str, metres, price_m, supplier: str, received_on: str | None = None,
			note: str | None = None, update_price=True) -> dict:
	"""A roll or a cut bought from a wholesaler: so many metres at so much a metre.

	The price paid becomes the card's purchase price (owner, 11.11.2026:
	prices change) — unless `update_price` is off, for a one-off discount.
	"""
	_film(item)
	result = material_stock.receive(item, metres, price_m, supplier, received_on=received_on, note=note)
	if _yes(update_price) and flt(price_m) > 0:
		film_catalog.set_card(item, via="приход", price_m=flt(price_m))
	return {"receipt": result["receipt"], "film": film_catalog.film(item)}


def _yes(value) -> bool:
	if isinstance(value, str):
		return value.strip().lower() not in ("", "0", "false", "no")
	return bool(value)


def sell(customer: str, lines, paid=0, method: str | None = None, bank: str | None = None,
		 sold_on: str | None = None, note: str | None = None, payments=None) -> dict:
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
		},
	)
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
			note=doc.get("remarks"),
			# The card follows a corrected price only if it came from the wrong one.
			update_price=flt(price) != flt(row.basic_rate) and card == flt(row.basic_rate),
		)
		new = made["receipt"]
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
	films = [f for f in catalog["films"] if f["enabled"] or f["on_hand"] > 0]
	for f in films:
		free = flt(f["on_hand"]) - flt(f["held"])
		f["free"] = free
		f["low"] = bool(f["min_stock"]) and free < flt(f["min_stock"])
	films.sort(key=lambda f: (not f["low"], f["maker"].casefold(), f["colour"].casefold()))
	return {
		"films": films,
		"suppliers": catalog["suppliers"],
		"sources_by_maker": catalog["sources_by_maker"],
		"can_edit": catalog["can_edit"],
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
			 "korkem_film_replaced_by", "korkem_film_replaces"], as_dict=True,
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
	}


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
		out.append({
			"customer": c.name,
			"name": c.customer_name or c.name,
			"phone": c.mobile_no,
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
		   remarks: str | None = None):
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
		out.append({
			"item": r.item_code,
			"title": _title(r.item_code, r.item_name),
			"metres": flt(r.qty),
			"price_m": (flt(r.get("korkem_film_price_m")) or None) if money else None,
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
