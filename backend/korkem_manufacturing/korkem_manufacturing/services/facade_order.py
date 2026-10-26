# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Turn a facade quote into a real, submitted Sales Order.

The order is built from a **fresh** quote, computed here on the server from the
same lines — never from figures the client sends back. A manager who quoted
yesterday and orders today gets today's prices, and nobody can edit a total on
the way from the screen to the database.

**One line per facade line**, `qty` = pieces and `rate` = the whole-tenge price
of one piece, so ERPNext's own `qty × rate` reproduces the quoted amount exactly.
The size, milling, finish and options go into structured fields on the line
(`add_facade_order_fields`), not into a description someone has to parse.
Demolition, when ordered, is a line of its own.

**The prepayment** agreed with the customer is stored on the order
(`korkem_prepayment_agreed`). ERPNext's payment schedule is deliberately not
used: it re-derives amounts from percentages and would turn 4 200 ₸ into
4 199.99. What the customer actually paid stays where ERPNext keeps it.

After submit the order's total is read back and compared with the quote. If
they differ — an Item Price or a pricing rule the factory configured that
quietly overrode a rate — the whole order is rolled back with an explanation,
rather than leaving an order whose total nobody agreed to.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import flt, getdate, nowdate

from korkem_manufacturing.services import audit, facade_prices, facade_quote
from korkem_manufacturing.services.scope import current_company

FACADE_ITEM = "KORKEM-FACADE"
DEMOLITION_ITEM = "KORKEM-DEMOLITION"


def create_order(
	*,
	customer: str,
	delivery_date: str,
	lines,
	demolition=False,
	prepayment_amount=None,
	notes: str | None = None,
) -> dict:
	facade_prices.ensure_editor()
	company = current_company()
	customer = _customer(customer, company)
	wanted = _delivery_date(delivery_date)

	quote = facade_quote.quote(lines, demolition=demolition, prepayment_amount=prepayment_amount)
	_ensure_items()

	items = [
		{
			"item_code": FACADE_ITEM,
			"item_name": _line_title(line),
			"description": _line_title(line),
			"qty": line["qty"],
			"uom": "Nos",
			"rate": line["price_per_piece"],
			"delivery_date": str(wanted),
			"korkem_width_mm": int(line["width_mm"]),
			"korkem_height_mm": int(line["height_mm"]),
			"korkem_area_m2": line["area_m2"],
			"korkem_milling": line["milling"],
			"korkem_finish": line["finish"],
			"korkem_double_sided": 1 if line["double_sided"] else 0,
			"korkem_customer_material": 1 if line["customer_material"] else 0,
		}
		for line in quote["lines"]
	]
	if quote["demolition"]:
		items.append(
			{
				"item_code": DEMOLITION_ITEM,
				"item_name": "Демонтаж",
				"description": f"Демонтаж ({quote['demolition_basis']})",
				"qty": 1,
				"uom": "Nos",
				"rate": quote["demolition"],
				"delivery_date": str(wanted),
			}
		)

	savepoint = "korkem_facade_order_" + frappe.generate_hash(length=8)
	frappe.db.savepoint(savepoint)
	try:
		order = frappe.get_doc(
			{
				"doctype": "Sales Order",
				"company": company,
				"customer": customer,
				"transaction_date": nowdate(),
				"delivery_date": str(wanted),
				"order_type": "Sales",
				# The rates are the quote's. A pricing rule silently applied on
				# top would make a total nobody agreed to.
				"ignore_pricing_rule": 1,
				"disable_rounded_total": 1,
				"items": items,
				"terms": (notes or "").strip()[:2000] or None,
			}
		)
		order.insert()
		order.submit()
		# Written past the permission layer on purpose: the figure is the
		# server's own (from the quote above), and a Sales User has no write
		# at the level this money field sits on.
		order.db_set("korkem_prepayment_agreed", quote["prepayment"], update_modified=False)
		order.reload()

		if Decimal(str(flt(order.grand_total))) != Decimal(str(quote["total"])):
			frappe.throw(
				f"ERPNext посчитал заказ на {flt(order.grand_total):,.2f} ₸, а расчёт — на "
				f"{quote['total']:,.0f} ₸. Вероятно, в ERPNext настроен налог или правило цены "
				"для этих позиций. Заказ не создан.".replace(",", " ")
			)
	except Exception:
		frappe.db.rollback(save_point=savepoint)
		raise
	frappe.db.release_savepoint(savepoint)

	audit.record_audit(
		action="sales.facade_order_created",
		entity_type="Sales Order",
		entity_id=order.name,
		diff={
			"customer": customer,
			"pieces": quote["pieces"],
			"area_m2": quote["area_m2"],
			"total": quote["total"],
			"prepayment": quote["prepayment"],
		},
	)
	return {
		"sales_order": order.name,
		"customer": customer,
		"delivery_date": str(wanted),
		"pieces": quote["pieces"],
		"area_m2": quote["area_m2"],
		"total": quote["total"],
		"prepayment": quote["prepayment"],
		"balance": quote["balance"],
		"status": "created",
	}


def customers(search: str | None = None, limit: int = 20) -> list[dict]:
	"""Customers an order can be written for, for the picker on the quote screen.

	ERPNext Customers (not CRM organisations): the order is an ERPNext Sales
	Order and must name one. Filtered by the same company rule `_customer`
	enforces, so the picker never offers a name the order would refuse.
	"""
	facade_prices.ensure_editor()
	company = current_company()
	limit = max(1, min(int(limit or 20), 50))
	filters = {"disabled": 0}
	if search and search.strip():
		filters["customer_name"] = ["like", f"%{search.strip()}%"]
	rows = frappe.get_all(
		"Customer",
		filters=filters,
		fields=["name", "customer_name", "mobile_no"],
		order_by="modified desc",
		limit_page_length=limit * 3,
	)
	allowed_for: dict[str, set] = {}
	if rows:
		for row in frappe.get_all(
			"Allowed To Transact With",
			filters={"parent": ["in", [r.name for r in rows]], "parenttype": "Customer"},
			fields=["parent", "company"],
		):
			allowed_for.setdefault(row.parent, set()).add(row.company)
	return [
		{"name": r.name, "customer_name": r.customer_name or r.name, "phone": r.mobile_no}
		for r in rows
		if r.name not in allowed_for or company in allowed_for[r.name]
	][:limit]


def _customer(name: str, company: str) -> str:
	name = (name or "").strip()
	if not name:
		frappe.throw("Укажите клиента.")
	row = frappe.db.get_value("Customer", name, ["name", "disabled"], as_dict=True)
	if not row:
		frappe.throw(f"Клиент «{name}» не найден.", frappe.DoesNotExistError)
	if row.disabled:
		frappe.throw(f"Клиент «{name}» отключён.")
	# ERPNext's own rule for which companies a customer trades with; an empty
	# list means all of them.
	allowed = frappe.get_all("Allowed To Transact With", filters={"parent": name}, pluck="company")
	if allowed and company not in allowed:
		frappe.throw(f"Клиент «{name}» не найден.", frappe.DoesNotExistError)
	return row.name


def _delivery_date(value) -> object:
	if not value:
		frappe.throw("Укажите срок сдачи заказа.")
	try:
		wanted = getdate(value)
	except Exception:
		frappe.throw(f"Срок «{value}» — не дата.")
	if wanted < getdate(nowdate()):
		frappe.throw("Срок сдачи уже прошёл.")
	return wanted


def _line_title(line: dict) -> str:
	options = "".join(f", {note}" for note in line.get("notes") or [])
	return (
		f"Фасад {line['milling']} — {line['finish']}, "
		f"{int(line['width_mm'])}×{int(line['height_mm'])} мм{options}"
	)[:140]


def _ensure_items() -> None:
	"""The two service items an order is written against, created once.

	Shared masters, like every ERPNext Item. Not stock items: a facade is made
	to measure, and what the shop floor needs is on the line's own fields.
	"""
	group = next(
		(g for g in ("Products", "Services", "All Item Groups") if frappe.db.exists("Item Group", g)),
		None,
	)
	for code, name in ((FACADE_ITEM, "Фасад (на заказ)"), (DEMOLITION_ITEM, "Демонтаж")):
		if frappe.db.exists("Item", code):
			continue
		frappe.get_doc(
			{
				"doctype": "Item",
				"item_code": code,
				"item_name": name,
				"item_group": group,
				"stock_uom": "Nos",
				"is_stock_item": 0,
				"is_sales_item": 1,
				"is_purchase_item": 0,
				"include_item_in_manufacturing": 0,
			}
		).insert(ignore_permissions=True)
