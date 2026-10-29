# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Trades on the shop floor, and who has which — several per person.

A **position** (`services/staff.py`) decides what a person may see and do; it
is a set of ERPNext roles and changing it is the owner's act. A **trade** says
what the person does at the factory — «Раскройщик», «Кромщик», «Сборщик» — and
one person often has several: in a small shop the cutter also edges the
panels. Trades give no rights, so they live apart from roles and can be named
by the company itself.

Until the company names its own, it is offered the usual list (`DEFAULTS`);
the first change stores it. A trade is switched off, never deleted: people
keep their history.

Who edits: the administrator and the production manager (`EDITORS`). Anyone
on the staff may read — a crew picker needs it.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import audit
from korkem_manufacturing.services.identity import is_staff
from korkem_manufacturing.services.scope import current_company

TRADE, MEMBER = "Shop Trade", "Shop Trade Member"
EDITORS = frozenset({"System Manager", "Manufacturing Manager"})
DEFAULTS = (
	"Раскройщик",
	"Кромщик",
	"Присадчик",
	"Оператор ЧПУ",
	"Маляр",
	"Сборщик",
	"Упаковщик",
	"Монтажник",
)
#: More than this per person is a mistake rather than a skill set.
MAX_PER_PERSON = 6


def _ensure_editor() -> None:
	if not EDITORS.intersection(frappe.get_roles()):
		frappe.throw("Профессии цеха задаёт администратор или начальник производства.", frappe.PermissionError)


def trades() -> dict:
	"""The company's trades and who has each. Defaults until it names its own."""
	if not is_staff():
		frappe.throw("Профессии видят сотрудники.", frappe.PermissionError)
	company = current_company()
	stored = frappe.get_all(
		TRADE, filters={"company": company}, fields=["name", "title", "enabled"], order_by="creation asc"
	)
	members: dict[str, list[str]] = {}
	for m in frappe.get_all(MEMBER, filters={"company": company}, fields=["user", "trade"]):
		members.setdefault(m.trade, []).append(m.user)
	if stored:
		rows = [
			{"trade": t.name, "title": t.title, "enabled": bool(t.enabled), "members": sorted(members.get(t.name, []))}
			for t in stored
		]
	else:
		rows = [{"trade": None, "title": title, "enabled": True, "members": []} for title in DEFAULTS]
	return {
		"trades": rows,
		"stored": bool(stored),
		"can_edit": bool(EDITORS.intersection(frappe.get_roles())),
	}


def add_trade(title: str) -> dict:
	_ensure_editor()
	company = _stored_company()
	title = " ".join((title or "").split())
	existing = frappe.db.get_value(TRADE, {"company": company, "title": title}, "name")
	if existing:
		frappe.db.set_value(TRADE, existing, "enabled", 1)
	else:
		doc = frappe.get_doc({"doctype": TRADE, "company": company, "title": title, "enabled": 1})
		doc.insert(ignore_permissions=True)
		existing = doc.name
	audit.record_audit(action="staff.trade_added", entity_type=TRADE, entity_id=existing, diff={"title": title})
	return trades()


def set_enabled(trade: str, enabled) -> dict:
	_ensure_editor()
	company = _stored_company()
	if frappe.db.get_value(TRADE, trade, "company") != company:
		frappe.throw("Такой профессии нет.", frappe.DoesNotExistError)
	enabled = bool(int(enabled)) if isinstance(enabled, str) else bool(enabled)
	frappe.db.set_value(TRADE, trade, "enabled", 1 if enabled else 0)
	audit.record_audit(action="staff.trade_enabled", entity_type=TRADE, entity_id=trade, diff={"enabled": enabled})
	return trades()


def set_member_trades(user: str, titles) -> dict:
	"""A person's trades, all at once: the list replaces what they had."""
	_ensure_editor()
	company = _stored_company()
	if isinstance(titles, str):
		titles = frappe.parse_json(titles) if titles.strip().startswith("[") else [titles]
	titles = list(dict.fromkeys(" ".join(str(t).split()) for t in (titles or []) if str(t).strip()))
	if len(titles) > MAX_PER_PERSON:
		frappe.throw(f"Не больше {MAX_PER_PERSON} профессий у одного человека.")
	if (
		not frappe.db.exists("User", {"name": user, "enabled": 1})
		or not is_staff(user)
		or not frappe.db.exists("User Permission", {"user": user, "allow": "Company", "for_value": company})
	):
		frappe.throw("Такого сотрудника нет.", frappe.DoesNotExistError)
	wanted = []
	for title in titles:
		trade = frappe.db.get_value(TRADE, {"company": company, "title": title, "enabled": 1}, "name")
		if not trade:
			frappe.throw(f"Профессии «{title}» нет. Сначала добавьте её.")
		wanted.append(trade)
	held = frappe.get_all(MEMBER, filters={"company": company, "user": user}, fields=["name", "trade"])
	before = sorted(m.trade for m in held)
	for m in held:
		if m.trade not in wanted:
			frappe.db.delete(MEMBER, {"name": m.name})
	for trade in wanted:
		if trade not in before:
			frappe.get_doc({"doctype": MEMBER, "company": company, "user": user, "trade": trade}).insert(
				ignore_permissions=True
			)
	audit.record_audit(
		action="staff.member_trades_set",
		entity_type="User",
		entity_id=user,
		diff={"before": before, "after": sorted(wanted)},
	)
	return {"user": user, "trades": titles}


def of_users(company: str | None = None) -> dict[str, list[str]]:
	"""Per person, the titles of their enabled trades — for the team list."""
	company = company or current_company()
	titles = {
		t.name: t.title
		for t in frappe.get_all(TRADE, filters={"company": company, "enabled": 1}, fields=["name", "title"])
	}
	result: dict[str, list[str]] = {}
	for m in frappe.get_all(MEMBER, filters={"company": company}, fields=["user", "trade"], order_by="creation asc"):
		if m.trade in titles:
			result.setdefault(m.user, []).append(titles[m.trade])
	return result


def _stored_company() -> str:
	"""The company, with its trades stored: the defaults become its own on the
	first change, so editing one never loses the others."""
	company = current_company()
	if not frappe.db.exists(TRADE, {"company": company}):
		for title in DEFAULTS:
			frappe.get_doc({"doctype": TRADE, "company": company, "title": title, "enabled": 1}).insert(
				ignore_permissions=True
			)
	return company
