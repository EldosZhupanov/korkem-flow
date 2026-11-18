# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Кому написать» — the customers to tell something today (owner, 18.11.2026).

Two messages a facade shop sends every day, and forgets as often:

- **«Заказ готов»** — an order whose stages are all done and whose customer
  has not been told. The sooner he knows, the sooner the shelf is free and
  the money comes in.
- **«Напоминание о долге»** — an order handed over with money still owed,
  a few days after it left (`AFTER_DAYS`), and again some days after the
  last reminder (`REPEAT_DAYS`) — never every day. The film department's
  debtors are listed beside them, by the department's own rule.

**A person sends it.** The text is prepared here, in the owner's words (the
templates are his to change), and the manager opens it in WhatsApp, reads it
and presses send. Nothing goes to a customer by itself: an automatic message
in the shop's name is the shop's decision, made per message (R10). When the
manager has sent it, `mark` records the day — on the order, in its history
and in the audit trail — and the row leaves the list.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import add_days, cint, flt, getdate, nowdate

from korkem_manufacturing.services import (
	audit,
	cnc_orders,
	directions,
	facade_prices,
	material_stock,
	mdf_orders,
	search_text,
)
from korkem_manufacturing.services.scope import current_company

READY, DEBT, FILM_DEBT = "ready", "debt", "film_debt"
KINDS = (READY, DEBT, FILM_DEBT)

#: A debt is reminded of this many days after the order left the shop…
AFTER_DAYS = 3
#: …and again no sooner than this many days after the last reminder.
REPEAT_DAYS = 4

#: The owner's words, until he writes his own. Placeholders in braces:
#: {имя} {номер} {сумма} {долг} {компания}.
DEFAULTS = {
	READY: "Здравствуйте, {имя}! Ваш заказ № {номер} готов, можно забирать.{долг_строка} Ждём вас! {компания}",
	DEBT: "Здравствуйте, {имя}! Напоминаем об оплате по заказу № {номер}: остаток {долг}. Спасибо! {компания}",
	FILM_DEBT: "Здравствуйте, {имя}! Напоминаем об оплате за плёнку: остаток {долг}. Спасибо! {компания}",
}
#: Added to «готов» when something is still owed.
DEBT_LINE = " К оплате: {долг}."

_KEY = "korkem_message_{kind}:{company}"
_FILM_MARK = "korkem_film_reminded:{customer}"


def _money(value) -> str:
	return f"{flt(value):,.0f} ₸".replace(",", " ")


def _company_name(company: str) -> str:
	return frappe.db.get_value("Company", company, "company_name") or company


def template(kind: str, company: str | None = None) -> str:
	if kind not in KINDS:
		frappe.throw(f"Нет такого сообщения: {kind}.")
	own = frappe.db.get_default(_KEY.format(kind=kind, company=company or current_company()))
	return own or DEFAULTS[kind]


def templates() -> dict:
	"""The three texts as they are now, and the owner's defaults beside them."""
	facade_prices.ensure_editor()
	company = current_company()
	return {kind: {"text": template(kind, company), "default": DEFAULTS[kind]} for kind in KINDS}


def set_template(kind: str, text: str | None = None) -> dict:
	"""The owner's own words; empty — back to the default."""
	facade_prices.ensure_editor()
	if kind not in KINDS:
		frappe.throw(f"Нет такого сообщения: {kind}.")
	company = current_company()
	text = (text or "").strip()[:1000]
	if text and "{имя}" not in text:
		frappe.throw("В тексте должно быть {имя} — так клиент видит, что пишут ему.")
	frappe.db.set_default(_KEY.format(kind=kind, company=company), text or None)
	audit.record_audit(action="customer_messages.template", entity_type="Company", entity_id=company,
					   diff={"kind": kind, "text": text or None}, company=company)
	return templates()


def _fill(text: str, **values) -> str:
	for key, value in values.items():
		text = text.replace("{" + key + "}", str(value))
	return " ".join(text.split())


def _phone(row) -> str | None:
	return frappe.db.get_value("Customer", row.customer, "mobile_no") or row.get("contact_mobile") or None


def _order_text(kind: str, row, company: str) -> str:
	debt = (cnc_orders._debt if row.korkem_direction == directions.CNC else mdf_orders._debt)(row)
	return _fill(
		template(kind, company),
		имя=(row.customer_name or "").split(" (")[0],
		номер=search_text.number_in(row.name) or row.name,
		сумма=_money(row.grand_total),
		долг=_money(debt),
		долг_строка=_fill(DEBT_LINE, долг=_money(debt)) if debt > 0 else "",
		компания=_company_name(company),
	)


_FIELDS = ["name", "customer", "customer_name", "contact_mobile", "docstatus", "grand_total", "advance_paid",
		   "korkem_tags", "korkem_direction", "korkem_ready_on", "korkem_handed_over_on", "korkem_hold_reason",
		   "korkem_told_on", "korkem_reminded_on", "korkem_reminders", "delivery_date"]


def _row(row, kind: str, company: str) -> dict:
	debt = (cnc_orders._debt if row.korkem_direction == directions.CNC else mdf_orders._debt)(row)
	return {
		"kind": kind,
		"order": row.name,
		"number": search_text.number_in(row.name),
		"cnc": row.korkem_direction == directions.CNC,
		"customer": row.customer,
		"customer_name": row.customer_name,
		"phone": _phone(row),
		"total": flt(row.grand_total),
		"debt": float(debt),
		"ready_on": str(row.korkem_ready_on) if row.korkem_ready_on else None,
		"handed_over_on": str(row.korkem_handed_over_on) if row.korkem_handed_over_on else None,
		"told_on": str(row.korkem_told_on) if row.korkem_told_on else None,
		"reminded_on": str(row.korkem_reminded_on) if row.korkem_reminded_on else None,
		"reminders": cint(row.korkem_reminders),
		"text": _order_text(kind, row, company),
	}


def todo() -> dict:
	"""Who to write to today: orders ready and not told, debts due a reminder,
	the film department's debtors."""
	facade_prices.ensure_editor()
	company = current_company()
	today = getdate(nowdate())
	base = {"company": company, "docstatus": 1, "korkem_direction": ["in", [directions.FACADES, directions.CNC]]}
	ready = [
		_row(r, READY, company)
		for r in frappe.get_all("Sales Order", filters={**base, "korkem_ready_on": ["is", "set"],
														  "korkem_handed_over_on": ["is", "not set"],
														  "korkem_told_on": ["is", "not set"]},
								 fields=_FIELDS, order_by="korkem_ready_on asc", limit_page_length=200)
	]
	debts = []
	for r in frappe.get_all("Sales Order", filters={**base, "korkem_handed_over_on": ["<=", add_days(today, -AFTER_DAYS)]},
							fields=_FIELDS, order_by="korkem_handed_over_on asc", limit_page_length=2000):
		if (cnc_orders._debt if r.korkem_direction == directions.CNC else mdf_orders._debt)(r) <= 0:
			continue
		if r.korkem_reminded_on and getdate(r.korkem_reminded_on) > add_days(today, -REPEAT_DAYS):
			continue
		debts.append(_row(r, DEBT, company))
	debts.sort(key=lambda d: -d["debt"])
	return {"ready": ready, "debts": debts, "film": _film_debtors(company, today),
			"after_days": AFTER_DAYS, "repeat_days": REPEAT_DAYS}


def _film_debtors(company: str, today) -> list[dict]:
	if not material_stock.is_staff():
		return []
	from korkem_manufacturing.services import film_dept

	out = []
	for c in film_dept.customers():
		if c.get("call") != "debt" or flt(c.get("debt")) <= 0.5:
			continue
		last = frappe.db.get_default(_FILM_MARK.format(customer=c["customer"]))
		if last and getdate(last) > add_days(today, -REPEAT_DAYS):
			continue
		out.append({
			"kind": FILM_DEBT, "customer": c["customer"], "customer_name": c["name"], "phone": c.get("phone"),
			"debt": flt(c["debt"]), "debt_days": c.get("debt_days"), "reminded_on": last or None,
			"text": _fill(template(FILM_DEBT, company), имя=c["name"].split(" (")[0], долг=_money(c["debt"]),
						  компания=_company_name(company)),
		})
	out.sort(key=lambda d: -d["debt"])
	return out


def mark(kind: str, order: str | None = None, customer: str | None = None) -> dict:
	"""The manager has sent it: remember the day, so it is not asked again."""
	facade_prices.ensure_editor()
	company = current_company()
	today = nowdate()
	if kind == FILM_DEBT:
		material_stock._ensure_staff()
		if not customer or not frappe.db.exists("Customer", customer):
			frappe.throw("Такого клиента нет.", frappe.DoesNotExistError)
		frappe.db.set_default(_FILM_MARK.format(customer=customer), today)
		audit.record_audit(action="customer_messages.film_debt", entity_type="Customer", entity_id=customer,
						   diff={"on": today}, company=company)
		return todo()
	if kind not in (READY, DEBT):
		frappe.throw(f"Нет такого сообщения: {kind}.")
	if not order or frappe.db.get_value("Sales Order", order, "company") != company:
		frappe.throw("Такого заказа нет.", frappe.DoesNotExistError)
	doc = frappe.get_doc("Sales Order", order)
	if kind == READY:
		doc.db_set("korkem_told_on", today, update_modified=False)
		doc.add_comment("Comment", "Клиенту написали: заказ готов.")
	else:
		doc.db_set({"korkem_reminded_on": today, "korkem_reminders": cint(doc.korkem_reminders) + 1},
				   update_modified=False)
		doc.add_comment("Comment", "Клиенту напомнили о долге.")
	audit.record_audit(action=f"customer_messages.{kind}", entity_type="Sales Order", entity_id=order,
					   diff={"on": today}, company=company)
	return todo()


def text_for(order: str, kind: str = READY) -> dict:
	"""One order's message, for its card: the phone and the words."""
	facade_prices.ensure_editor()
	company = current_company()
	rows = frappe.get_all("Sales Order", filters={"name": order, "company": company}, fields=_FIELDS)
	if not rows:
		frappe.throw("Такого заказа нет.", frappe.DoesNotExistError)
	return _row(rows[0], kind, company)


def counts(company: str) -> dict:
	"""For the evening summary: how many are waiting to be written to."""
	today = getdate(nowdate())
	base = {"company": company, "docstatus": 1, "korkem_direction": ["in", [directions.FACADES, directions.CNC]]}
	ready = frappe.db.count("Sales Order", {**base, "korkem_ready_on": ["is", "set"],
											"korkem_handed_over_on": ["is", "not set"],
											"korkem_told_on": ["is", "not set"]})
	debts = 0
	owed = Decimal(0)
	for r in frappe.get_all("Sales Order", filters={**base, "korkem_handed_over_on": ["is", "set"]},
							fields=_FIELDS, limit_page_length=0):
		debt = (cnc_orders._debt if r.korkem_direction == directions.CNC else mdf_orders._debt)(r)
		if debt <= 0:
			continue
		owed += debt
		if getdate(r.korkem_handed_over_on) <= add_days(today, -AFTER_DAYS) and not (
			r.korkem_reminded_on and getdate(r.korkem_reminded_on) > add_days(today, -REPEAT_DAYS)
		):
			debts += 1
	return {"ready": ready, "debts": debts, "owed_after_hand_over": float(owed)}

