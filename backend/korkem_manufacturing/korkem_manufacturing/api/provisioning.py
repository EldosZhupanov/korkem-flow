# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The only two endpoints a node answers before it has an owner.

Both are `allow_guest`, and they have to be: on a fresh node there is no account
to authenticate as. That is the whole reason the claim carries a one-time code
(ADR-0027) — the guest door is open for exactly as long as the node is nobody's,
and it is protected by something the installer can read off the machine.

`status` is deliberately thin. An unauthenticated caller learns whether this
node is taken and which languages it speaks, and nothing else: not the company,
not who the owner is, not how many people work here. A reconnaissance answer is
still an answer.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import provisioning


@frappe.whitelist(allow_guest=True, methods=["GET"])
def status() -> dict:
	"""Whether this node has an owner yet.

	The app asks this before showing anything. Unclaimed means "run first-time
	setup"; claimed means "show the ordinary sign-in".

	Minting the claim code happens here, on the first ask, and the code goes to
	the node's log — never into this response. A caller who is not standing at
	the machine cannot read it, which is the point.
	"""
	claimed = provisioning.is_claimed()
	if not claimed:
		_ensure_claim_code_is_logged()

	return {
		"claimed": claimed,
		"languages": ["ru", "kk", "en"],
	}


@frappe.whitelist(allow_guest=True, methods=["POST"])
def claim(
	code: str,
	company: str,
	owner_email: str,
	owner_name: str = "",
	owner_password: str = "",
	country: str = "Kazakhstan",
	currency: str = "KZT",
	timezone: str = "Asia/Almaty",
	language: str = "ru",
) -> dict:
	"""Claim an unclaimed node: build the company, create its owner.

	Refusals are deliberate and different from each other, because the person
	setting up a factory deserves to know which mistake they made: a wrong code
	is not the same problem as a node somebody already claimed.
	"""
	try:
		return provisioning.claim(
			code=code,
			company=company,
			owner_email=owner_email,
			owner_name=owner_name,
			owner_password=owner_password,
			country=country,
			currency=currency,
			timezone=timezone,
			language=language,
		)
	except provisioning.NodeAlreadyClaimed as refusal:
		frappe.local.response["http_status_code"] = 409
		return {"status": "already_claimed", "message": str(refusal)}
	except provisioning.ClaimCodeRefused as refusal:
		frappe.local.response["http_status_code"] = 403
		return {"status": "code_refused", "message": str(refusal)}


def _ensure_claim_code_is_logged() -> None:
	"""Mint the claim code once and put it where the installer can see it.

	Written with `print` as well as the error log: the log needs a reader with
	an account, and on an unclaimed node nobody has one yet. Standard output is
	what `docker logs` shows, which is what an installer can show a person.
	"""
	if frappe.db.get_default(provisioning.CLAIM_CODE_KEY):
		return

	try:
		code = provisioning.claim_code()
	except provisioning.NodeAlreadyClaimed:
		return

	banner = (
		"\n"
		"==================================================================\n"
		"  KORKEM: этот узел пока никому не принадлежит.\n"
		f"  Код для первого запуска: {code}\n"
		"  Введите его в приложении, чтобы создать компанию и владельца.\n"
		"  Код одноразовый и больше нигде не хранится.\n"
		"==================================================================\n"
	)
	print(banner, flush=True)  # noqa: T201 — see the docstring
	frappe.db.commit()
