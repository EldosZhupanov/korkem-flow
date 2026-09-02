# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Turning something that was said into a customer and an enquiry.

Step one of the chain in `ROADMAP.md`: обращение → клиент → заявка → замерщик
с датой. The capture already survived the moment it could have been lost; this
is what happens next, and it happens when somebody has both hands free.

Two decisions worth knowing before changing anything here.

**The enquiry is an ERPNext `Opportunity`, not a `CRM Lead`.** Opportunity
carries a company field, so it is scoped like everything else we own. `CRM Lead`
does not, and we measured the consequence: a manager of one company can read
another company's leads through the raw resource API. Until that is decided at
the data-model level (`ROADMAP.md`, развилка 5), nothing new of ours goes into
a doctype we know leaks.

**An ambiguous customer is a question, never a guess.** Two customers whose
names both look like what the owner said is exactly the moment to stop: the
wrong customer means the wrong address, the wrong price list and eventually a
kitchen delivered to somebody else. So this refuses and hands back the
candidates rather than picking the first one.

**Customer is a node-wide shared master in the current ERPNext model.** It has
no company field, so candidate search intentionally has no company filter and
may return a customer first created from another company's Capture. This is a
recorded model decision, not accidental reliance on missing scope; changing it
requires deciding how one real customer trading with two companies is stored.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services.scope import ensure_user_in_company, scoped


class AmbiguousCustomer(frappe.ValidationError):
	"""Raised when more than one customer could be the one that was named."""


def convert(
	*,
	capture: str,
	customer: str | None = None,
	customer_name: str | None = None,
	assign_measurer: str | None = None,
	measure_on: str | None = None,
) -> dict:
	"""Turn one capture into a customer and an enquiry, once.

	Calling this twice on the same capture returns the first result instead of
	creating a second customer and a second enquiry. The owner taps things twice
	on a phone with dusty hands; that must cost nothing.
	"""
	doc = _visible_capture(capture)

	if doc.status == "Converted" and doc.enquiry:
		return _already(doc)
	if assign_measurer:
		# Validate before creating Customer or Opportunity. A foreign assignee is
		# a rejected command, not a partially converted capture awaiting rollback.
		ensure_user_in_company(assign_measurer, doc.company)

	party = _resolve_customer(customer, customer_name or doc.customer_hint)

	opportunity = frappe.get_doc(
		{
			"doctype": "Opportunity",
			"opportunity_from": "Customer",
			"party_name": party["name"],
			"company": _company(),
			"status": "Open",
			"title": (doc.product_hint or doc.spoken_text)[:140],
			"expected_closing": doc.due_hint,
		}
	)
	opportunity.insert()
	# The sentence itself travels with the enquiry. Whoever picks this up later
	# needs the customer's own words, not our summary of them: «белый глянец» and
	# «белый матовый» are one word apart and a remake apart.
	_note(opportunity, doc)

	task = None
	if assign_measurer:
		task = capture_service._hand_over(doc, assign_measurer, measure_on or doc.due_hint)

	doc.db_set(
		{"status": "Converted", "enquiry": opportunity.name}, update_modified=False
	)

	return {
		"capture": doc.name,
		"customer": party["name"],
		"customer_created": party["created"],
		"enquiry": opportunity.name,
		"task": task,
	}


def candidates(name_said: str) -> list[dict]:
	"""Node-wide Customers that could be named, for a human to choose between."""
	name_said = (name_said or "").strip()
	if not name_said:
		return []
	rows = frappe.get_list(
		"Customer",
		filters={"customer_name": ["like", f"%{name_said}%"]},
		fields=["name", "customer_name", "mobile_no"],
		limit_page_length=10,
	)
	return [dict(row) for row in rows]


def _visible_capture(name: str):
	if not frappe.get_list("Capture", filters=scoped({"name": name}), pluck="name"):
		frappe.throw("No such capture in this company.", frappe.PermissionError)
	return frappe.get_doc("Capture", name)


def _company() -> str:
	company = scoped().get("company")
	if not company:
		frappe.throw("No company in scope.")
	return company


def _resolve_customer(customer: str | None, name_said: str | None) -> dict:
	"""Find the customer that was named, or create one — never guess between two."""
	if customer:
		if not frappe.db.exists("Customer", customer):
			frappe.throw(f"Customer {customer} does not exist.")
		return {"name": customer, "created": False}

	name_said = (name_said or "").strip()
	if not name_said:
		frappe.throw(
			"No customer was named. Say who this is for, or pick an existing customer."
		)

	found = candidates(name_said)
	exact = [row for row in found if row["customer_name"].strip().lower() == name_said.lower()]
	if len(exact) == 1:
		return {"name": exact[0]["name"], "created": False}
	if len(found) == 1:
		return {"name": found[0]["name"], "created": False}
	if len(found) > 1:
		raise AmbiguousCustomer(
			f"More than one customer matches «{name_said}». Choose one: "
			+ ", ".join(row["customer_name"] for row in found[:5])
		)

	created = frappe.get_doc(
		{
			"doctype": "Customer",
			"customer_name": name_said,
			"customer_type": "Individual",
		}
	).insert()
	return {"name": created.name, "created": True}


def _note(opportunity, capture) -> None:
	"""Keep the original sentence on the enquiry, guarded like every audit here."""
	savepoint = "korkem_enquiry_note_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "Opportunity",
				"reference_name": opportunity.name,
				"content": f"KORKEM: со слов — «{capture.spoken_text}»",
			}
		).insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title="Could not keep the spoken words on an enquiry",
			message=frappe.get_traceback(with_context=True),
		)


def _already(doc) -> dict:
	return {
		"capture": doc.name,
		"customer": None,
		"customer_created": False,
		"enquiry": doc.enquiry,
		"task": doc.task,
		"status": "already_converted",
	}
