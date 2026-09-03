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
