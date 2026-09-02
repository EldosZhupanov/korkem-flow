# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Role permissions the mobile app needs, as reproducible site state.

Two grants, both discovered by building screens against the real roles and
finding them empty:

* `Pending Action` was readable only by `System Manager`. A Sales Manager --
  the person who actually resolves an approval -- could not see one at all.
* `Work Order` was readable only by manufacturing and stock roles, so a
  salesperson could not answer "when does my kitchen ship" about their own deal.

Written as **Custom DocPerm**, via `frappe.permissions.add_permission`, and
never by saving the DocType: saving a DocType in developer mode exports its JSON
back into the app directory, which would edit vendored ERPNext source for what
is purely this site's policy. (Learned the hard way -- an earlier attempt did
exactly that and had to be reverted.)

This runs from both ``after_install`` and ``after_migrate``. Frappe marks every
patch as completed during a clean app install, so the historical entry in
``patches.txt`` is an upgrade path only; it never granted these permissions on
a new site. Running the same idempotent policy from lifecycle hooks covers both
shapes and repairs permission drift on the next migration.

One consequence worth knowing: once any Custom DocPerm exists for a doctype,
Frappe ignores that doctype's standard DocPerms entirely. `add_permission`
copies the existing rules across first, so nothing is lost today -- but a future
ERPNext release that changes Work Order's own permissions will no longer reach
this site.
"""

import frappe
from frappe.permissions import add_permission, update_permission_property

#: (doctype, role, {ptype: value}). Anything not listed stays at Frappe's
#: default for a new rule, which is read-only.
MOBILE_GRANTS = (
	(
		"Pending Action",
		"Sales Manager",
		# `write` is required: approve() and reject() save the document under
		# the caller's own permissions.
		{"read": 1, "write": 1, "create": 0, "delete": 0},
	),
	(
		"Work Order",
		"Sales User",
		# Read only, deliberately. Production state is changed on the shop
		# floor through task completion, never from a sales screen.
		{"read": 1, "write": 0, "create": 0, "delete": 0},
	),
	(
		"Work Order",
		"Sales Manager",
		{"read": 1, "write": 0, "create": 0, "delete": 0},
	),
)


def apply():
	"""Idempotent: safe to run on every migrate."""
	for doctype, role, perms in MOBILE_GRANTS:
		if not frappe.db.exists("DocType", doctype):
			# The app that owns it is not installed on this site.
			continue

		add_permission(doctype, role)
		for ptype, value in perms.items():
			update_permission_property(doctype, role, 0, ptype, value)

	frappe.clear_cache()


def notification_log_has_permission(doc, ptype: str, user: str | None = None, debug: bool = False) -> bool:
	"""A notification belongs to the person it was addressed to.

	Frappe already asserts this for lists — `frappe.hooks` registers
	`get_permission_query_conditions` for Notification Log — but registers no
	document-level check, and the `All` role has read. So the list hides
	another user's notification while a named GET hands it over, which is the
	worse of the two shapes: it looks safe from the outside.

	This restores the statement the list already makes. Administration stays
	global, because a system manager who cannot read a notification cannot
	diagnose why it never arrived.

	A controller check can only narrow what DocPerm already grants; it never
	grants anything by itself.
	"""
	del ptype, debug
	user = user or frappe.session.user
	if user == "Administrator" or "System Manager" in frappe.get_roles(user):
		return True
	return bool(doc.get("for_user")) and doc.get("for_user") == user
