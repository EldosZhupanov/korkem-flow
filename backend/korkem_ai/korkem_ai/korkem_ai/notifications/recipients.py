# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Who is told, decided from documents rather than from roles or guesses.

## The rule

A recipient is a `User` that a *document* names: the person a job was given to,
the person who gave it, the person who started a work order, the portal users of
the customer whose order it is. Nothing here broadcasts to a role, and nothing
here reads a message.

That is a deliberate narrowing. "Tell the managers" sounds helpful and is the
first cross-company leak: on a bench with two companies, `Manufacturing Manager`
is held by people who have no business knowing this factory stopped a machine.
When a real "who is responsible for this line" model exists, it belongs in
ERPNext, and this module will read it.

## Customers are reached only through the canonical binding

`Portal User` on `Customer` — the same row `scope.current_customer()` resolves in
the other direction. A phone number that happens to match, a Telegram display
name, a customer named in a message: none of them is an identity, and none of
them can select a recipient here.
"""

from __future__ import annotations

import frappe


def staff_for_work_order(work_order: str) -> list[str]:
	"""Who is watching this job: whoever started it.

	`owner` is the person who ran `start_production`, which on this system is
	the foreman or the planner who did it — a real answer from a real document
	rather than a role broadcast.
	"""
	owner = frappe.db.get_value("Work Order", work_order, "owner")
	return [owner] if owner and owner not in ("Administrator", "Guest") else []


def staff_for_sales_order(sales_order: str) -> list[str]:
	"""Staff with a stake in this order: whoever raised it, plus anybody who was
	given an instruction about it.

	An order placed by a customer through the assistant is owned by that
	customer, so the owner is filtered to staff by the caller's own check — a
	customer is never a *staff* recipient of their own order's internal events.
	"""
	people = []
	owner = frappe.db.get_value("Sales Order", sales_order, "owner")
	if owner:
		people.append(owner)
	people += frappe.get_all(
		"Work Instruction",
		filters={"sales_order": sales_order},
		pluck="owner",
	)
	return [
		user
		for user in dict.fromkeys(people)
		if user and user not in ("Administrator", "Guest") and not is_customer(user)
	]


def customers_for_sales_order(sales_order: str) -> list[str]:
	"""The portal users of the customer this order belongs to. Nobody else.

	The binding is ERPNext's own `Portal User` row, which is what makes this
	safe: there is no path from a message, a phone number or a display name to
	this list.
	"""
	customer = frappe.db.get_value("Sales Order", sales_order, "customer")
	if not customer:
		return []
	return frappe.get_all(
		"Portal User", filters={"parent": customer, "parenttype": "Customer"}, pluck="user"
	)


def is_customer(user: str) -> bool:
	"""Whether this user is somebody's customer contact rather than staff."""
	from korkem_ai.korkem_ai.tools import policy

	return policy._from_roles(user) == policy.CUSTOMER


def company_of(doctype: str, name: str) -> str | None:
	return frappe.db.get_value(doctype, name, "company")
