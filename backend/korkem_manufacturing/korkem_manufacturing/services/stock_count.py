# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The month-end count, and what the month really used.

The owner's rule (29.10.2026): «лучше чисто писать расход — купили 50 листов,
в конце месяца осталось 2 штука, и от него будем отталкиваться… бывает,
косячат сотрудники и клиенты, и от него сбивается счёт».

**The count.** Whoever keeps the warehouse walks the shelf and types what is
there. Each material that differs from the books is set to the counted
figure by one ERPNext Stock Reconciliation — ERPNext's own document for
exactly this, so stock on hand stays ERPNext's figure and the correction keeps
its value. Nothing differs → nothing is posted, and the count still says so.

**The month.** Per material, from ERPNext's stock ledger:

    used in fact   = at the start + bought − at the end
    used by orders = what facade orders wrote off
    unaccounted    = used in fact − used by orders

The last line is the one the owner asked for: spoilt sheets, offcuts thrown
away, something taken «на минутку» — not traced to a person, counted as a
figure that shows whether this month was worse than the last.

**The reminder.** On the month's last two days, if nobody has counted yet,
the owner is reminded once (`stock.count_due`).
"""

from __future__ import annotations

from collections import defaultdict
from decimal import Decimal, InvalidOperation

import frappe
from frappe.utils import add_days, flt, get_first_day, get_last_day, getdate, nowdate

from korkem_manufacturing import domain_events
from korkem_manufacturing.services import audit, material_stock, price_visibility
from korkem_manufacturing.services.scope import current_company

FIELD = "korkem_stock_count"
COUNT_DUE = "stock.count_due"


def _warehouses(company: str) -> list[str]:
	return frappe.get_all("Warehouse", filters={"company": company, "is_group": 0}, pluck="name")


def _rate(item: str, company: str) -> float:
	"""The value a counted sheet carries: its average, else the last purchase."""
	bins = frappe.get_all(
		"Bin",
		filters={"item_code": item, "warehouse": ["in", _warehouses(company)]},
		fields=["actual_qty", "stock_value"],
	)
	qty = sum(flt(b.actual_qty) for b in bins)
	if qty > 0:
		return round(sum(flt(b.stock_value) for b in bins) / qty, 2)
	last = frappe.db.sql(
		"""select d.basic_rate from `tabStock Entry Detail` d join `tabStock Entry` e on e.name = d.parent
		where d.item_code = %s and e.company = %s and e.docstatus = 1 and e.korkem_material_receipt = 1
		order by e.posting_date desc, e.creation desc limit 1""",
		(item, company),
	)
	return flt(last[0][0]) if last else flt(frappe.db.get_value("Item", item, "valuation_rate"))


def _on_hand_by_warehouse(item: str, company: str) -> dict[str, float]:
	return {
		b.warehouse: flt(b.actual_qty)
		for b in frappe.get_all(
			"Bin",
			filters={"item_code": item, "warehouse": ["in", _warehouses(company)]},
			fields=["warehouse", "actual_qty"],
		)
		if flt(b.actual_qty)
	}


def record(counted: dict | str, counted_on: str | None = None, note: str | None = None) -> dict:
	"""Set each material to what was counted on the shelf.

	`counted` maps a material to the quantity found. A material whose stock
	sits in several warehouses is counted in the main one, and the others are
	left as they are — the count says which.
	"""
	material_stock._ensure_editor()
	company = current_company()
	if isinstance(counted, str):
		counted = frappe.parse_json(counted)
	if not isinstance(counted, dict) or not counted:
		frappe.throw("Введите, сколько чего на полке.")
	day = getdate(counted_on) if counted_on else getdate(nowdate())
	if day > getdate(nowdate()):
		frappe.throw("Пересчёт не может быть в будущем.")
	main = material_stock._receiving_warehouse(company, None)

	rows: list[dict] = []
	lines: list[dict] = []
	for item, raw in counted.items():
		material_stock._own_item(item)
		try:
			qty = Decimal(str(raw).replace(",", "."))
		except (InvalidOperation, ValueError):
			frappe.throw(f"«{raw}» — не число.")
		if not qty.is_finite() or qty < 0 or qty > material_stock.MAX_QTY:
			frappe.throw("Количество на полке — от нуля и больше.")
		unit = frappe.db.get_value("Item", item, "stock_uom")
		if material_stock._whole_units(unit) and qty != qty.to_integral_value():
			frappe.throw(f"«{unit}» считается только целыми.")
		by_wh = _on_hand_by_warehouse(item, company)
		elsewhere = round(sum(q for wh, q in by_wh.items() if wh != main), 3)
		books_main = round(by_wh.get(main, 0.0), 3)
		title = frappe.db.get_value("Item", item, "item_name")
		if float(qty) < elsewhere:
			frappe.throw(
				f"{title}: на других складах числится {elsewhere:g}, больше насчитанного. "
				"Пересчитайте те склады отдельно."
			)
		# The count is of the whole material; the main shelf takes the difference.
		target = round(float(qty) - elsewhere, 3)
		before = round(books_main + elsewhere, 3)
		rows.append(
			{
				"item": item,
				"title": title,
				"unit": unit,
				"books": before,
				"counted": float(qty),
				"difference": round(float(qty) - before, 3),
			}
		)
		if abs(target - books_main) < 1e-9:
			continue
		lines.append(
			{
				"item_code": item,
				"warehouse": main,
				"qty": target,
				"valuation_rate": _rate(item, company) or 0,
			}
		)

	reconciliation = None
	if lines:
		doc = frappe.get_doc(
			{
				"doctype": "Stock Reconciliation",
				"company": company,
				"purpose": "Stock Reconciliation",
				"posting_date": str(day),
				"set_posting_time": 1,
				FIELD: 1,
				"remarks": ("Пересчёт склада. " + (note or "").strip())[:500],
				"items": lines,
			}
		)
		# Who may count is decided above, by role (the warehouse's editors).
		# ERPNext's reconciliation additionally asks the *session* user for
		# write on Stock Reconciliation while it reads the balance — a right a
		# head of sales does not hold upstream — so the document is posted as
		# the system and then named after the person who counted.
		person = frappe.session.user
		frappe.set_user("Administrator")
		try:
			doc.insert(ignore_permissions=True)
			doc.submit()
		finally:
			frappe.set_user(person)
		frappe.db.set_value("Stock Reconciliation", doc.name, "owner", person, update_modified=False)
		reconciliation = doc.name
	audit.record_audit(
		action="stock.counted",
		entity_type="Stock Reconciliation" if reconciliation else "Company",
		entity_id=reconciliation or company,
		diff={"counted_on": str(day), "rows": {r["item"]: [r["books"], r["counted"]] for r in rows}},
	)
	return {"reconciliation": reconciliation, "counted_on": str(day), "rows": rows}


def counts(month: str | None = None) -> list[dict]:
	"""This month's counts, newest first."""
	material_stock._ensure_staff()
	first, last = _month(month)
	return [
		{"reconciliation": r.name, "counted_on": str(r.posting_date), "by": r.owner}
		for r in frappe.get_all(
			"Stock Reconciliation",
			filters={"company": current_company(), FIELD: 1, "docstatus": 1, "posting_date": ["between", [first, last]]},
			fields=["name", "posting_date", "owner"],
			order_by="posting_date desc, creation desc",
		)
	]


def _month(month: str | None):
	try:
		first = get_first_day(getdate(f"{month}-01") if month else getdate(nowdate()))
	except Exception:
		frappe.throw("Месяц — в виде 2026-10.")
	return first, get_last_day(first)


def month_usage(month: str | None = None) -> dict:
	"""Per material: at the start, bought, at the end, used in fact, used by
	orders, unaccounted — from ERPNext's stock ledger."""
	material_stock._ensure_staff()
	company = current_company()
	first, last = _month(month)
	items = frappe.get_all(
		"Item",
		filters={"korkem_material_company": company},
		fields=["name", "item_name", "stock_uom", "korkem_material_kind"],
		limit_page_length=1000,
	)
	if not items:
		return {"month": str(first)[:7], "materials": [], "prices_visible": price_visibility.can_see_prices()}
	names = [i.name for i in items]
	warehouses = _warehouses(company)

	# Balances are read as ERPNext keeps them: the last `qty_after_transaction`
	# per item and warehouse. A reconciliation's ledger row carries the
	# counted balance there and `actual_qty` 0 — summing quantities would
	# miss every count (found by test_the_owner_s_month, 30.10.2026).
	def balance(before_or_on: str, day) -> dict[str, float]:
		last_of: dict[tuple[str, str], float] = {}
		for r in frappe.db.sql(
			f"""select item_code, warehouse, qty_after_transaction q from `tabStock Ledger Entry`
			where is_cancelled = 0 and posting_date {before_or_on} %(day)s
				and item_code in %(items)s and warehouse in %(whs)s
			order by posting_date, posting_time, creation""",
			{"day": day, "items": tuple(names), "whs": tuple(warehouses)},
			as_dict=True,
		):
			last_of[(r.item_code, r.warehouse)] = flt(r.q)  # the latest row wins
		result: dict[str, float] = defaultdict(float)
		for (item, _warehouse), qty in last_of.items():
			result[item] += qty
		return result

	opening = balance("<", first)
	closing = balance("<=", last)

	moves = defaultdict(lambda: {"in": 0.0, "orders": 0.0, "count": 0.0, "other": 0.0, "count_value": 0.0, "used_value": 0.0})
	for r in frappe.db.sql(
		"""select sle.item_code, sle.actual_qty, sle.stock_value_difference, sle.voucher_type,
			se.korkem_material_receipt, se.korkem_sales_order, se.purpose, sr.korkem_stock_count
		from `tabStock Ledger Entry` sle
		left join `tabStock Entry` se on sle.voucher_type = 'Stock Entry' and se.name = sle.voucher_no
		left join `tabStock Reconciliation` sr on sle.voucher_type = 'Stock Reconciliation' and sr.name = sle.voucher_no
		where sle.is_cancelled = 0 and sle.posting_date between %s and %s
			and sle.item_code in %s and sle.warehouse in %s""",
		(first, last, tuple(names), tuple(warehouses)),
		as_dict=True,
	):
		m = moves[r.item_code]
		qty = flt(r.actual_qty)
		if r.voucher_type == "Stock Entry" and r.korkem_material_receipt and qty > 0:
			m["in"] += qty
		elif r.voucher_type == "Stock Entry" and r.korkem_sales_order and qty < 0:
			m["orders"] += -qty
			m["used_value"] += -flt(r.stock_value_difference)
		elif r.voucher_type == "Stock Reconciliation":
			m["count"] += qty
			m["count_value"] += flt(r.stock_value_difference)
		else:
			m["other"] += qty

	allowed = price_visibility.can_see_prices()
	rows = []
	for i in items:
		m = moves[i.name]
		start = round(opening[i.name], 3)
		end = round(closing[i.name], 3)
		used = round(start + m["in"] - end, 3)
		if not (start or m["in"] or end or used):
			continue
		unaccounted = round(used - m["orders"], 3)
		rows.append(
			{
				"item": i.name,
				"title": i.item_name,
				"kind": i.korkem_material_kind,
				"unit": i.stock_uom,
				"start": start,
				"bought": round(m["in"], 3),
				"end": end,
				"used": used,
				"by_orders": round(m["orders"], 3),
				"unaccounted": unaccounted,
				# What the count wrote off, in money — the loss, when prices are shown.
				"unaccounted_value": price_visibility.money(round(-m["count_value"], 2), allowed=allowed),
			}
		)
	last_count = frappe.get_all(
		"Stock Reconciliation",
		filters={"company": company, FIELD: 1, "docstatus": 1, "posting_date": ["between", [first, last]]},
		fields=["posting_date"],
		order_by="posting_date desc",
		limit=1,
	)
	return {
		"month": str(first)[:7],
		"counted_on": str(last_count[0].posting_date) if last_count else None,
		"materials": rows,
		"prices_visible": allowed,
	}


def remind() -> int:
	"""Hourly: on the month's last two days, remind each company that has
	materials and no count this month. Said once a month (the key suffix)."""
	today = getdate(nowdate())
	last = get_last_day(today)
	if today < add_days(last, -1):
		return 0
	first = get_first_day(today)
	companies = frappe.get_all(
		"Item", filters={"korkem_material_company": ["is", "set"], "disabled": 0},
		pluck="korkem_material_company", distinct=True,
	)
	reminded = 0
	for company in companies:
		if not company or frappe.db.exists(
			"Stock Reconciliation",
			{"company": company, FIELD: 1, "docstatus": 1, "posting_date": ["between", [first, last]]},
		):
			continue
		domain_events.emit(COUNT_DUE, company=company, month=str(first)[:7])
		reminded += 1
	return reminded
