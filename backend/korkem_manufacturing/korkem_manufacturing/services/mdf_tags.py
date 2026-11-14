# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The tags of an MDF order and of a customer (owner, 08.11.2026).

A customer's are set once in the customer list and show on all their orders:
VIP, a furniture maker who buys often, a new customer, one who pays in
advance only. An order's are set in its head: urgent (to the top of the list
and the shop's plan), a rework and a warranty job (both our cost: no debt),
the customer's own paint and the customer's own facades.

Stored as codes, comma-separated, in `korkem_tags`; the words are the app's.
"""

from __future__ import annotations

import frappe

ORDER = ("urgent", "rework", "warranty", "client_paint", "client_parts")
CUSTOMER = ("vip", "furniture_maker", "new", "prepay_only")

#: The customer brings his own paint: the paint is cheaper by the factory's
#: discount, and the painter waits for it (owner, 14.11.2026).
CLIENT_PAINT = "client_paint"
#: The customer brings his own facades: sanded and painted or pressed here —
#: no cutting or milling, and no MDF from our shelf.
CLIENT_PARTS = "client_parts"

#: An order with one of these is our cost: nobody owes for it.
NOT_OWED = frozenset({"rework", "warranty"})


def parse(stored: str | None) -> list[str]:
	return [t for t in (stored or "").split(",") if t]


def clean(raw, allowed: tuple[str, ...], what: str) -> str | None:
	"""A list (or a comma string) of tag codes → the stored string, in a fixed order."""
	if raw in (None, ""):
		return None
	if isinstance(raw, str):
		raw = frappe.parse_json(raw) if raw.strip().startswith("[") else raw.split(",")
	if not isinstance(raw, (list, tuple)):
		frappe.throw(f"{what}: метки — списком.")
	tags = {str(t).strip() for t in raw if str(t).strip()}
	if unknown := tags - set(allowed):
		frappe.throw(f"{what}: метки «{', '.join(sorted(unknown))}» нет. Есть: {', '.join(allowed)}.")
	return ",".join(t for t in allowed if t in tags) or None


def owed(tags: str | None) -> bool:
	return not NOT_OWED.intersection(parse(tags))
