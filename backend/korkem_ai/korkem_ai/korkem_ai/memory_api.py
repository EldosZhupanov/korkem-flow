# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Что KORKEM знает» — то, что человек видит и может поправить.

Форма ответа задана экраном, а не хранилищем. Экран спрашивает: что это за
факт, откуда он взялся и подтверждён ли он — потому что человек, который не
видит источника, не может решить, верить факту или нет.

Поэтому наружу уходит **готовая фраза**, а не тройка «о чём / что / значение».
Разбирать её обратно в предложение на клиенте значило бы держать знание о
структуре памяти в двух местах.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai import memory

SOURCE_LABELS = {
	"stated": "указано вами",
	"inferred": "выведено из разговора",
	"imported": "из настроек компании",
}


@frappe.whitelist()
def list() -> dict:
	"""Два раздела: о компании и обо мне.

	Разделены здесь, а не на клиенте: это два разных предмета, и решать, куда
	отнести факт, должна та сторона, которая знает про области.
	"""
	return {
		"company": [_shown(row) for row in memory.recall(scope=memory.COMPANY, limit=200)],
		"user": [
			_shown(row)
			for row in memory.recall(
				scope=memory.USER, owner=frappe.session.user, limit=200
			)
		],
	}


@frappe.whitelist(methods=["POST"])
def update(name: str, value: str) -> dict:
	"""Человек поправил факт о себе.

	Правка — это подтверждение с новым значением: человек только что сказал,
	как оно на самом деле, и уверенность в этом полная.
	"""
	_mine(name)
	value = (value or "").strip()
	if not value:
		frappe.throw("Пустой факт — это забытый факт. Для этого есть «удалить».")

	doc = frappe.get_doc(memory.DOCTYPE, name)
	doc.value = value
	doc.source_type = "stated"
	doc.confidence = 1.0
	doc.confirmed_by = frappe.session.user
	doc.confirmed_at = frappe.utils.now_datetime()
	doc.save(ignore_permissions=True)
	return _shown(_row(name))


@frappe.whitelist(methods=["POST"])
def confirm(name: str) -> dict:
	"""«Да, так и есть». Подтверждённое живёт дольше выведенного."""
	_mine(name)
	memory.confirm(name)
	return _shown(_row(name))


@frappe.whitelist(methods=["POST"])
def delete(name: str) -> dict:
	"""Забыть.

	Строка остаётся выключенной, но для человека это неотличимо от удаления: в
	контекст факт больше не попадает и на экране его нет. Остаётся она ради
	вопроса «почему KORKEM перестал это знать».
	"""
	_mine(name)
	return memory.forget(name)


def _mine(name: str) -> None:
	"""Свой факт или факт своей компании — и ничей больше.

	Без этой проверки достаточно знать чужой идентификатор, чтобы стереть
	чужую память.
	"""
	row = frappe.db.get_value(
		memory.DOCTYPE, name, ["scope", "owner_key", "company"], as_dict=True
	)
	if not row:
		frappe.throw("Такого факта нет.")
	if row.scope == memory.USER and row.owner_key != frappe.session.user:
		frappe.throw("Это факт о другом человеке.", frappe.PermissionError)


def _row(name: str) -> dict:
	return frappe.db.get_value(
		memory.DOCTYPE,
		name,
		[
			"name",
			"scope",
			"category",
			"subject",
			"predicate",
			"value",
			"source_type",
			"source_reference",
			"confirmed_at",
			"creation",
		],
		as_dict=True,
	)


def _shown(row: dict) -> dict:
	"""Факт словами человека, а не полями таблицы."""
	return {
		"name": row["name"],
		"text": f"{row['subject']} · {row['predicate']}: {row['value']}",
		"scope": row["scope"],
		"category": row.get("category"),
		"source_label": _source_label(row),
		"confirmed": bool(row.get("confirmed_at")),
		"confirmed_at": row.get("confirmed_at"),
		"created_at": row.get("creation"),
	}


def _source_label(row: dict) -> str:
	base = SOURCE_LABELS.get(row.get("source_type"), "источник неизвестен")
	reference = row.get("source_reference")
	return f"{base} · {reference}" if reference else base
