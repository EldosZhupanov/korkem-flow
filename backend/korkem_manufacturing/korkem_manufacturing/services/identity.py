# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Classify the authenticated session into a business role.

This is a domain identity decision shared by every interface. AI-specific tool
policy imports and re-exports these names; the domain never imports the AI app.
"""

from __future__ import annotations

import frappe

ADMIN = "admin"
EMPLOYEE = "employee"
CUSTOMER = "customer"

ADMIN_ROLES = frozenset({"System Manager", "Korkem Admin"})

EMPLOYEE_ROLES = frozenset(
	{
		"Manufacturing User",
		"Manufacturing Manager",
		"Stock User",
		"Stock Manager",
		"Purchase User",
		"Purchase Manager",
		"Sales User",
		"Sales Manager",
		"Quality Manager",
	}
)

CHANNEL_ROLE_FLAG = "korkem_channel_role"


def _from_roles(user: str) -> str:
	"""This person's mode, from the roles on their User document."""
	if user in ("Administrator", "Guest"):
		return ADMIN if user == "Administrator" else CUSTOMER

	roles = set(frappe.get_roles(user))
	if roles & ADMIN_ROLES:
		return ADMIN
	if roles & EMPLOYEE_ROLES:
		return EMPLOYEE
	return CUSTOMER


def _narrowed(actual: str, channel_role: str | None) -> str:
	"""Apply a channel's pin, which may narrow and may never widen."""
	if not channel_role:
		return actual
	rank = {CUSTOMER: 0, EMPLOYEE: 1, ADMIN: 2}
	if rank.get(channel_role, 0) < rank.get(actual, 0):
		return channel_role
	return actual


def role_of(user: str | None = None) -> str:
	"""This person's mode, derived from server-owned identity data."""
	user = user or frappe.session.user
	actual = _from_roles(user)
	if user != frappe.session.user:
		return actual
	return _narrowed(actual, frappe.flags.get(CHANNEL_ROLE_FLAG))


def effective_role(user: str | None = None, channel_role: str | None = None) -> str:
	"""The role in force, after a channel identity has had its say."""
	return _narrowed(_from_roles(user or frappe.session.user), channel_role)
