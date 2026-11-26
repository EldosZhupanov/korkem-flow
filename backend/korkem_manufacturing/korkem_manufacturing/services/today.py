# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Сегодня» — the facade shop's home for the owner, an admin and managers
(owner, 27.11.2026: «открыл программу — сразу видно, что горит и что
делать»).

Nothing here is counted anew: the figures are the list's own
(`mdf_orders.overview`), the stages' load the shop board's
(`shop_board.board`), the film the warehouse lacks «К заказу»'s
(`film_shortage.count`). So the home and the screens it leads to never
disagree. What is added is the order of things:

- **what is late, and what will be** — overdue orders, and those the
  shop's pace says will miss their date while it can still be helped;
- **the load in days**, stage by stage, the jam in red;
- **«Нужно решить»** ranked by what hurts most — the jam first, then the
  dates at risk, the film to buy, stages given to nobody, urgent orders
  with no prepayment;
- **«Только что»** — the last things done, from the audit journal.
"""

from __future__ import annotations

import json

import frappe
from frappe.utils import flt, get_fullname

from korkem_manufacturing.services import (
	directions,
	facade_prices,
	film_shortage,
	mdf_orders,
	mdf_tags,
	shop_board,
)
from korkem_manufacturing.services.scope import current_company

#: What «Только что» tells, from the audit journal.
RECENT_ACTIONS = ("mdf.order_accepted", "mdf.stage", "mdf.handed_over", "mdf.order_cancelled",
				  "payment.receive_recorded")
RECENT = 8


def today() -> dict:
	"""The shop today: the four figures, the load by stage, what to decide, what was done."""
	facade_prices.ensure_editor()
	company = current_company()
	overview = mdf_orders.overview()
	board = shop_board.board()
	stage_days = {s["stage"]: s for s in board["stages"]}
	queues = {q["stage"]: q["orders"] for q in mdf_orders.plan(1)["stages"]}
	late = board["late"]
	# Will miss its date: «Жоспар» says so, or its stage is jammed for longer
	# than the days it has left.
	at_risk = [o for o in late if not o["overdue"]]
	at_risk_names = {o["order"] for o in at_risk}
	for stage in board["stages"]:
		days = stage.get("days") or 0
		if not stage.get("jam"):
			continue
		for o in queues.get(stage["stage"], []):
			if o["name"] not in at_risk_names and not o["overdue"] and o["days_left"] < days:
				at_risk.append({"order": o["name"], "customer": o["customer_name"], "days_left": o["days_left"],
								"stage": stage["stage"], "title": stage["title"]})
				at_risk_names.add(o["name"])
	ready = _ready_money(company)
	return {
		"day": board["day"],
		"figures": {
			"overdue": overview["overdue"],
			"at_risk": len(at_risk),
			"due_soon": overview["due_soon"],
			"ready": overview["ready"],
			"ready_money": ready,
			"debt": overview["debt"],
			"debtors": overview["debtors"],
		},
		"load": [
			{"stage": s["stage"], "title": s["title"], "waiting_m2": s["waiting_m2"],
			 "waiting_orders": s["waiting_orders"], "days": s["days"], "jam": s["jam"], "nobody": s["nobody"]}
			for s in board["stages"] if s["stage"] != "ready" and (s["waiting_m2"] or s["jam"])
		],
		"decide": _decide(company, overview, stage_days, at_risk),
		"recent": _recent(company),
	}


def _ready_money(company: str) -> float:
	"""What comes in when the ready orders are handed over: their debt."""
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "korkem_ready_on": ["is", "set"], "korkem_handed_over_on": ["is", "not set"]},
		fields=["name", "grand_total", "advance_paid"],
		limit_page_length=0,
	)
	return round(sum(max(0.0, flt(r.grand_total) - flt(r.advance_paid)) for r in rows), 2)


def _decide(company: str, overview: dict, stages: dict, at_risk: list) -> list[dict]:
	"""What to decide, the worst first: each with what it is about and where
	it is decided."""
	out: list[dict] = []
	jam = max((s for s in stages.values() if s.get("jam")), key=lambda s: s.get("days") or 0, default=None)
	if jam:
		bottleneck = overview.get("bottleneck") or {}
		out.append({"kind": "jam", "stage": jam["stage"], "title": jam["title"], "days": jam["days"],
					"waiting_m2": jam["waiting_m2"],
					"late": bottleneck.get("late") if bottleneck.get("stage") == jam["stage"] else None})
	if at_risk:
		out.append({"kind": "at_risk", "count": len(at_risk),
					"orders": [o["order"] for o in at_risk[:5]]})
	films = [f for f in film_shortage.count(company)["by_film"] if f["to_buy"] > 0]
	if films:
		out.append({"kind": "film", "count": len(films),
					"films": [{"decor": f["decor"], "to_buy": f["to_buy"]} for f in films[:3]]})
	nobody = [s for s in stages.values() if s.get("nobody") and s.get("waiting_orders")]
	for s in nobody:
		out.append({"kind": "post_empty", "stage": s["stage"], "title": s["title"],
					"orders": s["waiting_orders"]})
	unassigned = _unassigned(company)
	if unassigned:
		out.append({"kind": "unassigned", "count": sum(unassigned.values()),
					"stages": [{"stage": k, "title": mdf_orders.STAGE_NAMES.get(k, k), "orders": v}
							   for k, v in sorted(unassigned.items(), key=lambda kv: -kv[1])]})
	unpaid = _urgent_unpaid(company)
	if unpaid:
		out.append({"kind": "no_prepay", "count": len(unpaid), "orders": unpaid[:5]})
	return out


def _unassigned(company: str) -> dict[str, int]:
	"""Open orders whose waiting stage is given to nobody, by stage."""
	from korkem_manufacturing.services import stage_crew

	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "korkem_ready_on": ["is", "not set"], "korkem_handed_over_on": ["is", "not set"],
				 "korkem_hold_reason": ["is", "not set"]},
		fields=["name", "korkem_finish", "korkem_extra_stages", "korkem_coatings", "korkem_tags",
				*mdf_orders.STAGES.values(), *mdf_orders.STAGE_TO.values()],
		limit_page_length=0,
	)
	crews = stage_crew.of_orders([r.name for r in rows], "to")
	out: dict[str, int] = {}
	for r in rows:
		waiting = next((s for s in mdf_orders.stages_of(r) if not r.get(mdf_orders.STAGES[s])), None)
		if not waiting or waiting == "ready":
			continue
		if not r.get(mdf_orders.STAGE_TO[waiting]) and not crews.get((r.name, waiting)):
			out[waiting] = out.get(waiting, 0) + 1
	return out


def _urgent_unpaid(company: str) -> list[str]:
	"""Urgent orders taken in with nothing paid yet."""
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "korkem_handed_over_on": ["is", "not set"], "korkem_tags": ["like", "%urgent%"]},
		fields=["name", "advance_paid", "korkem_tags"],
		order_by="delivery_date asc",
		limit_page_length=0,
	)
	return [r.name for r in rows if "urgent" in mdf_tags.parse(r.korkem_tags) and flt(r.advance_paid) <= 0]


def _recent(company: str) -> list[dict]:
	"""The last things done in the shop, newest first."""
	rows = frappe.get_all(
		"Domain Audit Event",
		filters={"company": company, "action": ["in", list(RECENT_ACTIONS)], "entity_type": "Sales Order"},
		fields=["action", "entity_id", "actor", "diff_json", "creation"],
		order_by="creation desc",
		limit_page_length=RECENT,
	)
	names = {}
	out = []
	for r in rows:
		try:
			diff = json.loads(r.diff_json or "{}")
		except ValueError:
			diff = {}
		if r.actor not in names:
			names[r.actor] = get_fullname(r.actor)
		item = {"action": r.action, "order": r.entity_id, "at": str(r.creation)[:16], "by": names[r.actor]}
		if r.action == "mdf.stage":
			item.update({"stage": diff.get("stage"), "title": mdf_orders.STAGE_NAMES.get(diff.get("stage"), ""),
						 "done": bool(diff.get("done"))})
		elif r.action == "mdf.order_accepted":
			item["amount"] = flt(diff.get("total"))
		elif r.action.startswith("payment."):
			item["amount"] = flt(diff.get("amount"))
		out.append(item)
	return out
