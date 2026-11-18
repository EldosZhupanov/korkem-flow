# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""One way to write a phone (owner, 18.11.2026): stored one way, shown another.

- **Stored** as `+77015551234` — «+», the country code and the number, no
  spaces or brackets (E.164). One spelling per phone is what makes a
  duplicate findable, a search by digits exact and a WhatsApp link work.
- **Shown** as `+7 (701) 555-12-34` — on the screen, in print. That is the
  app's business (`Phone.pretty` in Flutter); `pretty` here is for what the
  server itself prints.
- **Typed** any way at all: `8 701 555 12 34`, `87015551234`, `+7 701…`,
  `701 555 1234` are the same phone. A foreign one keeps its own code:
  `+996 555 123 456`.

A number that cannot be read — too short, too long — is refused with a
sentence saying how to write it, never stored half-right.
"""

from __future__ import annotations

import re

import frappe

#: What a person is told when a phone cannot be read.
HOW = "Нужно 10 цифр после +7, например +7 (701) 555-12-34; иностранный номер — с «+» и кодом страны."


def digits(value: str | None) -> str:
	return re.sub(r"\D", "", str(value or ""))


def canonical(value: str | None) -> str | None:
	"""`+77015551234`, a foreign `+996555123456`, or None for nothing typed.

	Raises ValueError for a number that cannot be read.
	"""
	text = str(value or "").strip()
	found = digits(text)
	if not found:
		if text:
			raise ValueError(text)
		return None
	if text.startswith("+") and not found.startswith("7"):
		# Another country: its own code, 8–15 digits in all.
		if 8 <= len(found) <= 15:
			return f"+{found}"
		raise ValueError(text)
	if len(found) == 10:
		return f"+7{found}"
	if len(found) == 11 and found[0] in "78":
		return f"+7{found[1:]}"
	raise ValueError(text)


def clean(value: str | None, label: str = "Телефон") -> str | None:
	"""`canonical`, or a refusal that says how to write it."""
	try:
		return canonical(value)
	except ValueError:
		frappe.throw(f"{label}: «{value}» не похож на номер. {HOW}")


def lenient(value: str | None) -> str | None:
	"""`canonical` where it can be read; otherwise the text as typed, tidied.

	For a contact's second number, a supplier's line or a driver's phone —
	where refusing the whole card for one odd number would cost more than
	keeping it as written.
	"""
	try:
		return canonical(value)
	except ValueError:
		return " ".join(str(value or "").split())[:40] or None


def pretty(value: str | None) -> str:
	"""`+7 (701) 555-12-34` — for what the server prints itself."""
	text = str(value or "")
	if re.fullmatch(r"\+7\d{10}", text):
		n = text[2:]
		return f"+7 ({n[:3]}) {n[3:6]}-{n[6:8]}-{n[8:]}"
	return text


def same(a: str | None, b: str | None) -> bool:
	"""One phone, whatever way each was written."""
	one, other = digits(a)[-10:], digits(b)[-10:]
	return bool(one) and one == other
