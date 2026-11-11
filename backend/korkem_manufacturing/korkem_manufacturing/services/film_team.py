# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The film department's month by seller, and the team's bonus (owner,
11.11.2026: «командный бонус в конце месяца, чтобы повысить эффективность»).

**Every sale has its seller** (`korkem_film_seller`) — whoever entered it
unless said otherwise.

**The bonus is a team pot, shared by what each brought in:**

* It is counted on the *margin* — what a metre was sold at less what it cost
  (the stock's own rate at issue) — not on the takings: a discount bought
  for volume earns nothing.
* Only what was *paid* counts, in the month it was paid. A sale on credit
  joins the bonus when the customer pays, so collecting a debt pays too.
* The pot is a share of the team's margin: one share when the team made its
  plan for the month (metres sold), a smaller one when it did not — helping
  the others is worth it.
* Each seller's part is his share of the margin.

The owner sets the plan and the two shares. He sees everyone; a manager sees
his own figures, the team's total and the pot; the shop floor nothing.
"""

from __future__ import annotations

import calendar
import json
from datetime import date

import frappe
from frappe.utils import flt, get_fullname, getdate, nowdate

from korkem_manufacturing.services import audit, material_stock
from korkem_manufacturing.services.scope import current_company

SALE = "sale"
_KEY = "korkem_film_bonus"
DEFAULTS = {"plan_m": 0.0, "pct": 10.0, "pct_below": 5.0}


def _owner() -> bool:
	return "System Manager" in frappe.get_roles()


def settings(company: str | None = None) -> dict:
	raw = frappe.db.get_default(f"{_KEY}:{company or current_company()}")
	try:
		saved = json.loads(raw) if raw else {}
	except ValueError:
		saved = {}
	return {key: flt(saved.get(key, value)) for key, value in DEFAULTS.items()}


def set_settings(plan_m=None, pct=None, pct_below=None) -> dict:
	"""The month's plan (metres) and the pot's two shares — the owner's."""
	if not _owner():
		frappe.throw("План и бонус задаёт владелец.", frappe.PermissionError)
	company = current_company()
	now = settings(company)
	for key, value in (("plan_m", plan_m), ("pct", pct), ("pct_below", pct_below)):
		if value in (None, ""):
			continue
		number = flt(value)
		if number < 0 or (key != "plan_m" and number > 50) or number > 1_000_000:
			frappe.throw("План — метры от 0; доля котла — от 0 до 50 %.")
		now[key] = number
	frappe.db.set_default(f"{_KEY}:{company}", json.dumps(now))
	audit.record_audit(action="film.bonus_set", entity_type="Company", entity_id=company, diff=now)
	return now


def _month(month: str | None) -> tuple[date, date, str]:
	day = getdate(f"{month}-01") if month else getdate(nowdate()).replace(day=1)
	last = day.replace(day=calendar.monthrange(day.year, day.month)[1])
	return day, last, day.strftime("%Y-%m")


def team(month: str | None = None) -> dict:
	"""The month by seller: metres sold, sales, what was paid, the margin
	paid in — and the pot and each one's part."""
	material_stock._ensure_editor()
	company = current_company()
	start, end, key = _month(month)
	sales = frappe.get_all(
		"Stock Entry",
		filters={"company": company, "docstatus": 1, "korkem_film_kind": SALE},
		fields=["name", "posting_date", "korkem_film_amount", "korkem_film_paid", "korkem_film_payments",
				"korkem_film_seller", "owner"],
		limit_page_length=0,
	)
	rows: dict[str, dict] = {}

	def row(user: str) -> dict:
		return rows.setdefault(user, {"seller": user, "metres": 0.0, "sales": 0, "paid": 0.0, "margin": 0.0})

	for s in sales:
		seller = s.korkem_film_seller or s.owner
		lines = frappe.get_all(
			"Stock Entry Detail", filters={"parent": s.name},
			fields=["qty", "basic_rate", "korkem_film_price_m"],
		)
		amount = flt(s.korkem_film_amount)
		margin = sum((flt(l.korkem_film_price_m) - flt(l.basic_rate)) * flt(l.qty) for l in lines)
		if start <= getdate(s.posting_date) <= end:
			r = row(seller)
			r["metres"] += sum(flt(l.qty) for l in lines)
			r["sales"] += 1
		# What was paid this month, and the margin it carries.
		paid = 0.0
		for p in _payments(s):
			on = getdate(p.get("date") or s.posting_date)
			if start <= on <= end:
				paid += flt(p.get("amount"))
		if paid and amount:
			r = row(seller)
			r["paid"] += paid
			r["margin"] += margin * paid / amount
	conf = settings(company)
	metres = sum(r["metres"] for r in rows.values())
	made = conf["plan_m"] > 0 and metres >= conf["plan_m"]
	pct = conf["pct"] if made or conf["plan_m"] <= 0 else conf["pct_below"]
	margin = sum(max(r["margin"], 0.0) for r in rows.values())
	pot = round(margin * pct / 100)
	out = []
	for r in sorted(rows.values(), key=lambda r: -r["margin"]):
		share = max(r["margin"], 0.0) / margin if margin else 0.0
		out.append({
			**{k: round(v, 2) if isinstance(v, float) else v for k, v in r.items()},
			"name": get_fullname(r["seller"]) or r["seller"],
			"share": round(share * 100, 1),
			"bonus": round(pot * share),
		})
	me = frappe.session.user
	owner = _owner()
	return {
		"month": key,
		"rows": out if owner else [r for r in out if r["seller"] == me],
		"team": {
			"metres": round(metres, 2), "sales": sum(r["sales"] for r in rows.values()),
			"paid": round(sum(r["paid"] for r in rows.values()), 2), "margin": round(margin, 2),
		},
		"plan_m": conf["plan_m"],
		"done": round(metres / conf["plan_m"] * 100) if conf["plan_m"] else None,
		"pct": pct,
		"pot": pot,
		"settings": conf if owner else None,
		"can_set": owner,
	}


def _payments(s) -> list[dict]:
	if s.korkem_film_payments:
		try:
			rows = json.loads(s.korkem_film_payments)
			if isinstance(rows, list):
				return rows
		except ValueError:
			pass
	if flt(s.korkem_film_paid) > 0:
		return [{"date": str(s.posting_date), "amount": flt(s.korkem_film_paid)}]
	return []
