# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Замена цвета (owner, 19.11.2026: «клиент выбирает краску, но её нет в
наличии у поставщиков — мы заменили более похожим цветом; надо придумать
этот момент»).

A colour of an order no supplier has: the manager picks one of three ways —

- **wait** for the colour itself, by a day it should come;
- **tint** — have it mixed exactly from a base and pigments;
- **replace** it with the nearest colour there is (`paint_catalogue.similar`).

Whatever the way, the customer agrees first — by WhatsApp, with both colours
side by side, or on the phone — and the order keeps who agreed and when, so
that «я заказывал другой цвет» has an answer. Until he does, the order does
not go to paint: «Покрасил — сушится» and the stage «краска» are refused.
Agreed to a replacement, the order's positions take the new colour; the old
one stays on the order, crossed out, beside it.

The record is a JSON list on the order (`korkem_paint_swaps`), one entry a
colour: from, to, how, status (asked → agreed), when, who, how agreed.
"""

from __future__ import annotations

import json

import frappe
from frappe.utils import getdate, now_datetime

from korkem_manufacturing.services import (
	audit,
	facade_order,
	facade_prices,
	mdf_orders,
	mdf_paint,
	paint_catalogue,
)

FIELD = "korkem_paint_swaps"
WAYS = ("replace", "tint", "wait")
ASKED, AGREED = "asked", "agreed"
VIAS = ("whatsapp", "phone", "in_person")
LOOKS = {"same": "почти не отличить", "close": "очень похож, разница заметна только вблизи",
		 "other": "оттенок другой"}


def of(doc) -> list[dict]:
	try:
		rows = json.loads(doc.get(FIELD) or "[]")
	except ValueError:
		rows = []
	return [r for r in rows if isinstance(r, dict)]


def pending(doc) -> list[dict]:
	"""Swaps the customer has not agreed to yet."""
	return [r for r in of(doc) if r.get("status") == ASKED]


def ensure_agreed(doc) -> None:
	"""The paint shop's guard: no painting before the customer said yes."""
	waiting = pending(doc)
	if waiting:
		frappe.throw("Ждём согласия клиента на замену цвета: "
					 + ", ".join(f"{r['from']} → {r.get('to') or _way(r['how'])}" for r in waiting) + ".")


def _way(how: str) -> str:
	return {"replace": "замена", "tint": "колеровка", "wait": "ждём родной"}.get(how, how)


def _paint_lines(doc) -> list:
	return [i for i in doc.items if i.item_code == facade_order.FACADE_ITEM
			and (i.korkem_line_coating or mdf_orders.coating_of(i.korkem_finish or doc.get("korkem_finish")))
			== mdf_paint.PAINT]


def _colours_of(doc) -> dict[str, str]:
	"""The order's paint colours: key → the colour as the order names it."""
	out = {}
	for i in _paint_lines(doc):
		for colour in (i.korkem_decor_top, i.korkem_decor_bottom if i.korkem_double_sided else None):
			colour = (colour or "").strip()
			if colour:
				out.setdefault(paint_catalogue.key(colour), colour)
	return out


def _save(doc, rows: list[dict]) -> None:
	doc.db_set(FIELD, json.dumps(rows, ensure_ascii=False) if rows else None, update_modified=True)


def options(order: str, colour: str) -> dict:
	"""What to offer for a colour of an order: the nearest there is, on the
	shelf first, and the order's own record of it."""
	facade_prices.ensure_editor()
	doc = mdf_orders._order(order)
	k = paint_catalogue.key(colour)
	if k not in _colours_of(doc):
		frappe.throw("В заказе нет такого цвета.")
	near = paint_catalogue.similar(colour=colour)
	return {
		"order": doc.name, "colour": colour, "hex": near["hex"],
		"similar": near["similar"],
		"swap": next((r for r in of(doc) if r.get("key") == k), None),
	}


def message(doc, row: dict) -> str:
	"""The words to the customer, ready for WhatsApp."""
	hello = f"Здравствуйте, {doc.customer_name}!" if doc.customer_name else "Здравствуйте!"
	lead = f"По заказу №{doc.name}: краски {row['from']} сейчас нет у поставщиков."
	if row["how"] == "replace":
		look = LOOKS.get(row.get("look") or "", "")
		offer = f"Предлагаем {row['to']}" + (f" — {look}" if look else "") + "."
	elif row["how"] == "tint":
		offer = f"Можем заколеровать {row['from']} точно в цвет из базы и пигментов."
	else:
		when = row.get("wait_until")
		offer = "Можем дождаться этой краски" + (f": ожидаем к {getdate(when).strftime('%d.%m')}" if when else "") \
			+ ", срок заказа сдвинется."
	return f"{hello} {lead} {offer} Вы согласны?"


def propose(order: str, colour: str, how: str, to: str | None = None, wait_until: str | None = None,
			note: str | None = None) -> dict:
	"""A way for a colour no supplier has — asked of the customer."""
	facade_prices.ensure_editor()
	doc = mdf_orders._accepted(order)
	if doc.korkem_handed_over_on:
		frappe.throw("Заказ уже выдан.")
	if how not in WAYS:
		frappe.throw("Как быть — один из: заменить, заколеровать, ждать.")
	k = paint_catalogue.key(colour)
	colours = _colours_of(doc)
	if k not in colours:
		frappe.throw("В заказе нет такого цвета.")
	row = {"key": k, "from": colours[k], "how": how, "status": ASKED, "asked_at": str(now_datetime())[:16],
		   "asked_by": frappe.session.user, "note": (note or "").strip()[:300] or None}
	if how == "replace":
		to = " ".join((to or "").split())
		if not to:
			frappe.throw("На какой цвет заменить?")
		if paint_catalogue.key(to) == k:
			frappe.throw("Это тот же цвет.")
		near = paint_catalogue.similar(colour=colours[k])
		match = next((c for c in near["similar"] if c["key"] == paint_catalogue.key(to)), None)
		row.update({"to": to, "look": match["look"] if match else None, "delta": match["delta"] if match else None})
	if how == "wait":
		row["wait_until"] = str(getdate(wait_until)) if wait_until else None
	rows = [r for r in of(doc) if r.get("key") != k] + [row]
	_save(doc, rows)
	audit.record_audit(action="paint.swap_asked", entity_type="Sales Order", entity_id=doc.name, diff=row)
	return {"swaps": rows, "message": message(doc, row), "phone": frappe.db.get_value("Customer", doc.customer,
																						 "mobile_no")}


def agree(order: str, colour: str, via: str = "phone", who: str | None = None) -> dict:
	"""The customer said yes. A replacement takes the order's positions to
	the new colour; the old one stays on the record."""
	facade_prices.ensure_editor()
	doc = mdf_orders._accepted(order)
	if via not in VIAS:
		frappe.throw("Как согласовали — WhatsApp, по телефону или лично.")
	k = paint_catalogue.key(colour)
	rows = of(doc)
	row = next((r for r in rows if r.get("key") == k), None)
	if not row:
		frappe.throw("По этому цвету замену не предлагали.")
	if row.get("status") == AGREED:
		return {"swaps": rows}
	if row["how"] == "replace":
		new = paint_catalogue.listed(row["to"])["value"]
		row["to"] = new
		for i in _paint_lines(doc):
			for field in ("korkem_decor_top", "korkem_decor_bottom"):
				if paint_catalogue.key(i.get(field)) == k:
					frappe.db.set_value("Sales Order Item", i.name, field, new, update_modified=False)
	row.update({"status": AGREED, "agreed_at": str(now_datetime())[:16], "agreed_via": via,
				"agreed_by": " ".join((who or "").split())[:120] or doc.customer_name})
	doc.reload()
	_save(doc, rows)
	audit.record_audit(action="paint.swap_agreed", entity_type="Sales Order", entity_id=doc.name, diff=row)
	return {"swaps": rows}


def cancel(order: str, colour: str) -> dict:
	"""Not asked after all — before the customer agreed."""
	facade_prices.ensure_editor()
	doc = mdf_orders._accepted(order)
	k = paint_catalogue.key(colour)
	rows = of(doc)
	row = next((r for r in rows if r.get("key") == k), None)
	if row and row.get("status") == AGREED:
		frappe.throw("Клиент уже согласился — замена в заказе.")
	rows = [r for r in rows if r.get("key") != k]
	_save(doc, rows)
	audit.record_audit(action="paint.swap_cancelled", entity_type="Sales Order", entity_id=doc.name,
					   diff={"key": k})
	return {"swaps": rows}
