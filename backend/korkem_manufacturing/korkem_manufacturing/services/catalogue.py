# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Номенклатура и цены — то, из чего собирается коммерческое предложение.

Последний пункт «администрирования без админки». КП уже работает, но позицию
для него можно завести только через панель ERPNext, и владелец упирается в это
на первом же предложении.

**Ничего своего.** `Item` и `Item Price` ERPNext — это и есть номенклатура с
ценами, и КП читает цену именно оттуда.

**Цена пишется в прайс-лист продаж по умолчанию, а не в произвольный.** У сайта
их два, и цена, записанная не в тот, не появится в предложении: ERPNext возьмёт
список из настроек продаж и не найдёт в нём ничего. Проверять надо там же, где
он смотрит.

**Единицы измерения отфильтрованы, а не показаны все.** В ERPNext их 240 — от
абампера до акра. Владельцу мастерской нужно семь, и лишние здесь не безобидны:
единица выбирается один раз и печатается в накладной, а «Acre» в списке рядом со
«шт» приглашает к ошибке, которую заметят при отгрузке.

**Позиция без цены — нормальное состояние.** Мебель на заказ считается по
проекту: сначала заводят «Кухонный гарнитур», цену называют после замера. Форма,
требующая цену, заставила бы вписать неправду.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import current_company

#: Единицы, которые встречаются в мебельном производстве. Порядок — по частоте,
#: а не по алфавиту: «шт» стоит первым, потому что им считается почти всё.
UNITS: tuple[tuple[str, str], ...] = (
	("Nos", "шт"),
	("Set", "комплект"),
	("Meter", "м, погонный метр"),
	("Square Meter", "м², квадратный метр"),
	("Sheet", "лист"),
	("Pair", "пара"),
	("Kg", "кг"),
)

ITEM_GROUP = "Products"


def units() -> list[dict]:
	"""Единицы измерения, которые имеет смысл предлагать."""
	existing = set(
		frappe.get_all("UOM", filters={"name": ["in", [u for u, _ in UNITS]]}, pluck="name")
	)
	return [
		{"unit": unit, "label": label} for unit, label in UNITS if unit in existing
	]


def items(*, query: str | None = None, limit: int = 50) -> list[dict]:
	"""Номенклатура с ценами. `query` ищет и по коду, и по названию."""
	filters: dict = {"disabled": 0}
	or_filters = None
	if query and query.strip():
		needle = f"%{query.strip()}%"
		or_filters = {"item_code": ["like", needle], "item_name": ["like", needle]}

	rows = frappe.get_list(
		"Item",
		filters=filters,
		or_filters=or_filters,
		fields=["name", "item_name", "stock_uom", "description"],
		order_by="modified desc",
		limit_page_length=limit,
	)
	prices = _prices([row["name"] for row in rows])

	return [
		{
			"code": row["name"],
			"name": row.get("item_name"),
			"unit": row.get("stock_uom"),
			"description": row.get("description"),
			"price": prices.get(row["name"]),
		}
		for row in rows
	]


def create(
	*,
	name: str,
	unit: str,
	code: str | None = None,
	description: str | None = None,
	price: float | None = None,
) -> dict:
	"""Завести позицию. Цена необязательна — её часто называют после замера."""
	frappe.only_for("System Manager")

	name = (name or "").strip()
	if not name:
		frappe.throw("У позиции должно быть название: без него её не найти в списке.")

	unit = (unit or "").strip()
	if not unit or unit not in {u for u, _ in UNITS}:
		frappe.throw(
			"Выберите единицу измерения. «Шкаф 2» без единицы — это два чего, "
			"и в накладной это увидит клиент."
		)

	code = (code or "").strip() or name
	if frappe.db.exists("Item", code):
		frappe.throw(f"Позиция «{code}» уже заведена.")

	doc = frappe.get_doc(
		{
			"doctype": "Item",
			"item_code": code,
			"item_name": name,
			"item_group": _item_group(),
			"stock_uom": unit,
			"description": (description or "").strip() or name,
			"is_stock_item": 0,
		}
	)
	doc.insert()

	if price is not None:
		set_price(code=doc.name, price=price)

	return _one(doc.name)


def set_price(*, code: str, price: float) -> dict:
	"""Назвать цену позиции — в том прайс-листе, из которого её читает КП."""
	frappe.only_for("System Manager")

	if not frappe.db.exists("Item", code):
		frappe.throw(f"Нет такой позиции: «{code}».")

	value = frappe.utils.flt(price)
	if value < 0:
		frappe.throw("Цена не бывает отрицательной.")

	price_list = _selling_price_list()
	existing = frappe.get_all(
		"Item Price",
		filters={"item_code": code, "price_list": price_list},
		pluck="name",
		limit_page_length=1,
	)
	if existing:
		frappe.db.set_value("Item Price", existing[0], "price_list_rate", value)
	else:
		frappe.get_doc(
			{
				"doctype": "Item Price",
				"item_code": code,
				"price_list": price_list,
				"price_list_rate": value,
			}
		).insert()

	return _one(code)


def _one(code: str) -> dict:
	row = frappe.db.get_value(
		"Item", code, ["name", "item_name", "stock_uom", "description"], as_dict=True
	)
	return {
		"code": row["name"],
		"name": row.get("item_name"),
		"unit": row.get("stock_uom"),
		"description": row.get("description"),
		"price": _prices([code]).get(code),
	}


def _prices(codes: list[str]) -> dict[str, float]:
	if not codes:
		return {}
	rows = frappe.get_all(
		"Item Price",
		filters={"item_code": ["in", codes], "price_list": _selling_price_list()},
		fields=["item_code", "price_list_rate"],
	)
	return {row["item_code"]: frappe.utils.flt(row["price_list_rate"]) for row in rows}


def _selling_price_list() -> str:
	"""Тот список, из которого цену возьмёт КП, а не любой из заведённых.

	Цена, записанная не в тот прайс-лист, не появится в предложении, и это
	выглядит как «цена не сохранилась», хотя она сохранилась — не там.
	"""
	name = frappe.db.get_single_value("Selling Settings", "selling_price_list")
	if not name:
		frappe.throw(
			"В настройках продаж не выбран прайс-лист. Пока его нет, цену "
			"некуда записать так, чтобы её увидело предложение."
		)
	return name


def _item_group() -> str:
	if frappe.db.exists("Item Group", ITEM_GROUP):
		return ITEM_GROUP
	groups = frappe.get_all(
		"Item Group", filters={"is_group": 0}, pluck="name", limit_page_length=1
	)
	if not groups:
		frappe.throw("В системе нет ни одной группы номенклатуры.")
	return groups[0]
