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
from frappe.utils import flt

from korkem_manufacturing.services import (
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
		   *mdf_orders.STAGES.values()]


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
