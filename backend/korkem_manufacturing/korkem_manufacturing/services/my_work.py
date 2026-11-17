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

from korkem_manufacturing.services import directions, mdf_orders, mdf_volume, team
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
