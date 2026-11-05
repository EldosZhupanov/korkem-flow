# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The MDF order card: what the manager does in OnayBaza, on ERPNext's order.

The owner's decisions (NOW.md, 31.10 and 01.11.2026):

- **One window per order** — a head (client, due date, thickness, finish,
  decor face and back, patina, milling, edge, an extra name, a default price
  per m²) and lines (height × width × pieces, the line's own milling, note and
  price).
- **The owner's arithmetic**, checked on his order forms №36 and №1129: a
  line's area is height × width × pieces / 1 000 000 **rounded to 0.01 m²**,
  its amount that area × the price **to whole tenge**; no minimum area.
- **The price comes from «Цены фасадов»** by the line's milling and the
  order's finish, unless the manager typed one on the line. A pair nobody
  priced **does not stop the order**: the line counts at 0 ₸ and says so.
- **Draft → accepted → in the shop → ready → handed over**, plus on hold (with
  a reason) and cancelled. A draft is ERPNext's unsubmitted order and changes
  freely; «Принять» submits it, which fixes the prices. **The manager ticks the
  stages** (Кесу, Фреза, Жону, Вакуум, Бояу), each with its date, as in
  OnayBaza; which of them an order has follows its finish.

Nothing is invented here that ERPNext already keeps: the customer, the due
date, the lines, the payments (`payments.record_payment`, `advance_paid`) and
cancelling are ERPNext's own. This module is the order of operations and the
owner's arithmetic on top.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

import frappe
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_manufacturing.services import (
	audit,
	directions,
	facade_materials,
	facade_order,
	facade_prices,
	facade_spec,
)
from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope

AREA = Decimal("0.01")
TENGE = Decimal("1")
MIN_MM, MAX_MM = 10, 3000
MAX_LINES = 300

#: Stage → field, in the order the shop works.
STAGES = {
	"cut": "korkem_stage_cut",
	"mill": "korkem_stage_mill",
	"sand": "korkem_stage_sand",
	"vacuum": "korkem_stage_vacuum",
	"paint": "korkem_stage_paint",
}
HEAD = {
	"thickness_mm": "korkem_thickness_mm",
	"finish": "korkem_finish",
	"decor_top": "korkem_decor_top",
	"decor_bottom": "korkem_decor_bottom",
	"patina": "korkem_patina",
	"milling": "korkem_milling",
	"edge_profile": "korkem_edge_profile",
	"extra_name": "korkem_extra_name",
	"default_rate": "korkem_default_rate",
}
#: A warning this many days before the due date, if the order is not ready.
DUE_SOON_DAYS = 2


def stages_for(finish: str | None) -> list[str]:
	"""The stages an order with this finish goes through.

	Film is pressed and never painted; enamel is painted and never pressed;
	a raw («черновая») facade is cut, milled and sanded. A finish the rule does
	not recognise gets every stage — a tick too many is harmless, a missing
	one hides work.
	"""
	name = (finish or "").lower()
	if "плён" in name or "плен" in name or "пвх" in name:
		return ["cut", "mill", "sand", "vacuum"]
	if "эмал" in name or "краск" in name or "бояу" in name:
		return ["cut", "mill", "sand", "paint"]
	if "чернов" in name:
		return ["cut", "mill", "sand"]
	return list(STAGES)


# --- the arithmetic --------------------------------------------------------


def price(lines, *, finish: str | None, default_rate=None, company: str | None = None) -> dict:
	"""Price lines the owner's way. Pure arithmetic and price lookups; saves nothing.

	Each line: `height_mm`, `width_mm`, `qty`, and optionally `milling`,
	`note`, `rate` (a price typed by hand). Returns the lines with `area_m2`,
	`rate_m2`, `amount`, `manual_rate`, `no_price`, and the totals.
	"""
	if isinstance(lines, str):
		lines = frappe.parse_json(lines)
	if not isinstance(lines, list):
		frappe.throw("Позиции заказа — это список.")
	if len(lines) > MAX_LINES:
		frappe.throw(f"Не больше {MAX_LINES} позиций в одном заказе.")
	company = company or current_company()
	fallback = _money(default_rate, "Цена за м² по умолчанию") if default_rate not in (None, "") else None

	priced, pieces, area_total, total = [], 0, Decimal("0"), Decimal("0")
	for index, raw in enumerate(lines, start=1):
		if not isinstance(raw, dict):
			frappe.throw(f"Позиция {index}: непонятный формат.")
		label = f"Позиция {index}"
		height = _number(raw.get("height_mm"), f"{label}, высота")
		width = _number(raw.get("width_mm"), f"{label}, ширина")
		for size, name in ((height, "высота"), (width, "ширина")):
			if not MIN_MM <= size <= MAX_MM:
				frappe.throw(f"{label}: {name} {size:f} мм — вне {MIN_MM}–{MAX_MM} мм.")
		qty = _number(raw.get("qty", 1), f"{label}, количество")
		if qty != qty.to_integral_value() or qty < 1:
			frappe.throw(f"{label}: количество — целое число от 1.")

		milling = (raw.get("milling") or "").strip()
		manual = raw.get("rate") not in (None, "")
		if manual:
			rate = _money(raw.get("rate"), f"{label}, цена")
		else:
			found = facade_prices.price_for(milling, finish or "", company) if milling and finish else None
			rate = found if found is not None else fallback
		no_price = rate is None
		rate = rate or Decimal("0")

		area = (height * width * qty / Decimal(1_000_000)).quantize(AREA, rounding=ROUND_HALF_UP)
		amount = (area * rate).quantize(TENGE, rounding=ROUND_HALF_UP)

		pieces += int(qty)
		area_total += area
		total += amount
		priced.append(
			{
				"line": index,
				"height_mm": int(height),
				"width_mm": int(width),
				"qty": int(qty),
				"milling": milling or None,
				"note": (raw.get("note") or "").strip()[:140] or None,
				"area_m2": float(area),
				"rate_m2": float(rate),
				"amount": float(amount),
				"manual_rate": manual,
				"no_price": no_price,
			}
		)
	return {
		"lines": priced,
		"pieces": pieces,
		"area_m2": float(area_total),
		"total": float(total),
		"no_price_lines": [line["line"] for line in priced if line["no_price"]],
	}


# --- the card --------------------------------------------------------------


def save_draft(*, customer: str, delivery_date: str, head=None, lines=None, order: str | None = None,
			   notes: str | None = None) -> dict:
	"""Create a draft, or change one that is still a draft. Returns the card."""
	facade_prices.ensure_editor()
	company = current_company()
	head = frappe.parse_json(head) if isinstance(head, str) else (head or {})
	customer = facade_order._customer(customer, company)
	wanted = _due(delivery_date)
	values = _head(head, company)
	quote = price(lines or [], finish=values["finish"], default_rate=values["default_rate"], company=company)
	if not quote["lines"]:
		frappe.throw("Добавьте хотя бы одну позицию.")
	facade_order._ensure_items()

	if order:
		doc = _order(order)
		if doc.docstatus != 0:
			frappe.throw("Заказ уже принят — меняйте его через «Изменить заказ».")
		doc.set("items", [])
	else:
		doc = frappe.new_doc("Sales Order")
		doc.update(
			{
				"company": company,
				"transaction_date": nowdate(),
				"order_type": "Sales",
				"korkem_direction": directions.FACADES,
				"ignore_pricing_rule": 1,
				"disable_rounded_total": 1,
			}
		)
	doc.customer = customer
	doc.delivery_date = str(wanted)
	doc.terms = (notes or "").strip()[:2000] or None
	for key, field in HEAD.items():
		doc.set(field, values[key])
	for line in quote["lines"]:
		doc.append("items", _item(line, values, wanted))
	doc.save()
	_check_total(doc, quote["total"])
	audit.record_audit(
		action="mdf.order_draft_saved",
		entity_type="Sales Order",
		entity_id=doc.name,
		diff={"customer": customer, "pieces": quote["pieces"], "area_m2": quote["area_m2"], "total": quote["total"]},
	)
	return card(doc.name)


def accept(order: str) -> dict:
	"""«Принять»: the prices are fixed, the material is held."""
	facade_prices.ensure_editor()
	doc = _order(order)
	if doc.docstatus != 0:
		frappe.throw("Заказ уже принят.")
	doc.submit()
	facade_materials.reserve(doc.name)
	audit.record_audit(action="mdf.order_accepted", entity_type="Sales Order", entity_id=doc.name,
					   diff={"total": flt(doc.grand_total)})
	return card(doc.name)


def delete_draft(order: str) -> dict:
	"""Only a draft is deleted; an accepted order is cancelled, with a reason."""
	facade_prices.ensure_editor()
	doc = _order(order)
	if doc.docstatus != 0:
		frappe.throw("Принятый заказ не удаляется — отмените его с причиной.")
	frappe.delete_doc("Sales Order", doc.name)
	audit.record_audit(action="mdf.order_draft_deleted", entity_type="Sales Order", entity_id=doc.name, diff={})
	return {"deleted": doc.name}


def cancel(order: str, reason: str) -> dict:
	facade_prices.ensure_editor()
	reason = _reason(reason, "Укажите, почему заказ отменён.")
	doc = _order(order)
	if doc.docstatus != 1:
		frappe.throw("Отменить можно только принятый заказ; черновик просто удалите.")
	if flt(doc.advance_paid) > 0:
		frappe.throw("По заказу есть оплаты — сначала верните их клиенту.")
	doc.add_comment("Comment", f"Отменён: {reason}")
	doc.cancel()
	audit.record_audit(action="mdf.order_cancelled", entity_type="Sales Order", entity_id=doc.name,
					   diff={"reason": reason})
	return card(doc.name)


def set_stage(order: str, stage: str, done=True) -> dict:
	"""Tick or untick one stage. The date is today's; the last tick makes the order ready."""
	facade_prices.ensure_editor()
	doc = _accepted(order)
	if stage not in STAGES:
		frappe.throw(f"Этап «{stage}» не знаю.")
	if doc.korkem_handed_over_on:
		frappe.throw("Заказ уже выдан.")
	done = directions.flag(done)
	doc.db_set(STAGES[stage], nowdate() if done else None, update_modified=True)
	needed = stages_for(doc.korkem_finish)
	doc.reload()
	ready = all(doc.get(STAGES[s]) for s in needed)
	doc.db_set("korkem_ready_on", (doc.korkem_ready_on or nowdate()) if ready else None, update_modified=False)
	audit.record_audit(action="mdf.stage", entity_type="Sales Order", entity_id=doc.name,
					   diff={"stage": stage, "done": done, "ready": ready})
	return card(doc.name)


def hold(order: str, reason: str | None = None) -> dict:
	"""Put an order on hold (a reason is required), or take it off hold (no reason)."""
	facade_prices.ensure_editor()
	doc = _accepted(order)
	text = (reason or "").strip()
	doc.db_set("korkem_hold_reason", text[:1000] or None, update_modified=True)
	audit.record_audit(action="mdf.hold" if text else "mdf.resume", entity_type="Sales Order",
					   entity_id=doc.name, diff={"reason": text or None})
	return card(doc.name)


def hand_over(order: str, comment: str | None = None) -> dict:
	"""«Выдан». Not with a debt, unless an administrator says why."""
	facade_prices.ensure_editor()
	doc = _accepted(order)
	if not doc.korkem_ready_on:
		frappe.throw("Заказ ещё не готов — не все этапы отмечены.")
	debt = _debt(doc)
	if debt > 0:
		if "System Manager" not in frappe.get_roles():
			frappe.throw(f"Остаток долга {debt:,.0f} ₸ — выдать может администратор с комментарием.".replace(",", " "))
		_reason(comment, "Укажите, почему заказ выдан с долгом.")
		doc.add_comment("Comment", f"Выдан с долгом {debt:,.0f} ₸: {comment.strip()}".replace(",", " "))
	doc.db_set("korkem_handed_over_on", nowdate(), update_modified=True)
	audit.record_audit(action="mdf.handed_over", entity_type="Sales Order", entity_id=doc.name,
					   diff={"debt": float(debt)})
	return card(doc.name)


def card(order: str) -> dict:
	"""Everything the card shows, in one answer."""
	facade_prices.ensure_editor()
	doc = _order(order)
	needed = stages_for(doc.korkem_finish)
	lines = [
		{
			"name": item.name,
			"height_mm": item.korkem_height_mm,
			"width_mm": item.korkem_width_mm,
			"qty": int(item.qty),
			"milling": item.korkem_milling,
			"note": item.korkem_line_note,
			"area_m2": flt(item.korkem_area_m2, 2),
			"rate_m2": flt(item.korkem_rate_m2),
			"amount": flt(item.amount),
			"manual_rate": bool(item.korkem_manual_rate),
			"no_price": not flt(item.korkem_rate_m2),
		}
		for item in doc.items
		if item.item_code == facade_order.FACADE_ITEM
	]
	payments = frappe.get_all(
		"Payment Entry Reference",
		filters={"reference_doctype": "Sales Order", "reference_name": doc.name, "docstatus": 1},
		fields=["parent", "allocated_amount"],
	)
	paid_rows = []
	for row in payments:
		entry = frappe.db.get_value("Payment Entry", row.parent, ["posting_date", "mode_of_payment", "owner"],
									as_dict=True)
		paid_rows.append({"amount": flt(row.allocated_amount), "date": str(entry.posting_date),
						  "method": entry.mode_of_payment, "received_by": entry.owner})
	return {
		"name": doc.name,
		"status": status_of(doc),
		"overdue": _overdue(doc),
		"due_soon": _due_soon(doc),
		"customer": doc.customer,
		"customer_name": doc.customer_name,
		"phone": frappe.db.get_value("Customer", doc.customer, "mobile_no"),
		"created_on": str(doc.transaction_date),
		"delivery_date": str(doc.delivery_date),
		"head": {key: doc.get(field) for key, field in HEAD.items()},
		"lines": lines,
		"pieces": sum(line["qty"] for line in lines),
		"area_m2": flt(sum(Decimal(str(line["area_m2"])) for line in lines), 2),
		"total": flt(doc.grand_total),
		"paid": flt(doc.advance_paid),
		"debt": float(_debt(doc)),
		"payments": paid_rows,
		"stages": [{"stage": s, "done_on": str(doc.get(STAGES[s])) if doc.get(STAGES[s]) else None} for s in needed],
		"ready_on": str(doc.korkem_ready_on) if doc.korkem_ready_on else None,
		"handed_over_on": str(doc.korkem_handed_over_on) if doc.korkem_handed_over_on else None,
		"hold_reason": doc.korkem_hold_reason,
		"notes": doc.terms,
	}


STATUS_FILTERS = ("draft", "accepted", "in_shop", "ready", "handed_over", "on_hold", "cancelled")


def status_of(doc) -> str:
	if doc.docstatus == 0:
		return "draft"
	if doc.docstatus == 2:
		return "cancelled"
	if doc.korkem_handed_over_on:
		return "handed_over"
	if doc.korkem_hold_reason:
		return "on_hold"
	if doc.korkem_ready_on:
		return "ready"
	if any(doc.get(field) for field in STAGES.values()):
		return "in_shop"
	return "accepted"


def listing(search: str | None = None, status: str | None = None, overdue=False, with_debt=False,
			start: int = 0, limit: int = 50) -> dict:
	"""The list of MDF orders, newest first, a page at a time."""
	facade_prices.ensure_editor()
	company = current_company()
	limit = max(1, min(int(limit or 50), 200))
	start = max(0, int(start or 0))
	filters = {"company": company, "korkem_direction": directions.FACADES}
	or_filters = None
	text = (search or "").strip()
	if text:
		like = f"%{text}%"
		or_filters = {"name": ["like", like], "customer_name": ["like", like], "korkem_decor_top": ["like", like],
					  "contact_mobile": ["like", like]}
		phones = frappe.get_all("Customer", filters={"mobile_no": ["like", like]}, pluck="name", limit_page_length=50)
		if phones:
			or_filters["customer"] = ["in", phones]
	fields = ["name", "docstatus", "transaction_date", "delivery_date", "customer", "customer_name",
			  "grand_total", "advance_paid", "korkem_finish", "korkem_decor_top", "korkem_milling",
			  "korkem_edge_profile", "korkem_ready_on", "korkem_handed_over_on", "korkem_hold_reason",
			  *STAGES.values()]
	rows = frappe.get_all("Sales Order", filters=filters, or_filters=or_filters, fields=fields,
						  order_by="creation desc", limit_start=start, limit_page_length=limit * 3 if (
							  status or overdue or with_debt) else limit)
	out = []
	for row in rows:
		row_status = status_of(row)
		if status and row_status != status:
			continue
		if directions.flag(overdue) and not _overdue(row):
			continue
		debt = _debt(row)
		if directions.flag(with_debt) and debt <= 0:
			continue
		done = [s for s in stages_for(row.korkem_finish) if row.get(STAGES[s])]
		out.append(
			{
				"name": row.name,
				"status": row_status,
				"overdue": _overdue(row),
				"due_soon": _due_soon(row),
				"created_on": str(row.transaction_date),
				"delivery_date": str(row.delivery_date),
				"customer_name": row.customer_name,
				"phone": frappe.db.get_value("Customer", row.customer, "mobile_no"),
				"finish": row.korkem_finish,
				"decor_top": row.korkem_decor_top,
				"milling": row.korkem_milling,
				"edge_profile": row.korkem_edge_profile,
				"area_m2": _area(row.name),
				"total": flt(row.grand_total),
				"paid": flt(row.advance_paid),
				"debt": float(debt),
				"stage": done[-1] if done else None,
			}
		)
		if len(out) >= limit:
			break
	return {"orders": out, "start": start, "limit": limit}


# --- helpers ---------------------------------------------------------------


def _head(head: dict, company: str) -> dict:
	spec = facade_spec.read(head, "Заказ", company)
	finish = (head.get("finish") or "").strip() or None
	default_rate = head.get("default_rate")
	return {
		"thickness_mm": spec["thickness_mm"],
		"finish": finish,
		"decor_top": spec["decor_top"],
		"decor_bottom": spec["decor_bottom"],
		"patina": (head.get("patina") or "").strip()[:140] or None,
		"milling": (head.get("milling") or "").strip()[:140] or None,
		"edge_profile": spec["edge_profile"],
		"extra_name": (head.get("extra_name") or "").strip()[:140] or None,
		"default_rate": float(_money(default_rate, "Цена за м²")) if default_rate not in (None, "") else None,
	}


def _item(line: dict, head: dict, wanted) -> dict:
	qty = Decimal(line["qty"])
	amount = Decimal(str(line["amount"]))
	milling = line["milling"] or head["milling"]
	title = f"{milling or 'Фасад'} {line['height_mm']}×{line['width_mm']}"[:140]
	return {
		"item_code": facade_order.FACADE_ITEM,
		"item_name": title,
		"description": title,
		"qty": int(qty),
		"uom": "Nos",
		# The amount is the owner's; ERPNext's qty × rate, rounded to two
		# decimals, lands back on it (the rate keeps six — add_mdf_order_fields).
		"rate": float((amount / qty).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)),
		"delivery_date": str(wanted),
		"korkem_height_mm": line["height_mm"],
		"korkem_width_mm": line["width_mm"],
		"korkem_area_m2": line["area_m2"],
		"korkem_milling": milling,
		"korkem_finish": head["finish"],
		"korkem_line_note": line["note"],
		"korkem_rate_m2": line["rate_m2"],
		"korkem_manual_rate": 1 if line["manual_rate"] else 0,
		**facade_spec.as_fields(
			{
				"thickness_mm": head["thickness_mm"],
				"decor_top": head["decor_top"],
				"decor_bottom": head["decor_bottom"],
				"edge_profile": head["edge_profile"],
				"color_group": head["decor_top"],
			}
		),
	}


def _check_total(doc, expected: float) -> None:
	if Decimal(str(flt(doc.grand_total))) != Decimal(str(expected)):
		frappe.throw(
			f"ERPNext посчитал заказ на {flt(doc.grand_total):,.2f} ₸, а расчёт — на {expected:,.0f} ₸. "
			"Вероятно, настроен налог или правило цены. Заказ не сохранён.".replace(",", " ")
		)


def _order(name: str):
	if not name or not frappe.db.exists("Sales Order", name):
		frappe.throw("Заказ не найден.", frappe.DoesNotExistError)
	doc = frappe.get_doc("Sales Order", name)
	enforce_tenant_scope(doc.company)
	if doc.get("korkem_direction") != directions.FACADES:
		frappe.throw("Это не заказ МДФ-фасадов.", frappe.DoesNotExistError)
	return doc


def _accepted(name: str):
	doc = _order(name)
	if doc.docstatus != 1:
		frappe.throw("Сначала примите заказ." if doc.docstatus == 0 else "Заказ отменён.")
	return doc


def _debt(row) -> Decimal:
	if row.docstatus != 1:
		return Decimal("0")
	return max(Decimal("0"), Decimal(str(flt(row.grand_total))) - Decimal(str(flt(row.advance_paid))))


def _overdue(row) -> bool:
	return status_of(row) in ("accepted", "in_shop") and getdate(row.delivery_date) < getdate(nowdate())


def _due_soon(row) -> bool:
	if status_of(row) not in ("accepted", "in_shop"):
		return False
	due = getdate(row.delivery_date)
	return getdate(nowdate()) <= due <= getdate(add_days(nowdate(), DUE_SOON_DAYS))


def _area(order: str) -> float:
	values = frappe.get_all("Sales Order Item", filters={"parent": order, "item_code": facade_order.FACADE_ITEM},
							pluck="korkem_area_m2")
	return flt(sum(Decimal(str(flt(v))) for v in values), 2)


def _due(value):
	if not value:
		frappe.throw("Укажите срок сдачи заказа.")
	try:
		return getdate(value)
	except Exception:
		frappe.throw(f"Срок «{value}» — не дата.")


def _reason(text, message: str) -> str:
	text = (text or "").strip()
	if not text:
		frappe.throw(message)
	return text[:1000]


def _number(value, field: str) -> Decimal:
	try:
		number = Decimal(str(value).strip().replace(",", "."))
	except (InvalidOperation, TypeError, ValueError):
		frappe.throw(f"{field}: нужно число, а пришло {value!r}.")
	if not number.is_finite():
		frappe.throw(f"{field}: нужно число.")
	return number


def _money(value, field: str) -> Decimal:
	number = _number(value, field)
	if number < 0:
		frappe.throw(f"{field}: не меньше нуля.")
	return number
