# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The facade price matrix: milling × finish, per m², per company.

**Who may change it:** the administrator and the people who take orders
(`EDITORS`). Prices are money, so nobody on the shop floor reads them either —
`Facade Price` grants them nothing at all.

**Starting prices** come from the factory's own price list, as given when this
feature was asked for (2026-10-26). They are written once per company and never
again: a price somebody edited is theirs, and a migration that "restores
defaults" over it would silently reprice every new order.

A missing cell is a real answer. Квадро and Тегіс have no rough («Черновая»)
price because the factory does not sell them that way; a quote for one is
refused rather than priced at something invented.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import flt

from korkem_manufacturing.services import audit
from korkem_manufacturing.services.scope import current_company

EDITORS = frozenset({"System Manager", "Sales Manager", "Sales User"})

PVC, ENAMEL, ROUGH = "ПВХ плёнка", "Эмаль", "Черновая"
FINISHES = (PVC, ENAMEL, ROUGH)

#: The «Покрытие» and «Фрезеровка» lists of `Material Option` — the owner's
#: own, edited from the order form (OnayBaza's dictionaries, 08.11.2026).
#: Nothing is written into them for him: «я сам заполню».
FINISH_LIST, MILLING_LIST = "Покрытие", "Фрезеровка"


def is_film(finish: str | None) -> bool:
	"""A film-pressed finish, whatever the owner calls it («ПВХ плёнка», «Пленка ПВХ»)."""
	name = (finish or "").lower()
	return "плён" in name or "плен" in name or "пвх" in name


def finishes(company: str | None = None) -> list[str]:
	"""The finishes a price can be set for: the starting three, then the «Покрытие» list."""
	company = company or current_company()
	own = frappe.get_all(
		"Material Option",
		filters={"company": company, "kind": FINISH_LIST, "enabled": 1},
		pluck="value",
		order_by="creation asc",
	)
	return list(dict.fromkeys([*FINISHES, *own]))


def millings(company: str | None = None) -> list[str]:
	"""The «Фрезеровка» list, then any milling that has a price and is not on it yet."""
	company = company or current_company()
	own = frappe.get_all(
		"Material Option",
		filters={"company": company, "kind": MILLING_LIST, "enabled": 1},
		fields=["value", "note"],
		order_by="creation asc",
	)
	# A variant («Рифлёный 16-14») is not a row of the matrix: it is priced
	# as its kind (owner, 12.11.2026).
	own = [o.value for o in own if not _parent(o.note)]
	listed = set(frappe.get_all(
		"Material Option", filters={"company": company, "kind": MILLING_LIST}, pluck="value"
	))
	priced = frappe.get_all(
		"Facade Price", filters={"company": company}, pluck="milling", distinct=True, order_by="milling asc"
	)
	return own + [m for m in priced if m not in listed]


#: ₸ per m², from the factory's price list.
STARTING_PRICES: dict[tuple[str, str], int] = {
	("Квадро", PVC): 21_000,
	("Квадро", ENAMEL): 35_000,
	("Классика", PVC): 19_500,
	("Классика", ENAMEL): 33_000,
	("Классика", ROUGH): 9_000,
	("Рифлёный", PVC): 19_500,
	("Рифлёный", ENAMEL): 32_000,
	("Рифлёный", ROUGH): 9_500,
	("Тегіс", PVC): 17_000,
	("Тегіс", ENAMEL): 29_000,
}


def seed_company(company: str) -> int:
	"""Write the starting prices a company does not have yet. Returns how many."""
	written = 0
	for (milling, finish), price in STARTING_PRICES.items():
		if frappe.db.exists("Facade Price", {"company": company, "milling": milling, "finish": finish}):
			continue
		doc = frappe.get_doc(
			{
				"doctype": "Facade Price",
				"company": company,
				"milling": milling,
				"finish": finish,
				"price_per_m2": price,
				"enabled": 1,
			}
		)
		doc.flags.korkem_seed = True
		doc.insert(ignore_permissions=True)
		written += 1
	return written


def seed_all_companies() -> None:
	for company in frappe.get_all("Company", pluck="name"):
		seed_company(company)


def on_company_created(doc, method=None) -> None:
	"""doc_events hook: a new company starts with the factory's price list."""
	seed_company(doc.name)


def can_edit(user: str | None = None) -> bool:
	return bool(EDITORS.intersection(frappe.get_roles(user)))


def ensure_editor() -> None:
	if not can_edit():
		frappe.throw("Цены фасадов видят администратор и менеджеры по заказам.", frappe.PermissionError)


def table() -> dict:
	"""The whole matrix for this company, for the settings screen."""
	ensure_editor()
	company = current_company()
	rows = frappe.get_all(
		"Facade Price",
		filters={"company": company},
		fields=["name", "milling", "finish", "price_per_m2", "enabled"],
		order_by="milling asc, finish asc",
	)
	return {
		"company": company,
		"finishes": finishes(company),
		"millings": millings(company),
		"variants": variants(company),
		"prices": [
			{
				"milling": row.milling,
				"finish": row.finish,
				"price_per_m2": flt(row.price_per_m2),
				"enabled": bool(row.enabled),
			}
			for row in rows
		],
		"can_edit": can_edit(),
	}


def set_price(milling: str, finish: str, price_per_m2, enabled: bool | int | str = True) -> dict:
	"""Change one cell, or add a new milling to the matrix."""
	ensure_editor()
	company = current_company()
	milling = (milling or "").strip()
	allowed = finishes(company)
	if finish not in allowed:
		frappe.throw(f"Покрытие должно быть одним из: {', '.join(allowed)}.")
	try:
		price = Decimal(str(price_per_m2))
	except Exception:
		frappe.throw("Цена должна быть числом.")
	enabled = bool(int(enabled)) if isinstance(enabled, str) else bool(enabled)

	name = frappe.db.get_value(
		"Facade Price", {"company": company, "milling": milling, "finish": finish}, "name"
	)
	doc = frappe.get_doc("Facade Price", name) if name else frappe.new_doc("Facade Price")
	before = {"price_per_m2": flt(doc.price_per_m2), "enabled": bool(doc.enabled)} if name else None
	doc.update(
		{
			"company": company,
			"milling": milling,
			"finish": finish,
			"price_per_m2": float(price),
			"enabled": 1 if enabled else 0,
		}
	)
	doc.save()

	audit.record_audit(
		action="settings.facade_price",
		entity_type="Facade Price",
		entity_id=doc.name,
		diff={"cell": f"{milling} / {finish}", "before": before, "after": {"price_per_m2": float(price), "enabled": enabled}},
	)
	return table()


def price_for(milling: str, finish: str, company: str | None = None) -> Decimal | None:
	"""₸ per m² for one cell, or None when the factory does not sell it.

	A variant of a milling with no price of its own is priced as its kind
	(owner, 12.11.2026: «Рифлёный 16-14» costs what «Рифлёный» costs)."""
	company = company or current_company()
	value = frappe.db.get_value(
		"Facade Price",
		{"company": company, "milling": milling, "finish": finish, "enabled": 1},
		"price_per_m2",
	)
	if not value:
		kind = kind_of(milling, company)
		if kind and kind != milling:
			value = frappe.db.get_value(
				"Facade Price",
				{"company": company, "milling": kind, "finish": finish, "enabled": 1},
				"price_per_m2",
			)
	return Decimal(str(value)) if value else None


# --------------------------------------------------------------------------
# A milling's variants (owner, 12.11.2026): «Рифлёный» — 16-14, 10-8, 20-10.
# A variant is an entry of the «Фрезеровка» list of its own, so the order
# form offers it as it is; its note names its kind.
# --------------------------------------------------------------------------

_PARENT = "вид:"


def _parent(note: str | None) -> str | None:
	note = (note or "").strip()
	if not note.startswith(_PARENT):
		return None
	return note[len(_PARENT):].strip() or None


def kind_of(milling: str | None, company: str | None = None) -> str | None:
	"""The kind a variant belongs to; None for a kind or an unknown name."""
	if not milling:
		return None
	note = frappe.db.get_value(
		"Material Option",
		{"company": company or current_company(), "kind": MILLING_LIST, "value": milling},
		"note",
	)
	return _parent(note)


def variants(company: str | None = None) -> dict[str, list[str]]:
	"""Kind by kind, its variants, oldest first."""
	out: dict[str, list[str]] = {}
	for o in frappe.get_all(
		"Material Option",
		filters={"company": company or current_company(), "kind": MILLING_LIST, "enabled": 1},
		fields=["value", "note"],
		order_by="creation asc",
	):
		kind = _parent(o.note)
		if kind:
			out.setdefault(kind, []).append(o.value)
	return out


def add_variant(kind: str, variant: str) -> dict:
	"""«16-14» under «Рифлёный»: the order form gets «Рифлёный 16-14»."""
	ensure_editor()
	company = current_company()
	kind = " ".join((kind or "").split())
	variant = " ".join((variant or "").split())
	if not kind or not variant:
		frappe.throw("Укажите вид фрезеровки и вариант.")
	if kind not in millings(company):
		frappe.throw("Такого вида фрезеровки нет.")
	value = variant if variant.casefold().startswith(kind.casefold()) else f"{kind} {variant}"
	name = frappe.db.get_value(
		"Material Option", {"company": company, "kind": MILLING_LIST, "value": value}, "name"
	)
	if name:
		frappe.db.set_value("Material Option", name, {"enabled": 1, "note": f"{_PARENT} {kind}"})
	else:
		frappe.get_doc({
			"doctype": "Material Option", "company": company, "kind": MILLING_LIST, "value": value,
			"enabled": 1, "note": f"{_PARENT} {kind}",
		}).insert(ignore_permissions=True)
	audit.record_audit(action="settings.milling_variant_added", entity_type="Material Option",
					   entity_id=value, diff={"kind": kind})
	return table()


def remove_variant(value: str) -> dict:
	"""Off the order form; orders that used it keep it."""
	ensure_editor()
	name = frappe.db.get_value(
		"Material Option", {"company": current_company(), "kind": MILLING_LIST, "value": value}, ["name", "note"],
		as_dict=True,
	)
	if not name or not _parent(name.note):
		frappe.throw("Такого варианта нет.", frappe.DoesNotExistError)
	frappe.db.set_value("Material Option", name.name, "enabled", 0)
	audit.record_audit(action="settings.milling_variant_removed", entity_type="Material Option", entity_id=value)
	return table()
