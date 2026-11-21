# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""One customer on one page (owner, 18.11.2026): who he is, everything he
ordered — facades, CNC, film — what he paid and what he still owes.

Read only. Each part asks its own door, as the general search does: the
orders and the money the facade managers' (`facade_prices.can_edit`), the
film purchases the film staff's (`material_stock.is_staff`). A person who
may open neither is refused; one who may open one sees that one.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import cint, date_diff, flt, nowdate

from korkem_manufacturing.services import (
	audit,
	cnc_orders,
	directions,
	facade_prices,
	material_stock,
	mdf_customers,
	mdf_orders,
	mdf_tags,
	search_text,
)
from korkem_manufacturing.services.scope import current_company

#: The newest orders and payments shown; the totals count all of them.
SHOWN = 100

_FIELDS = ["name", "docstatus", "transaction_date", "delivery_date", "customer", "grand_total", "advance_paid",
		   "korkem_tags", "korkem_direction", "korkem_decor_top", "korkem_ready_on", "korkem_handed_over_on",
		   "korkem_hold_reason", "korkem_cnc_started_on", "korkem_told_on", "korkem_reminded_on",
		   "korkem_finish", "korkem_extra_stages", "korkem_coatings", "korkem_reminders",
		   *mdf_orders.STAGES.values()]
#: A debt older than this, days, is told apart on the card (owner, 21.11.2026).
OLD_DEBT_DAYS = 7


def card(customer: str) -> dict:
	editor = facade_prices.can_edit()
	film = material_stock.is_staff()
	if not (editor or film):
		frappe.throw("Карточку клиента видят менеджеры.", frappe.PermissionError)
	company = current_company()
	if not customer or not frappe.db.exists("Customer", customer) or not mdf_customers._allowed([customer], company):
		frappe.throw("Такого клиента нет.", frappe.DoesNotExistError)
	c = frappe.get_doc("Customer", customer)
	out = {
		"customer": c.name,
		"name": c.customer_name or c.name,
		"phone": c.mobile_no,
		"organization": c.get("korkem_organization"),
		"tags": mdf_tags.parse(c.get("korkem_tags")),
		"film_customer": bool(c.get("korkem_film_customer")),
		"can": {"facades": editor, "film": film},
	}
	if editor:
		out.update(_orders(company, c.name))
		# His terms and the limit on what he may owe, on the card (owner,
		# 21.11.2026: «как бы ты настроил»).
		terms_row = frappe.db.get_value("Customer", c.name, list(mdf_customers.TERMS.values()), as_dict=True) or {}
		out["terms"] = mdf_customers._terms_of(terms_row)
		out["limit"] = mdf_customers.debt_limit(c.name, company)
	if film and c.get("korkem_film_customer"):
		from korkem_manufacturing.services import film_dept

		row = frappe.get_all("Customer", filters={"name": c.name}, fields=film_dept.CUSTOMER_FIELDS)
		out["film"] = film_dept.customers_of(row)[0] if row else None
	return out


def _orders(company: str, customer: str) -> dict:
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "customer": customer, "docstatus": ["<", 2],
				 "korkem_direction": ["in", [directions.FACADES, directions.CNC]]},
		fields=_FIELDS, order_by="transaction_date desc, creation desc", limit_page_length=0,
	)
	orders, total, paid, owed = [], Decimal(0), Decimal(0), Decimal(0)
	dates = []
	areas = _areas([r.name for r in rows])
	today = nowdate()
	for r in rows:
		cnc = r.korkem_direction == directions.CNC
		debt = (cnc_orders._debt if cnc else mdf_orders._debt)(r)
		if r.docstatus == 1:
			total += Decimal(str(flt(r.grand_total)))
			paid += Decimal(str(flt(r.advance_paid)))
			owed += debt
			dates.append(str(r.transaction_date))
		orders.append({
			"name": r.name,
			"number": search_text.number_in(r.name),
			"cnc": cnc,
			"status": (cnc_orders.status_of if cnc else mdf_orders.status_of)(r),
			"created_on": str(r.transaction_date) if r.transaction_date else None,
			"due": str(r.delivery_date) if r.delivery_date else None,
			"decor": r.get("korkem_decor_top"),
			"total": flt(r.grand_total),
			"paid": flt(r.advance_paid),
			"debt": float(debt),
			"told_on": str(r.korkem_told_on) if r.korkem_told_on else None,
			"ready_on": str(r.korkem_ready_on) if r.korkem_ready_on else None,
			"handed_over_on": str(r.korkem_handed_over_on) if r.korkem_handed_over_on else None,
			"area": areas.get(r.name, 0.0),
			# Where it is in the shop: its stages in order, each done or not.
			"stages": [] if cnc or r.docstatus != 1 else [
				{"key": k, "done": bool(r.get(mdf_orders.STAGES[k]))}
				for k in mdf_orders.stages_of(r) if k in mdf_orders.STAGES
			],
			# How long the money has been owed: since it left the shop, else
			# since it was accepted.
			"debt_days": date_diff(today, r.korkem_handed_over_on or r.transaction_date)
			if debt > 0 and r.docstatus == 1 and (r.korkem_handed_over_on or r.transaction_date) else None,
		})
	accepted = len(dates)
	payments = frappe.db.sql(
		"""
		select pe.posting_date as date, pe.mode_of_payment as method, per.reference_name as order_name,
			   so.korkem_direction as direction, per.allocated_amount as amount
		from `tabPayment Entry Reference` per
		join `tabPayment Entry` pe on pe.name = per.parent
		join `tabSales Order` so on so.name = per.reference_name
		where per.reference_doctype = 'Sales Order' and pe.docstatus = 1 and pe.company = %(company)s
		  and so.customer = %(customer)s
		order by pe.posting_date desc, pe.creation desc
		limit %(limit)s
		""",
		{"company": company, "customer": customer, "limit": SHOWN},
		as_dict=True,
	)
	return {
		"orders": orders[:SHOWN],
		"payments": [{"date": str(p.date), "method": p.method, "order": p.order_name,
					  "cnc": p.direction == directions.CNC, "amount": flt(p.amount)} for p in payments],
		"figures": {
			"orders": accepted,
			"total": float(total),
			"paid": float(paid),
			"debt": float(owed),
			"average": float(total / accepted) if accepted else 0.0,
			"first": min(dates) if dates else None,
			"last": max(dates) if dates else None,
		},
	}


def _areas(orders: list[str]) -> dict[str, float]:
	"""The facades' square metres of each order, in one query."""
	if not orders:
		return {}
	rows = frappe.db.sql(
		"""select parent, sum(korkem_area_m2) as area from `tabSales Order Item`
		   where parenttype = 'Sales Order' and parent in %(orders)s group by parent""",
		{"orders": tuple(orders)}, as_dict=True,
	)
	return {r.parent: flt(r.area, 2) for r in rows}


def _owing(company: str, customer: str) -> list:
	"""His accepted orders that still owe, the oldest first."""
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "customer": customer, "docstatus": 1,
				 "korkem_direction": ["in", [directions.FACADES, directions.CNC]]},
		fields=_FIELDS, order_by="transaction_date asc, creation asc", limit_page_length=0,
	)
	out = []
	for r in rows:
		debt = (cnc_orders._debt if r.korkem_direction == directions.CNC else mdf_orders._debt)(r)
		if debt > 0:
			out.append((r, debt))
	return out


def _customer(customer: str, company: str):
	if not customer or not frappe.db.exists("Customer", customer) or not mdf_customers._allowed([customer], company):
		frappe.throw("Такого клиента нет.", frappe.DoesNotExistError)
	return frappe.get_doc("Customer", customer)


def pay(customer: str, amount, method: str, bank: str | None = None, idempotency_key: str | None = None) -> dict:
	"""One payment for all he owes (owner, 21.11.2026: «Оплата на весь долг»):
	the money closes the oldest orders first, a payment on each, so seven
	orders are not paid one by one. More than he owes is refused — an
	overpayment is entered on its order."""
	facade_prices.ensure_editor()
	company = current_company()
	c = _customer(customer, company)
	value = Decimal(str(flt(amount))).quantize(Decimal("0.01"))
	if value <= 0:
		frappe.throw("Сумма оплаты больше нуля.")
	owing = _owing(company, c.name)
	total = sum((d for _, d in owing), Decimal(0))
	if value > total + Decimal("0.5"):
		frappe.throw(f"Он должен {_money(total)} — больше не внести одной оплатой; переплату вносят в заказ.")
	from korkem_manufacturing.services import mdf_payments, payments

	left, split = value, []
	for row, debt in owing:
		if left <= 0:
			break
		part = min(left, debt)
		payments.record_payment(
			sales_order=row.name, amount=float(part), mode_of_payment=method, bank=bank,
			idempotency_key=f"{idempotency_key}:{row.name}" if idempotency_key else None,
		)
		frappe.get_doc("Sales Order", row.name).add_comment(
			"Comment", f"Оплата (общая по клиенту): {mdf_payments._words(float(part), method, bank)}.")
		split.append({"order": row.name, "number": search_text.number_in(row.name), "amount": float(part)})
		left -= part
	c.add_comment("Comment", f"Оплата {_money(value)} разнесена по заказам: "
				  + ", ".join(f"№ {s['number'] or s['order']} — {_money(s['amount'])}" for s in split) + ".")
	audit.record_audit(action="customer.pay", entity_type="Customer", entity_id=c.name,
					   diff={"amount": float(value), "method": method, "split": split}, company=company)
	return {"split": split, "card": card(c.name)}


def debt_text(customer: str) -> dict:
	"""The reminder of all he owes, in the owner's words for a debt: the
	orders by number, the sum — to send as it is."""
	facade_prices.ensure_editor()
	from korkem_manufacturing.services import customer_messages

	company = current_company()
	c = _customer(customer, company)
	owing = _owing(company, c.name)
	total = sum((d for _, d in owing), Decimal(0))
	numbers = ", ".join(str(search_text.number_in(r.name) or r.name) for r, _ in owing)
	text = customer_messages._fill(
		customer_messages.template(customer_messages.DEBT, company),
		имя=(c.customer_name or "").split(" (")[0],
		номер=numbers,
		сумма=_money(total),
		долг=_money(total),
		долг_строка="",
		компания=customer_messages._company_name(company),
	)
	return {"phone": c.mobile_no, "text": text, "debt": float(total), "orders": [r.name for r, _ in owing]}


def reminded(customer: str) -> dict:
	"""The reminder was sent: each order owing remembers the day, the card
	says it once."""
	facade_prices.ensure_editor()
	company = current_company()
	c = _customer(customer, company)
	owing = _owing(company, c.name)
	today = nowdate()
	for r, _ in owing:
		frappe.db.set_value("Sales Order", r.name, {"korkem_reminded_on": today,
													"korkem_reminders": cint(r.korkem_reminders) + 1},
							update_modified=False)
	total = sum((d for _, d in owing), Decimal(0))
	c.add_comment("Comment", f"Напомнили о долге {_money(total)}: заказы "
				  + ", ".join(f"№ {search_text.number_in(r.name) or r.name}" for r, _ in owing) + ".")
	audit.record_audit(action="customer.reminded", entity_type="Customer", entity_id=c.name,
					   diff={"debt": float(total), "orders": [r.name for r, _ in owing]}, company=company)
	return card(c.name)


def add_note(customer: str, text: str) -> list[dict]:
	"""A note on the customer — «звонить после 14:00» — in his history."""
	if not (facade_prices.can_edit() or material_stock.is_staff()):
		frappe.throw("Заметки о клиенте пишут менеджеры.", frappe.PermissionError)
	note = " ".join(str(text or "").split())[:500]
	if not note:
		frappe.throw("Напишите заметку.")
	c = _customer(customer, current_company())
	c.add_comment("Comment", note)
	return history(c.name)


def history(customer: str) -> list[dict]:
	"""Everything that happened with him on one line, newest first (owner,
	21.11.2026: «а истории заказа нету ли тут?»): his orders accepted, ready,
	handed over; what was written on each — payments, invoices, reminders;
	and the notes on him. Each says its kind, for the card's filters."""
	editor = facade_prices.can_edit()
	if not (editor or material_stock.is_staff()):
		frappe.throw("Историю клиента видят менеджеры.", frappe.PermissionError)
	company = current_company()
	c = _customer(customer, company)
	out = []
	for n in frappe.get_all("Comment", filters={"reference_doctype": "Customer", "reference_name": c.name,
												 "comment_type": "Comment"},
							fields=["creation", "owner", "content"], order_by="creation desc", limit_page_length=200):
		text = frappe.utils.strip_html(n.content or "")
		out.append({"at": str(n.creation)[:16], "by": n.owner, "text": text, "kind": _kind(text, note=True)})
	if editor:
		rows = frappe.get_all(
			"Sales Order",
			filters={"company": company, "customer": c.name, "docstatus": ["<", 2],
					 "korkem_direction": ["in", [directions.FACADES, directions.CNC]]},
			fields=["name", "docstatus", "transaction_date", "grand_total", "korkem_decor_top", "korkem_ready_on",
					"korkem_handed_over_on", "owner"],
			order_by="transaction_date desc", limit_page_length=SHOWN,
		)
		numbers = {r.name: search_text.number_in(r.name) or r.name for r in rows}
		for r in rows:
			no = numbers[r.name]
			if r.docstatus == 1 and r.transaction_date:
				out.append({"at": str(r.transaction_date), "kind": "order", "order": r.name, "number": no,
							"text": " · ".join(x for x in (f"Заказ № {no} принят", r.korkem_decor_top,
														   _money(r.grand_total)) if x)})
			if r.korkem_ready_on:
				out.append({"at": str(r.korkem_ready_on), "kind": "order", "order": r.name, "number": no,
							"text": f"Заказ № {no} готов"})
			if r.korkem_handed_over_on:
				out.append({"at": str(r.korkem_handed_over_on), "kind": "order", "order": r.name, "number": no,
							"text": f"Заказ № {no} выдан"})
		if rows:
			for n in frappe.get_all("Comment", filters={"reference_doctype": "Sales Order",
														 "reference_name": ["in", list(numbers)],
														 "comment_type": "Comment"},
									fields=["creation", "owner", "content", "reference_name"],
									order_by="creation desc", limit_page_length=300):
				text = frappe.utils.strip_html(n.content or "")
				# The card's own line for a payment split across orders says it once.
				if text.startswith("Оплата (общая по клиенту)"):
					continue
				out.append({"at": str(n.creation)[:16], "by": n.owner, "text": text, "kind": _kind(text),
							"order": n.reference_name, "number": numbers.get(n.reference_name)})
	out.sort(key=lambda e: e["at"], reverse=True)
	return out[:400]


def _kind(text: str, note: bool = False) -> str:
	low = text.lower()
	if low.startswith(("оплата", "счёт", "счет", "возврат")) or "разнесена" in low:
		return "money"
	if low.startswith(("напомнили", "клиенту напомнили", "клиенту написали")):
		return "message"
	return "note" if note else "order"


def _money(value) -> str:
	return f"{flt(value):,.0f} ₸".replace(",", " ")
