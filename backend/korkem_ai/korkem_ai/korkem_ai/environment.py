# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Which environment this site is, and what that forbids.

## Why a site needs to know

Everything built so far ran on one bench, in one mode, with one kind of data:
a developer's laptop holding a seeded factory that can be torn down and rebuilt
at will. A pilot is the same code against a real furniture business's real
ERPNext — the same orders their money is in.

The difference cannot be a convention. `seed_demo.remove()` deletes every Sales
Order belonging to the customers it knows about, cancelling submitted documents
on the way; run against a real site it would be indistinguishable from an
attack. So the site itself has to be able to answer "am I allowed to be torn
down", and the destructive fixtures have to *ask*.

## How the answer is decided

`korkem_env` in the site config — set by `bootstrap.sh` from the `KORKEM_ENV`
compose variable, so a container started with the pilot overlay says `pilot` and
one started for development says `development`.

When it is **not set**, the answer is inferred, and it is inferred pessimistically:

* `developer_mode` on  → `development`. A developer-mode site is by definition
  not somebody's business; Frappe itself treats the flag that way, and
  `seed_users` has refused to run without it since Sprint 1.
* `developer_mode` off → `production`. An unconfigured site that is *not* in
  developer mode is assumed to be real, so a missing setting fails closed. The
  cost of being wrong in this direction is an operator typing one bench command;
  the cost of the other direction is somebody's order history.

## What it does not do

It is not a permission system and grants nothing. `require_non_production` is a
*refusal*, and the only thing it protects against is a destructive fixture being
pointed at real data by mistake. Access control stays where it is: ERPNext
roles, User Permissions, and the customer binding in `customer_access`.
"""

from __future__ import annotations

import frappe

DEVELOPMENT = "development"
PILOT = "pilot"
PRODUCTION = "production"

#: Every value `korkem_env` may hold. An unrecognised one is not silently
#: mapped to something permissive — see `current()`.
ENVIRONMENTS = (DEVELOPMENT, PILOT, PRODUCTION)

#: The environments that hold somebody's real business.
PRODUCTION_LIKE = (PILOT, PRODUCTION)

#: The site config key. Set with:
#:     bench --site <site> set-config korkem_env pilot
CONFIG_KEY = "korkem_env"


def current() -> str:
	"""The environment this site is running as.

	An unrecognised value is treated as `production`: a typo in a deployment
	variable must not be the thing that lets a fixture delete real orders.
	"""
	configured = frappe.conf.get(CONFIG_KEY)
	if configured:
		configured = str(configured).strip().lower()
		return configured if configured in ENVIRONMENTS else PRODUCTION

	return DEVELOPMENT if frappe.conf.get("developer_mode") else PRODUCTION


def is_production_like() -> bool:
	"""True when this site holds real data and must not be reshaped by fixtures."""
	return current() in PRODUCTION_LIKE


def require_non_production(action: str) -> None:
	"""Refuse `action` on a pilot or production site.

	The message names the environment and the setting, because the operator who
	sees it is the one who has to decide whether they are on the wrong site or
	the site is labelled wrong — and those need different fixes.
	"""
	if not is_production_like():
		return

	frappe.throw(
		f"{action} rewrites or deletes data and is refused on a "
		f"'{current()}' site. If this site is not a pilot or production site, "
		f"correct `{CONFIG_KEY}` in its configuration.",
		title="Refused on a production-like site",
	)


def describe() -> dict:
	"""The environment as a health report states it — names only, no secrets.

	`developer_mode` and `allow_tests` are included because they are the two
	settings whose being *on* in a pilot is itself the finding. Nothing here is
	a credential, a host, or a path.
	"""
	return {
		"environment": current(),
		"configured": bool(frappe.conf.get(CONFIG_KEY)),
		"developer_mode": bool(frappe.conf.get("developer_mode")),
		"allow_tests": bool(frappe.conf.get("allow_tests")),
	}
