# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Мои заказы» — a worker's own stages, from his own phone (owner,
17.11.2026: «каждый отмечает со своего телефона и видит свой проделанный
объём, а кто не умеет — менеджер сам»).

The person is the Employee whose `user_id` is the signed-in user
(`team.me`); his posts (`team`) say which stages are his. An order's stage
is his to do when it is given to him, or to nobody, and every stage before it
is done; one not yet reachable is shown as coming. He ticks only his own
stage: the manager still ticks anything for anyone (`mdf_orders.set_stage`).

His volume is what the shop's volume counts (`mdf_volume`): the m² of every
order whose stage was ticked with his name, this month.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import flt, getdate, nowdate

from korkem_manufacturing.services import directions, facade_prices, mdf_orders, mdf_volume, search_text, team
from korkem_manufacturing.services.scope import current_company


def _me() -> dict:
	person = team.me()
	if not person:
		frappe.throw("Ваш вход не привязан к сотруднику — попросите менеджера в «Команде».",
					 frappe.PermissionError)
	return person


def _mine(stage: str, coatings, posts: list[str]) -> bool:
	return bool(set(team.posts_for_stage(stage, coatings)) & set(posts))


def work() -> dict:
	"""His stages: ready now, coming; and his m² this month."""
	person = team.me()
	if not person:
		return {"me": None, "ready": [], "coming": [], "month": None}
	company = current_company()
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "korkem_handed_over_on": ["is", "not set"], "korkem_hold_reason": ["is", "not set"]},
		fields=["name", "customer_name", "delivery_date", "korkem_finish", "korkem_extra_stages", "korkem_coatings",
				"korkem_tags", *mdf_orders.STAGES.values(), *mdf_orders.STAGE_TO.values()],
		order_by="delivery_date asc, name asc",
		limit_page_length=1000,
	)
	areas = mdf_volume._areas([r.name for r in rows])
	ready, coming = [], []
	for r in rows:
		needed = mdf_orders.stages_of(r)
		for i, stage in enumerate(needed):
			if r.get(mdf_orders.STAGES[stage]) or not _mine(stage, r.korkem_coatings, person["posts"]):
				continue
			given = r.get(mdf_orders.STAGE_TO[stage])
			if given and given != person["employee"]:
				continue
			row = {"order": r.name, "customer": r.customer_name, "delivery_date": str(r.delivery_date),
				   "stage": stage, "area_m2": flt(areas.get(r.name, Decimal(0)), 2), "given_to_me": given == person[
					   "employee"], "overdue": getdate(r.delivery_date) < getdate(nowdate())}
			before = [s for s in needed[:i] if not r.get(mdf_orders.STAGES[s])]
			(coming if before else ready).append({**row, "waiting_for": before})
	return {"me": person, "ready": ready, "coming": coming, "month": _month(person["employee"], company)}


def _month(employee: str, company: str) -> dict:
	today = getdate(nowdate())
	since = today.replace(day=1)
	ticked = [t for t in mdf_volume._ticked(company, since, today) if t[2] == employee]
	areas = mdf_volume._areas({order for order, *_ in ticked})
	by_stage: dict[str, Decimal] = {}
	for order, stage, _, _ in ticked:
		by_stage[stage] = by_stage.get(stage, Decimal(0)) + areas.get(order, Decimal(0))
	return {
		"since": str(since),
		"area_m2": flt(sum(by_stage.values(), Decimal(0)), 2),
		"stages": {s: flt(v, 2) for s, v in by_stage.items()},
		"orders": len({order for order, *_ in ticked}),
	}


def done(order: str, stage: str, undo=False) -> dict:
	"""«Сделал»: his own stage of an order, ticked with his name — or, the
	same day, taken back."""
	person = _me()
	doc = frappe.get_doc("Sales Order", order)
	if doc.company != current_company() or doc.korkem_direction != directions.FACADES:
		frappe.throw("Такого заказа нет.", frappe.DoesNotExistError)
	if stage not in mdf_orders.STAGES or not _mine(stage, doc.get("korkem_coatings"), person["posts"]):
		frappe.throw("Этот этап — не ваш.", frappe.PermissionError)
	given = doc.get(mdf_orders.STAGE_TO[stage])
	if given and given != person["employee"]:
		name = frappe.db.get_value("Employee", given, "employee_name")
		frappe.throw(f"Этот этап отдан сотруднику «{name}».", frappe.PermissionError)
	if str(undo).lower() in ("1", "true", "yes"):
		if doc.get(mdf_orders.STAGE_BY[stage]) != person["employee"]:
			frappe.throw("Снять можно только свою отметку.", frappe.PermissionError)
		if str(doc.get(mdf_orders.STAGES[stage])) != nowdate():
			frappe.throw("Отметку прошлых дней снимает менеджер.", frappe.PermissionError)
		mdf_orders._tick(order, stage, False)
	else:
		mdf_orders._tick(order, stage, True, worker=person["employee"])
	return work()


#: What a sticker's QR says: the order's name, behind this prefix so a
#: scanner's text is never mistaken for something typed.
QR_PREFIX = "KORKEM:ORDER:"


def _order_by_code(code: str, company: str) -> str:
	"""The order a scanned (or typed) code names: «KORKEM:ORDER:SAL-ORD-…»,
	the name itself, or its number («245», «№245»)."""
	text = (code or "").strip()
	if text.upper().startswith(QR_PREFIX):
		text = text[len(QR_PREFIX):].strip()
	base = {"company": company, "korkem_direction": directions.FACADES, "docstatus": 1}
	if frappe.db.exists("Sales Order", {**base, "name": text}):
		return text
	number = search_text.number_of(text)
	if number:
		for name in frappe.get_all("Sales Order", filters={**base, "name": ["like", f"%{number}"]},
								   pluck="name", order_by="creation desc", limit_page_length=50):
			if search_text.number_in(name) == number:
				return name
	frappe.throw(f"Заказ «{code}» не найден.", frappe.DoesNotExistError)


def scan(code: str) -> dict:
	"""A sticker scanned on the shop floor (owner, 18.11.2026): the order, and
	its stages — which are this worker's to tick now. A manager (who ticks
	anything) gets the same, every stage his."""
	company = current_company()
	person = team.me()
	manager = facade_prices.can_edit()
	if not person and not manager:
		frappe.throw("Ваш вход не привязан к сотруднику — попросите менеджера в «Команде».",
					 frappe.PermissionError)
	order = _order_by_code(code, company)
	doc = frappe.get_doc("Sales Order", order)
	needed = mdf_orders.stages_of(doc)
	stages = []
	for i, stage in enumerate(needed):
		done_on = doc.get(mdf_orders.STAGES[stage])
		given = doc.get(mdf_orders.STAGE_TO[stage])
		mine = manager or bool(person and _mine(stage, doc.get("korkem_coatings"), person["posts"])
							   and (not given or given == person["employee"]))
		waiting = [s for s in needed[:i] if not doc.get(mdf_orders.STAGES[s])]
		stages.append({
			"stage": stage, "name": mdf_orders.STAGE_NAMES.get(stage, stage),
			"done_on": str(done_on) if done_on else None, "mine": mine, "waiting_for": waiting,
			"by_me": bool(person and doc.get(mdf_orders.STAGE_BY[stage]) == person["employee"]),
		})
	areas = mdf_volume._areas([order])
	return {
		"order": order,
		"number": search_text.number_in(order),
		"customer": doc.customer_name,
		"decor": doc.get("korkem_decor_top"),
		"delivery_date": str(doc.delivery_date) if doc.delivery_date else None,
		"area_m2": flt(areas.get(order, Decimal(0)), 2),
		"handed_over": bool(doc.korkem_handed_over_on),
		"on_hold": bool(doc.get("korkem_hold_reason")),
		"manager": manager,
		"stages": stages,
	}


def tick(order: str, stage: str, undo=False) -> dict:
	"""«Сделал» from a scan: his own stage as in «Мои заказы»; a manager's
	tick as on the order's card. Answers the scan again."""
	person = team.me()
	doc = frappe.get_doc("Sales Order", order)
	own = bool(person and stage in mdf_orders.STAGES
			   and _mine(stage, doc.get("korkem_coatings"), person["posts"]))
	if own or not facade_prices.can_edit():
		done(order, stage, undo)
	else:
		mdf_orders.set_stage(order, stage, not directions.flag(undo))
	return scan(order)
