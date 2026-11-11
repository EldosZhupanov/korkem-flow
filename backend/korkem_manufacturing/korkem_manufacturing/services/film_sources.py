# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Where film is bought: the sources of a maker (owner, 11.11.2026).

**A maker is a brand; a source is where we actually buy it.** Adilet is bought
from its Astana branch, from its Almaty branch and from a local wholesaler —
three telephones, three people, three prices. When one has no film the other
is rung, so each is a card of its own: city, person, telephones, how long it
takes, a note — and whose films it sells.

A source is ERPNext's own `Supplier` (the one a receipt names), so «откуда
пришла» on a receipt and in a film's history is the same record. A wholesaler
sells several makers; a maker is sold by several sources.

A maker's own card is short — a site and a note (`Material Option`) — and
lists its sources.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import audit, material_stock
from korkem_manufacturing.services.scope import current_company

MAKERS = "Производитель"

#: The card's fields, as the client names them.
CARD = {
	"kind": "korkem_src_kind",
	"city": "korkem_src_city",
	"contact": "korkem_src_contact",
	"phone": "korkem_src_phone",
	"phone2": "korkem_src_phone2",
	"whatsapp": "korkem_src_whatsapp",
	"address": "korkem_src_address",
	"lead": "korkem_src_lead",
	"min_order": "korkem_src_min_order",
	"note": "korkem_src_note",
}
_MAKERS_FIELD = "korkem_src_makers"
_FIELDS = ["name", "supplier_name", "disabled", _MAKERS_FIELD, *CARD.values()]


def sources() -> dict:
	"""Every source in use with its card; the makers to tick."""
	material_stock._ensure_staff()
	known = _known_makers()
	rows = frappe.get_all(
		"Supplier", filters={"disabled": 0}, fields=_FIELDS, order_by="supplier_name asc", limit_page_length=500
	)
	return {
		"sources": [_source(r, known) for r in rows],
		"makers": sorted(known, key=str.casefold),
		"can_edit": material_stock.can_edit(),
	}


def by_maker() -> dict[str, list[str]]:
	"""Maker → the sources that sell it. The caller has checked who may."""
	known = _known_makers()
	result: dict[str, list[str]] = {}
	for r in frappe.get_all(
		"Supplier", filters={"disabled": 0}, fields=["name", _MAKERS_FIELD], order_by="supplier_name asc",
		limit_page_length=500,
	):
		for maker in _split(r.get(_MAKERS_FIELD), known):
			result.setdefault(maker, []).append(r.name)
	return result


def add(name: str, **card) -> dict:
	"""A new source; one of the same name that was switched off comes back."""
	material_stock._ensure_editor()
	name = _name(name)
	material_stock.add_supplier(name)
	supplier = frappe.db.get_value("Supplier", {"supplier_name": name}, "name")
	return set_card(supplier, **card)


def set_card(supplier: str, **card) -> dict:
	"""Write a source's card. A field left out stays; an empty one is cleared."""
	material_stock._ensure_editor()
	if not frappe.db.exists("Supplier", supplier):
		frappe.throw("Такого поставщика нет.", frappe.DoesNotExistError)
	values = {}
	if "name" in card:
		name = _name(card["name"])
		other = frappe.db.get_value("Supplier", {"supplier_name": name}, "name")
		if other and other != supplier:
			frappe.throw(f"Поставщик «{name}» уже есть.")
		values["supplier_name"] = name
	for key, field in CARD.items():
		if key in card:
			limit = 500 if key == "note" else 140
			values[field] = " ".join(str(card[key] or "").split())[:limit] or None
	if "makers" in card:
		makers = card["makers"]
		if isinstance(makers, str):
			makers = frappe.parse_json(makers) if makers.strip().startswith("[") else makers.split("\n")
		known = _known_makers()
		picked = []
		for maker in makers or []:
			maker = " ".join(str(maker).split())
			if not maker or maker in picked:
				continue
			if maker not in known:
				frappe.throw(f"Производителя «{maker}» нет в справочнике «{MAKERS}».")
			picked.append(maker)
		values[_MAKERS_FIELD] = "\n".join(picked) or None
	if values:
		frappe.db.set_value("Supplier", supplier, values)
		audit.record_audit(action="film.source_set", entity_type="Supplier", entity_id=supplier, diff=values)
	return source(supplier)


def remove(supplier: str) -> dict:
	"""A source is never deleted — receipts name it; it is switched off."""
	material_stock.disable_supplier(supplier)
	return sources()


def source(supplier: str) -> dict:
	row = frappe.db.get_value("Supplier", supplier, _FIELDS, as_dict=True)
	if not row:
		frappe.throw("Такого поставщика нет.", frappe.DoesNotExistError)
	return _source(row, _known_makers())


def maker(name: str) -> dict:
	"""A maker's card: its site, a note, and where its film is bought."""
	material_stock._ensure_staff()
	row = _maker_row(name)
	known = _known_makers()
	rows = frappe.get_all(
		"Supplier", filters={"disabled": 0}, fields=_FIELDS, order_by="supplier_name asc", limit_page_length=500
	)
	return {
		"maker": row.value,
		"site": row.site or None,
		"note": row.note or None,
		"sources": [s for s in (_source(r, known) for r in rows) if row.value in s["makers"]],
		"can_edit": material_stock.can_edit(),
	}


def set_maker(name: str, site: str | None = None, note: str | None = None) -> dict:
	material_stock._ensure_editor()
	row = _maker_row(name)
	values = {
		"site": " ".join((site or "").split())[:140] or None,
		"note": " ".join((note or "").split())[:500] or None,
	}
	frappe.db.set_value("Material Option", row.name, values)
	audit.record_audit(action="film.maker_set", entity_type="Material Option", entity_id=row.name, diff=values)
	return maker(name)


def maker_renamed(before: str, after: str) -> None:
	"""A renamed maker keeps its sources (`mdf_dictionaries.rename`)."""
	for r in frappe.get_all(
		"Supplier", filters={_MAKERS_FIELD: ["like", f"%{before}%"]}, fields=["name", _MAKERS_FIELD],
		limit_page_length=500,
	):
		makers = [after if m == before else m for m in (r.get(_MAKERS_FIELD) or "").split("\n")]
		frappe.db.set_value("Supplier", r.name, _MAKERS_FIELD, "\n".join(makers))


def _known_makers() -> set[str]:
	return set(material_stock.enabled_values(MAKERS, current_company()))


def _maker_row(name: str):
	row = frappe.db.get_value(
		"Material Option", {"company": current_company(), "kind": MAKERS, "value": name, "enabled": 1},
		["name", "value", "site", "note"], as_dict=True,
	)
	if not row:
		frappe.throw(f"Производителя «{name or '—'}» нет в справочнике «{MAKERS}».", frappe.DoesNotExistError)
	return row


def _name(name: str | None) -> str:
	name = " ".join((name or "").split())[:140]
	if len(name) < 2:
		frappe.throw("Название поставщика слишком короткое.")
	return name


def _split(text: str | None, known: set[str]) -> list[str]:
	return [m for m in (text or "").split("\n") if m in known]


def _source(r, known: set[str]) -> dict:
	return {
		"supplier": r.name,
		"name": r.supplier_name or r.name,
		"makers": _split(r.get(_MAKERS_FIELD), known),
		**{key: r.get(field) or None for key, field in CARD.items()},
	}
