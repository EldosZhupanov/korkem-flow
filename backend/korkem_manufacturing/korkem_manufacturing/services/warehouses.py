# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Склады — последний пункт «администрирования без админки».

ERPNext заводит четыре склада сам, при создании компании: `Stores`,
`Work In Progress`, `Finished Goods`, `Goods In Transit`. Заводить их заново не
нужно — нужно другое.

**Переименовать их нельзя, и это выяснено, а не предположено.** «Stores - ED»
печатается в каждой накладной и читается владельцем мастерской в Астане как шум,
поэтому первая версия этого файла складам имена меняла. ERPNext ответил
«Warehouse not allowed to be renamed», и проверка показала, что это не
формальность: у `Warehouse` нет ни `after_rename`, ни отображаемого имени —
в документах печатается сам идентификатор, а дерево складов держится на нём
через `lft`/`rgt` и `parent_warehouse`. Переносить ссылки было бы некому.
Обойти флаг через `force=True` можно за одну строку — и это ровно тот случай,
про который сказано «не двигать `Bin` руками».

**Поэтому задача решается иначе, средствами ERPNext.** Владелец заводит склад
сразу с русским именем, назначает его складом отгрузки и отключает английский,
которым не пользуется. Результат тот же — в документах стоит понятное имя, —
но реестр остатков остаётся согласованным.

**Добавить склад можно, удалить — нет.** Склад, по которому шли проводки, нельзя
убрать, не оторвав историю остатков. Ненужное место отключается: оно перестаёт
предлагаться в новых документах и остаётся читаемым в старых.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import current_company


def listing() -> list[dict]:
	"""Склады компании — с тем, что на них лежит."""
	company = current_company()
	rows = frappe.get_list(
		"Warehouse",
		filters={"company": company, "is_group": 0},
		fields=["name", "warehouse_name", "disabled"],
		order_by="disabled asc, warehouse_name asc",
		limit_page_length=0,
	)
	counts = _stock_counts([row["name"] for row in rows])
	default_fg = frappe.db.get_value("Company", company, "default_fg_warehouse")

	return [
		{
			"warehouse": row["name"],
			"name": row.get("warehouse_name"),
			"disabled": bool(row.get("disabled")),
			"positions": counts.get(row["name"], 0),
			"is_shipping_default": row["name"] == default_fg,
		}
		for row in rows
	]


def create(*, name: str) -> dict:
	"""Завести склад — второй цех, арендованное помещение, машину."""
	frappe.only_for("System Manager")

	name = (name or "").strip()
	if not name:
		frappe.throw("У склада должно быть название: без него его не выбрать.")

	company = current_company()
	if _by_display_name(company, name):
		frappe.throw(f"Склад «{name}» уже есть.")

	doc = frappe.get_doc(
		{
			"doctype": "Warehouse",
			"warehouse_name": name,
			"company": company,
			"parent_warehouse": _root(company),
			"is_group": 0,
		}
	)
	doc.insert()
	return _one(doc.name)


def set_shipping_default(*, warehouse: str) -> dict:
	"""Назначить склад, с которого уходит готовая мебель.

	Это то, ради чего заводят свой склад: без переназначения заказы всё равно
	отгружаются с английского `Finished Goods`, и новый склад стоит пустым.
	"""
	frappe.only_for("System Manager")

	company = current_company()
	_visible(company, warehouse)

	if frappe.db.get_value("Warehouse", warehouse, "disabled"):
		frappe.throw(
			"Этот склад отключён. Отгружать с места, которое не предлагается "
			"в документах, не выйдет."
		)

	frappe.db.set_value("Company", company, "default_fg_warehouse", warehouse)
	return _one(warehouse)


def set_disabled(*, warehouse: str, disabled: bool) -> dict:
	"""Убрать место из выбора, не трогая историю остатков."""
	frappe.only_for("System Manager")

	company = current_company()
	_visible(company, warehouse)

	if disabled and frappe.db.get_value("Company", company, "default_fg_warehouse") == warehouse:
		frappe.throw(
			"Это склад отгрузки: с него уходит готовая мебель. Сначала назначьте "
			"другой, иначе заказы будет некуда отгружать."
		)

	frappe.db.set_value("Warehouse", warehouse, "disabled", 1 if disabled else 0)
	return _one(warehouse)


def _visible(company: str, warehouse: str) -> dict:
	row = frappe.db.get_value(
		"Warehouse", warehouse, ["name", "warehouse_name", "company"], as_dict=True
	)
	if not row or row["company"] != company:
		frappe.throw("Нет такого склада в этой компании.", frappe.PermissionError)
	return row


def _one(warehouse: str) -> dict:
	for row in listing():
		if row["warehouse"] == warehouse:
			return row
	frappe.throw("Склад пропал из списка сразу после изменения.")


def _by_display_name(company: str, name: str) -> str | None:
	rows = frappe.get_all(
		"Warehouse",
		filters={"company": company, "warehouse_name": name},
		pluck="name",
		limit_page_length=1,
	)
	return rows[0] if rows else None


def _root(company: str) -> str | None:
	rows = frappe.get_all(
		"Warehouse",
		filters={"company": company, "is_group": 1},
		pluck="name",
		order_by="lft asc",
		limit_page_length=1,
	)
	return rows[0] if rows else None


def _stock_counts(warehouses: list[str]) -> dict[str, int]:
	"""Сколько разных позиций лежит на каждом складе.

	Считается по `Bin` — реестру остатков ERPNext, а не по проводкам: он для
	этого и существует, и не заставляет складывать историю заново.

	Складов у мастерской единицы, поэтому считается по одному запросу на склад:
	группировка через `fields` во Frappe 17 запрещена строкой, а ради пяти
	значений городить построитель запросов незачем.
	"""
	return {
		warehouse: frappe.db.count(
			"Bin", {"warehouse": warehouse, "actual_qty": [">", 0]}
		)
		for warehouse in warehouses
	}
