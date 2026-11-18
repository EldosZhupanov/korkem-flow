# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The order's film window (owner, 18.11.2026): one place to pick a film —
every film on the books, on the shelf or not, and every maker's catalogue
decor not taken in yet — with this customer's films of late on top.

A catalogue decor picked for an order is taken in as a film there and then
(`take`): the stock's material, nothing on hand, ordered from its maker
once the order is accepted (`film_orders.wanted`).
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import directions, facade_prices, film_catalog, film_decors, material_stock
from korkem_manufacturing.services.scope import current_company

#: How many of the customer's films of late are offered on top.
RECENT = 6


def extras(customer: str | None = None) -> dict:
	"""What the window shows besides the films on the books: the catalogue
	decors not taken in yet, and the customer's films of late."""
	material_stock._ensure_staff()
	company = current_company()
	taken = {
		(film_decors._key(i.korkem_manufacturer), film_decors._key(i.korkem_color))
		for i in frappe.get_all(
			"Item",
			filters={"korkem_material_company": company, "korkem_material_kind": material_stock.FILM},
			fields=["korkem_manufacturer", "korkem_color"],
			limit_page_length=0,
		)
	}
	decors = [
		{
			"decor": r.name, "maker": r.maker, "name": r.decor_name, "collection": r.collection,
			"code": r.code, "hex": r.hex, "image": r.image, "label": film_catalog.label(r.maker, r.decor_name),
		}
		for r in film_decors._rows(company)
		if (film_decors._key(r.maker), film_decors._key(r.decor_name)) not in taken
	]
	return {"decors": decors, "recent": _recent(customer, company)}


def _recent(customer: str | None, company: str) -> list[str]:
	if not customer:
		return []
	orders = frappe.get_all(
		"Sales Order",
		filters={"company": company, "customer": customer, "korkem_direction": directions.FACADES,
				 "docstatus": ["<", 2]},
		pluck="name", order_by="creation desc", limit_page_length=10,
	)
	if not orders:
		return []
	by_order: dict[str, list[str]] = {}
	for r in frappe.get_all("Sales Order Item", filters={"parent": ["in", orders], "parenttype": "Sales Order"},
							fields=["parent", "korkem_decor_top"], order_by="idx asc", limit_page_length=0):
		if r.korkem_decor_top:
			by_order.setdefault(r.parent, []).append(r.korkem_decor_top)
	known = film_catalog.labels(company)
	out: list[str] = []
	for name in orders:
		for decor in by_order.get(name, []):
			if decor in known and decor not in out:
				out.append(decor)
	return out[:RECENT]


def take(decor: str) -> dict:
	"""A maker's catalogue decor picked for an order: the film it is, taken
	in if it is not yet, and its name for the order."""
	if not (facade_prices.can_edit() or material_stock.can_edit()):
		frappe.throw("Плёнку в заказ выбирают менеджеры.", frappe.PermissionError)
	company = current_company()
	d = frappe.db.get_value(film_decors.DOCTYPE, decor, ["company", "maker", "decor_name"], as_dict=True)
	if not d or d.company != company:
		frappe.throw("Такого декора нет.", frappe.DoesNotExistError)
	have = frappe.get_all(
		"Item",
		filters={"korkem_material_company": company, "korkem_material_kind": material_stock.FILM,
				 "korkem_manufacturer": d.maker, "korkem_color": d.decor_name},
		pluck="name", order_by="name", limit_page_length=1,
	)
	if have:
		return {"item": have[0], "label": film_catalog.label(d.maker, d.decor_name)}
	with material_stock.granted():
		film = film_decors.from_decor(decor)
	return {"item": film["item"], "label": film.get("label") or film_catalog.label(d.maker, d.decor_name)}
