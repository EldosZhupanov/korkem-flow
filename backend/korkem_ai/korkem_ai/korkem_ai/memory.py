# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Что KORKEM помнит о компании и о человеке — и чего не помнит намеренно.

## Одно правило, из которого следует всё остальное

**Память не источник правды.** Заказы, остатки, цены, оплаты и сроки живут в
ERPNext; память хранит устойчивое — должность человека, кто за что отвечает,
как в этом цехе называют вещи, какие правила подтвердил владелец.

Из этого следует, что сюда нельзя писать всё подряд. Разговор, из которого
запомнили каждую фразу, через месяц превращается в набор устаревших
утверждений, и модель начинает уверенно называть числа, которых нет.

## Что сохраняется само, а что только по слову человека

Само — устойчивое и проверяемое: роль, зона ответственности, язык, единицы
измерения цеха, подтверждённое правило.

Не сохраняется само никогда: секреты, банковские данные, одноразовые коды,
текущий остаток, текущая цена, статус заказа и случайный разговор. Первые три —
потому что память уходит в модель. Остальные — потому что они меняются, а
запомненное изменяемое становится ложью, которую никто не заметит.
"""

from __future__ import annotations

import frappe

DOCTYPE = "Memory Fact"

COMPANY = "company"
USER = "user"

#: Сколько фактов берётся в контекст по умолчанию.
#:
#: Не «сколько влезет»: вся память в каждом запросе — это плата за токены и
#: шум, в котором тонет нужное. Отбираются самые важные, а остальное модель
#: может спросить отдельно.
DEFAULT_LIMIT = 12


def remember(
	*,
	scope: str,
	category: str,
	subject: str,
	predicate: str,
	value: str,
	source_type: str = "stated",
	source_reference: str | None = None,
	confidence: float = 0.5,
	importance: float = 0.5,
	owner: str | None = None,
	expires_at=None,
) -> str:
	"""Запомнить один факт, заменив прежний о том же самом.

	Замена, а не перезапись: старый факт остаётся и получает ссылку на новый.
	История нужна, когда человек спрашивает «почему KORKEM думает, что я
	бухгалтер» — ответ «так было сказано второго сентября» проверяем, а
	«не знаю» нет.
	"""
	if scope == COMPANY and owner:
		# Не нормализуем молча. Тот, кто передал человека, считал факт личным;
		# тихо сделать его фактом компании значит показать его всем — это
		# последствие для приватности, а не неаккуратность в аргументах.
		frappe.throw(
			"Факт компании принадлежит компании. Если он про одного человека — "
			"это область «user»."
		)
	if scope == USER and not owner:
		owner = frappe.session.user

	previous = _current(scope, owner, subject, predicate)

	doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"scope": scope,
			"owner_key": owner,
			"company": _company(),
			"category": category,
			"subject": subject,
			"predicate": predicate,
			"value": value,
			"source_type": source_type,
			"source_reference": source_reference,
			"confidence": confidence,
			"importance": importance,
			"is_active": 1,
			"expires_at": expires_at,
		}
	).insert(ignore_permissions=True)

	if previous:
		frappe.db.set_value(
			DOCTYPE, previous, {"is_active": 0, "superseded_by": doc.name}
		)
	return doc.name


def recall(
	*, scope: str | None = None, owner: str | None = None, limit: int = DEFAULT_LIMIT
) -> list[dict]:
	"""Факты для контекста: самые важные, живые, не устаревшие.

	Сортировка по важности, затем по свежести. Подтверждённое человеком идёт
	выше выведенного нами — он знает свой цех лучше, чем модель, которая его
	слушала.
	"""
	filters = {"is_active": 1, "company": _company()}
	if scope:
		filters["scope"] = scope
	if owner:
		filters["owner_key"] = owner

	rows = frappe.get_all(
		DOCTYPE,
		filters=filters,
		fields=[
			"name",
			"scope",
			"category",
			"subject",
			"predicate",
			"value",
			"confidence",
			"importance",
			"confirmed_at",
			"expires_at",
			"source_type",
			"source_reference",
			"modified",
		],
		limit_page_length=0,
	)

	now = frappe.utils.now_datetime()
	fresh = [
		row
		for row in rows
		if not row["expires_at"] or frappe.utils.get_datetime(row["expires_at"]) > now
	]
	fresh.sort(
		key=lambda row: (
			1 if row["confirmed_at"] else 0,
			row["importance"] or 0,
			row["modified"],
		),
		reverse=True,
	)
	return fresh[:limit]


def confirm(name: str) -> dict:
	"""Человек подтвердил факт о себе или о своей компании.

	Подтверждённое живёт дольше и стоит выше в отборе: это единственное место,
	где человек может поправить то, что система вывела сама.
	"""
	frappe.db.set_value(
		DOCTYPE,
		name,
		{
			"confirmed_by": frappe.session.user,
			"confirmed_at": frappe.utils.now_datetime(),
			"confidence": 1.0,
			"source_type": "stated",
		},
	)
	return {"confirmed": name}


def forget(name: str) -> dict:
	"""Забыть факт.

	Выключение, а не удаление: строка остаётся, и на вопрос «почему KORKEM
	перестал это знать» есть ответ. Для человека это неотличимо от удаления —
	в контекст факт больше не попадает.
	"""
	frappe.db.set_value(DOCTYPE, name, "is_active", 0)
	return {"forgotten": name}


def _current(scope: str, owner: str | None, subject: str, predicate: str) -> str | None:
	"""Действующий факт о том же самом, если он есть."""
	return frappe.db.get_value(
		DOCTYPE,
		{
			"scope": scope,
			"owner_key": owner,
			"subject": subject,
			"predicate": predicate,
			"is_active": 1,
			"company": _company(),
		},
		"name",
	)


def _company() -> str | None:
	"""Компания этого узла.

	Через общий `scope`, а не своим запросом: узел сегодня обслуживает одну
	компанию, но поле проставляется всегда — добавленное потом, оно потребовало
	бы переноса данных.
	"""
	try:
		from korkem_ai.korkem_ai.tools import scope as company_scope

		return company_scope.current_company()
	except Exception:
		return frappe.defaults.get_user_default("Company")
