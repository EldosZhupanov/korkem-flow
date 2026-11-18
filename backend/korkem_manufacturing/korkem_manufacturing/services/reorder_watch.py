# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Пора заказать» — the morning list (owner, 18.11.2026): the films that ran
low, by supplier and with the metres to order, and the glue that will not
last.

The films are «К заказу» itself (`film_orders.wanted`): the lines a person
added and the ones the shop's pace offers by itself (`film_dept._reorder`).
Nothing is ordered here — the list is said, and the person sends it to the
supplier from «К заказу» as before.

The glue in work is short when what is on the store does not cover the
vacuum press's queue, or lasts fewer than `GLUE_DAYS` days at the last
month's pace.

**When.** The morning hour (`HOUR`), once a day, and only when there is
something to order — an empty «всё есть» every morning teaches people not
to read it. Switched on with the evening summary's own switch, «утром».
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, getdate, now_datetime

from korkem_manufacturing import domain_events
from korkem_manufacturing.services import daily_summary, glue_stock, material_stock
from korkem_manufacturing.services.scope import current_company

EVENT = "reorder.morning"
HOUR = 9
GLUE_DAYS = 10
_SENT = "korkem_reorder_sent:{company}"


def _kg(value) -> str:
	return f"{flt(value):g}".replace(".", ",")


def report() -> dict:
	"""What to order now: films by supplier, and the glue that will not last."""
	material_stock._ensure_staff()
	from korkem_manufacturing.services import film_orders

	films = []
	for g in film_orders.wanted()["suppliers"]:
		if g["open"]:
			films.append({"supplier": g["name"], "lines": [{"title": x["title"], "metres": x["metres"],
															 "auto": bool(x.get("auto"))} for x in g["open"]]})
	glue = []
	stock = glue_stock.stock()
	days = flt(stock["usage"]["days"]) or 30
	for g in stock["glues"]:
		fact = g.get("fact") or {}
		pace = (flt(fact.get("kg_by_norm")) + max(flt(fact.get("kg_counted")), 0)) / days
		left = round(g["on_hand_kg"] / pace) if pace > 0 else None
		short = stock["queue"]["short_kg"] if g["in_work"] else 0
		if short > 0 or (left is not None and left < GLUE_DAYS):
			glue.append({"title": g["title"], "on_hand_kg": g["on_hand_kg"], "days_left": left, "short_kg": short})
	return {"films": films, "glue": glue}


def text(r: dict, company: str) -> str | None:
	if not r["films"] and not r["glue"]:
		return None
	name = frappe.db.get_value("Company", company, "company_name") or company
	lines = [f"Пора заказать — {name}", ""]
	for g in r["films"]:
		items = ", ".join(f"{x['title']} {_kg(x['metres'])} м" for x in g["lines"])
		lines.append(f"Плёнка, {g['supplier']}: {items}")
	for g in r["glue"]:
		parts = [f"на складе {_kg(g['on_hand_kg'])} кг"]
		if g["days_left"] is not None:
			parts.append(f"хватит на ~{g['days_left']} дн.")
		if g["short_kg"]:
			parts.append(f"для пресса не хватает {_kg(g['short_kg'])} кг")
		lines.append(f"Клей {g['title']}: {', '.join(parts)}")
	lines += ["", "Отправить поставщику — «Отдел плёнки → К заказу»."]
	return "\n".join(lines)


def run() -> dict:
	"""Hourly: the morning list once a day, when switched on and not empty."""
	now = now_datetime()
	today = str(getdate(now))
	if now.hour < HOUR:
		return {}
	try:
		company = current_company()
	except Exception:
		return {}
	if not daily_summary.settings(company)["morning"]:
		return {}
	if frappe.db.get_default(_SENT.format(company=company)) == today:
		return {}
	try:
		body = text(report(), company)
	except Exception:
		frappe.log_error(title="reorder_watch", message=frappe.get_traceback(with_context=True))
		return {}
	frappe.db.set_default(_SENT.format(company=company), today)
	if body:
		domain_events.emit(EVENT, company=company, day=today, body=body)
	return {company: bool(body)}
