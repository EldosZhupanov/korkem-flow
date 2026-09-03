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

**Идентификатор ищется по очереди: `SyncID`, `ID`, `Код`, наименование.**
Документация обещает `SyncID`, и первая версия этого файла на него и опиралась.
В пяти настоящих выгрузках с производства (БАЗИС 10.1 и 10.4) **`SyncID` пуст
везде** — `<SyncID/>`, — а живой идентификатор лежит в `<ID>`. Причём `ID = -1`
означает «в справочнике БАЗИС этого нет», то есть тоже не идентификатор.
Порядок именно такой: обещанное поле первым, чтобы заработало само, когда
технолог начнёт его заполнять.

**Детали лежат в блоках, вложенных друг в друга.** Изделие → `Блок` (секция) →
`Блок` (ящик) → `Объект` (панель). Есть ещё `Сборка` — составная фурнитура со
своим списком. Первая версия читала только прямых детей и на настоящем файле
находила **ноль деталей из пяти**; проверка это и показала. Обход рекурсивный,
и путь блоков сохраняется: цеху важно, из какого ящика деталь.

**Разобрано на пяти настоящих выгрузках, присланных владельцем 3 сентября.**
До них здесь стояли файлы, собранные по документации, и четыре вещи из четырёх
оказались не такими. Что всё ещё не проверено: **операции**. `СписокОпераций`
пуст во всех пяти файлах, то есть маршрут из этих выгрузок не собирается вовсе,
и код маршрута по-прежнему держится на документации.
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


#: Контейнеры, внутри которых лежат детали. `Блок` — секция или ящик, вложенные
#: друг в друга; `Сборка` — составная фурнитура со своим списком.
CONTAINERS = ("Блок", "Сборка")


def _product(node: ET.Element) -> dict:
	parts: list[dict] = []
	_collect_parts(node, (), parts)

	return {
		"name": _text(node, "Наименование"),
		"article": _text(node, "Артикул"),
		"order": _text(node, "Заказ"),
		"qty": _number(node, "Количество"),
		"price": _number(node, "Цена"),
		"parts": parts,
		"materials": _materials(node),
		"operations": [
			_operation(row) for row in node.iterfind("./СписокОпераций/*")
		],
	}


def _materials(node: ET.Element) -> list[dict]:
	"""Материалы вместе с типом объекта, которому они принадлежат.

	Тип нужен затем, что пустая единица измерения у панели и у фурнитуры
	означает разное, и узнать это можно только по владельцу.
	"""
	found: list[dict] = []
	for owner in node.iter():
		if owner.tag not in ("Объект", "Изделие", "Блок", "Сборка"):
			continue
		kind = _text(owner, "ТипОбъекта")
		for tag in ("ОсновнойМатериал", "СопутствующийМатериал"):
			for row in owner.findall(f"./{tag}") + owner.findall(f"./СопутствующиеМатериалы/{tag}"):
				found.append(_material(row, kind, tag))
	return found


def _collect_parts(node: ET.Element, path: tuple[str, ...], into: list[dict]) -> None:
	"""Обойти изделие вглубь, помня, в каком блоке лежит деталь."""
	for child in node.findall("./СписокЭлементов/*"):
		if child.tag == "Объект":
			into.append(_part(child, path))
		elif child.tag in CONTAINERS:
			name = _text(child, "Наименование") or child.tag
			_collect_parts(child, (*path, name), into)


def _part(node: ET.Element, path: tuple[str, ...] = ()) -> dict:
	return {
		"block": " / ".join(path) or None,
		"name": _text(node, "Наименование"),
		"code": _text(node, "Код"),
		"kind": _text(node, "Тип"),
		"length": _number(node, "Длина"),
		"width": _number(node, "Ширина"),
		"thickness": _number(node, "Толщина"),
		"qty": _number(node, "Количество"),
		# Кромки лежат в четырёх списках по сторонам детали, плюс отдельный
		# список для криволинейного контура. Пустая кромка — заглушка стороны,
		# а не материал: у неё нет наименования.
		"edges": [
			name
			for edge in node.iter("Кромка")
			if (name := _text(edge, "Наименование"))
		],
	}


def _material(
	node: ET.Element, owner: str | None = None, kind: str | None = None
) -> dict:
	return {
		"sync_id": _identity(node),
		"name": _text(node, "Наименование"),
		"code": _text(node, "Код"),
		"owner": owner,
		"kind": kind,
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


def _identity(node: ET.Element) -> str | None:
	"""Чем этот материал опознаётся при повторном импорте.

	`SyncID` обещан документацией и пуст во всех настоящих выгрузках. `ID` есть
	и живой, но `-1` означает «в справочнике БАЗИС такого нет» — это не
	идентификатор, а его отсутствие.
	"""
	sync = _text(node, "SyncID")
	if sync:
		return sync

	identifier = _text(node, "ID")
	if identifier and identifier.strip() != "-1":
		return identifier

	return _text(node, "Код")


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
	# «комп» — так это пишет БАЗИС в настоящих выгрузках.
	"комп": "Set",
	"комп.": "Set",
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
	Отказ приходит со списком того, что не разобрали. Пустая единица — не
	незнакомая: см. ниже, она разрешается по типу объекта.

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
			if material["unit"]
			and _unit(material["unit"], material.get("owner"), material.get("kind")) is None
		}
	)
	if unknown:
		frappe.throw(
			"Не понимаю единицы измерения: "
			+ ", ".join(f"«{u}»" for u in unknown)
			+ ". Подставить вместо них штуки нельзя — единица печатается в "
			"накладной, и её читает клиент. Ничего не записано."
		)


def _unit(
	raw: str | None, owner: str | None = None, kind: str | None = None
) -> str | None:
	"""Единица материала. Пустая — норма, и разрешается по типу объекта.

	В настоящих выгрузках `ЕдИзм` у основного материала пуст почти всегда, а
	количество при этом — площадь листа. Проверено арифметикой на файлах
	владельца: у детали «дно» 600×460 стоит 0.276, что ровно 0.6 × 0.46; у
	«Boc» 600×430 при коэффициенте 1.2 стоит 0.3096, что ровно 0.6 × 0.43 × 1.2.
	Это метры квадратные, а не штуки, и подставлять сюда штуки нельзя — ERPNext
	справедливо отказывается принимать 0.276 штуки.

	У сопутствующего материала панели пустая единица означает **погонные
	метры**: это кромка, и считается она по периметру. Тоже проверено: у фасада
	637 + 637 + 222 + 222 мм при коэффициенте 1.1 дают ровно 1.8898.

	У фурнитуры пустая единица означает штуки: там количество целое — четыре
	ноги, двадцать два шурупа.
	"""
	if raw and raw.strip():
		return UNITS.get(raw.strip().lower())
	if owner == "Панель":
		return "Meter" if kind == "СопутствующийМатериал" else "Square Meter"
	return "Nos"


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

	bom, status, skipped = _bom(item, product, materials, routed, company)

	return {
		"product": product["name"],
		"item": item,
		"bom": bom,
		"bom_status": status,
		"materials": materials,
		"materials_without_quantity": skipped,
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
	unit = _unit(material.get("unit"), material.get("owner"), material.get("kind")) or "Nos"

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

	# Один материал приходит десятками строк — по разу на каждую деталь. В
	# спецификации он должен стоять один раз с общим количеством: иначе закупка
	# увидит двадцать позиций ЛДСП вместо одной и не поймёт, сколько брать.
	summed: dict[tuple[str, str], dict] = {}
	skipped: list[str] = []
	for material, row in zip(materials, product["materials"], strict=False):
		quantity = frappe.utils.flt(row.get("qty"))
		if quantity <= 0:
			# Ноль в выгрузке значит «БАЗИС это не посчитал». Написать вместо
			# него единицу — придумать за технолога количество, по которому
			# потом закупят.
			skipped.append(row.get("name") or material)
			continue
		uom = _unit(row.get("unit"), row.get("owner"), row.get("kind")) or "Nos"
		line = summed.setdefault(
			(material, uom), {"qty": 0.0, "rate": row.get("price") or 0}
		)
		line["qty"] += quantity

	for (material, uom), line in summed.items():
		doc.append(
			"items",
			{"item_code": material, "qty": line["qty"], "uom": uom, "rate": line["rate"]},
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
	return doc.name, status, skipped


def _item_group() -> str:
	for name in ("Products", "Raw Material", "All Item Groups"):
		if frappe.db.exists("Item Group", name):
			return name
	groups = frappe.get_all("Item Group", filters={"is_group": 0}, pluck="name", limit_page_length=1)
	if not groups:
		frappe.throw("В системе нет ни одной группы номенклатуры.")
	return groups[0]
