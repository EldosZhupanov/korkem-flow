# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A film an order lacks: where to get it (owner, 19.11.2026).

«MC Group есть в Астане и в Алмате… в Алмате дёшево, логистика 5 дней, в
Астане чуть дороже, но 2 дня». For each film the order cannot take from the
shelf this lays out:

- **where to buy that very film** — every source of its maker (`film_sources`):
  its last price for this film and when, what the bringing cost a metre, how
  many days it takes, the day it would come and whether that is in time for
  the shop. One is marked: the cheapest that comes in time — for an urgent
  order the quickest;
- **what is like it at the other makers** (`decor_colors.analogues`), what
  is on our shelf first.

Whether a source has it is known only after a call: «Есть — заказать» puts the
metres on «К заказу» for that source, tied to the order (so the roll is put
by for it when it comes), and the price the manager named onto the film's
card, with who said it. «Нет нигде» is remembered. A look-alike the customer
agreed to replaces the film in the order, the reason in its history.

The program advises; a person rings and decides.
"""

from __future__ import annotations

import re
from datetime import timedelta

import frappe
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_manufacturing.services import (
	audit,
	facade_prices,
	film_catalog,
	film_orders,
	film_sources,
	material_stock,
	mdf_orders,
	mdf_tags,
	price_visibility,
	search_text,
)
from korkem_manufacturing.services.scope import current_company

#: The film is wanted in the shop this many days before the order is due:
#: the press is not the last stage.
SHOP_DAYS_BEFORE = 2
#: How many look-alikes are offered.
LOOKALIKES = 4
_NOWHERE = "korkem_film_nowhere"


def _days(lead: str | None) -> int | None:
	"""«1–2 дня», «3 дня», «5» → the longest number said; None when unsaid."""
	numbers = [int(n) for n in re.findall(r"\d+", str(lead or ""))]
	return max(numbers) if numbers else None


def _bought(item: str, supplier: str) -> dict:
	"""This film from this source: how often, last price and day; and what
	bringing from this source cost a metre, over its last deliveries."""
	rows = frappe.db.sql(
		"""select se.posting_date, sed.basic_rate, sed.qty, se.korkem_delivery_cost, sed.item_code
		from `tabStock Entry Detail` sed join `tabStock Entry` se on se.name = sed.parent
		where se.docstatus = 1 and se.korkem_supplier = %(s)s and ifnull(sed.t_warehouse, '') != ''
			and ifnull(sed.s_warehouse, '') = '' and se.company = %(c)s
		order by se.posting_date desc, se.creation desc limit 40""",
		{"s": supplier, "c": current_company()}, as_dict=True,
	)
	mine = [r for r in rows if r.item_code == item]
	carried = [r for r in rows if flt(r.qty) > 0][:5]
	per_m = (sum(flt(r.korkem_delivery_cost) for r in carried) / sum(flt(r.qty) for r in carried)) if carried else 0
	return {
		"times": len(mine),
		"price_m": flt(mine[0].basic_rate) if mine else None,
		"price_on": str(mine[0].posting_date) if mine else None,
		"delivery_m": round(per_m, 0),
	}


def _need_by(doc) -> str:
	due = getdate(doc.delivery_date)
	return str(max(getdate(nowdate()), due - timedelta(days=SHOP_DAYS_BEFORE)))


def where(order: str) -> dict:
	"""Every film the order lacks, where to get it, what is like it."""
	facade_prices.ensure_editor()
	doc = mdf_orders._order(order)
	need_by = _need_by(doc)
	urgent = "urgent" in mdf_tags.parse(doc.get("korkem_tags"))
	money = price_visibility.can_see_prices()
	sources = film_sources.by_maker()
	films = []
	for label, lack in mdf_orders._film_to_buy(doc).items():
		item = lack.get("item")
		if not item:
			continue
		maker = frappe.db.get_value("Item", item, "korkem_manufacturer")
		card_price = flt(frappe.db.get_value("Item", item, film_catalog.CARD["price_m"])) or None
		rows = []
		for supplier in sources.get(maker, []):
			src = _source_card(supplier)
			b = _bought(item, supplier)
			days = _days(src.get("lead"))
			comes = add_days(nowdate(), days) if days is not None else None
			price = b["price_m"] or card_price
			rows.append({
				"supplier": supplier, "name": src["name"], "city": src.get("city"), "contact": src.get("contact"),
				"phone": src.get("phone") or src.get("phone2"), "whatsapp": src.get("whatsapp"),
				"lead": src.get("lead"), "days": days, "order_until": src.get("order_until"),
				"times": b["times"], "price_on": b["price_on"], "price_known": b["price_m"] is not None,
				"price_m": price if money else None, "delivery_m": b["delivery_m"] if money else None,
				"landed_m": (price + b["delivery_m"]) if (money and price) else None,
				"comes_on": str(comes) if comes else None,
				"in_time": None if comes is None else str(comes) <= need_by,
			})
		_advise(rows, urgent)
		rows.sort(key=lambda r: (not r["advised"], -r["times"], r["name"]))
		films.append({
			"film": label, "item": item, "maker": maker, "short": lack["short"], "unit": lack["unit"],
			"sources": rows, "ordered": _ordered(order, item), "nowhere": _nowhere_on(item),
			"lookalikes": _lookalikes(item),
		})
	return {"order": order, "accepted": doc.docstatus == 1, "need_by": need_by, "urgent": urgent, "films": films}


def _source_card(supplier: str) -> dict:
	fields = ["supplier_name", *film_sources.CARD.values()]
	r = frappe.db.get_value("Supplier", supplier, fields, as_dict=True) or {}
	return {"name": r.get("supplier_name") or supplier,
			**{key: r.get(field) or None for key, field in film_sources.CARD.items()}}


def _advise(rows: list[dict], urgent: bool) -> None:
	"""One is advised: the cheapest landed that comes in time — the quickest
	for an urgent order, or when none is known to come in time."""
	for r in rows:
		r["advised"] = False
	timely = [r for r in rows if r["in_time"]]
	pick = None
	if urgent or not timely:
		dated = [r for r in rows if r["days"] is not None]
		pick = min(dated, key=lambda r: (r["days"], r["landed_m"] or 1e12), default=None)
	else:
		priced = [r for r in timely if r["landed_m"]]
		pick = min(priced, key=lambda r: (r["landed_m"], r["days"])) if priced else \
			min(timely, key=lambda r: r["days"])
	if pick:
		pick["advised"] = True


def _ordered(order: str, item: str) -> list[dict]:
	return [
		{"line": r.name, "supplier": frappe.db.get_value("Supplier", r.supplier, "supplier_name") or r.supplier,
		 "metres": flt(r.metres), "status": r.status, "note": r.note, "on": str(r.creation)[:10]}
		for r in frappe.get_all(film_orders._DOC, filters={"sales_order": order, "item": item,
														   "status": ["in", [film_orders.OPEN, film_orders.SENT,
																			 film_orders.ORDERED]]},
								fields=["name", "supplier", "metres", "status", "note", "creation"],
								order_by="creation asc")
	]


def _nowhere_on(item: str) -> str | None:
	return frappe.db.get_default(f"{_NOWHERE}:{item}") or None


def _lookalikes(item: str) -> list[dict]:
	from korkem_manufacturing.services import decor_colors

	try:
		found = decor_colors.analogues(item=item)["analogues"]
	except (frappe.DoesNotExistError, frappe.ValidationError):
		frappe.clear_messages()
		return []
	# What is on our shelf first, then the nearest (owner: «сначала что есть у нас»).
	near = found[: LOOKALIKES * 2]
	near.sort(key=lambda m: (-(flt(m.get("on_shelf")) > 0), flt(m.get("distance"))))
	return near[:LOOKALIKES]


def order(order: str, item: str, supplier: str, metres, price_m=None, comes_on: str | None = None,
		  said_by: str | None = None) -> dict:
	"""«Есть — заказать»: so many metres from this source onto «К заказу» for
	the order; the price the manager named onto the film's card."""
	facade_prices.ensure_editor()
	doc = mdf_orders._order(order)
	if doc.docstatus != 1:
		frappe.throw("Сначала примите заказ — плёнку заказывают под принятый.")
	if frappe.db.get_value("Item", item, "korkem_material_company") != current_company():
		frappe.throw("Такой плёнки нет.", frappe.DoesNotExistError)
	if not frappe.db.exists("Supplier", supplier):
		frappe.throw("Такого поставщика нет.", frappe.DoesNotExistError)
	qty = flt(metres)
	if not 0 < qty <= 2000:
		frappe.throw("Сколько метров заказать — от 0 до 2000.")
	said = " ".join(str(said_by or "").split())[:60] or None
	when = str(getdate(comes_on)) if comes_on else None
	note = " · ".join(x for x in (f"подтвердил: {said}" if said else None,
								   f"привезут {getdate(when).strftime('%d.%m')}" if when else None) if x) or None
	line = frappe.get_doc({
		"doctype": film_orders._DOC, "company": doc.company, "item": item, "metres": qty, "sales_order": order,
		"supplier": supplier, "status": film_orders.OPEN, "added_by": frappe.session.user, "note": note,
	}).insert(ignore_permissions=True)
	if price_m not in (None, "") and flt(price_m) > 0:
		number = search_text.number_in(order) or order
		with material_stock.granted():
			film_catalog.set_card(item, via=f"со слов {said or 'поставщика'}, заказ № {number}", price_m=flt(price_m))
	frappe.db.set_default(f"{_NOWHERE}:{item}", "")
	audit.record_audit(action="film.ordered_for_order", entity_type="Sales Order", entity_id=order,
					   diff={"item": item, "supplier": supplier, "metres": qty, "price_m": price_m, "said_by": said,
							 "comes_on": when, "line": line.name})
	return where(order)


def nowhere(order: str, item: str) -> dict:
	"""Rung everyone: no one has it. Remembered for the film, with the day."""
	facade_prices.ensure_editor()
	mdf_orders._order(order)
	frappe.db.set_default(f"{_NOWHERE}:{item}", nowdate())
	audit.record_audit(action="film.nowhere", entity_type="Item", entity_id=item, diff={"order": order})
	return where(order)


def replace(order: str, old: str, new: str, reason: str | None = None) -> dict:
	"""The customer agreed to a look-alike: the order's film is the other one
	now — the same sizes, the same price a metre; the reason in its history."""
	facade_prices.ensure_editor()
	if new not in film_catalog.labels(current_company()):
		frappe.throw(f"Плёнки «{new}» нет в каталоге.")
	card = mdf_orders.card(order)
	if not any(line.get("film") == old or line.get("film_back") == old for line in card["lines"]) \
			and card["head"].get("decor_top") != old:
		frappe.throw(f"В заказе нет плёнки «{old}».")
	keys = ("height_mm", "width_mm", "qty", "milling", "note", "film", "film_back", "material", "thickness_mm",
			"edge", "patina", "coating", "client_paint", "client_mdf", "client_film", "gloss")
	lines = []
	for line in card["lines"]:
		raw = {k: line.get(k) for k in keys}
		raw["film"] = new if raw["film"] == old else raw["film"]
		raw["film_back"] = new if raw["film_back"] == old else raw["film_back"]
		raw["rate"] = line["rate_m2"]  # the customer pays as agreed
		lines.append(raw)
	head = dict(card["head"])
	for key in ("decor_top", "decor_bottom"):
		if head.get(key) == old:
			head[key] = new
	rates = head.get("film_rates") or {}
	if isinstance(rates, str):
		rates = frappe.parse_json(rates) if rates.strip() else {}
	if old in rates:
		rates[new] = rates.pop(old)
	head["film_rates"] = rates
	why = " ".join(str(reason or "").split()) or "клиент согласен"
	mdf_orders.change_order(order, lines=lines, head=head, reason=f"плёнка {old} → {new}: {why}")
	return where(order)
