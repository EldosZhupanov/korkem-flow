# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Exactly-once execution for retried client commands.

A successful record is inserted before the business callback and completed
afterwards, inside the same savepoint and request transaction. A competing
INSERT for the same deterministic name waits on MariaDB's primary-key lock and
replays the winner's result after commit. Domain refusals returned as data are
stored exactly like successful results; raised exceptions roll the reservation
back with the failed action.
"""

from __future__ import annotations

import hashlib
import json
from collections.abc import Callable

import frappe

MAX_KEY_LENGTH = 200


def execute(
	action: str,
	idempotency_key: str | None,
	arguments: dict,
	callback: Callable[[], dict],
) -> dict:
	"""Run once per user, action and client key, or replay its stored result."""
	if idempotency_key is None:
		return callback()

	key = _validated_key(idempotency_key)
	user = frappe.session.user
	name = _record_name(user, action, key)
	fingerprint = _fingerprint(arguments)
	savepoint = "korkem_idempotency_" + frappe.generate_hash(length=8)
	frappe.db.savepoint(savepoint)

	record = frappe.get_doc(
		{
			"doctype": "Idempotency Record",
			"name": name,
			"request_user": user,
			"action": action,
			"request_fingerprint": fingerprint,
			"status": "In Progress",
		}
	)
	try:
		record.insert(ignore_permissions=True)
	except frappe.DuplicateEntryError:
		frappe.db.rollback(save_point=savepoint)
		return _replay(name, fingerprint)
	except frappe.QueryDeadlockError as exc:
		# When the winner commits while this INSERT waits, MariaDB raises CHECKREAD
		# (1020) rather than duplicate-key. Unlike a duplicate, CHECKREAD has
		# already rolled back the whole losing transaction, including its
		# savepoints, so start clean and read the winner. Do not turn real deadlocks
		# into replays: only 1020 has this meaning.
		if not _is_checkread(exc):
			raise
		frappe.db.rollback()
		return _replay(name, fingerprint)

	action_savepoint = "korkem_idempotent_action_" + frappe.generate_hash(length=8)
	frappe.db.savepoint(action_savepoint)
	try:
		result = callback()
		if not isinstance(result, dict):
			raise TypeError(f"Idempotent action {action} must return a dict.")
		frappe.db.release_savepoint(action_savepoint)
		record.status = "Completed"
		record.response_json = frappe.as_json(result, indent=None, separators=(",", ":"))
		record.save(ignore_permissions=True)
	except Exception:
		frappe.db.rollback(save_point=savepoint)
		raise

	frappe.db.release_savepoint(savepoint)
	return result


def _replay(name: str, fingerprint: str) -> dict:
	record = frappe.db.get_value(
		"Idempotency Record",
		name,
		["request_fingerprint", "status", "response_json"],
		as_dict=True,
		# Permission and company checks have already read in this transaction.
		# Under MariaDB REPEATABLE READ a normal SELECT could therefore keep an
		# older snapshot even after the duplicate INSERT waited for the winner's
		# commit. A locking read sees the latest committed row.
		for_update=True,
	)
	if not record:
		# The winner rolled back after our duplicate was reported. Let the client
		# retry instead of risking an unprotected second execution in this request.
		frappe.throw("The first attempt did not finish. Retry this command.")
	if record.request_fingerprint != fingerprint:
		frappe.throw(
			"This idempotency key was already used with different command data. "
			"Create a new key for a new command."
		)
	# There is deliberately no "replay the recorded failure" branch, and the
	# absence is the design. An action that raises rolls the reservation back
	# with itself, so a retry simply runs again — and fails the same way, which
	# is what idempotent means here. Recording the exception instead would need
	# a commit inside the action, and that commit would fix every other pending
	# write of the request too.
	#
	# A *refused* command is different: the domain returns it as data, it is
	# stored like any other response, and the replay below returns it verbatim.
	if record.status != "Completed" or not record.response_json:
		frappe.throw("This command is still being processed. Retry shortly.")
	return frappe.parse_json(record.response_json)


def _validated_key(value: str) -> str:
	if not isinstance(value, str) or not value.strip():
		frappe.throw("idempotency_key must be non-empty text when provided.")
	value = value.strip()
	if len(value) > MAX_KEY_LENGTH:
		frappe.throw(f"idempotency_key cannot exceed {MAX_KEY_LENGTH} characters.")
	return value


def _record_name(user: str, action: str, key: str) -> str:
	digest = hashlib.sha256(f"{user}\0{action}\0{key}".encode()).hexdigest()
	return f"idem-{digest}"


def _fingerprint(arguments: dict) -> str:
	payload = json.dumps(
		arguments,
		sort_keys=True,
		separators=(",", ":"),
		ensure_ascii=False,
		default=str,
	)
	return hashlib.sha256(payload.encode()).hexdigest()


def _is_checkread(exc: frappe.QueryDeadlockError) -> bool:
	underlying = exc.args[0] if exc.args else None
	return bool(getattr(underlying, "args", None) and underlying.args[0] == 1020)
