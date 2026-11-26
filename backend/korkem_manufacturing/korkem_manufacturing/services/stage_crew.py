# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A stage of an order done — or given — by several people at once, and the
part of its m² each one gets (owner, 26.11.2026: «бывает большой объём, тогда
2 или 3 вакуумщика делают вместе, и система делит на ровную часть … это
должно касаться всех этапов»).

The order keeps one name per stage (`mdf_orders.STAGE_TO`, `STAGE_BY`) — the
first of the crew — so everything that reads one person still reads someone.
The crew itself is `MDF Stage Crew`: one row per person, with his share in %,
for the stage **given** («to») and for the stage **done** («by»). A stage of
one person has no rows.

Shares are equal unless said: 10 m² by two is 5 and 5, by three 3.33 each.
Said by hand (60/40, 5 + 3 + 2) they must add up to the whole — the screen
gives the last one what is left, and this checks it again. The stage's m²
are counted once for the shop; each person gets his share of them.
"""

from __future__ import annotations

import json

import frappe
from frappe.utils import flt

DOCTYPE = "MDF Stage Crew"
KINDS = ("to", "by")
MAX_CREW = 10
#: A sum of shares this close to 100 is 100: the screen rounds to 0.01 m².
_SLACK = 0.5


def parse(crew, company: str) -> list[tuple[str, float]]:
	"""(employee, share %) for each person — equal shares when none are said.

	`crew` is a list (or its JSON) of employee ids, or of
	{"employee": …, "share": …}. Every one is an active person of the company,
	once; shares, when said, are above zero and add up to 100.
	"""
	if isinstance(crew, str):
		crew = json.loads(crew) if crew.strip() else []
	if not isinstance(crew, list) or not crew:
		frappe.throw("Отметьте, кто делает этап.")
	if len(crew) > MAX_CREW:
		frappe.throw(f"На одном этапе — не больше {MAX_CREW} человек.")
	people, shares = [], []
	for item in crew:
		item = item if isinstance(item, dict) else {"employee": item}
		employee = str(item.get("employee") or "").strip()
		if not employee:
			frappe.throw("Отметьте, кто делает этап.")
		row = frappe.db.get_value("Employee", employee, ["company", "status", "employee_name"], as_dict=True)
		if not row or row.company != company or row.status != "Active":
			frappe.throw("Такого сотрудника в компании нет.")
		if employee in people:
			frappe.throw(f"{row.employee_name or employee} отмечен дважды.")
		people.append(employee)
		shares.append(item.get("share"))
	if all(s in (None, "") for s in shares):
		return list(zip(people, equal(len(people)), strict=True))
	if any(s in (None, "") for s in shares):
		frappe.throw("Укажите долю каждому — или поделите поровну.")
	values = [flt(s, 4) for s in shares]
	if any(v <= 0 for v in values):
		frappe.throw("Доля каждого — больше нуля. Кто не делал, того не отмечайте.")
	total = sum(values)
	if abs(total - 100) > _SLACK:
		frappe.throw(f"Доли в сумме {total:g}% — должно быть 100%.")
	# The last one takes the rounding, as on the screen.
	values[-1] = round(100 - sum(values[:-1]), 4)
	return list(zip(people, values, strict=True))


def equal(n: int) -> list[float]:
	"""n equal shares in %, the last one taking the rounding: 3 → 33.3333 ×2, 33.3334."""
	part = round(100 / n, 4)
	return [part] * (n - 1) + [round(100 - part * (n - 1), 4)]


def get(order: str, stage: str, kind: str) -> list[tuple[str, float]]:
	return [(r.employee, flt(r.share)) for r in frappe.get_all(
		DOCTYPE, filters={"sales_order": order, "stage": stage, "kind": kind},
		fields=["employee", "share"], order_by="idx asc, creation asc", limit_page_length=0)]


def put(company: str, order: str, stage: str, kind: str, members: list[tuple[str, float]]) -> None:
	"""The stage's crew of this kind is [members]; one person or none — no rows."""
	if kind not in KINDS:
		raise ValueError(kind)
	frappe.db.delete(DOCTYPE, {"sales_order": order, "stage": stage, "kind": kind})
	if len(members) < 2:
		return
	for i, (employee, share) in enumerate(members, start=1):
		frappe.get_doc({"doctype": DOCTYPE, "company": company, "sales_order": order, "stage": stage,
						"kind": kind, "employee": employee, "share": share, "idx": i}).insert(ignore_permissions=True)


def of_orders(orders, kind: str) -> dict[tuple[str, str], list[tuple[str, float]]]:
	"""(order, stage) → its crew of this kind, for many orders at once."""
	out: dict[tuple[str, str], list[tuple[str, float]]] = {}
	orders = sorted(set(orders))
	if not orders:
		return out
	for r in frappe.get_all(DOCTYPE, filters={"sales_order": ["in", orders], "kind": kind},
							fields=["sales_order", "stage", "employee", "share"],
							order_by="sales_order asc, idx asc, creation asc", limit_page_length=0):
		out.setdefault((r.sales_order, r.stage), []).append((r.employee, flt(r.share)))
	return out


def given_to(company: str, employee: str) -> list[tuple[str, str]]:
	"""(order, stage) of every stage given to a crew he is in."""
	return [(r.sales_order, r.stage) for r in frappe.get_all(
		DOCTYPE, filters={"company": company, "kind": "to", "employee": employee},
		fields=["sales_order", "stage"], limit_page_length=0)]


def describe(members: list[tuple[str, float]]) -> list[dict]:
	"""The crew for a card: name and share of each."""
	if not members:
		return []
	names = dict(frappe.get_all("Employee", filters={"name": ["in", [e for e, _ in members]]},
								fields=["name", "employee_name"], as_list=True))
	return [{"employee": e, "name": names.get(e) or e, "share": round(s, 2)} for e, s in members]
