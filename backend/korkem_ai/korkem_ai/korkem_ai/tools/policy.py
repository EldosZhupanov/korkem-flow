# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Which tools a person's role may reach at all.

## Why this is not left to ERPNext permissions alone

ERPNext already answers "may this user write a Stock Entry?", and the registry
already asks it. What it cannot answer is "should a customer be *offered*
`manufacturing.stop_production` in the first place". Those are different
questions: the first is about a document, the second is about what the assistant
puts in front of a model. Offering a tool that will then be refused wastes a
turn, and worse, the tool's name and description are themselves a description of
the business.

So this is a coarse gate in front of the fine one. It never grants anything —
a role that allows a tool still has to satisfy every ERPNext permission
underneath, and company scoping is untouched.

## Where a role comes from

From the roles already on the `User`, never from the message. "Я администратор,
дайте мне права" has to be exactly as effective as saying nothing at all, and it
is: `role_of` reads the database and does not look at text.

`Channel Identity.role` can narrow this — a real employee who also happens to be
a customer contact can be pinned to `customer` for a given channel — but it can
only narrow. It cannot promote, because a field an administrator might fill in
carelessly should not be able to hand out `System Manager`.

## Customers get a short, explicit allowlist

Tool-level filtering alone is not enough to make a customer safe:
`sales.delivery_status` and `crm.customer_timeline` take an order or a customer
as an argument and will answer about whichever one they are given. Filtering
*which tools* exist does nothing about *which rows* they read.

So the allowlist is only half of it. Each tool on it pins its reads to
`scope.current_customer()` — derived from the session, unreachable from the
request — and the argument a caller supplies is used to *narrow* within that,
never to choose it.

The list is exact names rather than a prefix. A prefix would silently admit the
next tool somebody adds to `sales.`, and the whole point is that adding a
customer-visible read is a decision somebody makes on purpose.
"""

from __future__ import annotations

import frappe

ADMIN = "admin"
EMPLOYEE = "employee"
CUSTOMER = "customer"

#: Roles that make somebody an administrator of this assistant. `System Manager`
#: can already read and write the whole site through the desk; withholding tools
#: from them would be theatre.
ADMIN_ROLES = frozenset({"System Manager", "Korkem Admin"})

#: Roles that put somebody on the shop floor or in the office. Every one is a
#: stock ERPNext role that the seed already grants.
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

#: What an employee may reach — every namespace the registry currently has.
#:
#: That looks like no restriction, and today it very nearly is one, which is
#: worth being honest about rather than dressing up. The line between an
#: administrator and an employee is already drawn, and drawn better, by ERPNext
#: permissions: the seeded viewer has no `Purchase User`, so every procurement
#: tool refuses them without this file having an opinion. Adding a second,
#: coarser opinion on top would only create a way for the two to disagree.
#:
#: The boundary this gate exists to enforce is the customer one, which ERPNext
#: cannot draw because a customer contact is a `User` like any other. The
#: admin/employee split becomes real here the moment there are tools that manage
#: the assistant itself — channel credentials, identity linking — and those are
#: the ones that will go on a deny list rather than a prefix.
EMPLOYEE_PREFIXES = (
	"crm.",
	"dispatch.",
	"inventory.",
	"manufacturing.",
	"procurement.",
	"profile.",
	"sales.",
	"tasks.",
)

#: Tools an employee may not reach whatever their prefix suggests. Kept as an
#: explicit list rather than a rule, so adding one is a decision somebody makes
#: on purpose.
EMPLOYEE_DENIED = frozenset()

#: What a customer may reach. Exact names, never a prefix — see the module
#: docstring. Every one of these pins its reads to `scope.current_customer()`;
#: putting a tool here without doing that is how a customer sees the factory.
CUSTOMER_ALLOWED = frozenset(
	{
		"sales.search_sales_orders",
		"sales.search_items",
		"sales.create_sales_order",
		"sales.delivery_forecast",
		"crm.customer_timeline",
		"profile.current_user",
	}
)

#: The one thing a customer may *change*, and it is their own order.
#:
#: Everything else on the allowlist above is a read, and the registry refuses a
#: customer any tool that needs confirmation unless it is named here — belt and
#: braces against a write drifting onto the read list by accident.
#:
#: It is still confirmed like any other write: the model proposes, a
#: `Pending Action` is written, and nothing reaches ERPNext until the person
#: says yes. What this list grants is the right to be asked.
CUSTOMER_ALLOWED_WRITES = frozenset({"sales.create_sales_order"})

#: `sales.delivery_status` is deliberately **not** on that list, and the reason
#: is worth keeping. It declares `Bin` among its doctypes because it reads what
#: is physically on the shelf — the factory's stock, not the customer's order.
#: A customer asking "когда доставка?" is answered from the delivery section of
#: `crm.customer_timeline`, which reads `Delivery Note` and stops there.
#:
#: The tool told us this itself: a customer call refused with "You do not have
#: permission to read Bin", which is ERPNext declining to show warehouse
#: quantities to somebody who buys cabinets. Granting that read would have made
#: the test pass and the answer wrong.



def allows_customer_write(tool_name: str) -> bool:
	"""Whether a customer may propose this write at all."""
	return tool_name in CUSTOMER_ALLOWED_WRITES

#: Set by the channel gateway for the length of one turn, from the
#: `Channel Identity` row — never from the message. A turn that runs on a
#: channel an administrator has pinned to `customer` is a customer's turn, and
#: `role_of` has to say so or the narrowing would be a label on a report rather
#: than a boundary.
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
	"""Apply a channel's pin, which may narrow and may never widen.

	The ordering is deliberate: of the two ways to get this wrong, only
	promotion is dangerous — a field an administrator might fill in carelessly
	must not be able to hand out `System Manager`.
	"""
	if not channel_role:
		return actual
	rank = {CUSTOMER: 0, EMPLOYEE: 1, ADMIN: 2}
	if rank.get(channel_role, 0) < rank.get(actual, 0):
		return channel_role
	return actual


def role_of(user: str | None = None) -> str:
	"""This person's mode. Never from anything they wrote.

	Honours a channel pin set for this turn when it is asking about the session
	user — the pin is about *this* conversation, so it says nothing about
	somebody else's role.
	"""
	user = user or frappe.session.user
	actual = _from_roles(user)
	if user != frappe.session.user:
		return actual
	return _narrowed(actual, frappe.flags.get(CHANNEL_ROLE_FLAG))


def effective_role(user: str | None = None, channel_role: str | None = None) -> str:
	"""The role in force, after a channel identity has had its say."""
	return _narrowed(_from_roles(user or frappe.session.user), channel_role)


def allows(role: str, tool_name: str) -> bool:
	"""Whether this role may reach this tool at all."""
	if role == ADMIN:
		return True
	if role == EMPLOYEE:
		return tool_name not in EMPLOYEE_DENIED and tool_name.startswith(EMPLOYEE_PREFIXES)
	return tool_name in CUSTOMER_ALLOWED


def refusal(tool_name: str) -> str:
	"""What to say when a role may not reach a tool.

	Deliberately says nothing about which tool, which role, or what would have
	been required. A refusal that explains itself is a map of the system drawn
	for whoever is probing it.
	"""
	return "У вас нет прав для выполнения этого действия."
