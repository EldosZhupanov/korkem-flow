# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Letting a customer see their own orders, and only those.

## Why ERPNext's own `Customer` role was not enough

ERPNext gives a customer access through the **website portal**, which is guarded
by `has_website_permission` — a different door from the desk API these tools go
through. The stock `Customer` role therefore has no desk read on `Sales Order`
at all, and every customer-facing read refused with "You do not have permission
to read Sales Order".

Granting that read to the stock `Customer` role would have been the small diff
and the wrong one: it is held by users all over a site, and any of them without
a matching `User Permission` would have been handed every order on the bench.

## Two layers, and neither is decorative

So there is a role of our own, `Korkem Customer`, granted **only** by `link`
below — and `link` writes the `User Permission` in the same breath. The role
cannot exist on a user without the restriction that makes it safe, because one
function does both.

That gives:

1. **Frappe's own row filter.** A `User Permission` on `Customer` is applied by
   `get_list` and by document read checks without anything here being involved.
   This is the layer that holds even if our code is wrong.
2. **`scope.customer_scope()`**, which pins every customer read to
   `current_customer()`. This is the layer that holds even if the permission is
   misconfigured.

Either alone would be a single point of failure. The tests exercise both.

## The binding is ERPNext's

`Customer.portal_users` — the same `Portal User` table
`website_list_for_contact.get_parents_for_user` reads. An administrator who
links somebody in the desk has linked them here, and there is one place to look
when the answer is wrong. No identification by phone number, display name, or
anything a person can type.
"""

from __future__ import annotations

import frappe

ROLE = "Korkem Customer"

#: Read-only, and only what answering "where is my order" needs. `Customer` is
#: here because a `User Permission` on it is meaningless to a user who cannot
#: read the doctype at all.
READABLE = ("Customer", "Sales Order", "Delivery Note")


def ensure_role() -> str:
	"""Create the role and its read permissions. Safe to run twice."""
	if not frappe.db.exists("Role", ROLE):
		frappe.get_doc(
			{
				"doctype": "Role",
				"role_name": ROLE,
				"desk_access": 0,
				"is_custom": 1,
			}
		).insert(ignore_permissions=True)

	from frappe.permissions import add_permission

	for doctype in READABLE:
		if not frappe.db.get_value(
			"Custom DocPerm", {"parent": doctype, "role": ROLE, "permlevel": 0}
		):
			add_permission(doctype, ROLE, 0, "read")
	frappe.db.commit()
	return ROLE


def link(user: str, customer: str) -> dict:
	"""Bind a user to one customer, with everything that implies.

	Three things happen together and must never come apart: the `Portal User`
	row that says who they are, the role that lets them read anything at all,
	and the `User Permission` that restricts what "anything" means. A role
	without the permission is a user who can see every order on the site.

	Idempotent — running it twice adds nothing and changes nothing, because an
	administrator will run it twice.
	"""
	if not frappe.db.exists("Customer", customer):
		frappe.throw(f"Customer {customer} not found.")
	if not frappe.db.exists("User", user):
		frappe.throw(f"User {user} not found.")

	ensure_role()
	added = {"portal_user": False, "role": False, "user_permission": False}

	party = frappe.get_doc("Customer", customer)
	if not any(row.user == user for row in party.get("portal_users") or []):
		party.append("portal_users", {"user": user})
		party.save()
		added["portal_user"] = True

	account = frappe.get_doc("User", user)
	if ROLE not in {row.role for row in account.get("roles") or []}:
		account.append("roles", {"role": ROLE})
		account.save()
		added["role"] = True

	if not frappe.db.exists(
		"User Permission", {"user": user, "allow": "Customer", "for_value": customer}
	):
		frappe.get_doc(
			{
				"doctype": "User Permission",
				"user": user,
				"allow": "Customer",
				"for_value": customer,
				# Applies the restriction to every doctype with a Customer link
				# — Sales Order and Delivery Note among them — which is the
				# point. Narrowing it per doctype would mean remembering to add
				# each new one.
				"apply_to_all_doctypes": 1,
			}
		).insert()
		added["user_permission"] = True

	frappe.db.commit()
	return {"user": user, "customer": customer, "added": added}


def unlink(user: str, customer: str) -> dict:
	"""Take the binding away, all three parts of it.

	Leaving the role behind without the permission is the dangerous half, so
	the permission goes last: at no point is there a user who can read orders
	and is not restricted to one customer's.
	"""
	removed = {"portal_user": False, "role": False, "user_permission": False}

	party = frappe.get_doc("Customer", customer)
	rows = [row for row in party.get("portal_users") or [] if row.user != user]
	if len(rows) != len(party.get("portal_users") or []):
		party.set("portal_users", rows)
		party.save()
		removed["portal_user"] = True

	if not frappe.db.exists("Portal User", {"user": user, "parenttype": "Customer"}):
		account = frappe.get_doc("User", user)
		kept = [row for row in account.get("roles") or [] if row.role != ROLE]
		if len(kept) != len(account.get("roles") or []):
			account.set("roles", kept)
			account.save()
			removed["role"] = True

	for name in frappe.get_all(
		"User Permission",
		filters={"user": user, "allow": "Customer", "for_value": customer},
		pluck="name",
	):
		frappe.delete_doc("User Permission", name)
		removed["user_permission"] = True

	frappe.db.commit()
	return {"user": user, "customer": customer, "removed": removed}
