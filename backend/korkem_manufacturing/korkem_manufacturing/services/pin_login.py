# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Sign in on a shop-floor tablet with a PIN the administrator set.

**Why a PIN is only good on a registered tablet.** Four digits are ten
thousand guesses. On the open internet that is a password anyone can try; on
a tablet bolted to the wall of the shop, which the administrator registered and
can revoke, it is a convenience. So a PIN login requires the tablet's own token
(issued once, stored here only as a hash) *and* the person's PIN.

**What the administrator decides** (`ADMIN_ROLES`): who gets a PIN, what it
is, which tablets may use PINs, and taking either away. A "shared" PIN is just
a PIN on a shared account the administrator created — the rule is the same.

**What is refused on purpose.**
- A PIN for an administrator account: four digits must never open the account
  that can hand out PINs.
- Guessing: five wrong PINs lock that person for 15 minutes; thirty wrong
  attempts in an hour lock the tablet. Every attempt is audited.
- Saying which part was wrong. "Неверный PIN" whether the person has no PIN,
  is disabled, or typed the wrong digits.

PINs are stored through Frappe's password store (`__Auth`), hashed with the
same scheme as passwords — never in a field anybody can read.
"""

from __future__ import annotations

import hashlib
import re
import secrets
from datetime import timedelta

import frappe
from frappe.utils import cint, get_datetime, now_datetime
from frappe.utils.password import check_password, update_password

from korkem_manufacturing.services import audit
from korkem_manufacturing.services.identity import ADMIN_ROLES
from korkem_manufacturing.services.scope import current_company, ensure_user_in_company

PIN_DOCTYPE = "Korkem PIN"
DEVICE_DOCTYPE = "Korkem Kiosk Device"
PIN_PATTERN = re.compile(r"^\d{4,6}$")
MAX_USER_FAILURES = 5
USER_LOCK = timedelta(minutes=15)
MAX_DEVICE_FAILURES_PER_HOUR = 30
WRONG = "Неверный PIN."


class PinLocked(frappe.AuthenticationError):
	http_status_code = 429


# --------------------------------------------------------------------------
# What the administrator does
# --------------------------------------------------------------------------


def _ensure_admin() -> None:
	if not ADMIN_ROLES.intersection(frappe.get_roles()):
		frappe.throw("PIN-коды назначает администратор.", frappe.PermissionError)


def set_pin(user: str, pin: str) -> dict:
	_ensure_admin()
	company = current_company()
	user = (user or "").strip()
	pin = str(pin or "").strip()
	if not frappe.db.exists("User", user) or user in ("Administrator", "Guest"):
		frappe.throw("Сотрудник не найден.", frappe.DoesNotExistError)
	ensure_user_in_company(user, company)
	if ADMIN_ROLES.intersection(frappe.get_roles(user)):
		frappe.throw("Администратору PIN не назначается: четыре цифры не должны открывать его аккаунт.")
	if not PIN_PATTERN.match(pin):
		frappe.throw("PIN — от 4 до 6 цифр.")

	doc = frappe.get_doc(PIN_DOCTYPE, user) if frappe.db.exists(PIN_DOCTYPE, user) else frappe.new_doc(PIN_DOCTYPE)
	doc.update(
		{
			"user": user,
			"company": company,
			"failed_attempts": 0,
			"locked_until": None,
			"set_by": frappe.session.user,
			"set_on": now_datetime(),
		}
	)
	doc.flags.ignore_permissions = True
	doc.save()
	update_password(user, pin, doctype=PIN_DOCTYPE, fieldname="pin")
	audit.record_audit(action="auth.pin_set", entity_type="User", entity_id=user, diff={"by": frappe.session.user})
	return {"user": user, "status": "set"}


def clear_pin(user: str) -> dict:
	_ensure_admin()
	company = current_company()
	if frappe.db.get_value(PIN_DOCTYPE, user, "company") != company:
		frappe.throw("У этого сотрудника нет PIN.", frappe.DoesNotExistError)
	frappe.delete_doc(PIN_DOCTYPE, user, ignore_permissions=True, force=True)
	frappe.db.delete("__Auth", {"doctype": PIN_DOCTYPE, "name": user})
	audit.record_audit(action="auth.pin_cleared", entity_type="User", entity_id=user)
	return {"user": user, "status": "cleared"}


def people_with_pin() -> list[dict]:
	"""For the administrator's screen: who has a PIN and whether it is locked."""
	_ensure_admin()
	rows = frappe.get_all(
		PIN_DOCTYPE,
		filters={"company": current_company()},
		fields=["user", "locked_until", "set_on"],
		order_by="user asc",
	)
	names = _full_names([r.user for r in rows])
	return [
		{
			"user": r.user,
			"full_name": names.get(r.user, r.user),
			"locked": bool(r.locked_until and get_datetime(r.locked_until) > now_datetime()),
			"set_on": str(r.set_on) if r.set_on else None,
		}
		for r in rows
	]


def register_device(label: str) -> dict:
	"""Make this tablet a PIN tablet. The token is shown once, here, and never again."""
	_ensure_admin()
	label = (label or "").strip()[:80]
	if not label:
		frappe.throw("Назовите планшет, например «Цех, раскрой».")
	token = secrets.token_urlsafe(32)
	doc = frappe.get_doc(
		{
			"doctype": DEVICE_DOCTYPE,
			"label": label,
			"company": current_company(),
			"enabled": 1,
			"token_hash": _hash(token),
			"registered_by": frappe.session.user,
		}
	)
	doc.insert(ignore_permissions=True)
	audit.record_audit(action="auth.kiosk_registered", entity_type=DEVICE_DOCTYPE, entity_id=doc.name, diff={"label": label})
	return {"device": doc.name, "label": label, "device_token": token}


def revoke_device(device: str) -> dict:
	_ensure_admin()
	if frappe.db.get_value(DEVICE_DOCTYPE, device, "company") != current_company():
		frappe.throw("Планшет не найден.", frappe.DoesNotExistError)
	frappe.db.set_value(DEVICE_DOCTYPE, device, "enabled", 0)
	audit.record_audit(action="auth.kiosk_revoked", entity_type=DEVICE_DOCTYPE, entity_id=device)
	return {"device": device, "status": "revoked"}


def devices() -> list[dict]:
	_ensure_admin()
	return frappe.get_all(
		DEVICE_DOCTYPE,
		filters={"company": current_company()},
		fields=["name as device", "label", "enabled", "last_used"],
		order_by="creation desc",
	)


# --------------------------------------------------------------------------
# What the tablet does, before anybody is signed in
# --------------------------------------------------------------------------


def device_people(device_token: str) -> dict:
	"""Who may sign in on this tablet — names only, for the picker."""
	device = _device(device_token)
	rows = frappe.get_all(PIN_DOCTYPE, filters={"company": device.company}, pluck="user")
	active = frappe.get_all("User", filters={"name": ["in", rows], "enabled": 1}, fields=["name", "full_name"]) if rows else []
	return {
		"label": device.label,
		"people": sorted(
			({"user": u.name, "full_name": u.full_name or u.name} for u in active),
			key=lambda p: p["full_name"],
		),
	}


def login(device_token: str, user: str, pin: str) -> dict:
	"""Check the PIN and, if it is right, start a session for that person."""
	device = _device(device_token)
	_guard_device(device.name)

	record = frappe.db.get_value(
		PIN_DOCTYPE, {"name": user, "company": device.company}, ["name", "failed_attempts", "locked_until"], as_dict=True
	)
	enabled = record and frappe.db.get_value("User", user, "enabled")
	# Checked at every login, not only when the PIN was set: somebody given a
	# PIN as a cutter and promoted later must not open an administrator's
	# account with four digits. Refused exactly like a wrong PIN.
	if enabled and ADMIN_ROLES.intersection(frappe.get_roles(user)):
		enabled = False
	if record and record.locked_until and get_datetime(record.locked_until) > now_datetime():
		_audit_attempt(device, user, "locked")
		frappe.throw("Слишком много неверных попыток. Попробуйте через 15 минут.", PinLocked)

	ok = False
	if enabled:
		try:
			check_password(user, str(pin or ""), doctype=PIN_DOCTYPE, fieldname="pin", delete_tracker_cache=False)
			ok = True
		except frappe.AuthenticationError:
			ok = False

	if not ok:
		_count_device_failure(device.name)
		if record:
			failures = cint(record.failed_attempts) + 1
			values = {"failed_attempts": failures}
			if failures >= MAX_USER_FAILURES:
				values = {"failed_attempts": 0, "locked_until": now_datetime() + USER_LOCK}
			frappe.db.set_value(PIN_DOCTYPE, record.name, values, update_modified=False)
		_audit_attempt(device, user, "wrong")
		# Committed before the refusal: the request's transaction is rolled
		# back on the error below, and a rolled-back counter is no counter.
		# Not in the test runner, whose isolation is the rollback itself.
		if not frappe.flags.in_test:
			frappe.db.commit()  # nosemgrep
		frappe.throw(WRONG, frappe.AuthenticationError)

	frappe.db.set_value(PIN_DOCTYPE, record.name, {"failed_attempts": 0, "locked_until": None}, update_modified=False)
	frappe.db.set_value(DEVICE_DOCTYPE, device.name, "last_used", now_datetime(), update_modified=False)
	_audit_attempt(device, user, "ok")
	_start_session(user)
	return {"user": user, "status": "signed_in"}


# --------------------------------------------------------------------------


def _hash(token: str) -> str:
	return hashlib.sha256(token.encode()).hexdigest()


def _device(device_token: str):
	token = (device_token or "").strip()
	device = (
		frappe.db.get_value(
			DEVICE_DOCTYPE, {"token_hash": _hash(token), "enabled": 1}, ["name", "company", "label"], as_dict=True
		)
		if token
		else None
	)
	if not device:
		frappe.throw("Этот планшет не зарегистрирован для входа по PIN.", frappe.AuthenticationError)
	return device


def _device_key(device: str) -> str:
	return f"korkem_pin_failures::{device}"


def _guard_device(device: str) -> None:
	if cint(frappe.cache.get_value(_device_key(device))) >= MAX_DEVICE_FAILURES_PER_HOUR:
		frappe.throw("На этом планшете слишком много неверных попыток. Обратитесь к администратору.", PinLocked)


def _count_device_failure(device: str) -> None:
	key = _device_key(device)
	frappe.cache.set_value(key, cint(frappe.cache.get_value(key)) + 1, expires_in_sec=3600)


def _audit_attempt(device, user: str, outcome: str) -> None:
	audit.record_audit(
		action=f"auth.pin_login_{outcome}",
		entity_type=DEVICE_DOCTYPE,
		entity_id=device.name,
		company=device.company,
		actor=user if outcome == "ok" else "Guest",
		actor_role="Guest" if outcome != "ok" else None,
		channel="PIN",
		diff={"user": user, "device": device.label},
	)


def _start_session(user: str) -> None:
	"""A real Frappe session, the same one a password login creates."""
	if getattr(frappe.local, "request", None) and getattr(frappe.local, "login_manager", None):
		frappe.local.login_manager.login_as(user)
	else:
		# No HTTP request (tests, console): there is no cookie to set.
		frappe.set_user(user)


def _full_names(users: list[str]) -> dict[str, str]:
	if not users:
		return {}
	return {
		u.name: u.full_name or u.name
		for u in frappe.get_all("User", filters={"name": ["in", users]}, fields=["name", "full_name"])
	}
