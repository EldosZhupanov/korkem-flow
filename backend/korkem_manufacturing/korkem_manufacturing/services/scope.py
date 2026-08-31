# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Which company and which customer a session may see.

Moved here from `korkem_ai/tools/scope.py` unchanged. It answers a question
about the *business* — who is this person allowed to see — and nothing about
it was ever specific to an assistant. Leaving it in the AI app meant a desktop
client or a shop-floor terminal could only get company scoping by importing the
orchestrator, which is the dependency this horizon exists to remove.

`korkem_ai/tools/scope.py` now re-exports these names, so every tool that has
not yet been migrated keeps working against the same single implementation
rather than a copy that can drift.

---

Original module docstring follows.

---

Which company the assistant is answering about.

## Why this exists

A Frappe bench holds many companies. This one holds twenty-three, twenty-two of
them ERPNext's own test fixtures, and the assistant's answers were clean only by
accident: the other companies' orders happen to be drafts, so a `docstatus = 1`
filter hid them. Submit one and «какие заказы просрочены» starts quietly
reporting another company's late orders to a KORKEM planner.

Role permissions do not help here. `Sales User` grants read on *Sales Order* —
the doctype, not one company's rows. Company isolation is a separate axis, and
on a bench without User Permissions configured it is not enforced at all.

## The company is the server's answer, never the caller's

`current_company()` is deliberately not a tool argument and never will be. A
model that could pass `company` could read any company on the bench simply by
naming it, and no amount of care in the tools downstream would narrow it again —
the same reasoning that keeps a generic `http_request` tool out of the registry.

Resolution order, most specific first:

1. **A Company User Permission on the user.** ERPNext's own way of binding
   somebody to one company, and the only one that also constrains `get_list`
   automatically.
2. **The user's default company**, set per user in Frappe's defaults.
3. **The site's default company**, from Global Defaults.

If none of those answers, the tools refuse rather than guess. "Which company?"
has no safe default on a multi-company site.
"""

from __future__ import annotations

import frappe


def current_company() -> str:
	"""The company this session works in, decided by the server."""
	allowed = frappe.get_all(
		"User Permission",
		filters={"user": frappe.session.user, "allow": "Company"},
		pluck="for_value",
	)
	if allowed:
		# More than one is a legitimate configuration; the user's own default
		# picks between them, and failing that the first is as good as any —
		# every one of them is a company they are entitled to see.
		preferred = frappe.defaults.get_user_default("Company")
		return preferred if preferred in allowed else sorted(allowed)[0]

	company = frappe.defaults.get_user_default("Company") or frappe.db.get_single_value(
		"Global Defaults", "default_company"
	)
	if not company:
		frappe.throw(
			"No company is configured for you, so there is nothing to report on. "
			"Ask an administrator to set your default company."
		)
	return company


def scoped(filters: dict | None = None) -> dict:
	"""Add the company filter to a query.

	Applied to every list of documents the assistant reads or writes. Doctypes
	without a company — `Item`, `Customer`, `Supplier`, `Operation` — are shared
	masters and are deliberately left alone; scoping them would hide a supplier
	that genuinely sells to two companies.
	"""
	return {**(filters or {}), "company": current_company()}


def belongs_to_company(doctype: str, name: str) -> bool:
	"""Whether one named document is this session's to look at.

	For the tools that fetch a document by name rather than by filter, where a
	list filter cannot do the work.
	"""
	company = frappe.db.get_value(doctype, name, "company")
	# A doctype with no company column is a shared master and is not scoped.
	return company is None or company == current_company()


def ensure_company(doctype: str, name: str) -> None:
	"""Refuse a document belonging to somebody else.

	Worded as "not found" on purpose. Confirming that
	`SAL-ORD-…` exists but belongs to another company is itself a disclosure —
	it tells the caller how another company's numbering runs and that a given
	document is real.
	"""
	if not belongs_to_company(doctype, name):
		frappe.throw(f"{doctype} {name} not found.")


class CustomerNotLinked(frappe.ValidationError):
	"""This session is a customer's, and nobody has said which customer."""


def current_customer() -> str:
	"""Which customer this session speaks for, decided by the server.

	Deliberately takes no argument and never will. A customer asking «покажи
	заказ SAL-ORD-…» must not be able to widen their own scope by naming
	something, and the only way to guarantee that is for the boundary to be
	unreachable from the request — the same reasoning that keeps `company` off
	every tool.

	The binding is ERPNext's own: a `Portal User` row on the customer, which is
	what `website_list_for_contact.get_parents_for_user` reads for the customer
	portal. Reusing it means an administrator who links somebody in the desk has
	linked them here too, and there is one place to look when the answer is
	wrong.

	A phone number is **not** an identity on its own. Numbers are reassigned and
	spoofed, and a channel identity says only "this handset wrote in" — so a
	matching phone with no `Portal User` behind it resolves to nothing at all.
	"""
	linked = frappe.get_all(
		"Portal User",
		filters={"user": frappe.session.user, "parenttype": "Customer"},
		pluck="parent",
	)
	if not linked:
		raise CustomerNotLinked(
			"Ваш аккаунт клиента ещё не связан с KORKEM. Обратитесь к администратору."
		)

	company = current_company()
	for name in sorted(linked):
		# A customer is a shared master and carries no company of its own, so
		# the question is whether they trade with this one — `Allowed To
		# Transact With` is ERPNext's own answer, and an empty list means "all",
		# which is its documented default rather than an oversight.
		allowed = frappe.get_all(
			"Allowed To Transact With", filters={"parent": name}, pluck="company"
		)
		if not allowed or company in allowed:
			return name

	# Linked, but to nobody this company trades with. Worded as absence: that a
	# customer exists elsewhere is not this caller's business.
	raise CustomerNotLinked(
		"Ваш аккаунт клиента ещё не связан с KORKEM. Обратитесь к администратору."
	)


def customer_scope() -> str | None:
	"""The customer every read must be pinned to, or None for staff.

	Returns `None` for anybody who is not a customer — staff scope is company
	scope and is applied elsewhere. For a customer it returns the one customer
	they are, and raises rather than returning `None` when nobody has linked
	them: a customer whose scope silently became "no filter" would be shown the
	factory.
	"""
	# KNOWN INVERSION, and the last one in this module.
	#
	# The domain must not depend on `korkem_ai` (ADR-0003, ADR-0007). This
	# import is lazy, so nothing here depends on the AI app at import time —
	# only a customer-scoped read reaches it at all. It survives the move
	# because `policy.role_of()` does two different jobs in one function:
	# classifying a *session* (a domain question) and deciding which *tools* to
	# offer a model (an AI question). Splitting it is its own change with its
	# own tests, and doing it inside a migration of `start_production` would
	# mean two behaviour changes in one reviewable step.
	#
	# `start_production` does not reach this path. Raised for the architectural
	# review before the next four actions, which do.
	from korkem_ai.korkem_ai.tools import policy

	if policy.role_of() != policy.CUSTOMER:
		return None
	return current_customer()


def pin_customer(requested: str | None = None) -> str | None:
	"""The customer a read must be filtered by.

	For staff this is whatever they asked for — their boundary is the company,
	applied elsewhere. For a customer it is *always* the one they are bound to,
	and anything they asked for is discarded rather than merged: a request is
	not evidence about who is making it.
	"""
	pinned = customer_scope()
	return pinned if pinned else requested


def owns_or_absent(doctype: str, name: str, field: str = "customer") -> None:
	"""Refuse a document that is not this customer's, as though it were missing.

	Worded as absence on purpose, and identically to a name that does not
	exist. "That order belongs to somebody else" confirms both that the order
	is real and that the customer is — which is worth nothing to the person
	asking and something to whoever is probing.
	"""
	pinned = customer_scope()
	if not pinned:
		return
	if frappe.db.get_value(doctype, name, field) != pinned:
		frappe.throw(f"Не удалось найти {name} среди ваших заказов.", frappe.DoesNotExistError)
