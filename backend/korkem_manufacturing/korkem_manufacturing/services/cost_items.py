# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Статьи затрат» — where every tenge of the shop goes (owner, 25.11.2026:
«электричество цеха, А4, нож, стрейч плёнка и прочие расходные материалы…
нам надо видеть траекторию — куда деньги идут»).

The management accountant's first tool: every expense has an address —
a **group** (сырьё, расходники, коммуналка…) and an **item** in it (свет,
стрейч, нож). Each item says:

- **mode** — how it is counted: `bill`, a sum once a month (свет, аренда —
  `cost_bills`); `stock`, bought onto the shelf and taken off it (ножи, А4 —
  `consumables`, an ERPNext Item of the kind «Прочее»); `other`, money spent
  as it comes (urgent expenses put on the item);
- **behaviour** — `fixed`, the same whatever the shop makes (аренда), or
  `variable`, growing with the m² (стрейч). The break-even point is made of
  this split (`money_flow`);
- **area** — where in the shop it is spent (раскрой, пресс, покраска…);
- a unit, and a **monthly limit** for plan-against-fact.

The list is the owner's to grow: items are added, renamed, moved; one that
money was spent on is **archived, never deleted** — the months behind it must
still add up — and two that are the same («Нож», «Ножи») are **merged**, their
history with them. A worker who takes something not in the list adds it from
the floor; it is marked new for the owner to look at.

Raw material (МДФ, плёнка, краска, клей) and piece-work pay are not items
here: they are counted where they already are — the stock write-offs and the
piece-work book (`money_flow`).
"""

from __future__ import annotations

import frappe
from frappe.utils import cint, flt

from korkem_manufacturing.services import audit, material_stock
from korkem_manufacturing.services.identity import is_staff
from korkem_manufacturing.services.scope import current_company

DOCTYPE = "Cost Item"
#: Who keeps the cost items and sees where the money goes: the owner and
#: accounting — the deciders of the urgent expenses.
OWNERS = frozenset({"System Manager", "Accounts Manager"})
RAW, CONSUMABLES, UTILITIES, RENT, PAY, TRANSPORT, REPAIR, TAXES, ADS, OTHER = (
	"Сырьё", "Расходники", "Коммуналка", "Аренда", "Зарплата", "Транспорт", "Ремонт и инструмент", "Налоги",
	"Реклама", "Прочее",
)
GROUPS = (RAW, CONSUMABLES, UTILITIES, RENT, PAY, TRANSPORT, REPAIR, TAXES, ADS, OTHER)
AREAS = ("Весь цех", "Раскрой", "Фрезеровка", "Шлифовка", "Пресс", "Покраска", "Упаковка", "Офис", "Доставка")
MODES = ("bill", "stock", "other")
#: The cost items a shop starts with; the owner adds the rest.
SEED = (
	("Электричество", UTILITIES, "bill", "fixed", "Весь цех", "кВт·ч"),
	("Аренда цеха", RENT, "bill", "fixed", "Весь цех", "мес"),
	("Интернет и связь", UTILITIES, "bill", "fixed", "Офис", "мес"),
	("Вывоз мусора", UTILITIES, "bill", "fixed", "Весь цех", "мес"),
	("Оклады", PAY, "bill", "fixed", "Весь цех", "мес"),
	("Налоги", TAXES, "bill", "fixed", "Офис", "мес"),
	("Стрейч-плёнка", CONSUMABLES, "stock", "variable", "Упаковка", "рулон"),
	("Нож для раскроя", CONSUMABLES, "stock", "variable", "Раскрой", "шт"),
	("Наждачная бумага", CONSUMABLES, "stock", "variable", "Шлифовка", "шт"),
	("Бумага А4", CONSUMABLES, "stock", "fixed", "Офис", "пачка"),
	("Скотч", CONSUMABLES, "stock", "variable", "Упаковка", "шт"),
	("Перчатки", CONSUMABLES, "stock", "variable", "Весь цех", "шт"),
	("Топливо", TRANSPORT, "other", "variable", "Доставка", "л"),
	("Ремонт станков", REPAIR, "other", "fixed", "Весь цех", ""),
)
#: An urgent expense's own category, for one not put on an item.
CATEGORY_GROUP = {"Материалы": CONSUMABLES, "Инструмент": REPAIR, "Транспорт": TRANSPORT, "Ремонт": REPAIR,
				  "Другое": OTHER}
_FIELDS = ["name", "title", "cost_group", "mode", "behaviour", "area", "unit", "monthly_limit", "item", "archived",
		   "is_new", "merged_into"]


def is_owner() -> bool:
	return bool(OWNERS.intersection(frappe.get_roles()))


def ensure_owner() -> None:
	if not is_owner():
		frappe.throw("Статьи затрат и куда идут деньги видят владелец и бухгалтерия.", frappe.PermissionError)


def listing(search: str | None = None, archived: bool | int | str = False) -> dict:
	"""Every cost item of the company by group; the archived on asking."""
	ensure_owner()
	company = current_company()
	seed(company)
	filters = {"company": company, "merged_into": ["is", "not set"]}
	if not cint(archived):
		filters["archived"] = 0
	rows = frappe.get_all(DOCTYPE, filters=filters, fields=_FIELDS, order_by="title asc", limit_page_length=0)
	words = " ".join(str(search or "").lower().split())
	if words:
		rows = [r for r in rows if words in r.title.lower() or words in (r.cost_group or "").lower()]
	order = {g: i for i, g in enumerate(GROUPS)}
	rows.sort(key=lambda r: (order.get(r.cost_group, len(GROUPS)), r.title.lower()))
	return {"items": [_row(r) for r in rows], "groups": list(GROUPS), "areas": list(AREAS),
			"new": sum(1 for r in rows if r.is_new)}


def add(title: str, group: str, mode: str = "other", behaviour: str = "variable", area: str | None = None,
		unit: str | None = None, monthly_limit=None) -> dict:
	"""A new cost item; a stock one gets its shelf item at once."""
	ensure_owner()
	company = current_company()
	values = _clean(title=title, group=group, mode=mode, behaviour=behaviour, area=area, unit=unit,
					monthly_limit=monthly_limit)
	_unique(company, values["title"])
	doc = frappe.get_doc({"doctype": DOCTYPE, "company": company, **_doc_values(values)})
	doc.insert(ignore_permissions=True)
	if doc.mode == "stock":
		_shelf_item(doc)
	audit.record_audit(action="cost_item.added", entity_type=DOCTYPE, entity_id=doc.name, diff=values, company=company)
	return _row(doc)


def quick_add(title: str, unit: str | None = None) -> dict:
	"""From the floor: a consumable not in the list, taken today. Marked new
	— the owner looks at it, files it under its group, sets its minimum."""
	if not is_staff():
		frappe.throw("Добавляют сотрудники.", frappe.PermissionError)
	company = current_company()
	values = _clean(title=title, group=CONSUMABLES, mode="stock", behaviour="variable", area="Весь цех",
					unit=unit or "шт")
	same = _same(company, values["title"])
	if same:
		return _row(frappe.get_doc(DOCTYPE, same))
	doc = frappe.get_doc({"doctype": DOCTYPE, "company": company, "is_new": 1, **_doc_values(values)})
	doc.insert(ignore_permissions=True)
	_shelf_item(doc)
	audit.record_audit(action="cost_item.quick_added", entity_type=DOCTYPE, entity_id=doc.name, diff=values,
					   company=company)
	return _row(doc)


def edit(name: str, **changes) -> dict:
	"""Rename, regroup, move, change its limit; a new one, once looked at,
	is no longer new."""
	ensure_owner()
	doc = _own(name)
	now = _row(doc)
	values = _clean(
		title=changes.get("title", doc.title), group=changes.get("group", doc.cost_group),
		mode=changes.get("mode", doc.mode), behaviour=changes.get("behaviour", doc.behaviour),
		area=changes.get("area", doc.area), unit=changes.get("unit", doc.unit),
		monthly_limit=changes.get("monthly_limit", doc.monthly_limit),
	)
	if values["title"].lower() != doc.title.lower():
		_unique(doc.company, values["title"])
	doc.update(_doc_values(values))
	doc.is_new = 0
	doc.save(ignore_permissions=True)
	if doc.mode == "stock":
		_shelf_item(doc)
	if doc.item and values["title"] != now["title"]:
		frappe.db.set_value("Item", doc.item, {"item_name": values["title"], "description": values["title"]})
	audit.record_audit(action="cost_item.edited", entity_type=DOCTYPE, entity_id=doc.name,
					   diff={"before": now, "after": values}, company=doc.company)
	return _row(doc)


def archive(name: str, archived: bool | int | str = True) -> dict:
	"""Out of the lists, its history kept; back on asking."""
	ensure_owner()
	doc = _own(name)
	doc.archived = 1 if cint(archived) else 0
	doc.save(ignore_permissions=True)
	if doc.item:
		frappe.db.set_value("Item", doc.item, "disabled", doc.archived)
	audit.record_audit(action="cost_item.archived" if doc.archived else "cost_item.restored", entity_type=DOCTYPE,
					   entity_id=doc.name, diff={"title": doc.title}, company=doc.company)
	return _row(doc)


def merge(source: str, target: str) -> dict:
	"""Two items that are one («Нож» and «Ножи»): the source's bills and
	expenses move to the target, its shelf too when the target has none,
	and the source is gone from the lists, pointing at the target."""
	ensure_owner()
	src, dst = _own(source), _own(target)
	if src.name == dst.name:
		frappe.throw("Это одна и та же статья.")
	if dst.archived:
		frappe.throw("Сливают в живую статью — верните её из архива.")
	for bill in frappe.get_all("Cost Bill", filters={"cost_item": src.name}, fields=["name", "month", "amount"]):
		twin = frappe.db.get_value("Cost Bill", {"cost_item": dst.name, "month": bill.month}, ["name", "amount"],
								   as_dict=True)
		if twin:
			# One bill a month: the two sums become the target's one; the
			# source's, emptied, stays where it was (nothing is deleted).
			frappe.db.set_value("Cost Bill", twin.name, "amount", flt(twin.amount) + flt(bill.amount))
			frappe.db.set_value("Cost Bill", bill.name, "amount", 0)
		else:
			frappe.db.set_value("Cost Bill", bill.name, "cost_item", dst.name)
	frappe.db.sql("update `tabUrgent Expense` set cost_item = %s where cost_item = %s", (dst.name, src.name))
	if src.item and not dst.item:
		dst.db_set("item", src.item)
	src.db_set({"archived": 1, "merged_into": dst.name, "is_new": 0})
	audit.record_audit(action="cost_item.merged", entity_type=DOCTYPE, entity_id=src.name,
					   diff={"from": src.title, "into": dst.title}, company=src.company)
	return _row(dst)


def live(name: str, company: str) -> frappe._dict:
	"""A cost item of [company] money may be put on: not archived, not merged."""
	row = frappe.db.get_value(DOCTYPE, name, ["name", "company", "archived", "merged_into", "title"], as_dict=True)
	if not row or row.company != company:
		frappe.throw("Такой статьи затрат нет.", frappe.DoesNotExistError)
	if row.merged_into:
		return live(row.merged_into, company)
	if row.archived:
		frappe.throw(f"Статья «{row.title}» в архиве.")
	return row


def seed(company: str) -> None:
	"""The first look at the list fills it with the usual items, once."""
	if frappe.db.exists(DOCTYPE, {"company": company}):
		return
	for title, group, mode, behaviour, area, unit in SEED:
		frappe.get_doc({"doctype": DOCTYPE, "company": company, "title": title, "cost_group": group, "mode": mode,
						"behaviour": behaviour, "area": area, "unit": unit}).insert(ignore_permissions=True)


def group_of_expense(cost_group: str | None, category: str | None) -> str:
	return cost_group or CATEGORY_GROUP.get(category or "", OTHER)


def _shelf_item(doc) -> None:
	"""A stock cost item's ERPNext Item, of the kind «Прочее» — the ledger
	keeps the shelf, so receipts and write-offs are real stock entries."""
	if doc.item:
		return
	unit = doc.unit if doc.unit in material_stock.UNITS else "шт"
	material_stock._ensure_uom(unit)
	same = frappe.db.get_value("Item", {"korkem_material_company": doc.company, "item_name": doc.title}, "name")
	if not same:
		group = next((g for g in ("Consumable", "Raw Material", "All Item Groups") if frappe.db.exists("Item Group", g)),
					 None)
		item = frappe.get_doc({
			"doctype": "Item", "item_code": f"MAT-{frappe.generate_hash(length=8).upper()}", "item_name": doc.title,
			"description": doc.title, "item_group": group, "stock_uom": unit, "is_stock_item": 1,
			"is_purchase_item": 1, "is_sales_item": 0, "include_item_in_manufacturing": 0,
			"korkem_material_kind": material_stock.OTHER, "korkem_material_company": doc.company,
		})
		item.insert(ignore_permissions=True)
		same = item.name
	doc.db_set("item", same)


def _clean(**v) -> dict:
	title = " ".join(str(v.get("title") or "").split())[:140]
	if len(title) < 2:
		frappe.throw("Назовите статью.")
	group = " ".join(str(v.get("group") or "").split())
	if group not in GROUPS:
		frappe.throw(f"Группа — одна из: {', '.join(GROUPS)}.")
	mode = v.get("mode") or "other"
	if mode not in MODES:
		frappe.throw("Как учитывать: счёт за месяц, склад или по факту.")
	behaviour = v.get("behaviour") or "variable"
	if behaviour not in ("fixed", "variable"):
		frappe.throw("Затрата постоянная или переменная.")
	area = " ".join(str(v.get("area") or "").split()) or "Весь цех"
	if area not in AREAS:
		frappe.throw(f"Участок — один из: {', '.join(AREAS)}.")
	limit = flt(v.get("monthly_limit"))
	if limit < 0:
		frappe.throw("Лимит не меньше нуля.")
	return {"title": title, "group": group, "mode": mode, "behaviour": behaviour, "area": area,
			"unit": " ".join(str(v.get("unit") or "").split())[:20], "monthly_limit": limit}


def _doc_values(v: dict) -> dict:
	return {"title": v["title"], "cost_group": v["group"], "mode": v["mode"], "behaviour": v["behaviour"],
			"area": v["area"], "unit": v["unit"], "monthly_limit": v["monthly_limit"]}


def _same(company: str, title: str) -> str | None:
	for r in frappe.get_all(DOCTYPE, filters={"company": company, "merged_into": ["is", "not set"]},
							fields=["name", "title"], limit_page_length=0):
		if r.title.lower() == title.lower():
			return r.name
	return None


def _unique(company: str, title: str) -> None:
	if _same(company, title):
		frappe.throw(f"Статья «{title}» уже есть.")


def _own(name: str):
	if not name or not frappe.db.exists(DOCTYPE, name):
		frappe.throw("Такой статьи затрат нет.", frappe.DoesNotExistError)
	doc = frappe.get_doc(DOCTYPE, name)
	if doc.company != current_company():
		frappe.throw("Такой статьи затрат нет.", frappe.DoesNotExistError)
	return doc


def _row(r) -> dict:
	return {"name": r.name, "title": r.title, "group": r.cost_group, "mode": r.mode, "behaviour": r.behaviour,
			"area": r.area, "unit": r.unit, "monthly_limit": flt(r.monthly_limit), "item": r.item,
			"archived": bool(r.archived), "new": bool(r.is_new)}

