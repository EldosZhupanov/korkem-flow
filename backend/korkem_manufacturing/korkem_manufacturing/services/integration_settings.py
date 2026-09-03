# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Куда владелец кладёт ключи TrustMe и Kaspi — и почему именно туда.

Договор и оплата — два звена цепочки, которые нельзя написать кодом: нужен
аккаунт TrustMe и договор с Kaspi Bank. Но место, куда владелец вложит ключи,
когда они появятся, должно существовать заранее и быть безопасным.

**Секреты — поля типа `Password`, и это не косметика.** Frappe держит такие
значения в отдельной таблице `__Auth`, зашифрованными ключом сайта, и **никогда
не возвращает их через API** — на чтение приходит заглушка. Обычное поле `Data`
уехало бы в любой ответ, в любой экспорт и в любой отчёт.

**Ключи вводит владелец, а не мы.** Ни в репозиторий, ни в файл, ни в переписку.
Поэтому здесь есть `save`, который принимает значение и больше его не показывает,
и `status`, который отвечает «настроено или нет», не называя чем.

**Имена полей предварительные.** Аккаунтов ни там, ни там пока нет, и точные
названия параметров подтвердятся, когда владелец их откроет. Форма взята общая
для таких API — идентификатор организации или точки, токен, секрет вебхука.
Если реальность окажется другой, поменяются поля, а решение хранить их
зашифрованными и не отдавать наружу останется.

**Каждому клиенту — свои.** Сегодня настройки привязаны к установке: один узел —
один завод. Для подписки с несколькими компаниями на одном сервере это придётся
менять, и это записано отдельно как развилка 7 в `ROADMAP.md`, а не решено молча.
"""

from __future__ import annotations

import frappe

TRUSTME = "TrustMe Settings"
KASPI = "Kaspi Settings"

#: Что у какой настройки является секретом. Всё перечисленное — поля `Password`,
#: и ни одно из них не покидает сервер.
SECRETS: dict[str, tuple[str, ...]] = {
	TRUSTME: ("api_token", "webhook_secret"),
	KASPI: ("api_key", "webhook_secret"),
}

#: Что можно показать: это не секреты, а то, по чему владелец узнаёт свою запись.
PUBLIC: dict[str, tuple[str, ...]] = {
	TRUSTME: ("enabled", "organization_bin"),
	KASPI: ("enabled", "merchant_id"),
}


def status() -> dict:
	"""Настроено или нет — без единого значения.

	Экрану нужно показать «Kaspi подключён» или «ключа нет», и для этого не
	требуется знать ключ. Отдавать его, чтобы нарисовать галочку, было бы
	обменом секрета на удобство.
	"""
	frappe.only_for("System Manager")
	return {
		"trustme": _one(TRUSTME),
		"kaspi": _one(KASPI),
	}


def save(*, provider: str, values: dict) -> dict:
	"""Записать настройки. Пустое поле означает «не менять», а не «стереть».

	Владелец открывает экран, чтобы поправить БИН, и не должен при этом
	вводить заново токен, которого он не помнит и не видит.
	"""
	frappe.only_for("System Manager")

	doctype = _doctype(provider)
	doc = frappe.get_single(doctype)

	for field in PUBLIC[doctype]:
		if field in values and values[field] is not None:
			doc.set(field, values[field])

	for field in SECRETS[doctype]:
		value = (values.get(field) or "").strip()
		if value:
			doc.set(field, value)

	doc.save()
	return _one(doctype)


def clear_secret(*, provider: str, field: str) -> dict:
	"""Убрать ключ. Отдельным действием, а не пустым полем в форме.

	Стереть ключ — это отключить приём оплаты или подписание договоров.
	Такое делают намеренно, а не забыв заполнить поле.
	"""
	frappe.only_for("System Manager")

	doctype = _doctype(provider)
	if field not in SECRETS[doctype]:
		frappe.throw(f"У «{provider}» нет секрета «{field}».")

	doc = frappe.get_single(doctype)
	doc.set(field, "")
	doc.save()
	return _one(doctype)


def _one(doctype: str) -> dict:
	doc = frappe.get_single(doctype)
	body = {field: doc.get(field) for field in PUBLIC[doctype]}
	body["configured"] = {
		field: bool(_stored(doctype, field)) for field in SECRETS[doctype]
	}
	body["last_status"] = doc.get("last_status")
	body["last_checked_on"] = str(doc.get("last_checked_on") or "") or None
	body["last_error"] = doc.get("last_error")
	return body


def _stored(doctype: str, field: str) -> bool:
	"""Есть ли значение — не показывая его.

	`get_password` вернул бы сам секрет; здесь нужен только факт его наличия,
	и лишний раз доставать значение из хранилища незачем.

	Запрос сырой: `__Auth` — служебная таблица без колонки `creation`, а
	`frappe.db.get_value` добавляет по ней сортировку и падает на ней.
	"""
	rows = frappe.db.sql(
		"""SELECT 1 FROM `__Auth`
		   WHERE doctype = %s AND name = %s AND fieldname = %s LIMIT 1""",
		(doctype, doctype, field),
	)
	return bool(rows)


def _doctype(provider: str) -> str:
	mapping = {"trustme": TRUSTME, "kaspi": KASPI}
	name = mapping.get((provider or "").strip().lower())
	if not name:
		frappe.throw("Неизвестная интеграция. Есть trustme и kaspi.")
	return name
