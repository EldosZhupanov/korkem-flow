# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Итоги дня» — the owner's evening question in one message (owner, 18.11.2026):
сколько пришло (наличными, Kaspi…), сколько ушло, что приняли и выдали,
что просрочено, кто должен и кому написать.

**When.** At the hour the owner chose (`HOUR`, 20:00 unless he says
otherwise), once a day: the hourly scheduler asks `run`, which sends a
company's summary the first time it finds the hour has come, and remembers
the day. Off until the owner switches it on.

**How it travels.** The domain only says `summary.daily` with the text;
korkem_ai decides who hears it and on which channel — the owner's linked
Telegram or WhatsApp (domain_events, ADR-0003). A day's summary is one
delivery however many times the scheduler wakes (`Notification Delivery`
is keyed by the day). In the app the same summary is shown, copied, or sent
to the owner's own WhatsApp by hand.
"""

from __future__ import annotations

import json
from decimal import Decimal

import frappe
from frappe.utils import flt, getdate, now_datetime, nowdate

from korkem_manufacturing import domain_events
from korkem_manufacturing.services import (
	audit,
	cnc_orders,
	customer_messages,
	directions,
	facade_prices,
	mdf_cash,
	mdf_orders,
)
from korkem_manufacturing.services.scope import current_company

EVENT = "summary.daily"
HOUR = 20
_SETTINGS = "korkem_daily_summary:{company}"
_SENT = "korkem_daily_summary_sent:{company}"


def _money(value) -> str:
	return f"{flt(value):,.0f} ₸".replace(",", " ")


def settings(company: str | None = None) -> dict:
	raw = frappe.db.get_default(_SETTINGS.format(company=company or current_company()))
	try:
		saved = json.loads(raw) if raw else {}
	except ValueError:
		saved = {}
	hour = saved.get("hour")
	return {"enabled": bool(saved.get("enabled")), "hour": int(HOUR if hour in (None, "") else hour),
			# «Пора заказать» in the morning (`reorder_watch`), switched apart.
			"morning": bool(saved.get("morning"))}


def set_settings(enabled=None, hour=None, morning=None) -> dict:
	"""The owner switches it on or off and picks the hour; `morning` — the
	morning list of what to order."""
	facade_prices.ensure_editor()
	company = current_company()
	now = settings(company)
	if enabled is not None:
		now["enabled"] = str(enabled).lower() in ("1", "true", "yes")
	if morning is not None:
		now["morning"] = str(morning).lower() in ("1", "true", "yes")
	if hour not in (None, ""):
		hour = int(hour)
		if not 0 <= hour <= 23:
			frappe.throw("Час — от 0 до 23.")
		now["hour"] = hour
	frappe.db.set_default(_SETTINGS.format(company=company), json.dumps(now))
	audit.record_audit(action="daily_summary.settings", entity_type="Company", entity_id=company, diff=now,
					   company=company)
	return preview()


def collect(company: str, day=None) -> dict:
	"""The day's figures for one company."""
	day = getdate(day or nowdate())
	payments = mdf_cash._payments(company, day, day)
	expenses = mdf_cash._expenses(company, day, day)
	by_method: dict[str, Decimal] = {}
	for p in payments:
		method, _bank = mdf_cash.method_and_bank(p.method, p.bank)
		by_method[method] = by_method.get(method, Decimal(0)) + Decimal(str(flt(p.amount)))
	came = sum(by_method.values(), Decimal(0))
	went = sum((Decimal(str(flt(e["amount"]))) for e in expenses), Decimal(0))

	base = {"company": company, "korkem_direction": ["in", [directions.FACADES, directions.CNC]]}
	fields = ["name", "docstatus", "transaction_date", "delivery_date", "grand_total", "advance_paid",
			  "korkem_tags", "korkem_direction", "korkem_ready_on", "korkem_handed_over_on", "korkem_hold_reason",
			  "korkem_cnc_started_on", *mdf_orders.STAGES.values()]
	accepted = frappe.get_all("Sales Order", filters={**base, "docstatus": 1, "transaction_date": day},
							  fields=["grand_total"], limit_page_length=0)
	ready = frappe.db.count("Sales Order", {**base, "docstatus": 1, "korkem_ready_on": day})
	handed = frappe.db.count("Sales Order", {**base, "docstatus": 1, "korkem_handed_over_on": day})
	open_rows = frappe.get_all("Sales Order", filters={**base, "docstatus": 1, "korkem_handed_over_on": ["is", "not set"]},
							   fields=fields, limit_page_length=0)
	overdue = sum(1 for r in open_rows if r.korkem_direction == directions.FACADES and mdf_orders._overdue(r))
	owed = Decimal(0)
	for r in frappe.get_all("Sales Order", filters={**base, "docstatus": 1}, fields=fields, limit_page_length=0):
		owed += (cnc_orders._debt if r.korkem_direction == directions.CNC else mdf_orders._debt)(r)

	film = frappe.get_all(
		"Stock Entry",
		filters={"company": company, "docstatus": 1, "korkem_film_kind": "sale", "posting_date": day},
		fields=["korkem_film_amount", "korkem_film_paid"], limit_page_length=0,
	)
	to_write = customer_messages.counts(company)
	return {
		"day": str(day),
		"came": float(came),
		"by_method": [{"method": m, "amount": float(v)} for m, v in sorted(by_method.items(), key=lambda kv: -kv[1])],
		"went": float(went),
		"net": float(came - went),
		"accepted": len(accepted),
		"accepted_sum": float(sum(Decimal(str(flt(a.grand_total))) for a in accepted)),
		"ready": ready,
		"handed_over": handed,
		"overdue": overdue,
		"owed": float(owed),
		"film_sales": len(film),
		"film_sum": float(sum(Decimal(str(flt(f.korkem_film_amount))) for f in film)),
		"film_paid": float(sum(Decimal(str(flt(f.korkem_film_paid))) for f in film)),
		"to_tell_ready": to_write["ready"],
		"to_remind": to_write["debts"],
	}


def text(f: dict, company: str) -> str:
	"""The message, short enough to read on a phone at a glance."""
	name = frappe.db.get_value("Company", company, "company_name") or company
	day = getdate(f["day"]).strftime("%d.%m")
	lines = [f"Итоги дня {day} — {name}", ""]
	lines.append(f"Пришло: {_money(f['came'])}")
	for m in f["by_method"]:
		lines.append(f"  · {m['method']}: {_money(m['amount'])}")
	lines.append(f"Ушло: {_money(f['went'])}")
	lines.append(f"Итого за день: {_money(f['net'])}")
	lines.append("")
	lines.append(f"Принято заказов: {f['accepted']} на {_money(f['accepted_sum'])}")
	lines.append(f"Готово: {f['ready']} · выдано: {f['handed_over']}")
	if f["film_sales"]:
		lines.append(f"Плёнка: продаж {f['film_sales']} на {_money(f['film_sum'])}, оплачено {_money(f['film_paid'])}")
	if f["overdue"]:
		lines.append(f"Просрочено: {f['overdue']}")
	lines.append(f"Клиенты должны: {_money(f['owed'])}")
	if f["to_tell_ready"] or f["to_remind"]:
		lines.append(f"Кому написать: готово — {f['to_tell_ready']}, напомнить о долге — {f['to_remind']}")
	return "\n".join(lines)


def preview(day: str | None = None) -> dict:
	"""Today's summary as the owner would receive it, with its settings."""
	facade_prices.ensure_editor()
	company = current_company()
	figures = collect(company, day)
	from korkem_manufacturing.services import material_stock, reorder_watch

	morning = reorder_watch.text(reorder_watch.report(), company) if material_stock.is_staff() else None
	return {**figures, "text": text(figures, company), "settings": settings(company),
			"sent_on": frappe.db.get_default(_SENT.format(company=company)), "morning_text": morning}


def run() -> dict:
	"""Hourly: each company whose hour has come and whose day is not yet told."""
	now = now_datetime()
	today = str(getdate(now))
	sent = {}
	for company in frappe.get_all("Company", pluck="name"):
		conf = settings(company)
		if not conf["enabled"] or now.hour < conf["hour"]:
			continue
		if frappe.db.get_default(_SENT.format(company=company)) == today:
			continue
		try:
			figures = collect(company, today)
			body = text(figures, company)
		except Exception:
			frappe.log_error(title="daily_summary", message=frappe.get_traceback(with_context=True))
			continue
		domain_events.emit(EVENT, company=company, day=today, body=body)
		frappe.db.set_default(_SENT.format(company=company), today)
		sent[company] = today
	return sent

