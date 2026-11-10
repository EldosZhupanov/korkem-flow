# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The PVC film catalogue, maker by maker (owner, 10.11.2026).

**Each film is its maker's own.** «Белый Матовый» from KIRA is a shade
lighter than JS Group's, MC Group's is colder; one name for all of them is
how the wrong roll gets pressed. So a film is the stock's own material — an
ERPNext Item of kind «Плёнка ПВХ» with its maker, colour, width and
thickness (`material_stock`) — and this module adds its card: code, type,
sample colour, nearest RAL, supplier, the supplier's price per metre, a link.

**Everything is per running metre.** The shop buys, sells and counts film by
the metre; there is no m² on a film's card.

**Makers and types are lists the owner keeps** (`Material Option`
«Производитель», «Тип плёнки»): added, renamed and removed like any other.

A colour of the order form's old list that no film carries yet is shown
under «не указан» — the orders that name it stay as they are, and the owner
gives it a maker when there is time.
"""

from __future__ import annotations

import re

import frappe
from frappe.utils import flt

from korkem_manufacturing.services import audit, material_stock, price_visibility
from korkem_manufacturing.services.scope import current_company

MAKERS = "Производитель"
TYPES = "Тип плёнки"
COLOURS = "Цвет плёнки"

#: The card's own fields, as the client names them.
CARD = {
	"code": "korkem_film_code",
	"type": "korkem_film_type",
	"hex": "korkem_film_hex",
	"ral": "korkem_film_ral",
	"supplier": "korkem_film_supplier",
	"price_m": "korkem_film_price_m",
	"url": "korkem_film_url",
}

_FIELDS = [
	"name", "item_name", "stock_uom", "disabled", "korkem_manufacturer", "korkem_color",
	"korkem_film_width_mm", "korkem_film_thickness_mm", "korkem_film_textured", "korkem_min_stock",
	*CARD.values(),
]

_HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")


def catalog() -> dict:
	"""Every film, with its card and what is on hand; the makers and types to pick from."""
	material_stock._ensure_staff()
	company = current_company()
	items = frappe.get_all(
		"Item",
		filters={"korkem_material_company": company, "korkem_material_kind": material_stock.FILM},
		fields=_FIELDS,
		order_by="item_name asc",
		limit_page_length=5000,
	)
	stock = material_stock._stock([i.name for i in items], company)
	held = material_stock._reserved([i.name for i in items], company)
	films = [_film(i, stock.get(i.name, (0.0, 0.0))[0], held.get(i.name, 0.0)) for i in items]
	carried = {f["colour"] for f in films}
	# The old list's colours no film carries yet: «не указан».
	loose = sorted(
		v for v in material_stock.enabled_values(COLOURS, company) if v not in carried
	)
	return {
		"films": films,
		"unassigned": loose,
		"makers": sorted(material_stock.enabled_values(MAKERS, company), key=str.casefold),
		"types": sorted(material_stock.enabled_values(TYPES, company), key=str.casefold),
		"suppliers": material_stock.suppliers(),
		"can_edit": material_stock.can_edit(),
	}


def set_card(item: str, **card) -> dict:
	"""Write a film's card. A field left out stays as it is; an empty one is cleared."""
	material_stock._ensure_editor()
	material_stock._own_item(item)
	if frappe.db.get_value("Item", item, "korkem_material_kind") != material_stock.FILM:
		frappe.throw("Это не плёнка.")
	company = current_company()
	values = {}
	for key, field in CARD.items():
		if key not in card:
			continue
		values[field] = _clean(key, card[key], company)
	if values:
		frappe.db.set_value("Item", item, values)
		audit.record_audit(action="film.card_set", entity_type="Item", entity_id=item, diff=values)
	return film(item)


def film(item: str) -> dict:
	company = current_company()
	row = frappe.db.get_value("Item", item, _FIELDS, as_dict=True)
	if not row:
		frappe.throw("Такой плёнки нет.", frappe.DoesNotExistError)
	return _film(
		row,
		material_stock._stock([item], company).get(item, (0.0, 0.0))[0],
		material_stock._reserved([item], company).get(item, 0.0),
	)


def _clean(key: str, value, company: str):
	if value is None or str(value).strip() == "":
		return None
	if key == "price_m":
		try:
			price = flt(value)
		except (TypeError, ValueError):
			frappe.throw("Цена за метр — число.")
		if price < 0 or price > 10_000_000:
			frappe.throw("Цена за метр — от 0 до 10 000 000 ₸.")
		return price
	text = " ".join(str(value).split())[:140]
	if key == "type" and text not in material_stock.enabled_values(TYPES, company):
		frappe.throw(f"Типа «{text}» нет в справочнике «{TYPES}». Добавьте его в справочник.")
	if key == "hex":
		text = text if text.startswith("#") else f"#{text}"
		if not _HEX.match(text):
			frappe.throw("Образец цвета — шесть знаков, например #F4F3EE.")
		return text.upper()
	if key == "supplier" and not frappe.db.exists("Supplier", text):
		frappe.throw(f"Поставщика «{text}» нет.")
	if key == "url" and not text.lower().startswith(("http://", "https://")):
		text = f"https://{text}"
	return text


def _film(i, on_hand: float, held: float) -> dict:
	return {
		"item": i.name,
		"title": i.item_name,
		"maker": i.korkem_manufacturer or "",
		"colour": i.korkem_color or "",
		"width_mm": flt(i.korkem_film_width_mm) or None,
		"thickness_mm": flt(i.korkem_film_thickness_mm) or None,
		"textured": bool(i.korkem_film_textured),
		"enabled": not i.disabled,
		"unit": i.stock_uom,
		"on_hand": flt(on_hand),
		"held": flt(held),
		"min_stock": flt(i.korkem_min_stock) or None,
		**{key: i.get(field) for key, field in CARD.items()},
		# Money: the shop floor sees metres, not what was paid (`price_visibility`).
		"price_m": (flt(i.get(CARD["price_m"])) or None) if price_visibility.can_see_prices() else None,
	}
