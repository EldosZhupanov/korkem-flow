# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Плёнка: что докупить» — the film open orders still need, and what to buy.

OnayBaza's «Пленка» form, which the owner reads before calling GreenWood,
Kira or JS group: every order's film and metres; the orders whose film is
not on the shelf; and, summed by film, how many metres of each to order
(06.11.2026).

Here the metres are the press's own (`press_layout.film_metres`, by the
table and its sections, not area ÷ width), and «on the shelf» is the stock
ledger: what is held for the order, what was already issued to it, and what
is free. An order needs film until its vacuum stage is ticked; after that
the film is on the facades.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

import frappe
from frappe.utils import flt

from korkem_manufacturing.services import directions, facade_materials, facade_prices, material_stock, mdf_orders
from korkem_manufacturing.services.scope import current_company


def shortage() -> dict:
	"""By film: needed, held, free, to buy — and the orders behind each."""
	facade_prices.ensure_editor()
	company = current_company()
	orders = frappe.get_all(
		"Sales Order",
		filters={
			"company": company,
			"korkem_direction": directions.FACADES,
			"docstatus": 1,
			"korkem_handed_over_on": ["is", "not set"],
			"korkem_stage_vacuum": ["is", "not set"],
		},
		fields=["name", "customer_name", "delivery_date", "korkem_finish", "korkem_extra_stages"],
		order_by="delivery_date asc, name asc",
		limit_page_length=500,
	)
	films: dict[str, dict] = {}
	rows = []
	for order in orders:
		if "vacuum" not in mdf_orders.stages_of(order):
			continue
		need = facade_materials.need(order.name)
		press = None
		for material in need["materials"]:
			if material["kind"] != material_stock.FILM:
				continue
			decor = material["key"]
			needed = material["needed"]
			if needed is None:
				# Not on the books at all: the press still says how much.
				if press is None:
					from korkem_manufacturing.services import press_layout

					press = press_layout.film_metres(order.name)
				needed = flt(press.get(decor))
			held = flt(material["held"]) + flt(material["issued"])
			short = max(0.0, flt(needed) - held)
			film = films.setdefault(
				decor,
				{"decor": decor, "item": material["item"], "title": material["title"] or decor,
				 "unit": material["unit"] or "м", "needed": Decimal(0), "held": Decimal(0),
				 "short": Decimal(0), "free": Decimal(str(flt(material["free"]))), "orders": 0},
			)
			film["needed"] += Decimal(str(flt(needed)))
			film["held"] += Decimal(str(held))
			film["short"] += Decimal(str(short))
			film["orders"] += 1
			rows.append(
				{"order": order.name, "customer_name": order.customer_name, "delivery_date": str(order.delivery_date),
				 "decor": decor, "needed": _m(needed), "held": _m(held), "short": _m(short),
				 "on_books": material["item"] is not None}
			)
	by_film = []
	for film in films.values():
		to_buy = max(Decimal(0), film["short"] - film["free"])
		by_film.append(
			{"decor": film["decor"], "item": film["item"], "title": film["title"], "unit": film["unit"],
			 "orders": film["orders"], "needed": _m(film["needed"]), "held": _m(film["held"]),
			 "free": _m(film["free"]), "to_buy": _m(to_buy)}
		)
	by_film.sort(key=lambda f: (-f["to_buy"], f["decor"]))
	return {
		"by_film": by_film,
		"orders": rows,
		"needed_total": _m(sum((Decimal(str(f["needed"])) for f in by_film), Decimal(0))),
		"to_buy_total": _m(sum((Decimal(str(f["to_buy"])) for f in by_film), Decimal(0))),
	}


def _m(value) -> float:
	return float(Decimal(str(flt(value))).quantize(Decimal("0.1"), rounding=ROUND_HALF_UP))
