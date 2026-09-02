# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Invite the rest of a factory after its one owner has claimed the node.

The caller chooses a job, never Frappe roles.  The mapping below is server-owned
and uses stock ERPNext roles; accepting an arbitrary role list here would make
this endpoint a privilege editor and violate R5 by construction.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai import onboarding
from korkem_manufacturing.services.scope import current_company

POSITIONS = {
	"manager": ("Sales Manager",),
	"warehouse": ("Stock User",),
	"accountant": ("Accounts User",),
	"shop_floor": onboarding.DEFAULT_EMPLOYEE_ROLES,
}


def prevent_self_role_change(doc, method=None) -> None:
	"""R5 at the generic Frappe boundary, not only at our invitation API.

	Frappe lets a system user save parts of their own ``User`` document. That is
	useful for profile data, but on this version the same save can carry a changed
	roles child table. Compare against the stored document and refuse any self
	change to authorization; an owner editing somebody else's account is not a
	self-escalation and remains governed by Frappe's ordinary permissions.
	"""
	del method
	if doc.name != frappe.session.user or doc.name == "Administrator" or doc.is_new():
		return
	before = doc.get_doc_before_save()
	if not before:
		return
	old_roles = {row.role for row in before.get("roles") or []}
	new_roles = {row.role for row in doc.get("roles") or []}
	if new_roles != old_roles:
		frappe.throw(
			"You cannot change your own roles. Ask the factory owner.",
			frappe.PermissionError,
		)


def invite_employee(*, email: str, first_name: str = "", position: str) -> dict:
	"""Create one company-bound employee with the roles for ``position``.

	Only the owner may cross this boundary.  ``create_employee`` repeats the
	System Manager check as defence in depth, but it is not a substitute for a
	domain service deciding who may invite before it parses a job or an email.
	"""
	frappe.only_for("System Manager")

	position = (position or "").strip().lower()
	roles = POSITIONS.get(position)
	if not roles:
		frappe.throw(
			"Unknown position. Choose manager, warehouse, accountant or shop_floor."
		)

	company = current_company()
	result = onboarding.create_employee(
		email=email,
		first_name=first_name,
		roles=list(roles),
		company=company,
	)
	_audit(company, result["user"], position)
	return {**result, "position": position}


def _audit(company: str, invited: str, position: str) -> None:
	"""R9: who invited whom, to which company and job."""
	savepoint = "korkem_invitation_audit_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "Company",
				"reference_name": company,
				"content": (
					f"KORKEM: {frappe.session.user} пригласил {invited}; "
					f"должность {position}."
				),
			}
		).insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title="Could not record an employee invitation",
			message=frappe.get_traceback(with_context=True),
		)
