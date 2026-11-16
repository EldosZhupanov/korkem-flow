# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The company's departments, the posts in each, and the people on them
(owner, 17.11.2026: «у заказа всегда свои люди: менеджер по приёму,
ЧПУшник; ПВХ — шкурщик, вакуумщик; краска — шкурщик, маляр; продажа плёнки —
продажник, грузчик… довести каждый отдел до логики, как экосистема»).

**A person is an ERPNext `Employee`** — the record a ticked stage already
names (`mdf_orders.STAGE_BY`) — so a worker exists without a login. Whoever
gets one is linked through the employee's own `user_id`; nothing else changes.

**A post is fixed in code** because each one is a stage of the order:
the cutter cuts, the CNC operator mills, the PVC sander and the paint sander
both sand — the order's coatings say which of them — the vacuum operator
presses, the painter paints, the packer closes «готово». Posts with no stage
(the film seller, the loader, the storekeeper, the driver) are there so the
department is whole and its people are on the list. A person holds any
number of posts: in a small shop the sander works in both departments.

Who edits: the administrator and whoever runs orders (`facade_prices`'s
editors). Anyone on the staff may read — a picker needs it.
"""

from __future__ import annotations

import frappe
from frappe.utils import nowdate

from korkem_manufacturing.services import audit, facade_prices
from korkem_manufacturing.services.identity import is_staff
from korkem_manufacturing.services.scope import current_company

ROLES_FIELD = "korkem_team_roles"

#: Department → its posts. A post's key is «department.post».
DEPARTMENTS: dict[str, dict] = {
	"intake": {"title": "Приём заказов", "posts": {"manager": "Менеджер по приёму"}},
	"cut": {"title": "Раскрой", "posts": {"cutter": "Раскройщик"}},
	"cnc": {"title": "ЧПУ", "posts": {"operator": "ЧПУшник"}},
	"pvc": {"title": "ПВХ плёнка", "posts": {"sander": "Шкурщик", "vacuum": "Вакуумщик"}},
	"paint": {"title": "Покраска", "posts": {"sander": "Шкурщик", "painter": "Маляр"}},
	"pack": {"title": "Упаковка и выдача", "posts": {"packer": "Упаковщик"}},
	"film_sales": {"title": "Продажа плёнки", "posts": {"seller": "Продажник", "loader": "Грузчик"}},
	"warehouse": {"title": "Склад и доставка", "posts": {"storekeeper": "Кладовщик", "driver": "Водитель"}},
}
POSTS = {f"{d}.{p}": title for d, dept in DEPARTMENTS.items() for p, title in dept["posts"].items()}
MANAGER = "intake.manager"

#: An order's stage → the posts that do it. Sanding is the PVC sander's on a
#: film group and the paint sander's on a paint group (`for_stage`).
STAGE_POSTS = {
	"cut": ("cut.cutter",),
	"mill": ("cnc.operator",),
	"sand": ("pvc.sander", "paint.sander"),
	"vacuum": ("pvc.vacuum",),
	"paint": ("paint.painter",),
	"ready": ("pack.packer",),
}
_SAND_BY_COATING = {"pvc": "pvc.sander", "paint": "paint.sander"}


def can_edit() -> bool:
	return facade_prices.can_edit()


def _ensure_editor() -> None:
	if not can_edit():
		frappe.throw("Команду меняют администратор и менеджеры по заказам.", frappe.PermissionError)


def structure() -> dict:
	"""The departments and their posts, in the shop's order."""
	return {
		"departments": [
			{"key": d, "title": dept["title"],
			 "posts": [{"key": f"{d}.{p}", "title": title, "stages": _stages_of_post(f"{d}.{p}")}
					   for p, title in dept["posts"].items()]}
			for d, dept in DEPARTMENTS.items()
		],
	}


def _stages_of_post(post: str) -> list[str]:
	return [stage for stage, posts in STAGE_POSTS.items() if post in posts]


def parse(value) -> list[str]:
	"""Stored posts, known ones only, in the structure's order."""
	if isinstance(value, (list, tuple)):
		raw = value
	else:
		raw = (value or "").replace(",", "\n").split("\n")
	wanted = {str(p).strip() for p in raw if str(p).strip()}
	return [p for p in POSTS if p in wanted]


def _clean_posts(posts) -> list[str]:
	if isinstance(posts, str):
		posts = frappe.parse_json(posts) if posts.strip().startswith("[") else posts.split("\n")
	unknown = [str(p) for p in posts or [] if str(p).strip() and str(p).strip() not in POSTS]
	if unknown:
		frappe.throw("Такой должности нет: " + ", ".join(unknown) + ".")
	return parse(posts)


def people(include_left: bool = False) -> dict:
	"""Everyone at the company with their posts, phone, and login if any."""
	if not is_staff():
		frappe.throw("Команду видят сотрудники компании.", frappe.PermissionError)
	company = current_company()
	filters = {"company": company}
	if not include_left:
		filters["status"] = "Active"
	rows = frappe.get_all(
		"Employee",
		filters=filters,
		fields=["name", "employee_name", "first_name", "last_name", "cell_number", "user_id", "status",
				ROLES_FIELD],
		order_by="employee_name asc",
		limit_page_length=1000,
	)
	return {
		"people": [_person(r) for r in rows],
		"can_edit": can_edit(),
		**structure(),
	}


def _person(r) -> dict:
	return {
		"employee": r.name,
		"name": r.employee_name or " ".join(x for x in (r.first_name, r.last_name) if x) or r.name,
		"phone": r.cell_number,
		"user": r.user_id,
		"active": r.status == "Active",
		"posts": parse(r.get(ROLES_FIELD)),
	}


def _gender() -> str:
	"""ERPNext wants a gender on an Employee; the shop does not ask for one."""
	for name in ("Male", "Мужской", "Female"):
		if frappe.db.exists("Gender", name):
			return name
	frappe.get_doc({"doctype": "Gender", "gender": "Male"}).insert(ignore_permissions=True)
	return "Male"


def _name(value) -> str:
	name = " ".join(str(value or "").split())[:140]
	if len(name) < 2:
		frappe.throw("Как зовут сотрудника?")
	return name


def _phone(value) -> str | None:
	phone = " ".join(str(value or "").split())[:40]
	return phone or None


def add_person(name: str, posts=None, phone: str | None = None) -> dict:
	"""A person at the company — no login needed; the manager ticks for him."""
	_ensure_editor()
	full = _name(name)
	first, _, last = full.partition(" ")
	doc = frappe.get_doc({
		"doctype": "Employee", "first_name": first, "last_name": last or None, "company": current_company(),
		"status": "Active", "gender": _gender(), "date_of_birth": "1990-01-01", "date_of_joining": nowdate(),
		"cell_number": _phone(phone), ROLES_FIELD: "\n".join(_clean_posts(posts or [])) or None,
	}).insert(ignore_permissions=True)
	audit.record_audit(action="team.person_added", entity_type="Employee", entity_id=doc.name,
					   diff={"name": full, "posts": parse(doc.get(ROLES_FIELD))})
	return people()


def _employee(employee: str):
	row = frappe.db.get_value("Employee", employee, ["name", "company"], as_dict=True)
	if not row or row.company != current_company():
		frappe.throw("Такого сотрудника нет.", frappe.DoesNotExistError)
	return row


def set_person(employee: str, name: str | None = None, posts=None, phone: str | None = None) -> dict:
	"""Rename, change the phone or the posts — what is sent changes."""
	_ensure_editor()
	_employee(employee)
	values = {}
	if name is not None:
		full = _name(name)
		first, _, last = full.partition(" ")
		values.update({"first_name": first, "last_name": last or None, "employee_name": full})
	if phone is not None:
		values["cell_number"] = _phone(phone)
	if posts is not None:
		values[ROLES_FIELD] = "\n".join(_clean_posts(posts)) or None
	if values:
		frappe.db.set_value("Employee", employee, values)
		audit.record_audit(action="team.person_changed", entity_type="Employee", entity_id=employee,
						   diff={k: v for k, v in values.items()})
	return people()


def set_active(employee: str, active) -> dict:
	"""Left the company: switched off, never deleted — his work stays his."""
	_ensure_editor()
	_employee(employee)
	on = str(active).lower() in ("1", "true", "yes")
	frappe.db.set_value("Employee", employee, {"status": "Active" if on else "Left",
											   "relieving_date": None if on else nowdate()})
	audit.record_audit(action="team.person_active", entity_type="Employee", entity_id=employee, diff={"active": on})
	return people()


def link_user(employee: str, user: str | None) -> dict:
	"""Tie a person to his login, so he sees his own orders from his phone."""
	_ensure_editor()
	_employee(employee)
	if user:
		if not frappe.db.exists("User", user):
			frappe.throw("Такого входа нет.", frappe.DoesNotExistError)
		other = frappe.db.get_value("Employee", {"user_id": user, "name": ["!=", employee]}, "employee_name")
		if other:
			frappe.throw(f"Этот вход уже у сотрудника «{other}».")
	frappe.db.set_value("Employee", employee, "user_id", user or None)
	audit.record_audit(action="team.person_login", entity_type="Employee", entity_id=employee, diff={"user": user})
	return people()


def posts_for_stage(stage: str, coatings=None) -> list[str]:
	"""Who does this stage of this order: sanding by the order's coatings."""
	posts = list(STAGE_POSTS.get(stage, ()))
	if stage == "sand":
		kinds = [c for c in (coatings if isinstance(coatings, (list, tuple)) else (coatings or "").split(","))
				 if c in _SAND_BY_COATING]
		if kinds:
			posts = [_SAND_BY_COATING[c] for c in kinds]
	return posts


def holders(posts, company: str | None = None) -> list[dict]:
	"""Active people on any of these posts."""
	wanted = set(posts)
	rows = frappe.get_all(
		"Employee",
		filters={"company": company or current_company(), "status": "Active"},
		fields=["name", "employee_name", ROLES_FIELD],
		order_by="employee_name asc",
		limit_page_length=1000,
	)
	return [{"employee": r.name, "name": r.employee_name, "posts": [p for p in parse(r.get(ROLES_FIELD))
																	 if p in wanted]}
			for r in rows if wanted & set(parse(r.get(ROLES_FIELD)))]


def me() -> dict | None:
	"""The person the signed-in user is, at the current company."""
	row = frappe.db.get_value(
		"Employee", {"user_id": frappe.session.user, "company": current_company(), "status": "Active"},
		["name", "employee_name", ROLES_FIELD], as_dict=True,
	)
	if not row:
		return None
	return {"employee": row.name, "name": row.employee_name, "posts": parse(row.get(ROLES_FIELD))}
