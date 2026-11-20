# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Счёт на оплату» for an MDF order (owner, 20.11.2026: «а здесь должен был
быть счёт на оплату»).

A furniture maker that is a company — a ТОО, an ИП — pays by bank transfer
against an invoice: the factory's requisites, his name and БИН, what he pays
for, the sum. The order's debt is what it was; the invoice gives the money a
number, a day to pay by, and a line on the card — «ждём оплату» until a
payment «По счёту № 7» closes it.

The invoices live on the order (`korkem_invoices`, a list kept as it was
printed, so a copy sent again is the same paper). The numbers are the
company's one series with the film sales' invoices (`film_invoice`). The
payer's name and БИН go on the customer card for the next time; a БИН is the
customer's `tax_id`, as on a film sale's invoice.
"""

from __future__ import annotations

from collections import OrderedDict
from decimal import ROUND_HALF_UP, Decimal

import frappe
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_manufacturing.services import audit, facade_order, facade_prices, film_invoice, material_stock
from korkem_manufacturing.services.scope import current_company

FIELD = "korkem_invoices"
PAYER = "korkem_payer"
#: The rate of VAT in Kazakhstan from 2026 (the new Tax Code), %.
VAT_RATE = 16
_VAT = "korkem_invoice_vat"

_COATING = {"pvc": "плёнка ПВХ", "paint": "покраска", "raw": "без покрытия"}


def rows(doc) -> list[dict]:
	"""The order's invoices, oldest first, with what was paid by each — a
	payment fixed or taken back counts no more."""
	kept = _kept(doc)
	entries = {e for inv in kept for e in inv.get("entries") or []}
	live = {}
	if entries:
		for r in frappe.get_all(
			"Payment Entry Reference",
			filters={"parent": ["in", list(entries)], "reference_doctype": "Sales Order",
					 "reference_name": doc.name, "docstatus": 1},
			fields=["parent", "allocated_amount"],
		):
			live[r.parent] = live.get(r.parent, 0.0) + flt(r.allocated_amount)
	out = []
	for inv in kept:
		paid = sum(live.get(e, 0.0) for e in inv.get("entries") or [])
		out.append({**inv, "paid": flt(paid), "state": _state(inv, paid)})
	return out


def payer(customer: str) -> dict:
	"""Who pays for the customer, as his last invoice said: a company name
	and its БИН; his own name where none was given."""
	row = frappe.db.get_value("Customer", customer, ["customer_name", "tax_id", PAYER], as_dict=True) or {}
	return {"name": row.get(PAYER) or row.get("customer_name") or customer, "bin": row.get("tax_id") or ""}


def vat_default(company: str | None = None) -> int:
	"""VAT on the shop's invoices: its rate when the shop pays VAT, else 0."""
	return VAT_RATE if frappe.db.get_default(f"{_VAT}:{company or current_company()}") == "1" else 0


def issue(doc, *, amount, payer_name: str | None = None, bin: str | None = None, due_on: str | None = None,
		  vat=None) -> dict:
	"""A new invoice for [amount] of what the order owes: numbered, kept on
	the order, the payer remembered on the customer card."""
	facade_prices.ensure_editor()
	value = Decimal(str(flt(amount))).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
	from korkem_manufacturing.services import mdf_orders

	debt = mdf_orders._debt(doc)
	if value <= 0:
		frappe.throw("Сумма счёта больше нуля.")
	if value > debt + Decimal("0.5"):
		frappe.throw(f"По заказу осталось {_money(debt)} — счёт на большую сумму не выставить.")
	name = " ".join(str(payer_name or "").split())[:140] or doc.customer_name
	bin = "".join(str(bin or "").split())
	if bin and not (bin.isdigit() and len(bin) == 12):
		frappe.throw("БИН/ИИН — 12 цифр.")
	made_on = getdate(nowdate())
	due = getdate(due_on) if due_on else add_days(made_on, film_invoice.DUE_DAYS)
	if getdate(due) < made_on:
		frappe.throw("Оплатить до — не раньше дня счёта.")
	rate = vat_default(doc.company) if vat in (None, "") else (VAT_RATE if _flag(vat) else 0)
	whole = abs(value - Decimal(str(flt(doc.grand_total)))) < Decimal("0.5")
	invoice = {
		"no": str(film_invoice.next_number(doc.company, made_on.year)),
		"on": str(made_on),
		"due_on": str(getdate(due)),
		"amount": float(value),
		"payer": name,
		"bin": bin,
		"vat": rate,
		"lines": _lines(doc) if whole else [_part_line(doc, value, debt)],
		"entries": [],
		"cancelled": False,
		"by": frappe.session.user,
	}
	_keep(doc, [*_kept(doc), invoice])
	values = {PAYER: name if name != doc.customer_name else None}
	if bin:
		values["tax_id"] = bin
	frappe.db.set_value("Customer", doc.customer, values, update_modified=False)
	if rate != vat_default(doc.company):
		frappe.db.set_default(f"{_VAT}:{doc.company}", "1" if rate else "")
	doc.add_comment("Comment", f"Счёт на оплату № {invoice['no']}: {_money(value)}, {name}.")
	audit.record_audit(action="mdf.invoice", entity_type="Sales Order", entity_id=doc.name,
					   diff={"no": invoice["no"], "amount": float(value), "payer": name, "bin": bin, "vat": rate})
	return invoice


def printed(doc, no: str) -> dict:
	"""An invoice as it was issued, with the factory's requisites, to print
	or send again."""
	facade_prices.ensure_editor()
	inv = _find(doc, no)
	with material_stock.granted():
		requisites = film_invoice.requisites(doc.company)
	return {"invoice": inv, "requisites": requisites}


def cancel(doc, no: str, reason: str) -> None:
	"""An invoice made by mistake — a wrong sum, a wrong payer: struck out,
	its number never used again."""
	facade_prices.ensure_editor()
	inv = _find(doc, no)
	if inv["state"] != "open":
		frappe.throw("По счёту уже есть оплата — его не отменить.")
	kept = _kept(doc)
	for row in kept:
		if row["no"] == inv["no"]:
			row["cancelled"] = True
	_keep(doc, kept)
	doc.add_comment("Comment", f"Счёт № {no} отменён. Причина: {reason}")
	audit.record_audit(action="mdf.invoice_cancelled", entity_type="Sales Order", entity_id=doc.name,
					   diff={"no": no, "reason": reason})


def paid_by(doc, no: str, entry: str | None) -> None:
	"""A payment came by the invoice: it counts towards it."""
	inv = _find(doc, no)
	if inv["cancelled"]:
		frappe.throw(f"Счёт № {no} отменён.")
	if not entry:
		return
	kept = _kept(doc)
	for row in kept:
		if row["no"] == inv["no"]:
			row["entries"] = [*(row.get("entries") or []), entry]
	_keep(doc, kept)


def relink(doc, old: str, new: str | None) -> None:
	"""A payment fixed: the new entry stands where the old one stood."""
	if not new:
		return
	kept = _kept(doc)
	changed = False
	for row in kept:
		if old in (row.get("entries") or []):
			row["entries"] = [*row["entries"], new]
			changed = True
	if changed:
		_keep(doc, kept)


def _state(inv: dict, paid: float) -> str:
	if inv.get("cancelled"):
		return "cancelled"
	if paid >= flt(inv["amount"]) - 0.5:
		return "paid"
	return "part" if paid > 0 else "open"


def _find(doc, no: str) -> dict:
	for inv in rows(doc):
		if inv["no"] == str(no):
			return inv
	frappe.throw(f"Счёта № {no} в этом заказе нет.")


def _kept(doc) -> list[dict]:
	raw = frappe.db.get_value("Sales Order", doc.name, FIELD)
	try:
		kept = frappe.parse_json(raw) if raw else []
	except ValueError:
		kept = []
	return [x for x in kept if isinstance(x, dict) and x.get("no")] if isinstance(kept, list) else []


def _keep(doc, kept: list[dict]) -> None:
	doc.db_set(FIELD, frappe.as_json(kept, indent=None), update_modified=True)


def _lines(doc) -> list[dict]:
	"""The order as an accountant reads it: the facades by thickness,
	coating and colour, in m²; anything else sold with them, a line each."""
	groups: OrderedDict[tuple, dict] = OrderedDict()
	other = []
	from korkem_manufacturing.services import mdf_orders

	for item in sorted(doc.items, key=lambda i: i.idx):
		if item.item_code != facade_order.FACADE_ITEM:
			other.append({"name": item.item_name or item.item_code, "qty": flt(item.qty), "unit": "шт",
						  "price": flt(item.rate), "amount": flt(item.amount)})
			continue
		coating = item.get("korkem_line_coating") or mdf_orders.coating_of(item.korkem_finish or doc.korkem_finish)
		key = (item.korkem_thickness_mm, coating, item.korkem_decor_top or "")
		g = groups.setdefault(key, {"area": Decimal("0"), "amount": Decimal("0")})
		g["area"] += Decimal(str(flt(item.korkem_area_m2, 2)))
		g["amount"] += Decimal(str(flt(item.amount)))
	out = []
	for (thickness, coating, colour), g in groups.items():
		words = ["Фасады МДФ"]
		if thickness:
			words[0] += f" {thickness} мм"
		if _COATING.get(coating):
			words.append(_COATING[coating])
		if colour:
			words.append(f"«{colour}»")
		area = g["area"]
		out.append({
			"name": ", ".join(words),
			"qty": float(area),
			"unit": "м²",
			"price": float((g["amount"] / area).quantize(Decimal("1"), rounding=ROUND_HALF_UP)) if area else 0.0,
			"amount": float(g["amount"]),
		})
	return [*out, *other]


def _part_line(doc, value: Decimal, debt: Decimal) -> dict:
	"""A part of the order — a prepayment, or what is left: one line, so the
	lines add up to the sum to pay."""
	first = not flt(doc.advance_paid) and value < debt - Decimal("0.5")
	what = "Предоплата" if first else "Оплата"
	return {"name": f"{what} по заказу № {doc.name} (фасады МДФ)", "qty": 1.0, "unit": "усл.",
			"price": float(value), "amount": float(value)}


def _flag(value) -> bool:
	return str(value).strip().lower() in ("1", "true", "yes", "on")


def _money(value) -> str:
	return f"{flt(value):,.0f} ₸".replace(",", " ")
