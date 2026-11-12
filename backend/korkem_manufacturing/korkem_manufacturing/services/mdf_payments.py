# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""A payment of an MDF order fixed or taken back (owner, 09.11.2026).

A payment is never edited in place: its Payment Entry is cancelled and, for a
fix, a new one is made with the right figures. The cancelled one stays on the
card struck through, and the order's history says who did it and why. A
manager may do it on the day the payment was entered — a typo is found at
once; an older payment only the owner touches, since the cash of that day is
counted by then.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, getdate, nowdate

from korkem_manufacturing.services import audit, facade_prices, payments

#: Ready-made reasons the card offers; any other words do as well.
REASONS = ("Ошибка в сумме", "Не тот способ", "Не тот банк", "Внесли дважды")


def rows(order: str) -> list[dict]:
	"""The order's payments, oldest first; a cancelled one says so."""
	from korkem_manufacturing.services.mdf_cash import method_and_bank

	refs = frappe.get_all(
		"Payment Entry Reference",
		filters={"reference_doctype": "Sales Order", "reference_name": order, "docstatus": ["in", [1, 2]]},
		fields=["parent", "allocated_amount", "docstatus"],
	)
	out = []
	for ref in refs:
		entry = frappe.db.get_value(
			"Payment Entry", ref.parent,
			["posting_date", "mode_of_payment", "korkem_bank", "owner", "creation"], as_dict=True,
		)
		if not entry:
			continue
		method, bank = method_and_bank(entry.mode_of_payment, entry.korkem_bank)
		out.append({
			"entry": ref.parent,
			"amount": flt(ref.allocated_amount),
			"date": str(entry.posting_date),
			"method": method,
			"bank": bank,
			"received_by": entry.owner,
			"cancelled": ref.docstatus == 2,
			"_at": entry.creation,
		})
	# Two payments in the same instant come in the order they were numbered.
	out.sort(key=lambda r: (r["date"], str(r["_at"]), r["entry"]))
	for r in out:
		del r["_at"]
	return out


def fix(order, entry: str, *, reason: str, amount, method: str, bank: str | None = None) -> None:
	"""The payment cancelled and entered again with the right figures, on its own date."""
	pe = _entry(order, entry)
	before = _words(flt(_allocated(pe, order)), pe.mode_of_payment, pe.get("korkem_bank"))
	if flt(amount) <= 0:
		frappe.throw("Сумма оплаты больше нуля.")
	paid_on = str(pe.posting_date)
	_take_back(order, pe)
	payments.record_payment(sales_order=order.name, amount=flt(amount), mode_of_payment=method,
							bank=bank, paid_on=paid_on)
	after = _words(flt(amount), method, bank)
	order.add_comment("Comment", f"Оплата исправлена: было {before}, стало {after}. Причина: {reason}")
	audit.record_audit(action="mdf.payment_fixed", entity_type="Sales Order", entity_id=order.name,
					   diff={"entry": entry, "before": before, "after": after, "reason": reason})


def delete(order, entry: str, *, reason: str) -> None:
	pe = _entry(order, entry)
	words = _words(flt(_allocated(pe, order)), pe.mode_of_payment, pe.get("korkem_bank"))
	_take_back(order, pe)
	order.add_comment("Comment", f"Оплата удалена: {words}. Причина: {reason}")
	audit.record_audit(action="mdf.payment_deleted", entity_type="Sales Order", entity_id=order.name,
					   diff={"entry": entry, "payment": words, "reason": reason})


def _entry(order, entry: str):
	facade_prices.ensure_editor()
	if not entry or not frappe.db.exists("Payment Entry", entry):
		frappe.throw("Оплата не найдена.")
	pe = frappe.get_doc("Payment Entry", entry)
	if not any(r.reference_doctype == "Sales Order" and r.reference_name == order.name for r in pe.references):
		frappe.throw("Эта оплата не по этому заказу.")
	if pe.docstatus != 1:
		frappe.throw("Эта оплата уже отменена.")
	if order.get("korkem_handed_over_on") and not _owner():
		frappe.throw("Заказ выдан — оплату исправляет только владелец.")
	if getdate(pe.creation) != getdate(nowdate()) and not _owner():
		frappe.throw("Оплата внесена не сегодня — исправить её может только владелец.")
	return pe


def _take_back(order, pe) -> None:
	pe.flags.ignore_permissions = True
	pe.cancel()
	# What is paid is what the live payments say, not what ERPNext last added up.
	live = frappe.get_all(
		"Payment Entry Reference",
		filters={"reference_doctype": "Sales Order", "reference_name": order.name, "docstatus": 1},
		pluck="allocated_amount",
	)
	order.db_set("advance_paid", flt(sum(flt(v) for v in live)), update_modified=True)


def _allocated(pe, order) -> float:
	return sum(flt(r.allocated_amount) for r in pe.references
			   if r.reference_doctype == "Sales Order" and r.reference_name == order.name)


def _words(amount: float, method: str | None, bank: str | None) -> str:
	from korkem_manufacturing.services.mdf_cash import method_and_bank

	method, bank = method_and_bank(method, bank)
	return " · ".join(x for x in (f"{amount:,.0f} ₸".replace(",", " "), method, bank) if x)


def _owner() -> bool:
	return "System Manager" in frappe.get_roles()
