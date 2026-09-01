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

#: Monotonic version of the KORKEM-owned database schema understood by this
#: checkout. This is deliberately an explicit integer, not a hash or the last
#: line of patches.txt:
#:
#: * a hash can say "different", but cannot say which side is newer;
#: * patches may be consolidated or reordered after old installations have
#:   already recorded them in Patch Log;
#: * an explicit monotonic number keeps rollback ordering stable across those
#:   maintenance operations.
#:
#: Increment this in the same change that adds an incompatible schema/patch.
#: A successful migrate records it in site_config.json through the
#: ``after_migrate`` hook below.
SCHEMA_VERSION = 1
SCHEMA_CONFIG_KEY = "korkem_schema_version"
SCHEMA_DATABASE_KEY = "korkem_schema_version"


class SchemaCompatibilityError(frappe.ValidationError):
	"""The site's schema marker is unsafe for this checkout."""


def _parse_schema_version(raw, source: str) -> int:
	"""Parse one persisted marker without accepting ambiguous coercions."""
	if raw is None or raw == "":
		return 0
	if isinstance(raw, bool):
		raise SchemaCompatibilityError(
			f"KORKEM START REFUSED: the schema marker in {source} must be a "
			f"non-negative integer, got {raw!r}. Restore a valid marker before starting."
		)
	try:
		version = int(raw)
	except (TypeError, ValueError) as exc:
		raise SchemaCompatibilityError(
			f"KORKEM START REFUSED: the schema marker in {source} must be a "
			f"non-negative integer, got {raw!r}. Restore a valid marker before starting."
		) from exc
	if version < 0 or str(raw).strip() != str(version):
		raise SchemaCompatibilityError(
			f"KORKEM START REFUSED: the schema marker in {source} must be a "
			f"non-negative integer, got {raw!r}. Restore a valid marker before starting."
		)
	return version


def site_config_schema_version() -> int:
	"""Return the marker that follows the site directory and its backups."""
	return _parse_schema_version(frappe.conf.get(SCHEMA_CONFIG_KEY), "site config")


def database_schema_version() -> int:
	"""Return the marker that follows a restored database dump."""
	return _parse_schema_version(
		frappe.db.get_default(SCHEMA_DATABASE_KEY),
		"database defaults",
	)


def data_schema_version() -> int:
	"""Return the newest schema marker carried by either part of the site.

	Sites created before this guard have no marker. They are version zero: older
	than current code and therefore eligible for a normal migration. Malformed
	markers fail closed because guessing at production-data lineage is precisely
	what this guard exists to prevent. The marker is deliberately duplicated:
	the site-config copy survives a code rollback on the same volume, while the
	database copy follows a SQL backup even when an operator restores only the
	encryption key from the accompanying config backup.
	"""
	return max(site_config_schema_version(), database_schema_version())


def schema_compatibility() -> dict:
	"""Describe the ordering between site data and this checkout."""
	data_version = data_schema_version()
	if data_version > SCHEMA_VERSION:
		state = "data_newer"
	elif data_version < SCHEMA_VERSION:
		state = "data_older"
	else:
		state = "equal"
	return {"data": data_version, "code": SCHEMA_VERSION, "state": state}


def assert_schema_compatible() -> None:
	"""Refuse to run older code against data migrated by newer code.

	The refusal is intentionally identical in development, pilot and production.
	Developers routinely restore production snapshots and test rollbacks; letting
	development silently cross this boundary would make the one environment used
	to rehearse recovery less safe than the real deployment. There is no bypass
	environment variable.
	"""
	compatibility = schema_compatibility()
	data_version = compatibility["data"]
	code_version = compatibility["code"]
	site = getattr(frappe.local, "site", None) or "<site>"

	if compatibility["state"] == "data_newer":
		raise SchemaCompatibilityError(
			f"KORKEM START REFUSED: site data schema version is {data_version}, "
			f"but this code supports only version {code_version}. Deploy code that "
			f"supports schema version {data_version} or newer, then run "
			f"`bench --site {site} migrate`. Do not migrate these data with older code."
		)

	if compatibility["state"] == "data_older":
		print(
			f"KORKEM schema migration required: data={data_version}, code={code_version}. "
			f"Startup may continue; run `bench --site {site} migrate`."
		)
		return

	print(f"KORKEM schema compatible: data={data_version}, code={code_version}.")


def _write_migrated_schema_version() -> None:
	"""Persist the site-config marker after the migration transaction commits."""
	from frappe.installer import update_site_config

	update_site_config(SCHEMA_CONFIG_KEY, SCHEMA_VERSION)


def record_schema_version_after_migrate() -> None:
	"""Schedule the marker write from Frappe's ``after_migrate`` hook.

	The database marker is written inside the migration transaction, so rollback
	removes it. A direct site-config write there could survive even if a later
	hook failed, so ``after_commit`` advances the file marker only after every
	after-migrate hook and the database commit succeed.
	"""
	frappe.defaults.set_default(SCHEMA_DATABASE_KEY, SCHEMA_VERSION, "__default")
	frappe.db.after_commit.add(_write_migrated_schema_version)


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
