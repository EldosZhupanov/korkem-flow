# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Этот заказ», «поменяй там», «проверь её оплату».

## Зачем отдельно от переписки

Сегодня такие ссылки держатся на одном: модель читает историю разговора. Работает,
пока история есть. Она ограничена сорока сообщениями и обрезается молча — а
человек, вернувшийся к разговору через час, продолжает говорить «этот заказ» и
получает вопрос «какой именно» там, где секунду назад всё понималось.

Ссылка на предмет разговора — не часть переписки, а состояние. Его и хранят
отдельно.

## Почему ссылка обязана уметь протухать

«Этот заказ» вчерашний и «этот заказ» минуту назад — разные вещи. Молча
применить вчерашний к сегодняшнему «поменяй срок» значит поменять срок не тому
заказу, и человек об этом не узнает.

Поэтому у каждой сущности есть время, а у ссылки — срок годности. Просроченная
не подставляется: лучше переспросить, чем угадать.

## Опасные действия не пользуются ссылками вовсе

Счёт, оплата, договор, списание. Для них «этот заказ» не подставляется даже
свежий: человек должен назвать предмет явно или подтвердить его на экране
предпросмотра. Цена ошибки здесь — чужие деньги, и она не отыгрывается назад.
"""

from __future__ import annotations

import json

import frappe

DOCTYPE = "Session Entity"

#: Сколько ссылка считается свежей.
#:
#: Полчаса — длина разговора, а не смены. Человек, вернувшийся после обеда,
#: говорит «этот заказ» уже про другой; человек, продолжающий беседу, — про тот
#: же. Точной границы нет, и любая будет спорной; эта хотя бы объяснима.
FRESH_MINUTES = 30

#: Что мы вообще запоминаем как предмет разговора.
KINDS = ("order", "customer", "item", "task", "employee", "project")


def remember(kind: str, value: str, *, user: str | None = None) -> None:
	"""Запомнить, о чём сейчас речь.

	Вызывается, когда инструмент вернул предмет: нашёл заказ, создал заявку,
	показал клиента. Не из слов человека — из того, что система на самом деле
	нашла: слова могут быть про одно, а найденное про другое.
	"""
	if kind not in KINDS or not value:
		return

	user = user or frappe.session.user
	if user in ("Guest", "Administrator"):
		return

	state = _load(user)
	state[kind] = {"value": value, "at": frappe.utils.now_datetime().isoformat()}
	_save(user, state)


def current(kind: str, *, user: str | None = None, for_risky: bool = False) -> str | None:
	"""На что показывает «этот» — или ничего.

	`for_risky` — действие с деньгами или необратимое. Для него ссылка не
	подставляется никогда, даже свежая: человек должен назвать предмет сам.
	Переспросить дешевле, чем выставить счёт не тому.
	"""
	if for_risky:
		return None

	entry = _load(user or frappe.session.user).get(kind)
	if not entry:
		return None

	if _stale(entry):
		# Не подставляем и не чистим: запись остаётся видимой на случай
		# вопроса «почему KORKEM переспросил».
		return None
	return entry.get("value")


def switched(kind: str, value: str, *, user: str | None = None) -> bool:
	"""Человек назвал другой предмет того же рода.

	Смена — не ошибка, а обычный ход разговора: «а теперь по заказу Асхата».
	Знать о ней нужно, чтобы не применить прежнюю ссылку к новой теме.
	"""
	previous = current(kind, user=user)
	return bool(previous and value and previous != value)


def forget(*, user: str | None = None) -> None:
	"""Разговор окончен."""
	user = user or frappe.session.user
	if frappe.db.exists(DOCTYPE, user):
		frappe.db.set_value(DOCTYPE, user, {"entities": "{}", "updated_at": frappe.utils.now_datetime()})


def described(*, user: str | None = None) -> str:
	"""Строка для инструкции модели — или пусто.

	Только свежее. Устаревшее не показывается вовсе: модель, увидевшая
	вчерашний заказ, сошлётся на него как на текущий, и это будет выглядеть
	уверенно.
	"""
	state = _load(user or frappe.session.user)
	fresh = {
		kind: entry["value"]
		for kind, entry in state.items()
		if isinstance(entry, dict) and entry.get("value") and not _stale(entry)
	}
	if not fresh:
		return ""

	lines = ["\n## What the conversation is about\n"]
	lines.append(
		"\nUse these when the person says «this order», «her», «change it there». "
		"For anything involving money or an irreversible change, ask which one "
		"instead of assuming.\n"
	)
	lines.extend(f"- {kind}: {value}\n" for kind, value in sorted(fresh.items()))
	return "".join(lines)


def _stale(entry: dict) -> bool:
	at = entry.get("at")
	if not at:
		return True
	age = frappe.utils.time_diff_in_seconds(frappe.utils.now_datetime(), at)
	return age > FRESH_MINUTES * 60


def _load(user: str) -> dict:
	raw = frappe.db.get_value(DOCTYPE, user, "entities")
	if not raw:
		return {}
	try:
		return json.loads(raw)
	except (TypeError, ValueError):
		return {}


def _save(user: str, state: dict) -> None:
	now = frappe.utils.now_datetime()
	if frappe.db.exists(DOCTYPE, user):
		frappe.db.set_value(
			DOCTYPE, user, {"entities": json.dumps(state), "updated_at": now}
		)
		return
	frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"user": user,
			"company": _company(),
			"entities": json.dumps(state),
			"updated_at": now,
		}
	).insert(ignore_permissions=True)


def _company() -> str | None:
	try:
		from korkem_ai.korkem_ai.tools import scope

		return scope.current_company()
	except Exception:
		return None
