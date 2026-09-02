# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The endpoint the shop-floor button talks to.

Thin on purpose: it validates shapes and hands everything to the domain
service, which is where the rule lives that a capture is recorded before it is
understood. See `services/capture.py` for why this exists at all.
"""

from __future__ import annotations

import json

import frappe

from korkem_manufacturing.services import capture as service


@frappe.whitelist(methods=["POST"])
def record(
	text: str,
	spoken_at: str | None = None,
	source: str = "Voice",
	understood: str | dict | None = None,
	assign_to: str | None = None,
	due_on: str | None = None,
) -> dict:
	"""Record one utterance and, if asked, hand its follow-up to somebody.

	`understood` arrives as JSON from a client that had a model available, and
	as nothing from one that did not. Both are ordinary: the sentence is stored
	either way.
	"""
	return service.record(
		text=text,
		spoken_at=spoken_at,
		source=source,
		understood=_as_dict(understood),
		assign_to=assign_to,
		due_on=due_on,
	)


@frappe.whitelist(methods=["GET"])
def stats(days: int = 30) -> dict:
	"""How much was caught, handed over, converted — and how much went stale.

	This is the endpoint behind the claim the owner asked us to prove: that he
	does not need to hire an administrator. It answers with counts rather than
	argument.
	"""
	return service.stats(days=int(days or 30))


def _as_dict(value: str | dict | None) -> dict | None:
	if not value:
		return None
	if isinstance(value, dict):
		return value
	try:
		parsed = json.loads(value)
	except (TypeError, ValueError):
		# A client that sent something unparseable still said something worth
		# keeping. Drop the interpretation, never the sentence.
		return None
	return parsed if isinstance(parsed, dict) else None
