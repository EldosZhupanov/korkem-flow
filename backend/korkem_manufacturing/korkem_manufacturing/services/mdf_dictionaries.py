# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The MDF order form's dictionaries — OnayBaza's blue button beside each list.

Every drop-down of the order head has a list the owner keeps himself: add,
rename, delete, right from the form (08.11.2026: «надо добавить такие
функции, остальное я сам заполню»). Nothing is filled in for him.

They are `Material Option` lists, the same the warehouse already keeps, so a
film colour added here is the colour a roll of film is received under:

	thickness — «Толщина МДФ»     decor   — «Цвет плёнки» (face and back)
	finish    — «Покрытие»        patina  — «Патина»
	milling   — «Фрезеровка»      edge    — «Профиль кромки» (край фасада)
	material  — «Материал»        bank    — «Банк» (перевод, карта)

R0 and R3 on the edge list cannot be renamed or deleted: R3 is every
position's edge unless the manager picks another, R0 a sharp corner.

Two rules keep what is already written true:

* **Renaming** carries the new name to the prices (finish, milling) and to
  the materials in stock (colour, thickness, edge), so they keep matching.
  Orders keep the name they were written with — an order is a document.
* **Deleting** a value an order or a material already uses only switches it
  off (it leaves the drop-down, the records stay as written); an unused one is
  deleted. Its prices are switched off either way — prices are never deleted.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import audit, facade_prices, material_stock
from korkem_manufacturing.services.scope import current_company

#: МДФ, ЛМДФ, ХДФ — the board a position is made of; its thickness is a list
#: of its own since 09.11.2026 (an older «16 мм МДФ» still reads as 16 mm).
MATERIAL = "Материал"
#: The edges no one may rename or delete (`mdf_orders.STANDARD_EDGES`).
LOCKED = {"edge": ("R0", "R3")}

KINDS: dict[str, str] = {
	"material": MATERIAL,
	"thickness": "Толщина МДФ",
	"finish": facade_prices.FINISH_LIST,
	"decor": "Цвет плёнки",
	"patina": "Патина",
	"milling": facade_prices.MILLING_LIST,
	"edge": "Профиль кромки",
	"bank": "Банк",
	# RAL 9010, NCS S 3040-Y60R, MPC 9010 — a paint group's colours, apart from
	# the films (owner, 09.11.2026: «не будут смешиваться краски и плёнки»).
	"paint": "Краска",
	# A film's maker and its type, each a list the owner keeps (10.11.2026):
	# KIRA, JS Group, МС-Груп …; матовая, софт, древесная …
	"maker": "Производитель",
	"film_type": "Тип плёнки",
}

#: Where a renamed value is carried: the price matrix, and the stock's materials.
_PRICE_FIELD = {"finish": "finish", "milling": "milling"}

MAX_LENGTH = 140


def _kind(key: str) -> str:
	if key not in KINDS:
		frappe.throw(f"Справочник — один из: {', '.join(KINDS)}.")
	return KINDS[key]


def _clean(value: str | None) -> str:
	value = " ".join((value or "").split())
	if not value:
		frappe.throw("Введите значение.")
	if len(value) > MAX_LENGTH:
		frappe.throw(f"Не длиннее {MAX_LENGTH} символов.")
	return value


def _row(key: str, option: str):
	row = frappe.db.get_value("Material Option", option, ["name", "company", "kind", "value", "enabled"],
							  as_dict=True)
	if not row or row.company != current_company() or row.kind != _kind(key):
		frappe.throw("Такого значения нет.", frappe.DoesNotExistError)
	return row


def _unlocked(key: str, value: str) -> None:
	if value in LOCKED.get(key, ()):
		frappe.throw(f"«{value}» — постоянное значение, его нельзя менять или удалять.")


def dictionaries() -> dict:
	"""Every list, its switched-on values in the order they were added."""
	facade_prices.ensure_editor()
	company = current_company()
	rows = frappe.get_all(
		"Material Option",
		filters={"company": company, "kind": ["in", list(KINDS.values())], "enabled": 1},
		fields=["name", "kind", "value"],
		order_by="creation asc",
		limit_page_length=0,
	)
	by_kind = {kind: [] for kind in KINDS.values()}
	for r in rows:
		by_kind[r.kind].append({"id": r.name, "value": r.value})
	return {key: by_kind[kind] for key, kind in KINDS.items()}


def add(key: str, value: str) -> dict:
	facade_prices.ensure_editor()
	kind = _kind(key)
	value = _clean(value)
	material_stock.put_option(kind, value)  # adding back a switched-off value switches it on
	return dictionaries()


def rename(key: str, option: str, value: str) -> dict:
	facade_prices.ensure_editor()
	kind = _kind(key)
	row = _row(key, option)
	_unlocked(key, row.value)
	value = _clean(value)
	if value == row.value:
		return dictionaries()
	# The database compares names without case, so «KASPI» → «Kaspi» finds the
	# row itself: only another row is a duplicate (owner, 11.11.2026).
	twins = frappe.get_all(
		"Material Option", filters={"company": row.company, "kind": kind, "value": value}, pluck="name"
	)
	if any(name != option for name in twins):
		frappe.throw(f"«{value}» уже есть в этом списке.")

	frappe.db.set_value("Material Option", option, "value", value)
	field = _PRICE_FIELD.get(key)
	if field:
		for name in frappe.get_all("Facade Price", filters={"company": row.company, field: row.value}, pluck="name"):
			frappe.db.set_value("Facade Price", name, field, value)
	item_field = material_stock._ITEM_FIELD.get(kind)
	if item_field:
		for name in frappe.get_all("Item", filters={"korkem_material_company": row.company, item_field: row.value},
								   pluck="name"):
			frappe.db.set_value("Item", name, item_field, value)
	if key == "maker":
		from korkem_manufacturing.services import film_sources

		film_sources.maker_renamed(row.value, value)
		from korkem_manufacturing.services import film_catalog

		film_catalog.maker_renamed(row.value, value)
	audit.record_audit(action="mdf.dictionary_renamed", entity_type="Material Option", entity_id=option,
					   diff={"list": kind, "before": row.value, "after": value})
	return dictionaries()


def remove(key: str, option: str) -> dict:
	facade_prices.ensure_editor()
	row = _row(key, option)
	_unlocked(key, row.value)
	outcome = material_stock.drop_option(option)
	field = _PRICE_FIELD.get(key)
	if field:
		# A price is never deleted (`Facade Price.on_trash`: old orders show what
		# they were priced at); it is switched off with the value.
		for name in frappe.get_all("Facade Price", filters={"company": row.company, field: row.value, "enabled": 1},
								   pluck="name"):
			frappe.db.set_value("Facade Price", name, "enabled", 0)
	return {**dictionaries(), "outcome": outcome}
