# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""What a facade is made of, beyond its size: the technical line of the order.

The KORKEM brief asks every facade position to carry its thickness, the film
decor on top and underneath, the edge profile (R3, 90° …) and a colour group —
the label the shop sorts a batch by, so that all «Графит» pieces go through
the press together. None of it changes the price (`facade_quote` prices by
milling × finish); all of it is what the floor reads to make the piece.

**The lists are the warehouse's own.** A decor is a value of the «Цвет плёнки»
list and an edge profile one of «Профиль кромки» — the same lists the
administrator and managers keep in `material_stock`, where «+ новый декор» is
simply adding a value. One catalogue, not a second one for orders: the decor a
manager picks here is the film the warehouse receives and, later, writes off.

**A colour group defaults to the top decor** — the brief's automatic grouping —
and can be set by hand for any set of positions afterwards
(`set_color_group`), including on an order already submitted.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import audit, material_stock
from korkem_manufacturing.services.scope import ensure_company

DECOR = "Цвет плёнки"
EDGE = "Профиль кромки"
MIN_THICKNESS, MAX_THICKNESS = 3, 60
MAX_GROUP = 40

#: Sales Order Item field for each spec key.
FIELDS = {
	"thickness_mm": "korkem_thickness_mm",
	"decor_top": "korkem_decor_top",
	"decor_bottom": "korkem_decor_bottom",
	"edge_profile": "korkem_edge_profile",
	"color_group": "korkem_color_group",
}

#: Grouping is planning the floor, so it is open to whoever plans it.
MAY_GROUP = frozenset(
	{"System Manager", "Sales Manager", "Sales User", "Manufacturing Manager"}
)


def read(raw: dict, label: str, company: str) -> dict:
	"""The spec part of one quote line, checked against this company's lists.

	Every key is optional: a facade quoted before the decor is chosen is still
	a facade. What is given must be real — a decor or a profile nobody has put
	on the list is refused, not stored as typed.
	"""
	spec = {key: None for key in FIELDS}

	thickness = raw.get("thickness_mm")
	if thickness not in (None, ""):
		try:
			value = int(str(thickness).strip())
		except ValueError:
			frappe.throw(f"{label}: толщина — целое число миллиметров.")
		if not MIN_THICKNESS <= value <= MAX_THICKNESS:
			frappe.throw(f"{label}: толщина {value} мм — вне {MIN_THICKNESS}–{MAX_THICKNESS} мм.")
		spec["thickness_mm"] = value

	for key, kind, name in (
		("decor_top", DECOR, "декор лицевой стороны"),
		("decor_bottom", DECOR, "декор обратной стороны"),
		("edge_profile", EDGE, "профиль кромки"),
	):
		value = _text(raw.get(key))
		if value is None:
			continue
		if value not in _values(kind, company):
			frappe.throw(
				f"{label}: {name} «{value}» нет в списке «{kind}». Добавьте его на складе материалов."
			)
		spec[key] = value

	group = _text(raw.get("color_group"))
	if group and len(group) > MAX_GROUP:
		frappe.throw(f"{label}: цветовая группа — не длиннее {MAX_GROUP} знаков.")
	spec["color_group"] = group or spec["decor_top"]
	return spec


def as_fields(spec: dict) -> dict:
	"""Sales Order Item values for a spec read by `read`."""
	return {FIELDS[key]: value for key, value in spec.items()}


def set_color_group(lines: list[str] | str, group: str | None) -> dict:
	"""Put any set of facade positions in one colour group, or clear it.

	The brief's «выбрать позиции 11, 13, 16, 17 и назначить группу»: the
	positions need not be next to each other, and the order may already be in
	work.
	"""
	if not MAY_GROUP.intersection(frappe.get_roles()):
		frappe.throw("Цветовые группы назначают продажи или начальник производства.", frappe.PermissionError)
	if isinstance(lines, str):
		lines = frappe.parse_json(lines) if lines.strip().startswith("[") else [lines]
	if not lines or not isinstance(lines, list):
		frappe.throw("Выберите хотя бы одну позицию.")
	group = _text(group)
	if group and len(group) > MAX_GROUP:
		frappe.throw(f"Цветовая группа — не длиннее {MAX_GROUP} знаков.")

	rows = frappe.get_all(
		"Sales Order Item",
		filters={"name": ["in", list(lines)], "parenttype": "Sales Order", "korkem_width_mm": [">", 0]},
		fields=["name", "parent", "korkem_color_group"],
	)
	if len(rows) != len(set(lines)):
		frappe.throw("Часть позиций — не фасады или их нет.", frappe.DoesNotExistError)
	for parent in {row.parent for row in rows}:
		# Another company's order reads exactly like a missing one.
		ensure_company("Sales Order", parent)
		if frappe.db.get_value("Sales Order", parent, "docstatus") == 2:
			frappe.throw(f"Заказ {parent} отменён.")

	changed = [row for row in rows if (row.korkem_color_group or None) != group]
	for row in changed:
		frappe.db.set_value("Sales Order Item", row.name, "korkem_color_group", group)
	if changed:
		audit.record_audit(
			action="manufacturing.color_group",
			entity_type="Sales Order",
			entity_id=changed[0].parent,
			diff={"lines": [row.name for row in changed], "group": group},
		)
	return {"lines": [row.name for row in rows], "group": group, "changed": len(changed)}


def _values(kind: str, company: str) -> set[str]:
	return material_stock.enabled_values(kind, company)


def _text(value) -> str | None:
	if value is None:
		return None
	text = " ".join(str(value).split())
	return text or None
