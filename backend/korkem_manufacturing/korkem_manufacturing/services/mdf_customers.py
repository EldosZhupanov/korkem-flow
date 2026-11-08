# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The customer list behind the order form — OnayBaza's «Заказчик» window.

Name, phone, organisation; add, edit, delete, beside the customer field of
the order (08.11.2026). The records are ERPNext Customers, the ones an order
is written for, so a customer added here is the customer the order names.

- Edit renames the customer and changes the phone and organisation. Orders
  keep the name they were written with (ERPNext copies it onto the order).
- Delete removes a customer with no orders; one with orders is disabled —
  it leaves the list and the pickers, and its orders stay as they are.
- The same phone twice is the same customer, as `mdf_orders.new_customer`
  has it: the second card for one person is refused.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import audit, facade_prices, mdf_tags
from korkem_manufacturing.services.scope import current_company

MAX = 2000


def _digits(phone: str | None) -> str:
	return "".join(ch for ch in (phone or "") if ch.isdigit())


def _clean(name: str | None, phone: str | None, organization: str | None) -> tuple[str, str | None, str | None]:
	name = " ".join((name or "").split())[:140]
	if len(name) < 2:
		frappe.throw("Укажите имя клиента.")
	phone = (phone or "").strip() or None
	if phone and not 10 <= len(_digits(phone)) <= 12:
		frappe.throw("Телефон — 10–12 цифр, например 8 777 123 45 67.")
	organization = " ".join((organization or "").split())[:140] or None
	return name, phone, organization


def _same_phone(phone: str | None, besides: str | None = None) -> str | None:
	digits = _digits(phone)[-10:]
	if not digits:
		return None
	for row in frappe.get_all("Customer", filters={"disabled": 0, "mobile_no": ["is", "set"]},
							  fields=["name", "customer_name", "mobile_no"], limit_page_length=0):
		if row.name != besides and _digits(row.mobile_no)[-10:] == digits:
			return row.customer_name
	return None


def _allowed(names: list[str], company: str) -> set[str]:
	"""Customers this company may sell to: no restriction, or this company among them."""
	bound: dict[str, set] = {}
	for r in frappe.get_all("Allowed To Transact With", filters={"parenttype": "Customer", "parent": ["in", names]},
							fields=["parent", "company"], limit_page_length=0):
		bound.setdefault(r.parent, set()).add(r.company)
	return {n for n in names if n not in bound or company in bound[n]}


def _row(doc) -> dict:
	return {"name": doc.name, "customer_name": doc.customer_name, "phone": doc.mobile_no,
			"organization": doc.get("korkem_organization"), "tags": mdf_tags.parse(doc.get("korkem_tags"))}


def customers() -> list[dict]:
	"""Every customer the company sells to, by name."""
	facade_prices.ensure_editor()
	rows = frappe.get_all("Customer", filters={"disabled": 0},
						  fields=["name", "customer_name", "mobile_no", "korkem_organization", "korkem_tags"],
						  order_by="customer_name asc", limit_page_length=MAX)
	allowed = _allowed([r.name for r in rows], current_company()) if rows else set()
	return [{"name": r.name, "customer_name": r.customer_name, "phone": r.mobile_no,
			 "organization": r.korkem_organization, "tags": mdf_tags.parse(r.korkem_tags)}
			for r in rows if r.name in allowed]


def add(name: str, phone: str | None = None, organization: str | None = None, tags=None) -> dict:
	facade_prices.ensure_editor()
	name, phone, organization = _clean(name, phone, organization)
	tags = mdf_tags.clean(tags, mdf_tags.CUSTOMER, "Клиент")
	if other := _same_phone(phone):
		frappe.throw(f"Этот телефон уже у клиента «{other}».")
	doc = frappe.get_doc({"doctype": "Customer", "customer_name": name, "customer_type": "Individual",
						  "mobile_no": phone, "korkem_organization": organization, "korkem_tags": tags}).insert()
	audit.record_audit(action="mdf.customer_created", entity_type="Customer", entity_id=doc.name, diff={"name": name})
	return _row(doc)


def update(customer: str, name: str, phone: str | None = None, organization: str | None = None,
		   tags=None) -> dict:
	"""Change a customer; `tags` None keeps theirs, an empty list clears them."""
	facade_prices.ensure_editor()
	doc = _own(customer)
	name, phone, organization = _clean(name, phone, organization)
	if other := _same_phone(phone, besides=doc.name):
		frappe.throw(f"Этот телефон уже у клиента «{other}».")
	before = _row(doc)
	doc.customer_name = name
	doc.mobile_no = phone
	doc.korkem_organization = organization
	if tags is not None:
		doc.korkem_tags = mdf_tags.clean(tags, mdf_tags.CUSTOMER, "Клиент")
	doc.save()
	audit.record_audit(action="mdf.customer_changed", entity_type="Customer", entity_id=doc.name,
					   diff={"before": before, "after": _row(doc)})
	return _row(doc)


def remove(customer: str) -> dict:
	"""Delete a customer with no orders; disable one with orders."""
	facade_prices.ensure_editor()
	doc = _own(customer)
	if frappe.db.exists("Sales Order", {"customer": doc.name}) or frappe.db.exists(
		"Sales Invoice", {"customer": doc.name}
	):
		doc.db_set("disabled", 1)
		outcome = "disabled"
	else:
		frappe.delete_doc("Customer", doc.name, ignore_permissions=True)
		outcome = "deleted"
	audit.record_audit(action=f"mdf.customer_{outcome}", entity_type="Customer", entity_id=customer,
					   diff={"name": doc.customer_name})
	return {"name": customer, "outcome": outcome}


def _own(customer: str):
	if not customer or not frappe.db.exists("Customer", customer):
		frappe.throw("Такого клиента нет.")
	if customer not in _allowed([customer], current_company()):
		frappe.throw("Такого клиента нет.")
	return frappe.get_doc("Customer", customer)
