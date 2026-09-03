# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""How a freshly installed node stops being nobody's and becomes a factory's.

Until this runs, a node has no company, no owner and no data — it is a running
server waiting to be claimed. After it runs, it belongs to one company and one
owner, and it can never be claimed again.

Three decisions shape this file, all recorded in ADR-0027.

**The company is created by ERPNext's own setup wizard, not by us.** A company
in ERPNext is not a row: it is a chart of accounts, warehouses, tax templates,
a fiscal year, units of measure, a currency and a timezone, created together.
We know what the shortcut costs because we took it on our own bench — a company
inserted directly left the site with `setup_complete` at 0, so every
administrator who opened the desk landed in a wizard that offered to create a
*second* company.

**Claiming needs a code.** The endpoint has to work unauthenticated, because no
account exists yet, and that is a dangerous window: whoever reaches the port
first would become the owner of the factory. "It is on the local network" is
not an answer — ADR-0026 puts a tunnel in front of this node on purpose. So the
node prints a one-time code at first start and accepts a claim only with it.
The person who can read the machine's log is the person who installed it.

**It happens exactly once.** After a successful claim the door is closed for
good, code or no code. Everyone else arrives by invitation, which is a
permissioned action — rule R5: nobody grants themselves a role.
"""

from __future__ import annotations

import hashlib
import hmac
import secrets

import frappe

CLAIM_CODE_KEY = "korkem_claim_code_hash"
CLAIM_ATTEMPTS_KEY = "korkem_claim_attempts"

# A wrong code is a person mistyping, or somebody guessing. Ten is generous for
# the first and useless for the second, and the code itself carries enough
# entropy that guessing was never the way in.
MAX_ATTEMPTS = 10

# Crockford-style: no I, L, O or U, so nothing is misread off a screen or
# misheard over a phone. Sixteen characters is about 74 bits.
_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
_CODE_LENGTH = 16


class NodeAlreadyClaimed(frappe.ValidationError):
	"""Raised when a claim arrives at a node that already has an owner."""


class ClaimCodeRefused(frappe.ValidationError):
	"""Raised when the code is wrong, missing, or has been tried too often."""


def is_claimed() -> bool:
	"""Whether this node already belongs to somebody.

	Two questions, and either one is enough, because they fail in opposite
	directions and a node must be safe when only one of them is true.

	`is_setup_complete` is what the desk itself consults, so a node that looks
	claimed to us can never look unclaimed to the administrator opening the
	panel — that disagreement is what produced the stray setup wizard we found
	on our own bench.

	**But a company can exist without that flag**, and CI proved it: our
	`bootstrap.sh` builds a site and seeds a company without ever running
	ERPNext's wizard, so the flag stays 0 while KORKEM sits in the database.
	Trusting the flag alone would have left every such node claimable — and a
	claim on a node that already has a company means a *second* company, which
	is the exact accident this whole file exists to prevent.
	"""
	if frappe.is_setup_complete():
		return True
	return bool(frappe.db.count("Company"))


def claim_code() -> str:
	"""Return the node's one-time claim code, creating it on first ask.

	The plain code is returned to the caller *once* and never stored; only its
	digest lives in the database. The caller's job is to put it somewhere the
	installer can show — the node log, or the installer's own screen.
	"""
	if is_claimed():
		raise NodeAlreadyClaimed("This node already has an owner.")

	code = "".join(secrets.choice(_ALPHABET) for _ in range(_CODE_LENGTH))
	frappe.db.set_default(CLAIM_CODE_KEY, _digest(code))
	frappe.db.set_default(CLAIM_ATTEMPTS_KEY, "0")
	return code


def claim(
	*,
	code: str,
	company: str,
	owner_email: str,
	owner_name: str,
	owner_password: str,
	country: str = "Kazakhstan",
	currency: str = "KZT",
	timezone: str = "Asia/Almaty",
	language: str = "ru",
) -> dict:
	"""Turn an unclaimed node into one company's node, with one owner.

	Ordered so that a failure leaves the node claimable rather than half-owned:
	the code is checked first, the company second — because ERPNext's wizard is
	the step that can fail on bad input — and the owner last, when there is
	something to bind them to.
	"""
	if is_claimed():
		raise NodeAlreadyClaimed(
			"This node already has an owner. A second owner is not created here; "
			"ask the owner for an invitation."
		)

	_verify_code(code)

	company = (company or "").strip()
	owner_email = (owner_email or "").strip().lower()
	owner_name = (owner_name or "").strip()
	if not company:
		frappe.throw("Company name is required.")
	if not owner_email:
		frappe.throw("Owner email is required.")
	if not owner_password:
		frappe.throw("Owner password is required.")

	# Everything from here writes what only an administrator may write, and the
	# caller is `Guest` -- deliberately, because the endpoint has to answer on a
	# node where nobody has an account yet. ERPNext's wizard is the first to
	# refuse: it writes `System Settings`, and the failure arrives as
	#
	#     User guest does not have access to this document: System Settings
	#
	# which reads like a permission bug in KORKEM and is not one. The authority
	# for this block is the one-time code, and it has just been proven; the
	# elevation is therefore explicit, starts only after `_verify_code`, and is
	# undone whatever happens next.
	#
	# Found by the first real installation (2026-09-03), not by the suite: every
	# test here runs as Administrator, so the guest path had never been walked.
	caller = frappe.session.user
	frappe.set_user("Administrator")
	try:
		_run_erpnext_setup(
			company=company,
			owner_email=owner_email,
			owner_name=owner_name,
			owner_password=owner_password,
			country=country,
			currency=currency,
			timezone=timezone,
			language=language,
		)

		if not is_claimed():
			# The wizard reports success by making this true. If it is still false
			# the node is untouched and must stay claimable, so say so plainly
			# rather than leaving the caller with a green answer and no company.
			frappe.throw("ERPNext setup did not complete; the node is still unclaimed.")

		name_the_shipping_warehouse(company)
		owner = _make_owner(owner_email, owner_name, company)

		frappe.db.set_default(CLAIM_CODE_KEY, "")
		frappe.db.set_default(CLAIM_ATTEMPTS_KEY, "")
		_audit(company, owner_email)
	finally:
		frappe.set_user(caller)

	return {
		"status": "claimed",
		"company": company,
		"owner": owner.get("user"),
		"roles": owner.get("roles_added", []),
	}


def _digest(code: str) -> str:
	return hashlib.sha256(code.strip().upper().encode()).hexdigest()


def _verify_code(code: str) -> None:
	stored = frappe.db.get_default(CLAIM_CODE_KEY)
	if not stored:
		raise ClaimCodeRefused(
			"This node has no claim code yet. Restart it and read the code from its log."
		)

	attempts = int(frappe.db.get_default(CLAIM_ATTEMPTS_KEY) or 0)
	if attempts >= MAX_ATTEMPTS:
		raise ClaimCodeRefused(
			"Too many wrong codes. Restart the node to get a new one."
		)

	# Constant-time: the comparison itself must not tell an attacker how much of
	# the code was right.
	if not hmac.compare_digest(stored, _digest(code or "")):
		frappe.db.set_default(CLAIM_ATTEMPTS_KEY, str(attempts + 1))
		raise ClaimCodeRefused("Wrong claim code.")


def _run_erpnext_setup(
	*,
	company: str,
	owner_email: str,
	owner_name: str,
	owner_password: str,
	country: str,
	currency: str,
	timezone: str,
	language: str,
) -> None:
	"""Hand the whole company build to ERPNext, exactly as the desk does."""
	from frappe.desk.page.setup_wizard.setup_wizard import setup_complete

	first_name, _, last_name = owner_name.partition(" ")
	setup_complete(
		{
			"language": _wizard_language(language),
			"country": country,
			"currency": currency,
			"timezone": timezone,
			"full_name": owner_name or owner_email,
			"first_name": first_name or owner_email,
			"last_name": last_name,
			"email": owner_email,
			"password": owner_password,
			"company_name": company,
			"company_abbr": _abbreviation(company),
			"chart_of_accounts": "Standard",
			"fy_start_date": frappe.utils.get_first_day(frappe.utils.nowdate()).replace(
				month=1, day=1
			),
			"fy_end_date": frappe.utils.get_last_day(frappe.utils.nowdate()).replace(
				month=12, day=31
			),
		}
	)


def _wizard_language(language: str) -> str:
	"""ERPNext's wizard wants a language *name*, not a code."""
	return {"ru": "Russian", "kk": "Russian", "en": "English"}.get(language, "English")


def _abbreviation(company: str) -> str:
	"""ERPNext needs a short company code and will invent a poor one if asked.

	Letters only, upper case, at most five — the abbreviation ends up in every
	warehouse and account name, so a stray punctuation mark from a company
	called «Мебель+» would follow the client around forever.
	"""
	letters = [c for c in company.upper() if c.isalnum()]
	return "".join(letters[:5]) or "KRK"


def _make_owner(email: str, name: str, company: str) -> dict:
	"""The owner as KORKEM understands one, on top of the user ERPNext made."""
	from korkem_ai.korkem_ai.onboarding import create_owner

	return create_owner(email=email, first_name=name or email, company=company)


def _audit(company: str, owner_email: str) -> None:
	"""Who claimed this node, and when. Guarded like every other audit here."""
	savepoint = "korkem_claim_audit_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "Company",
				"reference_name": company,
				"content": (
					f"KORKEM: узел занят. Владелец {owner_email}, "
					f"компания {company}."
				),
			}
		).insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title="Could not record who claimed this node",
			message=frappe.get_traceback(with_context=True),
		)


def name_the_shipping_warehouse(company: str) -> None:
	"""Указать компании, откуда она отгружает.

	Мастер ERPNext создаёт склад готовой продукции, но не делает его складом
	компании по умолчанию. Заметно это становится позже и неприятно: первый же
	заказ на складскую позицию отказывается сохраняться словами «нужен склад»,
	и происходит это у клиента, а не у нас.

	Вызывается из двух мест, и это не дублирование: компанию создаёт либо наш
	первый запуск у клиента, либо `setup.ensure_company` на стенде разработчика
	и в CI. Пропустить второй путь означало, что дефект живёт до тех пор, пока
	его не найдёт CI — что и произошло.

	Идемпотентна: если склад уже назван, ничего не делает. Если склада вдруг
	нет — молчит. Установка состоялась, а отсутствие склада по умолчанию заказ
	и так назовёт сам, понятной фразой.
	"""
	if frappe.db.get_value("Company", company, "default_fg_warehouse"):
		return
	abbr = frappe.db.get_value("Company", company, "abbr")
	warehouse = f"Finished Goods - {abbr}"
	if frappe.db.exists("Warehouse", warehouse):
		frappe.db.set_value("Company", company, "default_fg_warehouse", warehouse)
