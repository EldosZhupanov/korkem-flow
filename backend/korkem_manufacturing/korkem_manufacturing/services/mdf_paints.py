# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Paints by colour system (owner, 15.11.2026: «краска тоже должна делиться
на группы»).

A customer picks a colour from a catalogue, and the catalogue is the group:

	RAL Classic — four digits, 216 colours: RAL 9010, RAL 7016
	RAL Design  — seven digits, 1 825 colours
	RAL Effect  — «110-1», «110-M»: 490 colours, 70 of them metallic
	NCS         — the Swedish system designers like: NCS S 0502-Y
	По образцу  — matched to a sample the customer brought

The systems are a list of their own («Система цвета») the owner keeps like
any other; a colour on the «Краска» list names its system in its note
(«система: RAL Classic»). A colour with none stands apart, as before.

A company starts with the five systems and the colours a furniture shop
paints most — whites, greys, black — so the list is not empty on day one;
colours already on it are filed under their system by their number. That is
done once: a system the owner deleted is not put back.
"""

from __future__ import annotations

import re

import frappe

from korkem_manufacturing.services import audit
from korkem_manufacturing.services.scope import current_company

PAINT_LIST = "Краска"
SYSTEM_LIST = "Система цвета"
_SYSTEM = "система:"

RAL_CLASSIC, RAL_DESIGN, RAL_EFFECT, NCS, SAMPLE = "RAL Classic", "RAL Design", "RAL Effect", "NCS", "По образцу"
STARTING_SYSTEMS = (RAL_CLASSIC, RAL_DESIGN, RAL_EFFECT, NCS, SAMPLE)
#: What a furniture shop paints most (owner asked for the popular ones).
STARTING_PAINTS = (
	"RAL 9010 Чисто-белый",
	"RAL 9016 Транспортный белый",
	"RAL 9003 Сигнальный белый",
	"RAL 9001 Кремово-белый",
	"RAL 1013 Жемчужно-белый",
	"RAL 1015 Светлая слоновая кость",
	"RAL 7035 Светло-серый",
	"RAL 7024 Графитовый серый",
	"RAL 7016 Антрацитово-серый",
	"RAL 9005 Чёрный янтарь",
)

#: A colour's system by how its number is written.
_BY_NUMBER = (
	(re.compile(r"^RAL\s*\d{3}\s*\d{2}\s*\d{2}\b", re.I), RAL_DESIGN),
	(re.compile(r"^RAL\s*\d{3}-[\dM]\b", re.I), RAL_EFFECT),
	(re.compile(r"^RAL\s*\d{4}\b", re.I), RAL_CLASSIC),
	(re.compile(r"^NCS\b", re.I), NCS),
)


def system_of(note: str | None) -> str | None:
	"""The system a paint's note names; None for a colour that has none."""
	note = (note or "").strip()
	if not note.startswith(_SYSTEM):
		return None
	return note[len(_SYSTEM):].strip() or None


def guess_system(value: str) -> str | None:
	"""RAL 9010 → RAL Classic, RAL 110-1 → RAL Effect, NCS S … → NCS."""
	for pattern, system in _BY_NUMBER:
		if pattern.match(value.strip()):
			return system
	return None


def _systems(company: str) -> list[str]:
	return frappe.get_all("Material Option", filters={"company": company, "kind": SYSTEM_LIST, "enabled": 1},
						  pluck="value", order_by="creation asc")


def _named(value: str, system: str) -> str:
	"""«9010» under RAL Classic is «RAL 9010»; «S 0502-Y» under NCS, «NCS S 0502-Y»."""
	if system.upper().startswith("RAL") and not value.upper().startswith("RAL"):
		return f"RAL {value}"
	if system.upper() == NCS and not value.upper().startswith(NCS):
		return f"{NCS} {value}"
	return value


def _put(company: str, value: str, system: str | None) -> str:
	note = f"{_SYSTEM} {system}" if system else None
	name = frappe.db.get_value("Material Option", {"company": company, "kind": PAINT_LIST, "value": value}, "name")
	if name:
		frappe.db.set_value("Material Option", name, {"enabled": 1, "note": note})
	else:
		name = frappe.get_doc({
			"doctype": "Material Option", "company": company, "kind": PAINT_LIST, "value": value,
			"enabled": 1, "note": note,
		}).insert(ignore_permissions=True).name
	return value


def add_paint(value: str, system: str) -> str:
	"""A colour under its system. The caller has checked who may."""
	company = current_company()
	if system not in _systems(company):
		frappe.throw("Такой системы цвета нет.")
	value = _named(value, system)
	_put(company, value, system)
	audit.record_audit(action="mdf.paint_added", entity_type="Material Option", entity_id=value,
					   diff={"system": system})
	return value


def paints_of(company: str, system: str) -> list[str]:
	return [
		o.name for o in frappe.get_all("Material Option", filters={"company": company, "kind": PAINT_LIST},
									   fields=["name", "note"])
		if system_of(o.note) == system
	]


def system_renamed(company: str, before: str, after: str) -> None:
	"""Its colours are filed under the new name."""
	for name in paints_of(company, before):
		frappe.db.set_value("Material Option", name, "note", f"{_SYSTEM} {after}")


def system_removed(company: str, system: str) -> None:
	"""Its colours stay on the list, filed under no system."""
	for name in paints_of(company, system):
		frappe.db.set_value("Material Option", name, "note", None)


def seed_company(company: str) -> None:
	"""The five systems, the popular colours, and the colours already kept
	filed by their number — once: a company that has ever had a system is
	left as its owner made it."""
	if frappe.db.exists("Material Option", {"company": company, "kind": SYSTEM_LIST}):
		return
	for system in STARTING_SYSTEMS:
		frappe.get_doc({
			"doctype": "Material Option", "company": company, "kind": SYSTEM_LIST, "value": system, "enabled": 1,
		}).insert(ignore_permissions=True)
	kept = frappe.get_all("Material Option", filters={"company": company, "kind": PAINT_LIST},
						  fields=["name", "value", "note"])
	for o in kept:
		if not system_of(o.note) and (system := guess_system(o.value)):
			frappe.db.set_value("Material Option", o.name, "note", f"{_SYSTEM} {system}")
	numbers = {_number(o.value) for o in kept}
	for value in STARTING_PAINTS:
		if _number(value) not in numbers:
			_put(company, value, guess_system(value))


def _number(value: str) -> str:
	"""«RAL 9010 Чисто-белый» and «RAL 9010» are the same colour."""
	m = re.match(r"^(RAL\s*[\d\-M ]+?|NCS\s*\S+(?:\s\S+)?)(?:\s+[^\d\s].*)?$", value.strip(), re.I)
	return re.sub(r"\s+", "", (m.group(1) if m else value)).casefold()


def seed_all_companies() -> None:
	for company in frappe.get_all("Company", pluck="name"):
		seed_company(company)


def on_company_created(doc, method=None) -> None:
	"""doc_events hook: a new company starts with the colour systems."""
	seed_company(doc.name)
