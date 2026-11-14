# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Счёт на оплату» for a film sale (owner, 14.11.2026).

A customer — a furniture maker, a company — pays by bank transfer against an
invoice: the factory's requisites, his name, the films, the sum, a number and
the day to pay by. The sale stays a debt until «Оплатили», as any sale left
unpaid; the invoice only gives it a number and a deadline.

The requisites are the company's, kept once (`requisites`, `set_requisites`):
the name it trades under, its БИН, the bank, ИИК, БИК, Кбе, its address and
phone, who signs. Numbers run one after another within the company and the
year: the 45th invoice of 2026 is «45».
"""

from __future__ import annotations

import frappe
from frappe.utils import add_days, getdate, nowdate

from korkem_manufacturing.services import audit, film_dept, material_stock
from korkem_manufacturing.services.scope import current_company

#: What the requisites are made of, in the order an invoice prints them.
REQUISITES = ("name", "bin", "address", "phone", "bank", "iik", "bik", "kbe", "director")
#: An invoice is to be paid this many days after it is made, unless said.
DUE_DAYS = 5
_KEY = "korkem_requisites"


def requisites(company: str | None = None) -> dict:
	"""The company's requisites; empty strings where none were kept."""
	material_stock._ensure_editor()
	raw = frappe.db.get_default(f"{_KEY}:{company or current_company()}")
	kept = frappe.parse_json(raw) if raw else {}
	return {k: str(kept.get(k) or "") for k in REQUISITES}


def set_requisites(values) -> dict:
	material_stock._ensure_editor()
	if isinstance(values, str):
		values = frappe.parse_json(values) if values.strip() else {}
	clean = {k: " ".join(str((values or {}).get(k) or "").split())[:200] for k in REQUISITES}
	if not clean["name"]:
		frappe.throw("Название компании — как оно стоит в документах.")
	if clean["bin"] and not (clean["bin"].isdigit() and len(clean["bin"]) == 12):
		frappe.throw("БИН/ИИН — 12 цифр.")
	company = current_company()
	frappe.db.set_default(f"{_KEY}:{company}", frappe.as_json(clean))
	audit.record_audit(action="settings.requisites", entity_type="Company", entity_id=company, diff=clean)
	return clean


def invoice(sale: str, due_on: str | None = None) -> dict:
	"""The sale's invoice: made the first time it is asked for — the next
	number of the year — and the same one after; `due_on` moves its day."""
	material_stock._ensure_editor()
	doc = film_dept._movement(sale, film_dept.SALE)
	no = doc.get("korkem_film_invoice_no")
	made_on = getdate(doc.get("korkem_film_invoice_on") or nowdate())
	due = getdate(due_on) if due_on else (getdate(doc.get("korkem_film_invoice_due"))
										   if doc.get("korkem_film_invoice_due") else add_days(made_on, DUE_DAYS))
	if due < made_on:
		frappe.throw("Оплатить до — не раньше дня счёта.")
	if not no:
		no = str(_next_number(doc.company, made_on.year))
	doc.db_set({"korkem_film_invoice_no": no, "korkem_film_invoice_on": str(made_on),
				"korkem_film_invoice_due": str(getdate(due))}, update_modified=True)
	audit.record_audit(action="film.invoice", entity_type="Stock Entry", entity_id=sale,
					   diff={"no": no, "due": str(getdate(due))})
	return {"no": no, "on": str(made_on), "due_on": str(getdate(due)), "requisites": requisites(doc.company),
			"buyer": _buyer(doc.korkem_film_customer), "sale": film_dept.movement(sale)}


def _next_number(company: str, year: int) -> int:
	used = frappe.db.sql(
		"""select korkem_film_invoice_no from `tabStock Entry`
		where company = %s and korkem_film_invoice_no is not null and korkem_film_invoice_no != ''
			and year(korkem_film_invoice_on) = %s""",
		(company, year),
	)
	numbers = [int(n) for (n,) in used if str(n).isdigit()]
	return max(numbers, default=0) + 1


def _buyer(customer: str | None) -> dict:
	if not customer:
		return {"name": "", "bin": "", "phone": ""}
	row = frappe.db.get_value("Customer", customer, ["customer_name", "tax_id", "mobile_no"], as_dict=True) or {}
	return {"name": row.get("customer_name") or customer, "bin": row.get("tax_id") or "",
			"phone": row.get("mobile_no") or ""}
