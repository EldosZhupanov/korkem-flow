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

**A maker groups its films into collections of its own** (owner,
11.11.2026): Adilet has Solid Color and Wood, another has ALDA, Софт SF,
Древесные. A collection belongs to one maker — kept as `Material Option`
«Коллекция плёнки» under the name «Maker · Collection», so two makers may
each have a «Древесные» — and the owner adds, renames and removes them.

**A film is edited, archived, and only an unused one deleted** (owner,
11.11.2026). Its name, thickness and width are changed on its card; orders
keep the name they were written with. A film with receipts, sales or orders
behind it goes to the archive — off the maker's list and the order's pick,
its history and its metres intact — and comes back with one button. Every
change is written down with who made it and when (`changes`).

A colour of the order form's old list that no film carries yet is shown
under «не указан» — the orders that name it stay as they are, and the owner
gives it a maker when there is time.
"""

from __future__ import annotations

import json
import re

import frappe
from frappe.utils import flt

from korkem_manufacturing.services import audit, material_stock, price_visibility
from korkem_manufacturing.services.scope import current_company

MAKERS = "Производитель"
TYPES = "Тип плёнки"
COLOURS = "Цвет плёнки"
COLLECTIONS = "Коллекция плёнки"

#: The card's own fields, as the client names them.
CARD = {
	"code": "korkem_film_code",
	"type": "korkem_film_type",
	"collection": "korkem_film_collection",
	"hex": "korkem_film_hex",
	"ral": "korkem_film_ral",
	"supplier": "korkem_film_supplier",
	"price_m": "korkem_film_price_m",
	"url": "korkem_film_url",
	# What the department sells a metre for (`film_dept`).
	"retail_m": "korkem_film_retail_m",
	"wholesale_m": "korkem_film_wholesale_m",
}

#: The card's money, per running metre.
PRICES = ("price_m", "retail_m", "wholesale_m")

_FIELDS = [
	"name", "item_name", "stock_uom", "disabled", "korkem_manufacturer", "korkem_color",
	"korkem_film_width_mm", "korkem_film_thickness_mm", "korkem_film_textured", "korkem_min_stock",
	"korkem_film_archived",
	*CARD.values(),
]

#: What a film is, apart from its card: changed on the card too (11.11.2026).
SHAPE = {
	"colour": "korkem_color",
	"thickness": "korkem_film_thickness_mm",
	"width": "korkem_film_width_mm",
}
_SHAPE_LIST = {"colour": COLOURS, "thickness": "Толщина плёнки", "width": "Ширина плёнки"}

_HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")

#: How an order names a catalogue film: «KIRA · Белый Матовый». The maker is
#: part of the name — the same colour of another maker is another film — and
#: an order's old plain colour («Белый Матовый») stays what it was.
SEP = " · "


def label(maker: str, colour: str) -> str:
	return f"{maker}{SEP}{colour}"


def split(name: str | None) -> tuple[str, str] | None:
	"""A film's maker and colour from its name in an order; None for a plain colour."""
	if not name or SEP not in name:
		return None
	maker, colour = name.split(SEP, 1)
	return (maker, colour) if maker and colour else None


def labels(company: str) -> set[str]:
	"""Every catalogue film's name — a film in the archive too, and the names
	a renamed film had before: an order that names it must still save."""
	items = frappe.get_all(
		"Item",
		filters={"korkem_material_company": company, "korkem_material_kind": material_stock.FILM},
		fields=["name", "korkem_manufacturer", "korkem_color"],
		limit_page_length=5000,
	)
	names = {
		label(r.korkem_manufacturer, r.korkem_color) for r in items if r.korkem_manufacturer and r.korkem_color
	}
	makers = {r.name: r.korkem_manufacturer for r in items if r.korkem_manufacturer}
	for e in frappe.get_all(
		"Domain Audit Event",
		filters={
			"company": company, "entity_type": "Item", "action": "film.changed",
			"diff_json": ["like", f'%"{SHAPE["colour"]}"%'],
		},
		fields=["entity_id", "diff_json"],
		limit_page_length=5000,
	):
		maker = makers.get(e.entity_id)
		try:
			before = json.loads(e.diff_json or "{}").get(SHAPE["colour"], {}).get("before")
		except (ValueError, AttributeError):
			continue
		if maker and before:
			names.add(label(maker, before))
	return names


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
	since = _price_since([i.name for i in items], company)
	films = [
		{**_film(i, stock.get(i.name, (0.0, 0.0))[0], held.get(i.name, 0.0)), "price_since": since.get(i.name, {})}
		for i in items
	]
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
		"collections": collections(company),
		"suppliers": [s for s in material_stock.suppliers() if s["enabled"]],
		# Maker → the sources that sell it (`film_sources`): a receipt offers those first.
		"sources_by_maker": _by_maker(),
		"can_edit": material_stock.can_edit(),
	}


def _by_maker() -> dict:
	from korkem_manufacturing.services import film_sources

	return film_sources.by_maker()


def collections(company: str | None = None) -> dict[str, list[str]]:
	"""Maker → its collections, by name."""
	result: dict[str, list[str]] = {}
	for value in material_stock.enabled_values(COLLECTIONS, company or current_company()):
		pair = split(value)
		if pair:
			result.setdefault(pair[0], []).append(pair[1])
	return {maker: sorted(names, key=str.casefold) for maker, names in result.items()}


def _collection_name(name: str | None) -> str:
	name = " ".join((name or "").split())[:100]
	if len(name) < 2:
		frappe.throw("Назовите коллекцию.")
	if SEP in name:
		frappe.throw(f"В названии коллекции не должно быть «{SEP.strip()}».")
	return name


def _collection_option(maker: str, name: str, company: str) -> str:
	option = frappe.db.get_value(
		"Material Option",
		{"company": company, "kind": COLLECTIONS, "value": label(maker, name), "enabled": 1},
		"name",
	)
	if not option:
		frappe.throw(f"Коллекции «{name}» у {maker} нет.", frappe.DoesNotExistError)
	return option


def _films_of(maker: str, collection: str, company: str) -> list[str]:
	return frappe.get_all(
		"Item",
		filters={
			"korkem_material_company": company,
			"korkem_material_kind": material_stock.FILM,
			"korkem_manufacturer": maker,
			"korkem_film_collection": collection,
		},
		pluck="name",
		limit_page_length=5000,
	)


def add_collection(maker: str, name: str) -> dict:
	"""A new collection of this maker; one removed before comes back."""
	material_stock._ensure_editor()
	company = current_company()
	maker = " ".join((maker or "").split())
	if maker not in material_stock.enabled_values(MAKERS, company):
		frappe.throw(f"Производителя «{maker or '—'}» нет в справочнике «{MAKERS}».")
	material_stock.put_option(COLLECTIONS, label(maker, _collection_name(name)))
	return catalog()


def rename_collection(maker: str, name: str, new_name: str) -> dict:
	"""Rename a collection; its films follow."""
	material_stock._ensure_editor()
	company = current_company()
	option = _collection_option(maker, name, company)
	new_name = _collection_name(new_name)
	if new_name == name:
		return catalog()
	twins = frappe.get_all(
		"Material Option",
		filters={"company": company, "kind": COLLECTIONS, "value": label(maker, new_name)},
		pluck="name",
	)
	if any(twin != option for twin in twins):
		frappe.throw(f"Коллекция «{new_name}» у {maker} уже есть.")
	frappe.db.set_value("Material Option", option, "value", label(maker, new_name))
	for item in _films_of(maker, name, company):
		frappe.db.set_value("Item", item, "korkem_film_collection", new_name)
	audit.record_audit(
		action="film.collection_renamed", entity_type="Material Option", entity_id=option,
		diff={"maker": maker, "before": name, "after": new_name},
	)
	return catalog()


def remove_collection(maker: str, name: str) -> dict:
	"""Remove a collection. Its films stay in the catalogue, without one."""
	material_stock._ensure_editor()
	company = current_company()
	option = _collection_option(maker, name, company)
	for item in _films_of(maker, name, company):
		frappe.db.set_value("Item", item, "korkem_film_collection", None)
	frappe.delete_doc("Material Option", option, ignore_permissions=True, force=True)
	audit.record_audit(
		action="film.collection_removed", entity_type="Material Option", entity_id=option,
		diff={"maker": maker, "collection": name},
	)
	return catalog()


def drop_unassigned(colour: str) -> dict:
	"""Take a colour of the old list off «не указан» (owner, 11.11.2026: the
	old list is no longer kept by hand). Orders that name it stay as written."""
	material_stock._ensure_editor()
	company = current_company()
	if colour not in catalog()["unassigned"]:
		frappe.throw(f"«{colour}» — плёнка каталога или такого цвета нет.")
	option = frappe.db.get_value(
		"Material Option", {"company": company, "kind": COLOURS, "value": colour, "enabled": 1}, "name"
	)
	material_stock.drop_option(option)
	return catalog()


def maker_renamed(before: str, after: str) -> None:
	"""A renamed maker keeps its collections (`mdf_dictionaries.rename`)."""
	company = current_company()
	for r in frappe.get_all(
		"Material Option",
		filters={"company": company, "kind": COLLECTIONS, "value": ["like", f"{before}{SEP}%"]},
		fields=["name", "value"],
		limit_page_length=1000,
	):
		pair = split(r.value)
		if pair and pair[0] == before:
			frappe.db.set_value("Material Option", r.name, "value", label(after, pair[1]))


def add(
	maker: str,
	colour: str,
	thickness: str | None = None,
	width: str | None = None,
	collection: str | None = None,
	**card,
) -> dict:
	"""A new film of this maker, from the catalogue itself (owner, 10.11.2026:
	«где карточка плёнки?» — there was nowhere to add one but the stock).

	The film is the stock's material, counted in metres; its colour, width
	and thickness are put on the stock's lists if they are not there yet. A
	roll is 1400 mm wide unless said otherwise. Its code, surface, supplier
	and prices are taken at once (owner, 11.11.2026: the manager should not
	have to open the card after every film).
	"""
	material_stock._ensure_editor()
	company = current_company()
	maker = " ".join((maker or "").split())
	colour = " ".join((colour or "").split())[:100]
	width = " ".join(str(width or "1400").split())
	thickness = " ".join(str(thickness or "0,3").split())
	if maker not in material_stock.enabled_values(MAKERS, company):
		frappe.throw(f"Производителя «{maker or '—'}» нет в справочнике «{MAKERS}».")
	if len(colour) < 2:
		frappe.throw("Назовите плёнку.")
	if SEP in colour:
		frappe.throw(f"В названии плёнки не должно быть «{SEP.strip()}».")
	for kind, value in ((COLOURS, colour), ("Ширина плёнки", width), ("Толщина плёнки", thickness)):
		if value not in material_stock.enabled_values(kind, company):
			material_stock.put_option(kind, value)
	made = material_stock.define_material(
		material_stock.FILM, "м", color=colour, width=width, film_thickness=thickness, manufacturer=maker
	)
	collection = " ".join((collection or "").split())
	given = {k: v for k, v in card.items() if k in CARD and str(v or "").strip()}
	if collection:
		given["collection"] = collection
	if given:
		set_card(made["item"], **given)
	return film(made["item"])


def set_card(item: str, via: str | None = None, **card) -> dict:
	"""Write a film's card. A field left out stays as it is; an empty one is cleared.

	`via` says where a change came from when it is not the card itself —
	«приход», «продажа» — and is kept with it in the film's history.
	"""
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
	if values.get(CARD["collection"]):
		maker = frappe.db.get_value("Item", item, "korkem_manufacturer")
		if values[CARD["collection"]] not in collections(company).get(maker, []):
			frappe.throw(f"Коллекции «{values[CARD['collection']]}» у {maker or '—'} нет. Добавьте её.")
	values.update(_shape(item, card, company))
	before = frappe.db.get_value("Item", item, list(values), as_dict=True) if values else {}
	changed = {
		field: {"before": before.get(field), "after": value}
		for field, value in values.items()
		if _same(before.get(field)) != _same(value)
	}
	if changed:
		frappe.db.set_value("Item", item, {field: c["after"] for field, c in changed.items()})
		audit.record_audit(action="film.changed", entity_type="Item", entity_id=item, diff=changed, reason=via)
		if SHAPE["colour"] in changed:
			_drop_loose_colour(changed[SHAPE["colour"]]["before"], company)
	return film(item)


def _drop_loose_colour(colour: str | None, company: str) -> None:
	"""A name no film carries any more leaves the old colour list, so that a
	renamed or deleted film does not come back under «не указан»."""
	if not colour or frappe.db.exists(
		"Item",
		{"korkem_material_company": company, "korkem_material_kind": material_stock.FILM, "korkem_color": colour},
	):
		return
	option = frappe.db.get_value(
		"Material Option", {"company": company, "kind": COLOURS, "value": colour, "enabled": 1}, "name"
	)
	if option:
		material_stock.drop_option(option)


def _same(value):
	"""«3200» and 3200.0 are one price; nothing and «» are one emptiness."""
	if value is None or value == "":
		return None
	try:
		return float(value)
	except (TypeError, ValueError):
		return str(value)


def _shape(item: str, card: dict, company: str) -> dict:
	"""A new name, thickness or width: the values for the Item, its title too."""
	if not any(key in card for key in SHAPE):
		return {}
	row = frappe.db.get_value(
		"Item", item, ["korkem_manufacturer", *SHAPE.values()], as_dict=True
	)
	now = {key: row.get(field) for key, field in SHAPE.items()}
	for key in SHAPE:
		if key not in card:
			continue
		value = " ".join(str(card[key] or "").split())[:100]
		if key == "colour":
			if len(value) < 2:
				frappe.throw("Назовите плёнку.")
			if SEP in value:
				frappe.throw(f"В названии плёнки не должно быть «{SEP.strip()}».")
		elif _number(value) is None:
			frappe.throw("Толщина и ширина — числа, например 0,3 и 1400.")
		now[key] = value
	title = material_stock._title(
		material_stock.FILM,
		{
			"color": now["colour"], "width": now["width"], "film_thickness": now["thickness"],
			"manufacturer": row.korkem_manufacturer,
		},
	)[:140]
	# An order names a film by its maker and name alone («KIRA · Белый»), so
	# one name is one film of a maker, whatever its roll.
	twins = frappe.get_all(
		"Item",
		filters={
			"korkem_material_company": company, "korkem_material_kind": material_stock.FILM,
			"korkem_manufacturer": row.korkem_manufacturer, "korkem_color": now["colour"],
		},
		pluck="name",
	)
	twin = frappe.db.get_value("Item", {"korkem_material_company": company, "item_name": title}, "name")
	if any(t != item for t in twins) or (twin and twin != item):
		frappe.throw(f"Плёнка «{now['colour']}» у {row.korkem_manufacturer} уже есть.")
	for key in SHAPE:
		if now[key] not in material_stock.enabled_values(_SHAPE_LIST[key], company):
			material_stock.put_option(_SHAPE_LIST[key], now[key])
	return {**{SHAPE[key]: now[key] for key in SHAPE}, "item_name": title, "description": title}


def retitle(company: str) -> None:
	"""Each film's title made again from what it is now — after a list value
	it is made of (a thickness, a width, a maker) was renamed."""
	for r in frappe.get_all(
		"Item",
		filters={"korkem_material_company": company, "korkem_material_kind": material_stock.FILM},
		fields=["name", "item_name", "korkem_manufacturer", *SHAPE.values()],
		limit_page_length=5000,
	):
		title = material_stock._title(
			material_stock.FILM,
			{
				"color": r.korkem_color, "width": r.korkem_film_width_mm,
				"film_thickness": r.korkem_film_thickness_mm, "manufacturer": r.korkem_manufacturer,
			},
		)[:140]
		if title != r.item_name:
			frappe.db.set_value("Item", r.name, {"item_name": title, "description": title})


def archive(item: str) -> dict:
	"""Off the maker's list and the order's pick; history and metres stay."""
	return _set_archived(item, True)


def restore(item: str) -> dict:
	return _set_archived(item, False)


def _set_archived(item: str, archived: bool) -> dict:
	material_stock._ensure_editor()
	material_stock._own_item(item)
	if frappe.db.get_value("Item", item, "korkem_material_kind") != material_stock.FILM:
		frappe.throw("Это не плёнка.")
	values = {"korkem_film_archived": 1 if archived else 0}
	if not archived:
		values["disabled"] = 0  # one switched off the old way comes back too
	frappe.db.set_value("Item", item, values)
	audit.record_audit(
		action="film.archived" if archived else "film.restored", entity_type="Item", entity_id=item
	)
	return film(item)


def in_use(item: str) -> bool:
	"""Whether anything was ever done with the film: stock, or an order's name."""
	company = current_company()
	if frappe.db.exists("Stock Ledger Entry", {"item_code": item}):
		return True
	row = frappe.db.get_value("Item", item, ["korkem_manufacturer", "korkem_color"], as_dict=True)
	if row and row.korkem_manufacturer and row.korkem_color:
		name = label(row.korkem_manufacturer, row.korkem_color)
		for field in material_stock._ORDER_FIELDS[COLOURS]:
			for doctype in ("Sales Order Item", "Sales Order"):
				if frappe.db.has_column(doctype, field) and frappe.db.exists(doctype, {field: name}):
					return True
	return bool(frappe.db.exists("Stock Entry Detail", {"item_code": item}))


def delete(item: str) -> dict:
	"""Delete a film nothing was ever done with — one added by mistake.

	A film with receipts, sales or orders behind it is not deleted (the
	history and the stock would break): it goes to the archive.
	"""
	material_stock._ensure_editor()
	material_stock._own_item(item)
	if frappe.db.get_value("Item", item, "korkem_material_kind") != material_stock.FILM:
		frappe.throw("Это не плёнка.")
	if in_use(item):
		frappe.throw("По этой плёнке уже есть приходы, продажи или заказы — её можно только отправить в архив.")
	title, colour = frappe.db.get_value("Item", item, ["item_name", "korkem_color"])
	try:
		frappe.delete_doc("Item", item, ignore_permissions=True)
	except frappe.LinkExistsError:
		frappe.throw("По этой плёнке уже есть записи — её можно только отправить в архив.")
	audit.record_audit(action="film.deleted", entity_type="Item", entity_id=item, diff={"title": title})
	_drop_loose_colour(colour, current_company())
	return catalog()


#: What a change is called in the film's history, by the Item's field.
_NAMES = {
	"korkem_color": "название", "korkem_film_thickness_mm": "толщина", "korkem_film_width_mm": "ширина",
	"korkem_film_code": "код", "korkem_film_type": "поверхность", "korkem_film_collection": "коллекция",
	"korkem_film_ral": "RAL", "korkem_film_supplier": "поставщик", "korkem_film_price_m": "цена поставщика",
	"korkem_film_retail_m": "розница", "korkem_film_wholesale_m": "опт", "korkem_film_url": "ссылка",
}
_MONEY = ("korkem_film_price_m", "korkem_film_retail_m", "korkem_film_wholesale_m")


def changes(item: str) -> list[dict]:
	"""Who changed what on the film, and when — the newest first."""
	material_stock._ensure_staff()
	material_stock._own_item(item)
	from frappe.utils import get_fullname

	sees_money = price_visibility.can_see_prices()
	suppliers = {}
	out = []
	for e in frappe.get_all(
		"Domain Audit Event",
		filters={
			"entity_type": "Item", "entity_id": item,
			"action": ["in", ["film.changed", "film.archived", "film.restored", "stock.material_defined"]],
		},
		fields=["action", "actor", "creation", "diff_json", "reason"],
		order_by="creation desc",
		limit_page_length=200,
	):
		base = {"when": str(e.creation)[:16], "who": get_fullname(e.actor) or e.actor, "via": e.reason or None}
		if e.action != "film.changed":
			out.append({**base, "what": {
				"film.archived": "в архив", "film.restored": "из архива", "stock.material_defined": "добавлена",
			}[e.action], "before": None, "after": None})
			continue
		try:
			diff = json.loads(e.diff_json or "{}")
		except ValueError:
			continue
		for field, change in diff.items():
			if field not in _NAMES or (field in _MONEY and not sees_money):
				continue
			before, after = change.get("before"), change.get("after")
			if field in _MONEY:
				# An empty price is kept as 0: shown as «—», not as «0».
				before, after = (v if _same(v) else None for v in (before, after))
			if field == "korkem_film_supplier":
				for s in (before, after):
					if s and s not in suppliers:
						suppliers[s] = frappe.db.get_value("Supplier", s, "supplier_name") or s
				before, after = suppliers.get(before, before), suppliers.get(after, after)
			out.append({**base, "what": _NAMES[field], "before": _text(before), "after": _text(after)})
	return out


def _text(value) -> str | None:
	if value is None or value == "":
		return None
	if isinstance(value, float) and value == int(value):
		return str(int(value))
	return str(value)


def film(item: str) -> dict:
	company = current_company()
	row = frappe.db.get_value("Item", item, _FIELDS, as_dict=True)
	if not row:
		frappe.throw("Такой плёнки нет.", frappe.DoesNotExistError)
	return {
		**_film(
			row,
			material_stock._stock([item], company).get(item, (0.0, 0.0))[0],
			material_stock._reserved([item], company).get(item, 0.0),
		),
		"price_since": _price_since([item], company).get(item, {}),
	}


def _price_since(items: list[str], company: str) -> dict[str, dict]:
	"""Since when each price of a film stands, and where it came from — a
	receipt, a sale, or the card (owner, 11.11.2026: prices change).
	Nothing for one who does not see money."""
	if not items or not price_visibility.can_see_prices():
		return {}
	fields = {CARD[key]: key for key in PRICES}
	out: dict[str, dict] = {}
	for e in frappe.get_all(
		"Domain Audit Event",
		filters={
			"company": company, "entity_type": "Item", "action": "film.changed",
			"entity_id": ["in", items],
		},
		fields=["entity_id", "creation", "diff_json", "reason"],
		order_by="creation asc",
		limit_page_length=0,
	):
		try:
			diff = json.loads(e.diff_json or "{}")
		except ValueError:
			continue
		for field, key in fields.items():
			if field in diff:
				out.setdefault(e.entity_id, {})[key] = {"date": str(e.creation)[:10], "via": e.reason or None}
	return out


def _clean(key: str, value, company: str):
	if value is None or str(value).strip() == "":
		# A price column takes no emptiness: an empty price is kept as 0 and
		# read back as empty (11.11.2026: a card with no prices did not save).
		return 0.0 if key in PRICES else None
	if key in PRICES:
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


def _number(text) -> float | None:
	"""«0,3» is 0.3: the lists are written with a comma, and `flt` reads a
	comma as a thousands mark — the catalogue showed a 3 mm film (11.11.2026)."""
	try:
		return float(str(text or "").replace(" ", "").replace(",", ".")) or None
	except ValueError:
		return None


def _film(i, on_hand: float, held: float) -> dict:
	return {
		"item": i.name,
		"title": i.item_name,
		"maker": i.korkem_manufacturer or "",
		"colour": i.korkem_color or "",
		"label": label(i.korkem_manufacturer, i.korkem_color)
		if i.korkem_manufacturer and i.korkem_color else None,
		"width_mm": _number(i.korkem_film_width_mm),
		"thickness_mm": _number(i.korkem_film_thickness_mm),
		"textured": bool(i.korkem_film_textured),
		# A film in the archive is off the lists and the order's pick; one
		# switched off the old way (`disabled`) is in the archive too.
		"enabled": not i.disabled and not i.get("korkem_film_archived"),
		"archived": bool(i.disabled or i.get("korkem_film_archived")),
		"unit": i.stock_uom,
		"on_hand": flt(on_hand),
		"held": flt(held),
		"min_stock": flt(i.korkem_min_stock) or None,
		**{key: i.get(field) for key, field in CARD.items()},
		# Money: the shop floor sees metres, not what was paid (`price_visibility`).
		**{
			key: (flt(i.get(CARD[key])) or None) if price_visibility.can_see_prices() else None
			for key in PRICES
		},
	}
