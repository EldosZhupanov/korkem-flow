# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Logistics: what bringing material to the shop costs, kept apart from the
material itself.

The owner's own examples (29.10.2026) are what this module is for:

- 30 sheets of MDF 16 mm came on a Газель — 10 000 ₸;
- 3,1 m of GreenWood film for order №1127 came from Astana by taxi — 5 000 ₸;
- 27,9 m of JS group film for №1132 came from Almaty through a transport
  company (Тайбазаров) — 1 500 ₸, but four to seven days on a lorry;
- 1,1 m of Kira film for №1120 came from Semey by taxi — 4 000 ₸, paid extra
  because the order was urgent;
- a 150 m roll of Kira gloss for №1112 came from Karaganda by taxi — 25 000 ₸.

**One record per delivery** (`Logistics Delivery`): what it cost, where it
came from, how (Газель, такси, транспортная компания, КАМАЗ), who carried it,
when it was ordered and when it arrived, whether it was urgent — and what it
brought: MDF, film or something else, the material, the quantity, the order
it was for, the receipt it came with.

**Kept apart on purpose.** The material's price stays the supplier's price;
logistics is its own line, so the month answers «how much went on cars» —
for MDF and for film separately — instead of disappearing into a dearer sheet.
Per unit it is still visible: ₸ per sheet, ₸ per metre.

**Nothing is deleted.** A delivery entered by mistake is cancelled with a
reason; it stays in the history and leaves the totals.

Money: managers and accounting see and keep it; the shop floor does not.
"""

from __future__ import annotations

from collections import defaultdict
from decimal import Decimal, InvalidOperation

import frappe
from frappe.utils import add_days, add_months, date_diff, flt, get_first_day, get_last_day, getdate, nowdate

from korkem_manufacturing.services import audit
from korkem_manufacturing.services import material_stock as stock
from korkem_manufacturing.services.scope import current_company

DOCTYPE = "Logistics Delivery"
EDITORS = stock.EDITORS | {"Accounts Manager", "Accounts User"}
KINDS = stock.KINDS
MAX_AMOUNT = Decimal("10000000")
#: Offered before anything has been typed; what the shop uses joins them.
TRANSPORTS = ("Газель", "Такси", "Транспортная компания", "Фура / КАМАЗ", "Своя машина")
CITIES = ("Астана", "Алматы", "Караганда", "Семей", "Шымкент")
#: A receipt this old with no delivery written against it is asked about.
UNLINKED_DAYS = 14


def can_edit() -> bool:
	return bool(EDITORS.intersection(frappe.get_roles()))


def _ensure_editor() -> None:
	if not can_edit():
		frappe.throw("Логистику ведут администратор, менеджеры и бухгалтерия.", frappe.PermissionError)


def _text(value, limit: int = 80) -> str:
	return " ".join(str(value or "").split())[:limit]


def _flag(value) -> bool:
	if isinstance(value, str):
		return value.strip().lower() in ("1", "true", "yes", "да")
	return bool(value)


def _money(value) -> Decimal:
	try:
		amount = Decimal(str(value))
	except (InvalidOperation, ValueError):
		frappe.throw("Сумма доставки — число.")
	# Zero is a fact too: the supplier brought it himself.
	if not amount.is_finite() or amount < 0 or amount > MAX_AMOUNT:
		frappe.throw("Сумма доставки — от нуля (привёз поставщик) и больше.")
	return amount


def _quantity(value) -> float | None:
	if value in (None, ""):
		return None
	try:
		qty = Decimal(str(value).replace(",", "."))
	except (InvalidOperation, ValueError):
		frappe.throw("Количество — число.")
	if not qty.is_finite() or qty <= 0 or qty > stock.MAX_QTY:
		frappe.throw("Количество должно быть больше нуля.")
	return float(qty)


def _unit(value) -> str | None:
	"""«Лист» and «лист» are one unit: ERPNext's UOM may be capitalised, and
	the month's ₸-per-sheet must not split in two over it."""
	return _text(value, 20).lower() or None


# --------------------------------------------------------------------------
# Writing
# --------------------------------------------------------------------------


def record(
	amount,
	from_city: str,
	transport: str,
	category: str | None = None,
	delivered_on: str | None = None,
	ordered_on: str | None = None,
	carrier: str | None = None,
	urgent=False,
	supplier: str | None = None,
	sales_order: str | None = None,
	receipt: str | None = None,
	item: str | None = None,
	what: str | None = None,
	qty=None,
	unit: str | None = None,
	note: str | None = None,
) -> dict:
	"""One delivery: what it cost, from where, how, and what it brought."""
	_ensure_editor()
	company = current_company()
	cost = _money(amount)
	from_city, transport, carrier = _text(from_city), _text(transport), _text(carrier) or None
	if len(from_city) < 2:
		frappe.throw("Откуда привезли? Укажите город.")
	if len(transport) < 2:
		frappe.throw("Чем привезли? Газель, такси, транспортная компания…")

	today = getdate(nowdate())
	arrived = getdate(delivered_on) if delivered_on else today
	if arrived > today:
		frappe.throw("Доставка не может прийти в будущем.")
	ordered = getdate(ordered_on) if ordered_on else None
	if ordered and ordered > arrived:
		frappe.throw("Заказали позже, чем привезли? Проверьте даты.")

	qty = _quantity(qty)
	unit = _unit(unit)

	if receipt:
		row = frappe.db.get_value(
			"Stock Entry", receipt, ["company", "korkem_material_receipt", "korkem_supplier", "docstatus"], as_dict=True
		)
		if not row or row.company != company or not row.korkem_material_receipt:
			frappe.throw("Такого прихода нет.", frappe.DoesNotExistError)
		line = frappe.db.get_value(
			"Stock Entry Detail", {"parent": receipt}, ["item_code", "qty", "uom"], as_dict=True
		)
		supplier = supplier or row.korkem_supplier
		if line:
			item = item or line.item_code
			qty = qty if qty is not None else flt(line.qty)
			unit = unit or _unit(line.uom)
	if item:
		info = frappe.db.get_value(
			"Item", item, ["korkem_material_company", "korkem_material_kind", "stock_uom", "item_name"], as_dict=True
		)
		if not info or info.korkem_material_company != company:
			frappe.throw("Такого материала нет.", frappe.DoesNotExistError)
		category = category or info.korkem_material_kind
		unit = unit or _unit(info.stock_uom)
		what = what or info.item_name
	category = category or stock.OTHER
	if category not in KINDS:
		frappe.throw(f"Доставка — для одного из: {', '.join(KINDS)}.")
	if supplier and not frappe.db.exists("Supplier", supplier):
		frappe.throw("Такого поставщика нет.", frappe.DoesNotExistError)
	if sales_order and frappe.db.get_value("Sales Order", sales_order, "company") != company:
		frappe.throw("Такого заказа нет.", frappe.DoesNotExistError)

	doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"company": company,
			"delivered_on": str(arrived),
			"ordered_on": str(ordered) if ordered else None,
			"category": category,
			"amount": float(cost),
			"from_city": from_city,
			"transport": transport,
			"carrier": carrier,
			"urgent": 1 if _flag(urgent) else 0,
			"supplier": supplier or None,
			"sales_order": sales_order or None,
			"receipt": receipt or None,
			"item": item or None,
			"what": _text(what, 140) or None,
			"qty": qty,
			"unit": unit,
			"note": (note or "").strip()[:500] or None,
		}
	)
	doc.insert(ignore_permissions=True)
	audit.record_audit(
		action="logistics.recorded",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={"amount": float(cost), "category": category, "from": from_city, "by": transport},
	)
	return _row(doc)


def cancel(delivery: str, reason: str) -> dict:
	"""A mistake is cancelled with a reason; it stays in the history."""
	_ensure_editor()
	row = frappe.db.get_value(DOCTYPE, delivery, ["company", "cancelled"], as_dict=True)
	if not row or row.company != current_company():
		frappe.throw("Такой доставки нет.", frappe.DoesNotExistError)
	if row.cancelled:
		frappe.throw("Эта доставка уже отменена.")
	reason = (reason or "").strip()
	if len(reason) < 3:
		frappe.throw("Напишите, почему отменяете.")
	frappe.db.set_value(
		DOCTYPE, delivery, {"cancelled": 1, "cancelled_by": frappe.session.user, "cancel_reason": reason[:500]}
	)
	audit.record_audit(action="logistics.cancelled", entity_type=DOCTYPE, entity_id=delivery, diff={"reason": reason})
	return _row(frappe.get_doc(DOCTYPE, delivery))


# --------------------------------------------------------------------------
# Reading
# --------------------------------------------------------------------------

_FIELDS = [
	"name", "delivered_on", "ordered_on", "category", "amount", "from_city", "transport", "carrier", "urgent",
	"supplier", "sales_order", "receipt", "item", "what", "qty", "unit", "note", "cancelled", "cancel_reason",
]


def _days(r) -> int | None:
	if not r.get("ordered_on"):
		return None
	return date_diff(r.get("delivered_on"), r.get("ordered_on"))


def _row(r) -> dict:
	supplier = r.get("supplier")
	return {
		"delivery": r.get("name"),
		"delivered_on": str(r.get("delivered_on")),
		"ordered_on": str(r.get("ordered_on")) if r.get("ordered_on") else None,
		"days": _days(r),
		"category": r.get("category"),
		"amount": flt(r.get("amount")),
		"from_city": r.get("from_city"),
		"transport": r.get("transport"),
		"carrier": r.get("carrier"),
		"urgent": bool(r.get("urgent")),
		"supplier": supplier,
		"supplier_name": frappe.db.get_value("Supplier", supplier, "supplier_name") if supplier else None,
		"sales_order": r.get("sales_order"),
		"receipt": r.get("receipt"),
		"item": r.get("item"),
		"what": r.get("what"),
		"qty": flt(r.get("qty")) if r.get("qty") else None,
		"unit": r.get("unit"),
		"note": r.get("note"),
		"cancelled": bool(r.get("cancelled")),
		"cancel_reason": r.get("cancel_reason"),
	}


def _month_range(month: str | None) -> tuple:
	"""«2026-10» → its first and last day; nothing → this month."""
	try:
		first = get_first_day(getdate(f"{month}-01") if month else getdate(nowdate()))
	except Exception:
		frappe.throw("Месяц — в виде 2026-10.")
	return first, get_last_day(first)


def listing(
	month: str | None = None,
	category: str | None = None,
	sales_order: str | None = None,
	include_cancelled=False,
	limit: int = 200,
) -> dict:
	_ensure_editor()
	filters: dict = {"company": current_company()}
	if sales_order:
		filters["sales_order"] = sales_order
	else:
		first, last = _month_range(month)
		filters["delivered_on"] = ["between", [first, last]]
	if category:
		filters["category"] = category
	if not _flag(include_cancelled):
		filters["cancelled"] = 0
	rows = frappe.get_all(
		DOCTYPE,
		filters=filters,
		fields=_FIELDS,
		order_by="delivered_on desc, creation desc",
		limit_page_length=max(1, min(int(limit or 200), 1000)),
	)
	return {"deliveries": [_row(r) for r in rows], "can_edit": can_edit()}


def _group(rows, key) -> list[dict]:
	acc: dict = defaultdict(lambda: {"amount": 0.0, "count": 0, "days": []})
	for r in rows:
		g = acc[key(r)]
		g["amount"] += flt(r.amount)
		g["count"] += 1
		if (d := _days(r)) is not None:
			g["days"].append(d)
	return sorted(
		(
			{
				"name": name,
				"amount": round(g["amount"], 2),
				"count": g["count"],
				"average_days": round(sum(g["days"]) / len(g["days"]), 1) if g["days"] else None,
			}
			for name, g in acc.items()
		),
		key=lambda g: -g["amount"],
	)


def _per_unit(rows) -> list[dict]:
	"""₸ per sheet, ₸ per metre: only where the delivery says how much it brought."""
	acc: dict = defaultdict(lambda: [0.0, 0.0])
	for r in rows:
		if r.qty and r.unit:
			a = acc[(r.category, r.unit)]
			a[0] += flt(r.amount)
			a[1] += flt(r.qty)
	return [
		{"category": c, "unit": u, "amount": round(a, 2), "qty": round(q, 3), "per_unit": round(a / q, 2)}
		for (c, u), (a, q) in sorted(acc.items())
		if q
	]


def summary(month: str | None = None) -> dict:
	"""The month's logistics: in all, for MDF and for film, by city, by how,
	per unit, how long it took, what was urgent — and the month before."""
	_ensure_editor()
	company = current_company()
	first, last = _month_range(month)
	rows = frappe.get_all(
		DOCTYPE,
		filters={"company": company, "cancelled": 0, "delivered_on": ["between", [first, last]]},
		fields=_FIELDS,
	)
	before_first = get_first_day(add_months(first, -1))
	before = frappe.get_all(
		DOCTYPE,
		filters={
			"company": company, "cancelled": 0,
			"delivered_on": ["between", [before_first, get_last_day(before_first)]],
		},
		fields=["amount"],
	)
	urgent = [r for r in rows if r.urgent]
	return {
		"month": str(first)[:7],
		"total": round(sum(flt(r.amount) for r in rows), 2),
		"count": len(rows),
		"previous_total": round(sum(flt(r.amount) for r in before), 2),
		"by_category": _group(rows, lambda r: r.category),
		"by_city": _group(rows, lambda r: r.from_city),
		"by_transport": _group(rows, lambda r: r.transport),
		"by_carrier": _group([r for r in rows if r.carrier], lambda r: r.carrier),
		"per_unit": _per_unit(rows),
		"urgent": {"count": len(urgent), "amount": round(sum(flt(r.amount) for r in urgent), 2)},
		"unlinked_receipts": unlinked_receipts(),
	}


def for_order(sales_order: str) -> dict:
	"""What delivering this order's material cost — a line of its margin."""
	_ensure_editor()
	rows = listing(sales_order=sales_order)["deliveries"]
	return {"sales_order": sales_order, "deliveries": rows, "total": round(sum(r["amount"] for r in rows), 2)}


def suggestions() -> dict:
	"""What to offer in the form: the usual ones, then what the shop has used."""
	_ensure_editor()
	company = current_company()

	def used(field: str) -> list[str]:
		return [
			r[0]
			for r in frappe.db.sql(
				f"""select `{field}`, count(*) c from `tab{DOCTYPE}`
				where company = %s and ifnull(`{field}`, '') != '' group by `{field}` order by c desc limit 30""",
				(company,),
			)
		]

	def merged(used_values: list[str], defaults: tuple) -> list[str]:
		seen = {v.lower() for v in used_values}
		return used_values + [d for d in defaults if d.lower() not in seen]

	return {
		"cities": merged(used("from_city"), CITIES),
		"transports": merged(used("transport"), TRANSPORTS),
		"carriers": used("carrier"),
		"categories": list(KINDS),
	}


def unlinked_receipts(days: int = UNLINKED_DAYS, company: str | None = None) -> list[dict]:
	"""Recent receipts with no delivery written against them — the question
	the reminder asks: «привезли 30 листов, а доставку не записали»."""
	company = company or current_company()
	since = add_days(nowdate(), -int(days))
	entries = frappe.get_all(
		"Stock Entry",
		filters={"company": company, "korkem_material_receipt": 1, "docstatus": 1, "posting_date": [">=", since]},
		fields=["name", "posting_date", "korkem_supplier"],
		order_by="posting_date desc",
		limit_page_length=200,
	)
	if not entries:
		return []
	linked = set(
		frappe.get_all(
			DOCTYPE,
			filters={"company": company, "cancelled": 0, "receipt": ["in", [e.name for e in entries]]},
			pluck="receipt",
		)
	)
	result = []
	for e in entries:
		if e.name in linked:
			continue
		line = frappe.db.get_value("Stock Entry Detail", {"parent": e.name}, ["item_code", "item_name", "qty", "uom"], as_dict=True)
		result.append(
			{
				"receipt": e.name,
				"date": str(e.posting_date),
				"supplier": e.korkem_supplier,
				"item": line.item_code if line else None,
				"title": line.item_name if line else None,
				"qty": flt(line.qty) if line else None,
				"unit": line.uom if line else None,
			}
		)
	return result


#: A receipt gets a day before anyone is asked: the delivery is usually
#: written the same evening, and a reminder an hour after unloading is noise.
REMIND_AFTER_DAYS = 1
DELIVERY_MISSING = "logistics.delivery_missing"


def remind() -> int:
	"""Hourly: each receipt older than a day, younger than two weeks, with no
	delivery written, is asked about once (`logistics.delivery_missing`; the
	receipt is the subject, so delivery is idempotent on it)."""
	from korkem_manufacturing import domain_events

	cutoff = getdate(add_days(nowdate(), -REMIND_AFTER_DAYS))
	companies = frappe.get_all(
		"Stock Entry",
		filters={"korkem_material_receipt": 1, "docstatus": 1, "posting_date": [">=", add_days(nowdate(), -UNLINKED_DAYS)]},
		pluck="company",
		distinct=True,
	)
	asked = 0
	for company in companies:
		for row in unlinked_receipts(company=company):
			if getdate(row["date"]) > cutoff:
				continue
			domain_events.emit(DELIVERY_MISSING, company=company, **row)
			asked += 1
	return asked
