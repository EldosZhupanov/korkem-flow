# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""People one at a time (owner, 26.11.2026: «список людей, которых я могу
назначить на должность, снять или дать ещё одну должность»).

`team` keeps who holds which post; this is what happens around a change:

- **one post given or taken** (`set_post`) — against the posts as stored
  now, not as a screen last saw them, and written down post by post, so the
  card's history (`history`) reads «дали Раскройщик», «сняли ЧПУшник»;
- **the work he holds** (`open_work`, `hand_over`) — a stage given to him
  and not done stays his when his post is taken or he leaves; the manager is
  shown it and passes it on, or it would hang on nobody's list;
- **what is owed** (`dismissal`) — before «Уволен»: his stages still open
  and, for those who may see pay, what is left to pay him or what his
  advances are over his earnings;
- **one person, never two** (`duplicates`) — a new name or phone that is
  already on the list, a departed one too («вернуть его?»).
"""

from __future__ import annotations

import json
from datetime import timedelta

import frappe
from frappe.utils import getdate, nowdate

from korkem_manufacturing.services import audit, directions, mdf_orders, payroll, search_text, team
from korkem_manufacturing.services.identity import is_staff
from korkem_manufacturing.services.scope import current_company

#: How far back «what is left to pay» looks: the statement's own limit.
_PAY_DAYS = payroll.MAX_DAYS - 1


def set_post(post: str, on=True, employee: str | None = None, user: str | None = None) -> dict:
	"""Give a person one post, or take it. A login with no person yet
	(`user`) becomes one here, as in `team.set_person`."""
	team._ensure_editor()
	if post not in team.POSTS:
		frappe.throw(f"Такой должности нет: {post}.")
	if not employee:
		if not user:
			frappe.throw("Кого меняем?")
		employee = team.person_of(user)
	team._employee(employee)
	on = directions.flag(on)
	held = team.parse(frappe.db.get_value("Employee", employee, team.ROLES_FIELD))
	if (post in held) != on:
		posts = [*held, post] if on else [p for p in held if p != post]
		frappe.db.set_value("Employee", employee, team.ROLES_FIELD, "\n".join(team.parse(posts)) or None)
		audit.record_audit(action="team.post", entity_type="Employee", entity_id=employee,
						   diff={"post": post, "on": on})
	return team.people(include_left=True)


def open_work(employee: str, post: str | None = None) -> list[dict]:
	"""Stages given to him and not yet done, on orders not handed over —
	those of [post] only, when it is said."""
	team._ensure_editor()
	team._employee(employee)
	stages = team._stages_of_post(post) if post else list(mdf_orders.STAGES)
	out = []
	for stage in stages:
		for r in frappe.get_all(
			"Sales Order",
			filters={"company": current_company(), "docstatus": 1, "korkem_direction": directions.FACADES,
					 mdf_orders.STAGE_TO[stage]: employee, mdf_orders.STAGES[stage]: ["is", "not set"],
					 "korkem_handed_over_on": ["is", "not set"]},
			fields=["name", "customer_name"],
			order_by="name asc",
			limit_page_length=0,
		):
			out.append({"order": r.name, "number": search_text.number_in(r.name), "customer": r.customer_name,
						"stage": stage, "title": mdf_orders.STAGE_NAMES.get(stage, stage)})
	return out


def hand_over(employee: str, to: str | None = None, post: str | None = None) -> dict:
	"""His open stages (of [post], if said) to [to] — or to nobody, for the
	manager to give out again. Each one through `mdf_orders.assign`: its
	check and its audit row."""
	work = open_work(employee, post)
	if to:
		if to == employee:
			frappe.throw("Передать можно только другому человеку.")
		row = frappe.db.get_value("Employee", to, ["company", "status"], as_dict=True)
		if not row or row.company != current_company() or row.status != "Active":
			frappe.throw("Такого сотрудника в команде нет.")
	for w in work:
		mdf_orders.assign(w["order"], w["stage"], to or None)
	return {"moved": len(work), "to": to}


def dismissal(employee: str) -> dict:
	"""What to know before «Уволен»: his open stages and, for those who see
	pay, the money not settled over the last three months."""
	team._ensure_editor()
	team._employee(employee)
	user = frappe.db.get_value("Employee", employee, "user_id")
	money = None
	if user and payroll.READERS.intersection(frappe.get_roles()):
		end = getdate(nowdate())
		row = next((r for r in payroll.sheet_rows(current_company(), end - timedelta(days=_PAY_DAYS), end)
					if r["employee"] == user), None)
		if row:
			money = {"left": row["left"], "pending": row["pending"]}
	return {"open": open_work(employee), "money": money}


def duplicates(name: str | None = None, phone: str | None = None) -> list[dict]:
	"""People already on the list with this name or this phone — the ones
	who left too, who may be coming back."""
	if not is_staff():
		frappe.throw("Команду видят сотрудники компании.", frappe.PermissionError)
	wanted = _key(name)
	out = []
	for r in frappe.get_all("Employee", filters={"company": current_company()},
							fields=["name", "employee_name", "cell_number", "status", team.ROLES_FIELD],
							limit_page_length=0):
		same_name = bool(wanted) and _key(r.employee_name) in (wanted, _swapped(wanted))
		same_phone = bool(phone) and team._same_phone(r.cell_number, phone)
		if same_name or same_phone:
			out.append({"employee": r.name, "name": r.employee_name, "phone": r.cell_number,
						"active": r.status == "Active", "posts": team.parse(r.get(team.ROLES_FIELD)),
						"by": "phone" if same_phone else "name"})
	return out


def history(employee: str) -> list[dict]:
	"""Posts given and taken, leaving and coming back — newest first, with
	who did it. Read back from the audit rows `team` writes."""
	rows = frappe.get_all(
		"Domain Audit Event",
		filters={"entity_type": "Employee", "entity_id": employee,
				 "action": ["in", ["team.person_added", "team.person_changed", "team.post", "team.person_active"]]},
		fields=["action", "actor", "diff_json", "creation"],
		order_by="creation asc",
		limit_page_length=500,
	)
	names = {}
	held: set[str] = set()
	out = []
	for r in rows:
		diff = _json(r.diff_json)
		events = []
		if r.action == "team.post":
			post = diff.get("post")
			events.append(("post_on" if diff.get("on") else "post_off", post))
			if diff.get("on"):
				held.add(post)
			else:
				held.discard(post)
		elif r.action == "team.person_active":
			events.append(("back" if diff.get("active") else "left", None))
		else:
			raw = diff.get("posts") if r.action == "team.person_added" else diff.get(team.ROLES_FIELD, ...)
			if raw is ...:
				continue
			now = set(team.parse(raw))
			events += [("post_on", p) for p in team.parse(sorted(now - held))]
			events += [("post_off", p) for p in team.parse(sorted(held - now))]
			held = now
			if r.action == "team.person_added":
				events.insert(0, ("added", None))
		if r.actor not in names:
			names[r.actor] = frappe.db.get_value("User", r.actor, "full_name") or r.actor
		for kind, post in events:
			out.append({"on": str(getdate(r.creation)), "kind": kind, "post": post,
						"post_title": team.POSTS.get(post) if post else None, "by": names[r.actor]})
	out.reverse()
	return out


def _json(raw) -> dict:
	try:
		value = json.loads(raw or "{}")
	except ValueError:
		return {}
	return value if isinstance(value, dict) else {}


def _key(name: str | None) -> str:
	return " ".join(str(name or "").lower().replace("ё", "е").split())


def _swapped(key: str) -> str:
	"""«изимов владимир» for «владимир изимов»."""
	first, _, rest = key.partition(" ")
	return f"{rest} {first}" if rest else key
