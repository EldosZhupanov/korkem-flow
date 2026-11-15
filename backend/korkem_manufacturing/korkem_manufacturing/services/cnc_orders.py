# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""CNC services — the machine for hire (owner, 15.11.2026: «приходит клиент,
просит фрезеровать МДФ, ЛДСП, каменные столешницы, еврозапил, столешницы под
мойку выпилить или из фанеры сделать решётки»).

A third line of business beside facades and furniture
(`directions.CNC`). Its order is a Sales Order like theirs — so payments,
debts, the invoice and the customer's card are the ones every order has —
with a path of its own: taken in, on the machine, ready, handed over.

**The price list** (`CNC Service`) is the owner's: each service in its own
unit — a sheet, a piece, a running metre, a m², a machine minute, or «по
договорённости» when the price is set for the job (a lattice priced by its
pattern, the customer, its difficulty). A furniture maker may have a price of
his own. A company starts with the usual services and no prices.

**The material.** Mostly the customer's: what he brought is written down —
what, how many, any defects — and he agrees that a defect hidden inside is
his, which ends the «you spoiled it» argument before it starts. Sometimes the
shop sells him its own sheet: such a line is a material from the warehouse,
taken off it when the order is accepted, and put back if it is cancelled.

**The machine.** One machine, one queue: every service line carries its
minutes, and the queue — the urgent first, then by acceptance — says when an
order will be ready at so many working minutes a day.

**Extras.** Urgent costs a percentage more; an order below the minimum is
brought up to it. Both are shown as lines of their own, so the customer sees
why.
"""

from __future__ import annotations

from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

import frappe
from frappe.utils import add_days, flt, getdate, now_datetime, nowdate

from korkem_manufacturing.services import (
	audit,
	directions,
	facade_order,
	facade_prices,
	material_stock,
	mdf_tags,
)
from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope

CNC_ITEM = "KORKEM-CNC"
MAX_LINES = 100
MAX_INTAKE = 50
TENGE = Decimal("1")

#: The units a service is sold in; «договорная» has no list price.
UNITS = ("шт", "лист", "пог.м", "м²", "мин", "договорная")
BY_AGREEMENT = "договорная"

#: Line kinds: a service of the list, the shop's own material, an extra.
SERVICE, MATERIAL, EXTRA = "service", "material", "extra"

#: What a company starts with — the owner sets the prices (15.11.2026).
STARTING = (
	("Распил", "Распил ЛДСП", "лист", 20),
	("Распил", "Распил МДФ", "лист", 20),
	("Распил", "Распил фанеры", "лист", 20),
	("Распил", "Рез по контуру", "пог.м", 2),
	("Столешницы", "Еврозапил", "шт", 30),
	("Столешницы", "Вырез под мойку — накладная", "шт", 15),
	("Столешницы", "Вырез под мойку — врезная", "шт", 20),
	("Столешницы", "Вырез под мойку — подстольная (с полировкой)", "шт", 40),
	("Столешницы", "Вырез под варочную панель", "шт", 15),
	("Столешницы", "Вырез под розетку", "шт", 5),
	("Камень", "Вырез в камне под мойку", "шт", 60),
	("Камень", "Еврозапил камня", "шт", 60),
	("Камень", "Фрезеровка кромки камня", "пог.м", 10),
	("Решётки и узоры", "Решётка / узор", BY_AGREEMENT, 0),
	("Прочее", "Фрезеровка фасадов по шаблону", "м²", 15),
	("Прочее", "Паз", "пог.м", 2),
	("Прочее", "Фаска", "пог.м", 2),
	("Прочее", "Отверстие", "шт", 1),
	("Прочее", "Гравировка / 3D", "мин", 1),
	("Прочее", "Подготовка файла", BY_AGREEMENT, 0),
)

_URGENT_KEY, _MIN_KEY, _DAY_KEY = "korkem_cnc_urgent_pct", "korkem_cnc_min_order", "korkem_cnc_day_minutes"
DEFAULT_URGENT_PCT, DEFAULT_DAY_MINUTES = 20, 480
STATUSES = ("draft", "queued", "on_machine", "ready", "handed_over", "cancelled")


# ---------------------------------------------------------------- settings --

def settings(company: str | None = None) -> dict:
	company = company or current_company()

	def get(key, default):
		value = frappe.db.get_default(f"{key}:{company}")
		return flt(value) if value not in (None, "") else default

	return {"urgent_pct": get(_URGENT_KEY, DEFAULT_URGENT_PCT), "min_order": get(_MIN_KEY, 0),
			"day_minutes": get(_DAY_KEY, DEFAULT_DAY_MINUTES)}


def set_settings(urgent_pct=None, min_order=None, day_minutes=None) -> dict:
	"""Urgency's percentage, the minimum order, the machine's working minutes a day."""
	_ensure_owner()
	company = current_company()
	for key, value, top, what in ((_URGENT_KEY, urgent_pct, 300, "Наценка за срочность, %"),
								  (_MIN_KEY, min_order, 10_000_000, "Минимальный заказ"),
								  (_DAY_KEY, day_minutes, 1440, "Минут работы станка в день")):
		if value in (None, ""):
			continue
		number = _number(value, what)
		if number < 0 or number > top:
			frappe.throw(f"{what}: от 0 до {top}.")
		frappe.db.set_default(f"{key}:{company}", str(number))
	audit.record_audit(action="cnc.settings", entity_type="Company", entity_id=company,
					   diff={"urgent_pct": urgent_pct, "min_order": min_order, "day_minutes": day_minutes})
	return settings(company)


# -------------------------------------------------------------- price list --

def services(include_disabled=False) -> list[dict]:
	"""The price list, by group, in the owner's order."""
	facade_prices.ensure_editor()
	company = current_company()
	filters = {"company": company}
	if not directions.flag(include_disabled):
		filters["enabled"] = 1
	return [_service_row(r) for r in frappe.get_all(
		"CNC Service", filters=filters,
		fields=["name", "title", "service_group", "unit", "price", "price_trade", "minutes", "enabled", "sort"],
		order_by="sort asc, creation asc", limit_page_length=0)]


def _service_row(r) -> dict:
	return {"id": r.name, "title": r.title, "group": r.service_group, "unit": r.unit, "price": flt(r.price),
			"price_trade": flt(r.price_trade) or None, "minutes": flt(r.minutes), "enabled": bool(r.enabled)}


def save_service(title: str, unit: str, group: str | None = None, price=None, price_trade=None, minutes=None,
				 service: str | None = None, enabled=True) -> list[dict]:
	"""Add a service to the list, or change one."""
	_ensure_owner()
	company = current_company()
	title = " ".join(str(title or "").split())[:140]
	if not title:
		frappe.throw("Название услуги?")
	if unit not in UNITS:
		frappe.throw(f"Единица — одна из: {', '.join(UNITS)}.")
	values = {
		"title": title, "unit": unit, "service_group": " ".join(str(group or "").split())[:80] or None,
		"price": float(_money(price, "Цена")) if price not in (None, "") else 0,
		"price_trade": float(_money(price_trade, "Цена мебельщикам")) if price_trade not in (None, "") else 0,
		"minutes": float(_number(minutes, "Минут станка")) if minutes not in (None, "") else 0,
		"enabled": 1 if directions.flag(enabled) else 0,
	}
	if service:
		if frappe.db.get_value("CNC Service", service, "company") != company:
			frappe.throw("Такой услуги нет.", frappe.DoesNotExistError)
		doc = frappe.get_doc("CNC Service", service)
		doc.update(values)
		doc.save(ignore_permissions=True)
	else:
		last = frappe.db.get_value("CNC Service", {"company": company}, "max(sort)") or 0
		doc = frappe.get_doc({"doctype": "CNC Service", "company": company, "sort": int(last) + 1, **values})
		doc.insert(ignore_permissions=True)
	audit.record_audit(action="cnc.service_saved", entity_type="CNC Service", entity_id=doc.name, diff=values)
	return services(include_disabled=True)


def seed_company(company: str) -> None:
	"""The usual services, with no prices — once: a company that has ever
	had a list keeps it as its owner made it."""
	if frappe.db.exists("CNC Service", {"company": company}):
		return
	for sort, (group, title, unit, minutes) in enumerate(STARTING, start=1):
		frappe.get_doc({"doctype": "CNC Service", "company": company, "title": title, "service_group": group,
						"unit": unit, "minutes": minutes, "enabled": 1, "sort": sort}).insert(ignore_permissions=True)


def seed_all_companies() -> None:
	for company in frappe.get_all("Company", pluck="name"):
		seed_company(company)


def on_company_created(doc, method=None) -> None:
	seed_company(doc.name)


# ---------------------------------------------------------------- pricing --

def materials() -> list[dict]:
	"""The shop's own sheets a customer may buy with the job: MDF and the
	rest of the warehouse, with what is on hand and what it cost."""
	facade_prices.ensure_editor()
	company = current_company()
	items = frappe.get_all(
		"Item",
		filters={"korkem_material_company": company, "disabled": 0,
				 "korkem_material_kind": ["in", [material_stock.MDF, material_stock.OTHER]]},
		fields=["name", "item_name", "stock_uom"], order_by="item_name asc", limit_page_length=0)
	on_hand = material_stock._stock([i.name for i in items], company)
	return [{"item": i.name, "title": i.item_name, "unit": i.stock_uom,
			 "on_hand": on_hand.get(i.name, (0.0, 0.0))[0], "cost": on_hand.get(i.name, (0.0, 0.0))[1]}
			for i in items]


def price(lines, *, customer: str | None = None, tags=None, company: str | None = None) -> dict:
	"""Price an order: each line by the list (a furniture maker's own price
	where there is one) or by hand; urgent and the minimum as lines of their
	own. Saves nothing.

	A line: `service` (an id of the list) or `material` (an Item of the
	warehouse) or neither (a job of its own, `title` and `rate` required);
	`qty`; `rate` typed by hand; `note`.
	"""
	if isinstance(lines, str):
		lines = frappe.parse_json(lines)
	if not isinstance(lines, list):
		frappe.throw("Строки заказа — это список.")
	if len(lines) > MAX_LINES:
		frappe.throw(f"Не больше {MAX_LINES} строк в заказе.")
	company = company or current_company()
	maker = bool(customer) and "furniture_maker" in mdf_tags.parse(
		frappe.db.get_value("Customer", customer, "korkem_tags"))
	priced, total, minutes = [], Decimal(0), Decimal(0)
	for index, raw in enumerate(lines, start=1):
		if not isinstance(raw, dict):
			frappe.throw(f"Строка {index}: непонятный формат.")
		label = f"Строка {index}"
		qty = _number(raw.get("qty", 1), f"{label}, количество")
		if qty <= 0:
			frappe.throw(f"{label}: количество больше нуля.")
		manual = raw.get("rate") not in (None, "")
		rate = _money(raw.get("rate"), f"{label}, цена") if manual else None
		note = " ".join(str(raw.get("note") or "").split())[:140] or None
		if raw.get("material"):
			item = str(raw["material"])
			row = frappe.db.get_value("Item", item, ["korkem_material_company", "item_name", "stock_uom"], as_dict=True)
			if not row or row.korkem_material_company != company:
				frappe.throw(f"{label}: такого материала на складе нет.")
			if rate is None:
				frappe.throw(f"{label}: цена материала для клиента?")
			kind, title, unit, per_unit, service = MATERIAL, row.item_name, row.stock_uom, Decimal(0), None
		elif raw.get("service"):
			s = frappe.db.get_value("CNC Service", str(raw["service"]),
									["company", "title", "unit", "price", "price_trade", "minutes"], as_dict=True)
			if not s or s.company != company:
				frappe.throw(f"{label}: такой услуги нет в прайсе.")
			kind, title, unit, service = SERVICE, s.title, s.unit, str(raw["service"])
			per_unit = Decimal(str(flt(s.minutes)))
			if rate is None:
				listed = flt(s.price_trade) if maker and flt(s.price_trade) else flt(s.price)
				rate = Decimal(str(listed)) if listed else None
		else:
			title = " ".join(str(raw.get("title") or "").split())[:140]
			if not title:
				frappe.throw(f"{label}: что за работа?")
			kind, unit, service = SERVICE, " ".join(str(raw.get("unit") or "шт").split())[:20], None
			per_unit = _number(raw.get("minutes") or 0, f"{label}, минут")
		amount = ((rate or Decimal(0)) * qty).quantize(TENGE, rounding=ROUND_HALF_UP)
		line_minutes = (per_unit * qty) if kind == SERVICE else Decimal(0)
		total += amount
		minutes += line_minutes
		priced.append({"line": index, "kind": kind, "service": service, "material": raw.get("material") or None,
					   "title": title, "unit": unit, "qty": float(qty), "rate": float(rate or 0),
					   "amount": float(amount), "manual_rate": manual, "no_price": rate is None,
					   "minutes": float(line_minutes), "note": note})
	extras = _extras(total, tags, company)
	return {"lines": priced, "extras": extras, "minutes": float(minutes),
			"total": float(total + sum(Decimal(str(e["amount"])) for e in extras)),
			"no_price_lines": [p["line"] for p in priced if p["no_price"]], "maker_prices": maker}


def _extras(total: Decimal, tags, company: str) -> list[dict]:
	s = settings(company)
	out = []
	if "urgent" in mdf_tags.parse(tags if isinstance(tags, str) or tags is None else ",".join(tags)) and s["urgent_pct"]:
		amount = (total * Decimal(str(s["urgent_pct"])) / 100).quantize(TENGE, rounding=ROUND_HALF_UP)
		if amount:
			out.append({"kind": EXTRA, "title": f"Срочность +{s['urgent_pct']:g}%", "amount": float(amount)})
			total += amount
	if s["min_order"] and Decimal(0) < total < Decimal(str(s["min_order"])):
		out.append({"kind": EXTRA, "title": "До минимального заказа",
					"amount": float(Decimal(str(s["min_order"])) - total)})
	return out


# ------------------------------------------------------------------ order --

def _intake(raw) -> list[dict]:
	if isinstance(raw, str):
		raw = frappe.parse_json(raw) if raw.strip() else []
	out = []
	for index, row in enumerate(raw or [], start=1):
		if not isinstance(row, dict):
			continue
		what = " ".join(str(row.get("what") or "").split())[:140]
		if not what:
			continue
		qty = _number(row.get("qty") or 1, f"Материал клиента {index}, количество")
		out.append({"what": what, "qty": float(qty),
					"unit": " ".join(str(row.get("unit") or "шт").split())[:20],
					"defects": " ".join(str(row.get("defects") or "").split())[:200] or None})
	if len(out) > MAX_INTAKE:
		frappe.throw(f"Не больше {MAX_INTAKE} строк материала клиента.")
	return out


def save_draft(*, customer: str, delivery_date: str | None = None, lines=None, intake=None, terms=False,
			   tags=None, notes: str | None = None, order: str | None = None) -> dict:
	"""A new order of CNC work, or a draft changed."""
	facade_prices.ensure_editor()
	company = current_company()
	customer = facade_order._customer(customer, company)
	tag_list = mdf_tags.clean(tags, mdf_tags.ORDER, "Заказ")
	quote = price(lines or [], customer=customer, tags=tag_list, company=company)
	if not quote["lines"]:
		frappe.throw("Добавьте хотя бы одну работу.")
	taken_in = _intake(intake)
	_ensure_item()
	due = getdate(delivery_date) if delivery_date else getdate(add_days(nowdate(), 1))
	if due < getdate(nowdate()):
		frappe.throw("Срок не может быть в прошлом.")
	if order:
		doc = _order(order)
		if doc.docstatus != 0:
			frappe.throw("Заказ уже принят — его не меняют, а отменяют и оформляют заново.")
		doc.set("items", [])
	else:
		doc = frappe.new_doc("Sales Order")
		doc.update({"company": company, "transaction_date": nowdate(), "order_type": "Sales",
					"korkem_direction": directions.CNC, "ignore_pricing_rule": 1, "disable_rounded_total": 1})
	doc.customer = customer
	doc.delivery_date = str(due)
	doc.terms = (notes or "").strip()[:2000] or None
	doc.korkem_tags = tag_list
	doc.korkem_urgent = 1 if "urgent" in mdf_tags.parse(tag_list) else 0
	doc.korkem_cnc_intake = frappe.as_json(taken_in) if taken_in else None
	doc.korkem_cnc_terms = 1 if directions.flag(terms) else 0
	for line in quote["lines"]:
		doc.append("items", _row(line, due))
	for extra in quote["extras"]:
		doc.append("items", _row({**extra, "qty": 1, "rate": extra["amount"], "unit": "шт", "minutes": 0,
								  "note": None, "material": None, "service": None}, due))
	doc.save()
	if Decimal(str(flt(doc.grand_total))) != Decimal(str(quote["total"])):
		frappe.throw(f"ERPNext посчитал заказ на {flt(doc.grand_total):,.0f} ₸, а расчёт — на "
					 f"{quote['total']:,.0f} ₸. Вероятно, настроен налог. Заказ не сохранён.".replace(",", " "))
	audit.record_audit(action="cnc.order_draft_saved", entity_type="Sales Order", entity_id=doc.name,
					   diff={"customer": customer, "total": quote["total"], "minutes": quote["minutes"]})
	return card(doc.name)


def _row(line: dict, due) -> dict:
	qty = Decimal(str(line["qty"]))
	amount = Decimal(str(line.get("amount", 0)))
	material = line.get("material")
	return {
		"item_code": material or CNC_ITEM,
		"item_name": line["title"][:140],
		"description": line["title"],
		"qty": float(qty),
		"uom": frappe.db.get_value("Item", material, "stock_uom") if material else "Nos",
		"rate": float((amount / qty).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)) if qty else 0,
		"delivery_date": str(due),
		"korkem_line_note": line.get("note"),
		"korkem_cnc_service": line.get("service"),
		"korkem_cnc_unit": line.get("unit"),
		"korkem_cnc_minutes": line.get("minutes") or 0,
		"korkem_cnc_kind": line["kind"],
		"warehouse": material_stock._receiving_warehouse(current_company(), None) if material else None,
	}


def accept(order: str) -> dict:
	"""«Принять»: the order is fixed, goes into the machine's queue, and the
	shop's own material it sells is taken off the warehouse."""
	facade_prices.ensure_editor()
	doc = _order(order)
	if doc.docstatus != 0:
		frappe.throw("Заказ уже принят.")
	savepoint = "korkem_cnc_" + frappe.generate_hash(length=8)
	frappe.db.savepoint(savepoint)
	try:
		doc.submit()
		_issue_material(doc)
	except Exception:
		frappe.db.rollback(save_point=savepoint)
		raise
	frappe.db.release_savepoint(savepoint)
	audit.record_audit(action="cnc.order_accepted", entity_type="Sales Order", entity_id=doc.name,
					   diff={"total": flt(doc.grand_total)})
	return card(doc.name)


def _issue_material(doc) -> None:
	rows = [i for i in doc.items if i.get("korkem_cnc_kind") == MATERIAL]
	if not rows:
		return
	warehouse = material_stock._receiving_warehouse(doc.company, None)
	have = material_stock._stock([i.item_code for i in rows], doc.company)
	for i in rows:
		if have.get(i.item_code, (0.0, 0.0))[0] + 1e-6 < flt(i.qty):
			frappe.throw(f"«{i.item_name}»: на складе {have.get(i.item_code, (0.0, 0.0))[0]:g}, нужно {flt(i.qty):g}.")
	entry = frappe.get_doc({
		"doctype": "Stock Entry", "stock_entry_type": "Material Issue", "purpose": "Material Issue",
		"company": doc.company, "korkem_cnc_order": doc.name, "remarks": f"ЧПУ: материал для {doc.name}",
		"items": [{"item_code": i.item_code, "qty": flt(i.qty), "uom": i.uom, "stock_uom": i.uom,
				   "conversion_factor": 1, "s_warehouse": warehouse} for i in rows],
	})
	entry.insert(ignore_permissions=True)
	entry.submit()


def _return_material(order: str) -> None:
	for name in frappe.get_all("Stock Entry", filters={"korkem_cnc_order": order, "docstatus": 1}, pluck="name"):
		entry = frappe.get_doc("Stock Entry", name)
		entry.flags.ignore_permissions = True
		entry.cancel()


def start(order: str) -> dict:
	"""On the machine now."""
	facade_prices.ensure_editor()
	doc = _accepted(order)
	if doc.korkem_ready_on:
		frappe.throw("Заказ уже готов.")
	doc.db_set({"korkem_cnc_started_on": now_datetime(), "korkem_hold_reason": None}, update_modified=True)
	doc.add_comment("Comment", "На станке.")
	audit.record_audit(action="cnc.started", entity_type="Sales Order", entity_id=doc.name, diff={})
	return card(doc.name)


def ready(order: str, done=True) -> dict:
	"""«Готово» — or taken back, a mistake."""
	facade_prices.ensure_editor()
	doc = _accepted(order)
	if doc.korkem_handed_over_on:
		frappe.throw("Заказ уже выдан.")
	done = directions.flag(done)
	doc.db_set({"korkem_ready_on": nowdate() if done else None,
				"korkem_cnc_started_on": doc.korkem_cnc_started_on or (now_datetime() if done else None)},
			   update_modified=True)
	doc.add_comment("Comment", "Готово." if done else "Отметка «готово» снята.")
	audit.record_audit(action="cnc.ready", entity_type="Sales Order", entity_id=doc.name, diff={"done": done})
	return card(doc.name)


def hold(order: str, reason: str | None = None) -> dict:
	"""Waiting — for the customer's file, his material, his answer; or no longer."""
	facade_prices.ensure_editor()
	doc = _accepted(order)
	reason = " ".join(str(reason or "").split())[:300] or None
	doc.db_set("korkem_hold_reason", reason, update_modified=True)
	doc.add_comment("Comment", f"Ждём: {reason}." if reason else "Больше не ждём.")
	return card(doc.name)


def hand_over(order: str, comment: str | None = None, taken_by: str | None = None,
			  taken_phone: str | None = None) -> dict:
	"""«Выдан» — not with a debt, unless an administrator says why."""
	from korkem_manufacturing.services import mdf_orders

	facade_prices.ensure_editor()
	doc = _accepted(order)
	if doc.korkem_handed_over_on:
		frappe.throw("Заказ уже выдан.")
	if not doc.korkem_ready_on:
		frappe.throw("Заказ ещё не готов.")
	debt = _debt(doc)
	if debt > 0:
		if not mdf_orders._is_owner():
			frappe.throw(f"Остаток долга {debt:,.0f} ₸ — выдать может администратор с комментарием.".replace(",", " "))
		comment = mdf_orders._reason(comment, "Укажите, почему заказ выдан с долгом.")
		doc.add_comment("Comment", f"Выдан с долгом {debt:,.0f} ₸: {comment}".replace(",", " "))
	taken_by = (taken_by or "").strip()[:140] or None
	doc.db_set({"korkem_handed_over_on": nowdate(), "korkem_taken_by": taken_by,
				"korkem_taken_phone": (taken_phone or "").strip()[:40] or None if taken_by else None,
				"korkem_handed_over_by": frappe.session.user}, update_modified=True)
	doc.add_comment("Comment", f"Выдан. Забрал: {taken_by or 'клиент'}.")
	audit.record_audit(action="cnc.handed_over", entity_type="Sales Order", entity_id=doc.name,
					   diff={"debt": float(debt), "taken_by": taken_by})
	return card(doc.name)


def cancel(order: str, reason: str) -> dict:
	"""A draft is deleted; an accepted order is cancelled with a reason, and
	the shop's material it took goes back to the warehouse."""
	from korkem_manufacturing.services import mdf_orders

	facade_prices.ensure_editor()
	doc = _order(order)
	if doc.docstatus == 0:
		frappe.delete_doc("Sales Order", doc.name, ignore_permissions=True)
		return {"name": order, "deleted": True}
	if doc.docstatus == 2:
		frappe.throw("Заказ уже отменён.")
	if doc.korkem_handed_over_on:
		frappe.throw("Выданный заказ не отменяют.")
	reason = mdf_orders._reason(reason, "Укажите причину отмены.")
	if flt(doc.advance_paid):
		frappe.throw("По заказу есть оплаты — сначала верните их (удалите с причиной).")
	_return_material(doc.name)
	doc.cancel()
	doc.add_comment("Comment", f"Отменён: {reason}")
	audit.record_audit(action="cnc.cancelled", entity_type="Sales Order", entity_id=doc.name, diff={"reason": reason})
	return card(doc.name)


# ---------------------------------------------------------------- reading --

def status_of(doc) -> str:
	if doc.docstatus == 2:
		return "cancelled"
	if doc.docstatus == 0:
		return "draft"
	if doc.get("korkem_handed_over_on"):
		return "handed_over"
	if doc.get("korkem_ready_on"):
		return "ready"
	if doc.get("korkem_cnc_started_on"):
		return "on_machine"
	return "queued"


def _minutes(order: str) -> float:
	return flt(frappe.db.sql("""select sum(korkem_cnc_minutes) from `tabSales Order Item` where parent = %s""",
							 order)[0][0])


def queue(company: str | None = None) -> list[dict]:
	"""The machine's queue: on the machine first, then the urgent, then by
	acceptance; each with the minutes before it and when it will be ready,
	at the machine's working minutes a day."""
	company = company or current_company()
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.CNC, "docstatus": 1,
				 "korkem_ready_on": ["is", "not set"], "korkem_handed_over_on": ["is", "not set"]},
		fields=["name", "customer_name", "korkem_urgent", "korkem_cnc_started_on", "korkem_hold_reason",
				"creation", "delivery_date"],
		limit_page_length=0,
	)
	rows.sort(key=lambda r: (not r.korkem_cnc_started_on, not r.korkem_urgent, r.creation))
	day = settings(company)["day_minutes"] or DEFAULT_DAY_MINUTES
	ahead, out = 0.0, []
	for r in rows:
		mine = _minutes(r.name)
		done_after = ahead + mine
		days = int(done_after // day)
		out.append({"name": r.name, "customer_name": r.customer_name, "urgent": bool(r.korkem_urgent),
					"on_machine": bool(r.korkem_cnc_started_on), "hold": r.korkem_hold_reason,
					"minutes": mine, "minutes_ahead": ahead,
					"eta": str(_working_day(days)), "due": str(r.delivery_date)})
		if not r.korkem_hold_reason:
			ahead = done_after
	return out


def _working_day(days: int):
	"""So many working days on from today; Sunday is not one."""
	day = getdate(nowdate())
	while days > 0 or day.weekday() == 6:
		day += timedelta(days=1)
		if day.weekday() != 6:
			days -= 1
	return day


def card(order: str) -> dict:
	from korkem_manufacturing.services import mdf_orders, mdf_payments

	facade_prices.ensure_editor()
	doc = _order(order)
	lines = [{"name": i.name, "kind": i.get("korkem_cnc_kind") or SERVICE, "service": i.get("korkem_cnc_service"),
			  "material": i.item_code if i.get("korkem_cnc_kind") == MATERIAL else None, "title": i.item_name,
			  "unit": i.get("korkem_cnc_unit"), "qty": flt(i.qty), "rate": flt(i.rate), "amount": flt(i.amount),
			  "minutes": flt(i.get("korkem_cnc_minutes")), "note": i.get("korkem_line_note")} for i in doc.items]
	place = next((q for q in queue(doc.company) if q["name"] == doc.name), None) if doc.docstatus == 1 else None
	return {
		"name": doc.name, "status": status_of(doc), "customer": doc.customer, "customer_name": doc.customer_name,
		"phone": frappe.db.get_value("Customer", doc.customer, "mobile_no"),
		"customer_tags": mdf_tags.parse(frappe.db.get_value("Customer", doc.customer, "korkem_tags")),
		"tags": mdf_tags.parse(doc.get("korkem_tags")), "created_on": str(doc.transaction_date),
		"delivery_date": str(doc.delivery_date), "notes": doc.terms,
		"intake": frappe.parse_json(doc.korkem_cnc_intake) if doc.get("korkem_cnc_intake") else [],
		"terms": bool(doc.get("korkem_cnc_terms")),
		"lines": [line for line in lines if line["kind"] != EXTRA],
		"extras": [{"title": line["title"], "amount": line["amount"]} for line in lines if line["kind"] == EXTRA],
		"minutes": sum(line["minutes"] for line in lines),
		"total": flt(doc.grand_total), "paid": flt(doc.advance_paid), "debt": float(_debt(doc)),
		"payments": mdf_payments.rows(doc.name) if doc.docstatus else [],
		"started_on": str(doc.korkem_cnc_started_on) if doc.get("korkem_cnc_started_on") else None,
		"ready_on": str(doc.korkem_ready_on) if doc.get("korkem_ready_on") else None,
		"handed_over_on": str(doc.korkem_handed_over_on) if doc.get("korkem_handed_over_on") else None,
		"taken_by": doc.get("korkem_taken_by"), "hold_reason": doc.get("korkem_hold_reason"),
		"queue": place, "history": mdf_orders.comments(doc.name) if doc.docstatus else [],
	}


def listing(status: str | None = None, search: str | None = None) -> dict:
	"""Orders newest first; the machine's queue and what is owed above them."""
	facade_prices.ensure_editor()
	company = current_company()
	if status and status not in STATUSES:
		frappe.throw(f"Статус — один из: {', '.join(STATUSES)}.")
	filters = {"company": company, "korkem_direction": directions.CNC}
	rows = frappe.get_all(
		"Sales Order", filters=filters,
		fields=["name", "customer_name", "transaction_date", "delivery_date", "grand_total", "advance_paid",
				"docstatus", "korkem_tags", "korkem_ready_on", "korkem_handed_over_on", "korkem_cnc_started_on",
				"korkem_hold_reason", "korkem_urgent"],
		order_by="creation desc", limit_page_length=500)
	needle = (search or "").strip().casefold()
	places = {q["name"]: q for q in queue(company)}
	out = []
	for r in rows:
		state = status_of(r)
		if status and state != status:
			continue
		if needle and needle not in f"{r.name} {r.customer_name}".casefold():
			continue
		out.append({"name": r.name, "customer_name": r.customer_name, "status": state,
					"created_on": str(r.transaction_date), "due": str(r.delivery_date), "total": flt(r.grand_total),
					"debt": float(_debt(r)), "urgent": bool(r.korkem_urgent), "hold": r.korkem_hold_reason,
					"eta": places.get(r.name, {}).get("eta"), "minutes": _minutes(r.name)})
	waiting = list(places.values())
	return {
		"orders": out,
		"queue_minutes": sum(q["minutes"] for q in waiting if not q["hold"]),
		"queue_orders": len(waiting),
		"ready": sum(1 for r in out if r["status"] == "ready"),
		"debt": sum(r["debt"] for r in out),
		"settings": settings(company),
	}


# ---------------------------------------------------------------- helpers --

def _ensure_item() -> None:
	if frappe.db.exists("Item", CNC_ITEM):
		return
	group = next((g for g in ("Services", "Products", "All Item Groups") if frappe.db.exists("Item Group", g)), None)
	frappe.get_doc({"doctype": "Item", "item_code": CNC_ITEM, "item_name": "Услуга ЧПУ", "item_group": group,
					"stock_uom": "Nos", "is_stock_item": 0, "is_sales_item": 1, "is_purchase_item": 0,
					"include_item_in_manufacturing": 0}).insert(ignore_permissions=True)


def _order(name: str):
	if not name or not frappe.db.exists("Sales Order", name):
		frappe.throw("Заказ не найден.", frappe.DoesNotExistError)
	doc = frappe.get_doc("Sales Order", name)
	enforce_tenant_scope(doc.company)
	if doc.get("korkem_direction") != directions.CNC:
		frappe.throw("Это не заказ услуг ЧПУ.", frappe.DoesNotExistError)
	return doc


def _accepted(name: str):
	doc = _order(name)
	if doc.docstatus != 1:
		frappe.throw("Сначала примите заказ." if doc.docstatus == 0 else "Заказ отменён.")
	return doc


def _debt(row) -> Decimal:
	if row.docstatus != 1 or not mdf_tags.owed(row.get("korkem_tags")):
		return Decimal(0)
	return max(Decimal(0), Decimal(str(flt(row.grand_total))) - Decimal(str(flt(row.advance_paid))))


def _ensure_owner() -> None:
	from korkem_manufacturing.services import mdf_orders

	facade_prices.ensure_editor()
	if not mdf_orders._is_owner():
		frappe.throw("Прайс и настройки ЧПУ меняет администратор.", frappe.PermissionError)


def _number(value, what: str) -> Decimal:
	try:
		number = Decimal(str(value).replace(",", ".").replace(" ", ""))
	except (InvalidOperation, ValueError):
		frappe.throw(f"{what}: нужно число.")
	if not number.is_finite():
		frappe.throw(f"{what}: нужно число.")
	return number


def _money(value, what: str) -> Decimal:
	number = _number(value, what)
	if number < 0:
		frappe.throw(f"{what}: не меньше нуля.")
	return number.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
