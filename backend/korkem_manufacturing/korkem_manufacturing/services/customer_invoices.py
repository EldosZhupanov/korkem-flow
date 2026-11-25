# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Счёт на долг» — one invoice for all a customer owes (owner, 25.11.2026).

An invoice per order made a company with seven orders owing pay seven
papers. This one lists his orders still owing, oldest first, one line each,
for all of it or for a sum of one's own — then the oldest orders it covers.
He pays it in one transfer or in parts: the payment entered «по счёту № 12»
is laid on his orders the oldest first (`customer_card.pay`) and counts
towards the invoice until it is paid.

The invoices live on the customer (`korkem_invoices`, kept as printed, so a
copy sent again is the same paper), numbered in the company's one series
with the orders' and the film sales' invoices. What was paid by each is kept
with it, payment by payment; one taken back (its entry cancelled) no longer
counts.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

import frappe
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_manufacturing.services import (
	audit,
	facade_prices,
	film_invoice,
	material_stock,
	mdf_invoices,
	search_text,
)

FIELD = "korkem_invoices"


def rows(customer: str) -> list[dict]:
	"""His invoices for what he owes, oldest first, each with what was paid
	by it and where it stands."""
	kept = _kept(customer)
	entries = {p["entry"] for inv in kept for p in inv.get("payments") or [] if p.get("entry")}
	gone = set()
	if entries:
		gone = set(frappe.get_all("Payment Entry", filters={"name": ["in", list(entries)], "docstatus": 2},
								  pluck="name"))
	out = []
	for inv in kept:
		paid = sum(flt(p.get("amount")) for p in inv.get("payments") or [] if p.get("entry") not in gone)
		out.append({**inv, "paid": round(paid, 2), "state": _state(inv, paid)})
	return out


def issue(customer: str, owing: list, *, amount=None, payer_name: str | None = None, bin: str | None = None,
		  due_on: str | None = None, vat=None, company: str) -> dict:
	"""A new invoice for [amount] of what he owes — all of it when none is
	given: a line per order owing, the oldest first, the last cut to fit."""
	facade_prices.ensure_editor()
	total = sum((Decimal(str(d)) for _, d in owing), Decimal(0))
	if total <= 0:
		frappe.throw("Он ничего не должен — счёт не на что выставить.")
	value = total if amount in (None, "") else Decimal(str(flt(amount)))
	value = value.quantize(Decimal("1"), rounding=ROUND_HALF_UP)
	if value <= 0:
		frappe.throw("Сумма счёта больше нуля.")
	if value > total + Decimal("0.5"):
		frappe.throw(f"Он должен {_money(total)} — счёт на большую сумму не выставить.")
	c = frappe.get_doc("Customer", customer)
	name = " ".join(str(payer_name or "").split())[:140] or c.customer_name
	bin = "".join(str(bin or "").split())
	if bin and not (bin.isdigit() and len(bin) == 12):
		frappe.throw("БИН/ИИН — 12 цифр.")
	made_on = getdate(nowdate())
	due = getdate(due_on) if due_on else add_days(made_on, film_invoice.DUE_DAYS)
	if getdate(due) < made_on:
		frappe.throw("Оплатить до — не раньше дня счёта.")
	rate = mdf_invoices.vat_default(company) if vat in (None, "") else (
		mdf_invoices.VAT_RATE if mdf_invoices._flag(vat) else 0)
	lines, orders, left = [], [], value
	for row, debt in owing:
		if left <= 0:
			break
		part = min(left, Decimal(str(debt)))
		no = search_text.number_in(row.name) or row.name
		lines.append({"name": f"Оплата по заказу № {no} от {_day(row.transaction_date)}", "qty": 1.0, "unit": "усл.",
					  "price": float(part), "amount": float(part)})
		orders.append({"order": row.name, "number": no, "amount": float(part)})
		left -= part
	invoice = {
		"no": str(film_invoice.next_number(company, made_on.year)),
		"on": str(made_on),
		"due_on": str(getdate(due)),
		"amount": float(value),
		"payer": name,
		"bin": bin,
		"vat": rate,
		"lines": lines,
		"orders": orders,
		"payments": [],
		"cancelled": False,
		"by": frappe.session.user,
	}
	_keep(customer, [*_kept(customer), invoice])
	values = {mdf_invoices.PAYER: name if name != c.customer_name else None}
	if bin:
		values["tax_id"] = bin
	frappe.db.set_value("Customer", customer, values, update_modified=False)
	if rate != mdf_invoices.vat_default(company):
		frappe.db.set_default(f"{mdf_invoices._VAT}:{company}", "1" if rate else "")
	c.add_comment("Comment", f"Счёт на долг № {invoice['no']}: {_money(value)}, {name} — заказы "
				  + ", ".join(f"№ {o['number']}" for o in orders) + ".")
	audit.record_audit(action="customer.invoice", entity_type="Customer", entity_id=customer, company=company,
					   diff={"no": invoice["no"], "amount": float(value), "payer": name, "orders": orders})
	return find(customer, invoice["no"])


def printed(customer: str, no: str, company: str) -> dict:
	"""An invoice as it was issued, with the factory's requisites."""
	facade_prices.ensure_editor()
	inv = find(customer, no)
	with material_stock.granted():
		requisites = film_invoice.requisites(company)
	return {"invoice": inv, "requisites": requisites}


def cancel(customer: str, no: str, reason: str) -> None:
	"""An invoice made by mistake, struck out; its number is not used again."""
	facade_prices.ensure_editor()
	inv = find(customer, no)
	if inv["state"] != "open":
		frappe.throw("По счёту уже есть оплата — его не отменить.")
	kept = _kept(customer)
	for row in kept:
		if row["no"] == inv["no"]:
			row["cancelled"] = True
	_keep(customer, kept)
	frappe.get_doc("Customer", customer).add_comment("Comment", f"Счёт на долг № {no} отменён. Причина: {reason}")
	audit.record_audit(action="customer.invoice_cancelled", entity_type="Customer", entity_id=customer,
					   diff={"no": no, "reason": reason})


def open_one(customer: str, no: str) -> dict:
	"""The invoice a payment is entered by: refused when struck out or paid."""
	inv = find(customer, no)
	if inv["state"] == "cancelled":
		frappe.throw(f"Счёт № {no} отменён.")
	if inv["state"] == "paid":
		frappe.throw(f"Счёт № {no} уже оплачен.")
	return inv


def paid_by(customer: str, no: str, amount: float, entries: list[str]) -> None:
	"""A payment came by the invoice: up to what is left of it counts."""
	inv = open_one(customer, no)
	counted = min(flt(amount), flt(inv["amount"]) - flt(inv["paid"]))
	if counted <= 0:
		return
	kept = _kept(customer)
	for row in kept:
		if row["no"] == inv["no"]:
			row["payments"] = [*(row.get("payments") or []),
							   {"on": nowdate(), "amount": round(counted, 2),
								"entry": entries[0] if entries else None, "entries": entries}]
	_keep(customer, kept)


def find(customer: str, no: str) -> dict:
	for inv in rows(customer):
		if inv["no"] == str(no):
			return inv
	frappe.throw(f"Счёта № {no} у этого клиента нет.")


def _state(inv: dict, paid: float) -> str:
	if inv.get("cancelled"):
		return "cancelled"
	if paid >= flt(inv["amount"]) - 0.5:
		return "paid"
	return "part" if paid > 0 else "open"


def _kept(customer: str) -> list[dict]:
	raw = frappe.db.get_value("Customer", customer, FIELD)
	try:
		kept = frappe.parse_json(raw) if raw else []
	except ValueError:
		kept = []
	return [x for x in kept if isinstance(x, dict) and x.get("no")] if isinstance(kept, list) else []


def _keep(customer: str, kept: list[dict]) -> None:
	frappe.db.set_value("Customer", customer, FIELD, frappe.as_json(kept, indent=None), update_modified=False)


def _day(value) -> str:
	return getdate(value).strftime("%d.%m.%Y") if value else ""


def _money(value) -> str:
	return f"{flt(value):,.0f} ₸".replace(",", " ")
