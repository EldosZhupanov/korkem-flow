# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Расходники» on the shelf (owner, 25.11.2026): стрейч, ножи, А4,
наждачка — bought, taken, running low.

Each is a cost item counted as `stock` (`cost_items`) with an ERPNext Item
of the kind «Прочее» behind it, so the ledger keeps the shelf:

- **bought** — a Material Receipt at its price (`material_stock.receive`);
  a shop's corner store is a supplier like any other («Магазин» when none
  is named);
- **taken** — anyone on staff, one tap: a Material Issue at the shelf's own
  valuation. That is what the month's consumables cost (`money_flow`);
- **running low** — below its minimum it is said, in the hourly stock
  warning and in the morning brief's «Пора заказать».

Prices are the owner's: the floor sees how many there are, not what they cost.
"""

from __future__ import annotations

from decimal import Decimal, InvalidOperation

import frappe
from frappe.utils import add_days, flt, nowdate

from korkem_manufacturing.services import audit, cost_items, material_stock, stock_alerts
from korkem_manufacturing.services.identity import is_staff
from korkem_manufacturing.services.scope import current_company

SHOP = "Магазин"
#: How far back «взяли за месяц» looks.
RECENT_DAYS = 30


def listing() -> dict:
	"""Every consumable: how many are on the shelf, its minimum, how many
	went in the last month — and, for the owner, its price."""
	_ensure_staff()
	company = current_company()
	cost_items.seed(company)
	rows = _items(company)
	stock = material_stock._stock([r.item for r in rows], company)
	taken = _taken_qty(company, [r.item for r in rows], add_days(nowdate(), -RECENT_DAYS), nowdate())
	owner = cost_items.is_owner()
	out = []
	for r in rows:
		on_hand, price = stock.get(r.item, (0.0, 0.0))
		minimum = flt(r.minimum)
		out.append({
			"item": r.name, "stock_item": r.item, "title": r.title, "unit": r.stock_uom or r.unit,
			"area": r.area, "on_hand": on_hand, "minimum": minimum, "low": minimum > 0 and on_hand < minimum,
			"taken_30d": taken.get(r.item, 0.0), "new": bool(r.is_new),
			"price": price if owner else None,
		})
	out.sort(key=lambda x: (not x["low"], x["title"].lower()))
	return {"items": out, "low": sum(1 for x in out if x["low"]), "can_receive": owner}


def take(cost_item: str, qty, note: str | None = None) -> dict:
	"""Taken off the shelf — one tap from the floor."""
	_ensure_staff()
	company = current_company()
	row = _consumable(cost_item, company)
	quantity = _qty(qty, row.stock_uom)
	on_hand = material_stock._stock([row.item], company).get(row.item, (0.0, 0.0))[0]
	if quantity > Decimal(str(on_hand)) + Decimal("0.0005"):
		frappe.throw(f"На складе {on_hand:g} {row.stock_uom} «{row.title}» — сначала оприходуйте покупку.")
	warehouse = material_stock._receiving_warehouse(company, None)
	entry = frappe.get_doc({
		"doctype": "Stock Entry", "stock_entry_type": "Material Issue", "purpose": "Material Issue",
		"company": company,
		"remarks": f"Расходник: {row.title}" + (f" — {' '.join(str(note).split())[:200]}" if note else ""),
		"items": [{"item_code": row.item, "qty": float(quantity), "uom": row.stock_uom, "stock_uom": row.stock_uom,
				   "conversion_factor": 1, "s_warehouse": warehouse}],
	})
	# Who may take is decided above: anyone on staff, not a stock accountant.
	entry.insert(ignore_permissions=True)
	entry.submit()
	audit.record_audit(action="consumable.taken", entity_type="Stock Entry", entity_id=entry.name, company=company,
					   diff={"item": row.title, "qty": float(quantity), "note": note})
	stock_alerts.check(company, [row.item])
	return listing()


def receive(cost_item: str, qty, price_per_unit, supplier: str | None = None) -> dict:
	"""Bought — onto the shelf at its price."""
	cost_items.ensure_owner()
	company = current_company()
	row = _consumable(cost_item, company)
	name = " ".join(str(supplier or "").split()) or SHOP
	# The owner and accounting keep the consumables; the stock's own editors
	# need not be them — the reader was checked above.
	with material_stock.granted():
		if not frappe.db.exists("Supplier", {"name": name, "disabled": 0}):
			material_stock.add_supplier(name)
			name = frappe.db.get_value("Supplier", {"supplier_name": name}, "name") or name
		material_stock.receive(row.item, qty, price_per_unit, name, note=f"Расходник: {row.title}")
	return listing()


def set_minimum(cost_item: str, minimum) -> dict:
	"""Below this it is time to buy."""
	cost_items.ensure_owner()
	row = _consumable(cost_item, current_company())
	with material_stock.granted():
		material_stock.set_min_stock(row.item, minimum)
	return listing()


def low(company: str) -> list[dict]:
	"""The consumables below their minimum — for the morning brief."""
	rows = _items(company)
	items = [r.item for r in rows]
	return stock_alerts.low(company, items) if items else []


def spent(company: str, since, until) -> dict[str, float]:
	"""What was taken off the shelf in [since, until], at its valuation, by
	cost item."""
	rows = _items(company, archived=True)
	by_item = {r.item: r.name for r in rows}
	if not by_item:
		return {}
	out: dict[str, float] = {}
	for line in frappe.db.sql(
		"""
		select d.item_code, sum(d.amount) as amount
		from `tabStock Entry Detail` d join `tabStock Entry` e on e.name = d.parent
		where e.docstatus = 1 and e.purpose = 'Material Issue' and e.company = %(company)s
		  and e.posting_date between %(since)s and %(until)s and d.item_code in %(items)s
		group by d.item_code
		""",
		{"company": company, "since": since, "until": until, "items": tuple(by_item)},
		as_dict=True,
	):
		key = by_item[line.item_code]
		out[key] = out.get(key, 0.0) + flt(line.amount)
	return out


def _items(company: str, archived: bool = False) -> list:
	filters = {"company": company, "mode": "stock", "item": ["is", "set"], "merged_into": ["is", "not set"]}
	if not archived:
		filters["archived"] = 0
	rows = frappe.get_all(cost_items.DOCTYPE, filters=filters,
						  fields=["name", "title", "unit", "area", "item", "is_new"], limit_page_length=0)
	if not rows:
		return []
	meta = {i.name: i for i in frappe.get_all(
		"Item", filters={"name": ["in", [r.item for r in rows]]}, fields=["name", "stock_uom", "korkem_min_stock"],
		limit_page_length=0)}
	for r in rows:
		m = meta.get(r.item)
		r.stock_uom = m.stock_uom if m else r.unit
		r.minimum = flt(m.korkem_min_stock) if m else 0.0
	return rows


def _consumable(cost_item: str, company: str):
	live = cost_items.live(cost_item, company)
	row = next((r for r in _items(company) if r.name == live.name), None)
	if row is None:
		frappe.throw("Это не расходник со склада.")
	return row


def _qty(qty, unit: str) -> Decimal:
	try:
		value = Decimal(str(qty).replace(",", "."))
	except (InvalidOperation, ValueError):
		frappe.throw("Сколько — число.")
	if not value.is_finite() or value <= 0 or value > material_stock.MAX_QTY:
		frappe.throw("Сколько — больше нуля.")
	if material_stock._whole_units(unit) and value != value.to_integral_value():
		frappe.throw(f"«{unit}» считается только целыми.")
	return value


def _taken_qty(company: str, items: list[str], since, until) -> dict[str, float]:
	if not items:
		return {}
	return {r.item_code: flt(r.qty) for r in frappe.db.sql(
		"""
		select d.item_code, sum(d.qty) as qty
		from `tabStock Entry Detail` d join `tabStock Entry` e on e.name = d.parent
		where e.docstatus = 1 and e.purpose = 'Material Issue' and e.company = %(company)s
		  and e.posting_date between %(since)s and %(until)s and d.item_code in %(items)s
		group by d.item_code
		""",
		{"company": company, "since": since, "until": until, "items": tuple(items)}, as_dict=True)}


def _ensure_staff() -> None:
	if not is_staff():
		frappe.throw("Расходники видят сотрудники.", frappe.PermissionError)
