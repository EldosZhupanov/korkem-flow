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
from frappe.utils import flt

from korkem_manufacturing.services import audit, facade_prices, mdf_tags, phones
from korkem_manufacturing.services.scope import current_company

MAX = 2000
#: Order numbers and objects a customer is found by, the latest first.
FOUND_BY = 30
#: «Давно не заказывал»: no order for this many days (owner, 20.11.2026).
IDLE_DAYS = 90

#: Where a customer came from (owner, 20.11.2026: «в основном сарафанное,
#: инстаграм, 2гис»).
SOURCES = ("word", "instagram", "2gis", "repeat", "other")

#: A customer's own terms, by what the window calls them.
TERMS = {
	"discount_pct": "korkem_price_discount_pct",
	"price_pvc_m2": "korkem_price_pvc_m2",
	"price_paint_m2": "korkem_price_paint_m2",
	"debt_limit": "korkem_debt_limit",
	"source": "korkem_source",
}
_LIMIT_DEFAULT = "korkem_debt_limit"


def _digits(phone: str | None) -> str:
	return "".join(ch for ch in (phone or "") if ch.isdigit())


def _clean(name: str | None, phone: str | None, organization: str | None) -> tuple[str, str | None, str | None]:
	name = " ".join((name or "").split())[:140]
	if len(name) < 2:
		frappe.throw("Укажите имя клиента.")
	# One spelling per phone: +77015551234 (owner, 18.11.2026, `phones`).
	phone = phones.clean(phone)
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
			"organization": doc.get("korkem_organization"), "tags": mdf_tags.parse(doc.get("korkem_tags")),
			**_terms_of(doc)}


def _terms_of(row) -> dict:
	"""His terms as the window reads them; a zero is «none»."""
	out = {}
	for key, field in TERMS.items():
		value = row.get(field)
		if key == "source":
			if value:
				out[key] = value
		elif flt(value) > 0:
			out[key] = flt(value)
	return out


def _clean_terms(terms) -> dict:
	"""The fields of `terms` given, checked; None leaves a field as it is."""
	if terms is None:
		return {}
	if isinstance(terms, str):
		terms = frappe.parse_json(terms) if terms.strip() else {}
	if not isinstance(terms, dict):
		frappe.throw("Условия клиента — непонятный формат.")
	out = {}
	for key, field in TERMS.items():
		if key not in terms:
			continue
		value = terms[key]
		if key == "source":
			if value not in (None, "") and value not in SOURCES:
				frappe.throw("Откуда пришёл — сарафан, Instagram, 2ГИС, повторный или другое.")
			out[field] = value or None
			continue
		number = flt(value) if value not in (None, "") else 0
		if number < 0 or (key == "discount_pct" and number >= 100):
			frappe.throw("Скидка — от 0 до 99 %; цены и лимит — не меньше нуля.")
		out[field] = number
	return out


def default_debt_limit(company: str | None = None) -> float:
	"""The shop's debt limit for a customer without his own; 0 — none."""
	return max(0.0, flt(frappe.db.get_default(f"{_LIMIT_DEFAULT}:{company or current_company()}")))


def set_default_debt_limit(amount) -> dict:
	facade_prices.ensure_editor()
	value = flt(amount) if amount not in (None, "") else 0
	if value < 0:
		frappe.throw("Лимит — не меньше нуля.")
	frappe.db.set_default(f"{_LIMIT_DEFAULT}:{current_company()}", value)
	audit.record_audit(action="mdf.debt_limit_default", entity_type="Company", entity_id=current_company(),
					   diff={"limit": value})
	return {"debt_limit": value}


def debt_limit(customer: str, company: str | None = None) -> float:
	own = flt(frappe.db.get_value("Customer", customer, TERMS["debt_limit"]))
	return own if own > 0 else default_debt_limit(company)


def debt_check(customer: str, adding=0) -> dict:
	"""What he owes, his limit, and whether `adding` takes him over it —
	asked before an order is accepted (owner, 20.11.2026: «лимит долга
	должен настраиваться»)."""
	facade_prices.ensure_editor()
	from korkem_manufacturing.services import directions, mdf_orders

	company = current_company()
	owed = sum(
		float(mdf_orders._debt(o)) for o in frappe.get_all(
			"Sales Order",
			filters={"company": company, "customer": customer, "korkem_direction": directions.FACADES,
					 "docstatus": 1},
			fields=["grand_total", "advance_paid", "docstatus", "korkem_tags"],
			limit_page_length=0,
		)
	)
	limit = debt_limit(customer, company)
	after = owed + flt(adding)
	return {"debt": round(owed, 2), "limit": limit, "after": round(after, 2),
			"over": bool(limit > 0 and after > limit)}


def price_terms(customer: str | None) -> dict:
	"""His prices: a discount off the list, his own a m² by coating."""
	if not customer:
		return {}
	row = frappe.db.get_value("Customer", customer, list(TERMS.values()), as_dict=True)
	if not row:
		return {}
	return {"discount_pct": flt(row.korkem_price_discount_pct), "pvc": flt(row.korkem_price_pvc_m2),
			"paint": flt(row.korkem_price_paint_m2)}


def customers() -> list[dict]:
	"""Every customer the company sells to, by name — each with what the
	order form needs to know before choosing him (owner, 20.11.2026): his
	last order and what it was, how many, what he owes, what is in work, and
	the order numbers and objects he is found by."""
	facade_prices.ensure_editor()
	company = current_company()
	rows = frappe.get_all("Customer", filters={"disabled": 0},
						  fields=["name", "customer_name", "mobile_no", "korkem_organization", "korkem_tags",
								  *TERMS.values()],
						  order_by="customer_name asc", limit_page_length=MAX)
	allowed = _allowed([r.name for r in rows], company) if rows else set()
	summary = _summaries(company)
	shop_limit = default_debt_limit(company)
	return [{"name": r.name, "customer_name": r.customer_name, "phone": r.mobile_no,
			 "organization": r.korkem_organization, "tags": mdf_tags.parse(r.korkem_tags),
			 **_terms_of(r), "limit": flt(r.korkem_debt_limit) or shop_limit,
			 **summary.get(r.name, {})}
			for r in rows if r.name in allowed]


def _summaries(company: str) -> dict[str, dict]:
	"""Per customer, from his facade orders: one read of the orders, one of
	the last orders' positions."""
	from korkem_manufacturing.services import directions, mdf_orders

	orders = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1},
		fields=["name", "customer", "transaction_date", "grand_total", "advance_paid", "docstatus", "korkem_tags",
				"korkem_extra_name", "korkem_finish", "korkem_handed_over_on", "korkem_ready_on",
				"korkem_hold_reason", *mdf_orders.STAGES.values()],
		order_by="transaction_date desc, creation desc",
		limit_page_length=0,
	)
	out: dict[str, dict] = {}
	for o in orders:
		s = out.setdefault(o.customer, {"orders": 0, "debt": 0.0, "in_work": 0, "last_order": o.name,
										"last_on": str(o.transaction_date), "objects": [], "order_names": [],
										"_finish": o.korkem_finish})
		s["orders"] += 1
		s["debt"] += float(mdf_orders._debt(o))
		if mdf_orders.status_of(o) != "handed_over":
			s["in_work"] += 1
		if len(s["order_names"]) < FOUND_BY:
			s["order_names"].append(o.name)
		place = " ".join((o.korkem_extra_name or "").split())
		if place and place not in s["objects"] and len(s["objects"]) < FOUND_BY:
			s["objects"].append(place)
	last = {s["last_order"]: s for s in out.values()}
	for item in frappe.get_all(
		"Sales Order Item",
		filters={"parent": ["in", list(last)]} if last else {"name": ""},
		fields=["parent", "korkem_line_coating", "korkem_decor_top", "korkem_milling", "korkem_finish"],
		order_by="idx asc",
		limit_page_length=0,
	):
		s = last[item.parent]
		coating = item.korkem_line_coating or mdf_orders.coating_of(item.korkem_finish or s["_finish"])
		group = {"coating": coating, "film": item.korkem_decor_top}
		groups = s.setdefault("last_groups", [])
		if group not in groups:
			groups.append(group)
		millings = s.setdefault("last_millings", [])
		if item.korkem_milling and item.korkem_milling not in millings:
			millings.append(item.korkem_milling)
	for s in out.values():
		s.pop("_finish", None)
		s["debt"] = round(s["debt"], 2)
	return out


def add(name: str, phone: str | None = None, organization: str | None = None, tags=None, terms=None) -> dict:
	facade_prices.ensure_editor()
	name, phone, organization = _clean(name, phone, organization)
	tags = mdf_tags.clean(tags, mdf_tags.CUSTOMER, "Клиент")
	terms = _clean_terms(terms)
	if other := _same_phone(phone):
		frappe.throw(f"Этот телефон уже у клиента «{other}».")
	doc = frappe.get_doc({"doctype": "Customer", "customer_name": name, "customer_type": "Individual",
						  "mobile_no": phone, "korkem_organization": organization, "korkem_tags": tags,
						  **terms}).insert()
	audit.record_audit(action="mdf.customer_created", entity_type="Customer", entity_id=doc.name, diff={"name": name})
	return _row(doc)


def update(customer: str, name: str, phone: str | None = None, organization: str | None = None,
		   tags=None, terms=None) -> dict:
	"""Change a customer; `tags` None keeps theirs, an empty list clears them;
	`terms` None keeps his terms, a key given changes that one."""
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
	doc.update(_clean_terms(terms))
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
