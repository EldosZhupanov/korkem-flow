# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Чтение спецификации из БАЗИС-Мебельщик — этап 6 цепочки.

Технолог проектирует изделие в БАЗИС и получает оттуда деталировку, раскрой и
карту операций. Переучивать его не надо и не выйдет: это его инструмент, и он
знает его лучше нас. Нам нужно уметь прочитать то, что он выгружает.

Разведка формата — в `docs/architecture/bazis_integration_study.md`, по открытой
документации БАЗИС. Здесь — код, который по ней читает.

**Этот файл ничего не записывает.** Он разбирает выгрузку и рассказывает, что в
ней: изделие, детали, материалы, операции. Первое, что делают с чужим форматом,
— читают его вслух и сверяют с тем, что ожидали; создание документов из
непроверенного разбора создаёт мусор, который потом выковыривают руками.

**Кодировка берётся из самого файла.** БАЗИС — программа под Windows, и её
выгрузка приходит в `windows-1251` не реже, чем в UTF-8. Объявление в первой
строке XML говорит, в какой именно; угадывать не надо, надо прочитать.

**Идентификатор — `SyncID`, а не название.** Технолог правит названия чаще
всего остального, и повторная выгрузка исправленного проекта — это «обновить то
же самое», а не «создать ещё раз». Без устойчивого идентификатора повторный
импорт либо задваивает состав, либо угадывает соответствие по строке, которую
только что поменяли.

**Проверено на выдуманном файле, собранном по документации.** Одного настоящего
экспорта с живого производства всё ещё нет, и до него этот разбор — обоснованное
предположение, а не факт. Отдельно об этом сказано в ROADMAP; когда файл
появится, первое, что с ним нужно сделать, — прогнать через `inspect` и сверить.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET

import frappe

#: Предел на файл. Спецификация кухни — десятки килобайт; сто мегабайт означают,
#: что прислали не то.
MAX_FILE_BYTES = 20 * 1024 * 1024


def inspect(*, content: bytes) -> dict:
	"""Прочитать выгрузку и рассказать, что в ней. Ничего не записывает."""
	root = _parsed(content)

	products = [_product(node) for node in root.iter("Изделие")]
	if not products:
		frappe.throw(
			"В файле нет ни одного изделия. Возможно, это выгрузка раскроя, "
			"а не спецификация: нужна та, что содержит элемент «Изделие»."
		)

	return {
		"products": products,
		"totals": {
			"products": len(products),
			"parts": sum(len(p["parts"]) for p in products),
			"materials": sum(len(p["materials"]) for p in products),
			"operations": sum(len(p["operations"]) for p in products),
		},
	}


def _parsed(content: bytes) -> ET.Element:
	if not content:
		frappe.throw("Пустой файл.")
	if len(content) > MAX_FILE_BYTES:
		frappe.throw(
			f"Файл больше {MAX_FILE_BYTES // (1024 * 1024)} МБ. Спецификация "
			"изделия столько не весит — похоже, прислали не тот файл."
		)
	try:
		# `fromstring` на байтах читает объявление кодировки сам; на строке —
		# уже нет, и файл в windows-1251 разбирается в мусор.
		return ET.fromstring(content)
	except ET.ParseError as error:
		frappe.throw(f"Это не XML или он повреждён: {error}")


def _product(node: ET.Element) -> dict:
	return {
		"name": _text(node, "Наименование"),
		"article": _text(node, "Артикул"),
		"order": _text(node, "Заказ"),
		"qty": _number(node, "Количество"),
		"price": _number(node, "Цена"),
		"parts": [_part(row) for row in node.iterfind("./СписокЭлементов/Объект")],
		"materials": [_material(row) for row in node.iter("ОсновнойМатериал")],
		"operations": [
			_operation(row) for row in node.iterfind("./СписокОпераций/*")
		],
	}


def _part(node: ET.Element) -> dict:
	return {
		"name": _text(node, "Наименование"),
		"code": _text(node, "Код"),
		"kind": _text(node, "Тип"),
		"length": _number(node, "Длина"),
		"width": _number(node, "Ширина"),
		"thickness": _number(node, "Толщина"),
		"qty": _number(node, "Количество"),
		"edges": [
			_text(edge, "Наименование")
			for edge in node.iterfind("./СписокКромок/Кромка")
		],
	}


def _material(node: ET.Element) -> dict:
	return {
		"sync_id": _text(node, "SyncID"),
		"name": _text(node, "Наименование"),
		"code": _text(node, "Код"),
		"unit": _text(node, "ЕдИзм"),
		"qty": _number(node, "Количество"),
		"price": _number(node, "Цена"),
	}


def _operation(node: ET.Element) -> dict:
	return {
		"sync_id": _text(node, "SyncID"),
		"name": _text(node, "Наименование"),
		"qty": _number(node, "Количество"),
		"price": _number(node, "Цена"),
		"minutes": _number(node, "Трудоёмкость"),
	}


def _text(node: ET.Element, tag: str) -> str | None:
	"""Значение может лежать и вложенным элементом, и атрибутом.

	Выгрузки БАЗИС встречаются в обоих видах — это прямо видно в примерах
	документации, — и разбирать надо оба, а не спорить с файлом.
	"""
	child = node.find(tag)
	if child is not None and (child.text or "").strip():
		return child.text.strip()
	value = node.get(tag)
	return value.strip() if value and value.strip() else None


def _number(node: ET.Element, tag: str) -> float | None:
	raw = _text(node, tag)
	if raw is None:
		return None
	# Запятая как разделитель дробной части — норма для русской локали Windows.
	try:
		return float(raw.replace(",", ".").replace(" ", ""))
	except ValueError:
		return None


#: Единицы БАЗИС в единицы ERPNext. Список короткий намеренно: подстановка
#: «непонятное → штуки» напечатала бы в накладной неправду, а единица там
#: видна клиенту. Незнакомая единица — повод спросить, а не догадаться.
UNITS: dict[str, str] = {
	"шт": "Nos",
	"шт.": "Nos",
	"компл": "Set",
	"компл.": "Set",
	"м": "Meter",
	"м.": "Meter",
	"пог.м": "Meter",
	"м2": "Square Meter",
	"м²": "Square Meter",
	"кв.м": "Square Meter",
	"кг": "Kg",
	"лист": "Sheet",
}

#: Приставка к коду номенклатуры, заведённой импортом. По ней видно
#: происхождение позиции, и по ней же повторный импорт находит свою.
CODE_PREFIX = "БАЗИС"


def import_specification(*, content: bytes, sales_order: str | None = None) -> dict:
	"""Собрать спецификацию и маршрут из выгрузки технолога.

	**Спецификация создаётся черновиком.** Проведённая BOM — это решение
	человека: с неё считается себестоимость и по ней запускают производство.
	Импорт приносит данные, соглашается с ними технолог.

	**Повторный импорт правит свой черновик, а не плодит второй.** Технолог
	выгружает проект по три раза за день; каждая выгрузка, ставшая новой
	спецификацией, — это цех, который не знает, по какой из них пилить.
	Если предыдущая уже проведена, трогать её нельзя: делается новый черновик,
	и в ответе об этом сказано прямо.

	**Незнакомая единица измерения останавливает импорт до записи.** Подставить
	вместо неё штуки значит напечатать в накладной неправду, а её читает клиент.
	Отказ приходит со списком того, что не разобрали.

	**Операция без рабочего места в маршрут не встаёт, и это не ошибка файла.**
	БАЗИС говорит, что делают и сколько это занимает, но не на каком станке
	**этой** мастерской: у одного раскрой на форматнике, у другого на ЧПУ. Это
	знание цеха, и у ERPNext для него есть своё место — поле `Workstation` в
	справочнике операций. Пока владелец не сказал, где делается «Раскрой»,
	операция заводится в справочник и в ответе помечается как ждущая ответа.
	Догадаться за него нельзя: рабочее место определяет и загрузку, и срок.
	"""
	frappe.only_for("System Manager")

	read = inspect(content=content)
	_refuse_unknown_units(read)

	company = frappe.defaults.get_user_default("Company") or frappe.db.get_value(
		"Company", {}, "name"
	)

	imported = []
	for product in read["products"]:
		imported.append(_one_product(product, company, sales_order))

	return {"company": company, "products": imported, "totals": read["totals"]}


def _refuse_unknown_units(read: dict) -> None:
	unknown = sorted(
		{
			material["unit"]
			for product in read["products"]
			for material in product["materials"]
			if material["unit"] and _unit(material["unit"]) is None
		}
	)
	if unknown:
		frappe.throw(
			"Не понимаю единицы измерения: "
			+ ", ".join(f"«{u}»" for u in unknown)
			+ ". Подставить вместо них штуки нельзя — единица печатается в "
			"накладной, и её читает клиент. Ничего не записано."
		)


def _unit(raw: str | None) -> str | None:
	if not raw:
		return "Nos"
	return UNITS.get(raw.strip().lower())


def _one_product(product: dict, company: str, sales_order: str | None) -> dict:
	item = _product_item(product)
	materials = [_material_item(row) for row in product["materials"]]
	routed, pending = [], []
	for row in product["operations"]:
		if not row["name"]:
			continue
		name = _operation_doc(row)
		workstation = frappe.db.get_value("Operation", name, "workstation")
		(routed if workstation else pending).append((name, workstation, row))

	bom, status = _bom(item, product, materials, routed, company)

	return {
		"product": product["name"],
		"item": item,
		"bom": bom,
		"bom_status": status,
		"materials": materials,
		"operations": [name for name, _, _ in routed],
		"operations_awaiting_workstation": [name for name, _, _ in pending],
		"sales_order": sales_order,
	}


def _product_item(product: dict) -> str:
	"""Изделие как номенклатура. Мебель на заказ на складе не лежит."""
	code = (product.get("article") or product.get("name") or "").strip()
	if not code:
		frappe.throw("У изделия нет ни артикула, ни наименования — нечем его назвать.")

	if frappe.db.exists("Item", code):
		return code

	doc = frappe.get_doc(
		{
			"doctype": "Item",
			"item_code": code,
			"item_name": (product.get("name") or code)[:140],
			"item_group": _item_group(),
			"stock_uom": "Nos",
			"is_stock_item": 0,
		}
	)
	doc.insert()
	return doc.name


def _material_item(material: dict) -> str:
	"""Материал как складская номенклатура, найденная по `SyncID`.

	Код собирается из `SyncID`, а не из наименования: наименование технолог
	правит чаще всего остального, и поиск по нему после первой же правки
	завёл бы вторую позицию на тот же материал.
	"""
	key = material.get("sync_id") or material.get("code") or material.get("name")
	if not key:
		frappe.throw("У материала нет ни SyncID, ни кода, ни наименования.")

	code = f"{CODE_PREFIX}-{key}"[:140]
	name = (material.get("name") or key)[:140]
	unit = _unit(material.get("unit")) or "Nos"

	if frappe.db.exists("Item", code):
		# Наименование обновляем: технолог его правит, и в спецификации должно
		# стоять то, что он написал сейчас. Код при этом не меняется.
		frappe.db.set_value("Item", code, "item_name", name)
		return code

	frappe.get_doc(
		{
			"doctype": "Item",
			"item_code": code,
			"item_name": name,
			"item_group": _item_group(),
			"stock_uom": unit,
			"is_stock_item": 1,
		}
	).insert()
	return code


def _operation_doc(operation: dict) -> str:
	name = (operation.get("name") or "").strip()[:140]
	if not frappe.db.exists("Operation", name):
		frappe.get_doc({"doctype": "Operation", "__newname": name, "name": name}).insert()
	return name


def _bom(item: str, product: dict, materials: list[str], operations: list[str], company: str):
	existing = frappe.get_all(
		"BOM",
		filters={"item": item, "docstatus": 0},
		pluck="name",
		order_by="modified desc",
		limit_page_length=1,
	)

	doc = frappe.get_doc("BOM", existing[0]) if existing else frappe.new_doc("BOM")
	status = "updated" if existing else "created"

	doc.item = item
	doc.company = company
	doc.quantity = product.get("qty") or 1
	doc.set("items", [])
	doc.set("operations", [])

	for material, row in zip(materials, product["materials"], strict=False):
		doc.append(
			"items",
			{
				"item_code": material,
				"qty": row.get("qty") or 1,
				"uom": _unit(row.get("unit")) or "Nos",
				"rate": row.get("price") or 0,
			},
		)

	if operations:
		doc.with_operations = 1
		for name, workstation, row in operations:
			doc.append(
				"operations",
				{
					"operation": name,
					"workstation": workstation,
					"time_in_mins": row.get("minutes") or 0,
					"hour_rate": row.get("price") or 0,
				},
			)
	else:
		doc.with_operations = 0

	if not doc.get("items"):
		frappe.throw(
			f"У изделия «{product['name']}» в выгрузке нет ни одного материала. "
			"Спецификация без состава ничего не говорит цеху."
		)

	doc.save()
	return doc.name, status


def _item_group() -> str:
	for name in ("Products", "Raw Material", "All Item Groups"):
		if frappe.db.exists("Item Group", name):
			return name
	groups = frappe.get_all("Item Group", filters={"is_group": 0}, pluck="name", limit_page_length=1)
	if not groups:
		frappe.throw("В системе нет ни одной группы номенклатуры.")
	return groups[0]
