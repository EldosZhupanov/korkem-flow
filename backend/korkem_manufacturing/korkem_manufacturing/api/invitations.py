# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""REST API endpoints for company invitations and team onboarding."""

from __future__ import annotations

import frappe
from korkem_manufacturing.services import invitations as service


@frappe.whitelist(allow_guest=True, methods=["GET", "POST"])
def get_info(token: str) -> dict:
	"""Public endpoint: Retrieve invitation information by secure token."""
	return service.get_invitation_info(token=token)


@frappe.whitelist(allow_guest=True, methods=["POST"])
def accept(
	token: str,
	phone: str,
	full_name: str,
	email: str = "",
	password: str = "",
) -> dict:
	"""Public endpoint: Accept invitation, bind user to company and role."""
	return service.accept_invitation(
		token=token,
		phone=phone,
		full_name=full_name,
		email=email,
		password=password,
	)


@frappe.whitelist(methods=["POST"])
def create(
	role_name: str,
	phone: str = "",
	max_uses: int = 1,
	expires_days: int = 7,
	company: str | None = None,
) -> dict:
	"""Create a new company invitation link."""
	return service.create_invitation(
		role_name=role_name,
		phone=phone,
		max_uses=max_uses,
		expires_days=expires_days,
		company=company,
	)


@frappe.whitelist(methods=["POST"])
def revoke(invitation_id: str) -> dict:
	"""Revoke an active invitation."""
	return service.revoke_invitation(invitation_id=invitation_id)


@frappe.whitelist(methods=["POST"])
def resend(invitation_id: str) -> dict:
	"""Regenerate token and sharing links for an invitation."""
	return service.resend_invitation(invitation_id=invitation_id)


@frappe.whitelist(methods=["POST"])
def change_role(invitation_id: str, new_role: str) -> dict:
	"""Change the intended role for an invitation."""
	return service.change_invitation_role(invitation_id=invitation_id, new_role=new_role)


@frappe.whitelist(methods=["GET"])
def list_all(company: str | None = None) -> list[dict]:
	"""List all invitations for the company."""
	return service.list_invitations(company=company)


@frappe.whitelist(allow_guest=True, methods=["GET"])
def canonical_roles() -> list[dict]:
	"""List all canonical KORKEM Flow roles with titles, descriptions, and landing routes."""
	return [
		{
			"key": key,
			"title_ru": val["title_ru"],
			"title_kz": val["title_kz"],
			"desc_ru": val["desc_ru"],
			"desc_kz": val["desc_kz"],
			"landing_route": val["landing_route"],
			"roles": list(val["roles"]),
		}
		for key, val in service.CANONICAL_ROLES.items()
	]


# Legacy endpoints for backwards compatibility
@frappe.whitelist(methods=["POST"])
def invite(email: str, position: str, first_name: str = "") -> dict:
	"""Legacy: Direct email invitation."""
	return service.invite_employee(
		email=email, first_name=first_name, position=position
	)


@frappe.whitelist(methods=["GET"])
def positions() -> list[dict]:
	"""Legacy: Positions list."""
	return [
		{"position": position, "roles": list(roles)}
		for position, roles in sorted(service.POSITIONS.items())
	]
