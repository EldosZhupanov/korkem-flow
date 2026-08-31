# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Creating the three kinds of real person this system has.

## Why this exists, when Frappe already has a user form

It does, and an administrator is welcome to use it. What the desk form does not
do is make the *three decisions that are easy to get wrong* at the same time:

1. **Roles.** Every role here is a **stock ERPNext role**. Nothing custom is
   invented — with one exception that is not new, `Korkem Customer`, which
   exists because ERPNext's own `Customer` role is a website-portal role with no
   desk read at all (see `customer_access`).
2. **Company isolation.** A user with the right roles and no Company `User
   Permission` can read *every* company on the site. `scope.current_company()`
   reads that permission first, precisely because it is ERPNext's own mechanism
   — but only if somebody wrote it. Here it is written in the same call as the
   roles, so the two cannot come apart.
3. **Customer isolation.** A customer account is not "a user with fewer roles".
   It is a `Portal User` row, a role and a `User Permission`, all three, and
   `customer_access.link` is the one function that writes all three or none.

## No password is ever set here

Not one of these functions accepts, generates, or returns a password, and none
sends a welcome email — a pilot bench usually has no SMTP, so a welcome mail
would fail silently and the operator would think an account had been delivered.

The account is created **enabled and without a password**, which in Frappe means
it cannot be signed into until one is set. Setting it is a deliberate act by an
administrator in the desk (**User → Set New Password**), or Frappe's own
password-reset mail once SMTP is configured. That keeps credentials out of this
file, out of a return value, out of a log and out of git.

## Running it

Not whitelisted, deliberately: a public endpoint that creates privileged users
is a bigger surface than this needs. It runs from the bench, as an operator:

    bench --site <site> execute korkem_ai.korkem_ai.onboarding.create_owner \\
        --kwargs '{"email": "...", "first_name": "...", "company": "..."}'

    bench --site <site> execute korkem_ai.korkem_ai.onboarding.create_employee \\
        --kwargs '{"email": "...", "first_name": "...", "roles": ["Stock User"]}'

    bench --site <site> execute korkem_ai.korkem_ai.onboarding.create_customer_user \\
        --kwargs '{"email": "...", "first_name": "...", "customer": "..."}'

Every one of them is idempotent: re-running adds what is missing and changes
nothing that is already right.
"""

from __future__ import annotations

import frappe
from frappe.utils import validate_email_address

from korkem_ai.korkem_ai import customer_access

#: The person who runs the factory. `System Manager` is here because somebody
#: has to be able to administer the site; the rest are ERPNext's own manager
#: roles for the four departments this system touches.
OWNER_ROLES = (
	"System Manager",
	"Manufacturing Manager",
	"Stock Manager",
	"Sales Manager",
	"Purchase Manager",
)

#: What an employee gets when the caller does not say. The smallest set that
#: lets somebody on the shop floor see their work and report it done — the same
#: pair the dispatch tools were built and tested against.
DEFAULT_EMPLOYEE_ROLES = ("Manufacturing User", "Stock User")


def _company(company: str | None) -> str:
	"""The company to bind to, and a refusal rather than a guess.

	Falls back to the site default because a single-company pilot should not
	have to repeat itself; refuses when there is no default, because on a
	multi-company site picking one for the operator is how somebody ends up
	seeing another company's orders.
	"""
	company = company or frappe.db.get_single_value("Global Defaults", "default_company")
	if not company:
		frappe.throw(
			"No company was given and this site has no default company. "
			"Pass `company` explicitly."
		)
	if not frappe.db.exists("Company", company):
		frappe.throw(f"Company {company} does not exist on this site.")
	return company


def _require_roles(roles: tuple[str, ...] | list[str]) -> list[str]:
	"""Every role must already exist. A typo must not create a role."""
	missing = [role for role in roles if not frappe.db.exists("Role", role)]
	if missing:
		frappe.throw(
			f"These roles do not exist on this site: {', '.join(sorted(missing))}. "
			"They come from ERPNext; check the app is installed before onboarding."
		)
	return list(roles)


def _user(email: str, first_name: str, user_type: str) -> tuple[object, bool]:
	"""Create or fetch the account. Never sets a password, never mails."""
	email = (email or "").strip().lower()
	validate_email_address(email, throw=True)

	if frappe.db.exists("User", email):
		return frappe.get_doc("User", email), False

	user = frappe.get_doc(
		{
			"doctype": "User",
			"email": email,
			"first_name": (first_name or "").strip() or email.split("@")[0],
			"user_type": user_type,
			"enabled": 1,
			# No mail: a pilot bench usually has no SMTP, and an operator who
			# believes an invitation was sent will wait for it.
			"send_welcome_email": 0,
		}
	)
	user.insert(ignore_permissions=True)
	return user, True


def _grant_roles(user, roles: list[str]) -> list[str]:
	"""Add the roles that are missing. Existing ones are left alone.

	Roles are *added*, never reset — unlike the demo fixture, which resets them
	on purpose. A real account may have been widened deliberately by an
	administrator, and re-running onboarding must not quietly narrow it.
	"""
	held = {row.role for row in user.get("roles") or []}
	added = [role for role in roles if role not in held]
	for role in added:
		user.append("roles", {"role": role})
	if added:
		user.save(ignore_permissions=True)
	return added


def _bind_company(user_id: str, company: str) -> bool:
	"""ERPNext's own company binding — a `User Permission` on Company.

	This is what `scope.current_company()` reads first, and what makes
	`get_list` filter by company without any of our code being involved.
	"""
	if frappe.db.exists(
		"User Permission", {"user": user_id, "allow": "Company", "for_value": company}
	):
		return False

	frappe.get_doc(
		{
			"doctype": "User Permission",
			"user": user_id,
			"allow": "Company",
			"for_value": company,
			"apply_to_all_doctypes": 1,
		}
	).insert(ignore_permissions=True)
	return True


def _summary(user_id: str, company: str | None, created: bool, roles_added: list[str], **extra) -> dict:
	"""What the operator is told. Names and booleans; never a credential."""
	body = {
		"user": user_id,
		"company": company,
		"created": created,
		"roles_added": sorted(roles_added),
		"password_set": False,
		"next_step": (
			"Set a password for this account in the desk (User → Set New Password), "
			"or configure SMTP and use Frappe's password reset."
		),
	}
	body.update(extra)
	return body


def create_owner(email: str, first_name: str = "", company: str | None = None) -> dict:
	"""The person who runs the factory: full ERPNext management, one company."""
	frappe.only_for("System Manager")
	company = _company(company)
	roles = _require_roles(OWNER_ROLES)

	user, created = _user(email, first_name, "System User")
	added = _grant_roles(user, roles)
	bound = _bind_company(user.name, company)

	frappe.db.commit()
	return _summary(user.name, company, created, added, company_permission_added=bound)


def create_employee(
	email: str,
	first_name: str = "",
	roles: list[str] | None = None,
	company: str | None = None,
) -> dict:
	"""Somebody who works here: the roles you name, and one company.

	`roles` is explicit rather than a level, because "employee" is not one thing
	— a person on the saw and a person in purchasing need different ERPNext
	roles, and inventing a KORKEM name for each combination would be a second
	permission system.
	"""
	frappe.only_for("System Manager")
	company = _company(company)
	requested = _require_roles(list(roles) if roles else list(DEFAULT_EMPLOYEE_ROLES))

	if "System Manager" in requested:
		frappe.throw(
			"`System Manager` is not an employee role. Use `create_owner` if this "
			"person is meant to administer the site."
		)

	user, created = _user(email, first_name, "System User")
	added = _grant_roles(user, requested)
	bound = _bind_company(user.name, company)

	frappe.db.commit()
	return _summary(user.name, company, created, added, company_permission_added=bound)


def create_customer_user(
	email: str,
	customer: str,
	first_name: str = "",
) -> dict:
	"""A customer's own account: their orders and nobody else's.

	No company permission is written and none is wanted. A customer is scoped by
	`Customer`, which `customer_access.link` binds — and the customer's company
	is whichever company they bought from, which the order itself already says.

	The account is a **Website User**: no desk, no ERPNext screens, which is the
	same door the mobile app's customer role already comes through.
	"""
	frappe.only_for("System Manager")
	if not frappe.db.exists("Customer", customer):
		frappe.throw(f"Customer {customer} does not exist on this site.")

	user, created = _user(email, first_name, "Website User")
	# `link` writes the Portal User row, the role and the User Permission — all
	# three or none. Nothing here duplicates any of it.
	linked = customer_access.link(user.name, customer)

	frappe.db.commit()
	return _summary(
		user.name,
		None,
		created,
		[customer_access.ROLE] if linked["added"]["role"] else [],
		customer=customer,
		binding=linked["added"],
	)
