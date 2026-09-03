# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Какая модель отвечает на этот вызов, и что делать, когда она не смогла.

## Зачем

Бесплатный тариф Gemini — двадцать обращений в сутки на модель. Один вопрос
ассистенту стоит трёх, значит владелец получает шесть-семь вопросов и тишину до
завтра. Бесплатная GLM на OpenRouter делит лимит со всем миром и отвечает
`429`, когда кастрюля пуста. Ни то, ни другое не чинится с нашей стороны — но
чинится тем, что моделей больше одной.

Правило простое и взято не из моды: **самая дешёвая модель, которая справится.**
Дорогая — когда дешёвая не смогла. Так работают RouteLLM и FrugalGPT, и так
экономия получается кратной, а не процентной.

## Что здесь есть и чего пока нет

Есть **цепочка по стоимости**: провайдеры пробуются от дешёвого к дорогому, и
отказ по исчерпанной квоте или недоступности переводит вызов к следующему.
Это то, что нужно владельцу сегодня: Gemini кончился на двадцатом вопросе —
следующий ответ приходит от другой модели, а не «нет связи».

Нет **выбора по сложности задачи**: «эта задача простая, эта требует
рассуждения». Для него нужен классификатор, которого у нас пока нет, и делать
вид, что он есть, — хуже, чем не делать его. Порядок сегодня задаёт цена,
записанная в самом провайдере, а не догадка о задаче.

## Почему переключение не может создать заказ дважды

Это единственное место, где ошибка стоила бы денег клиента, и оно решается не
осторожностью, а тем, где стоит роутер.

Инструменты выполняет цикл агента, **между** обращениями к модели. Роутер
подменяет только само обращение. К моменту переключения всё, что уже
выполнено, лежит в истории сообщений и уходит следующей модели как факт: она
видит, что заказ создан, и не создаёт его снова. Повторно вызывается разговор,
а не действие.

Поэтому здесь нет ни «идемпотентности», ни защёлок: их не требуется, пока
роутер стоит там, где стоит. Сдвинуть его наружу, обернув повтором весь ход, —
и повторный счёт клиенту станет вопросом времени.
"""

from __future__ import annotations

import time

import frappe

from korkem_ai.korkem_ai import errors
from korkem_ai.korkem_ai.orchestrator import llm

PROVIDER_DOCTYPE = "AI Provider"
SERVER_DOCTYPE = "AI Server Provider"

#: Чей ключ. Не смешивается никогда — см. заголовок `server_chain`.
USER = "user"
SERVER = "server"

#: Сколько провайдер отдыхает после «квота исчерпана».
#:
#: Не настройка, а следствие того, как считают провайдеры: суточные квоты
#: сбрасываются раз в сутки, минутные — через минуту, и узнать какая именно
#: кончилась по ответу нельзя. Полчаса — компромисс: минутный лимит к этому
#: времени отпустит, суточный нет, и повторная проверка стоит одного запроса,
#: а не одного на каждое сообщение человека.
COOLDOWN_MINUTES = 30

#: Отказы, после которых имеет смысл спросить другую модель.
#:
#: Кончившаяся квота, лежащий провайдер и молчание по таймауту — не наши ошибки
#: и у другой модели их может не быть.
RETRYABLE = (errors.RateLimited, errors.ProviderUnavailable, errors.AITimeout)

#: Отказы, после которых переключаться бессмысленно и вредно.
#:
#: Неверный ключ, слишком длинный контекст и неправильный запрос повторятся у
#: всех: у следующей модели тот же контекст и тот же запрос. Перебирать
#: провайдеров ради одного и того же отказа — это платить за него несколько раз
#: и показать человеку последнюю ошибку вместо настоящей.
FINAL = (errors.AIAuthError, errors.ContextTooLarge, errors.InvalidToolArguments)


class NoProviderAnswered(errors.AIError):
	"""Все модели цепочки отказали. Несёт причину первой — она объясняет больше."""


def chain(preferred: str | None = None) -> list[dict]:
	"""Оба пула подряд: сначала ключи клиента, потом резерв KORKEM."""
	return user_chain(preferred) + server_chain()


def user_chain(preferred: str | None = None) -> list[dict]:
	"""Провайдеры по порядку: сначала дешёвые.

	Порядок задаёт цена, записанная в самом провайдере, а не наше мнение о нём.
	Провайдер без цены считается бесплатным и идёт первым — это верно для
	бесплатных тарифов и для локальной модели, и неверно только там, где цену
	забыли проставить. Забытая цена стоит одного лишнего обращения, а не
	неправильного счёта.

	`preferred` ставится в голову цепочки, кем бы он ни был: человек, явно
	назвавший провайдера, имел в виду его, а не наш порядок.
	"""
	rows = frappe.get_all(
		PROVIDER_DOCTYPE,
		filters={"enabled": 1},
		fields=["name", "model", "input_rate_per_1k", "output_rate_per_1k", "cooldown_until"],
	)
	rows = [row for row in rows if not _resting(row)]
	for row in rows:
		row["scope"] = USER

	def cost(row) -> float:
		# Один вход к четырём выходам — грубо, но это соотношение обычного
		# разговора, и оно ближе к правде, чем считать их поровну.
		return (row["input_rate_per_1k"] or 0) + 4 * (row["output_rate_per_1k"] or 0)

	rows.sort(key=lambda row: (cost(row), row["name"]))

	if preferred:
		rows.sort(key=lambda row: row["name"] != preferred)

	return rows


def server_chain() -> list[dict]:
	"""Резерв KORKEM: наши ключи, наш счёт, наш порядок.

	Порядок задаёт `priority`, а не цена: здесь платим мы, и очерёдность — это
	решение, а не расчёт. Клиентский пул наоборот сортируется по цене, потому
	что там дешёвое для клиента и есть правильное.

	Пул общий по определению: он не привязан ни к какой компании, потому что
	принадлежит нам. Ключи клиентов общими не бывают никогда — `ADR-0029`.
	"""
	if not frappe.db.table_exists(SERVER_DOCTYPE):
		return []

	rows = frappe.get_all(
		SERVER_DOCTYPE,
		filters={"enabled": 1},
		fields=[
			"name",
			"provider",
			"model",
			"priority",
			"cooldown_until",
			"input_rate_per_1k",
			"output_rate_per_1k",
		],
		order_by="priority asc, name asc",
	)
	out = []
	for row in rows:
		if _resting(row):
			continue
		row["scope"] = SERVER
		out.append(row)
	return out


def _resting(row: dict) -> bool:
	"""Провайдер, которого недавно отправили отдыхать."""
	until = row.get("cooldown_until")
	if not until:
		return False
	return frappe.utils.get_datetime(until) > frappe.utils.now_datetime()


def complete(call, *, preferred: str | None = None, on_switch=None, turn_id: str | None = None):
	"""Выполнить одно обращение к модели, перебирая цепочку при отказе.

	`call` получает готовый адаптер и делает с ним ровно один вызов. Всё, что
	между вызовами — выполнение инструментов, история, подтверждения, — остаётся
	снаружи и не повторяется. Смотри заголовок модуля: на этом и держится то,
	что переключение не может выполнить действие дважды.
	"""
	attempts = chain(preferred)
	if not attempts:
		errors.throw(
			"Ни один провайдер ИИ не включён.", errors.AIErrorCode.NOT_CONFIGURED
		)

	first_failure = None
	previous = None
	for index, row in enumerate(attempts):
		try:
			adapter = _adapter(row)
		except errors.AIError as exc:
			# Провайдер включён, но настроен наполовину. Это не повод обрывать
			# цепочку — это повод пройти мимо него.
			first_failure = first_failure or exc
			continue

		started = time.monotonic()
		try:
			answer = call(adapter)
		except FINAL:
			# Ответ будет тем же у всех. Отдаём его как есть, не тратя чужие
			# квоты на повторение одной и той же ошибки.
			raise
		except RETRYABLE as exc:
			first_failure = first_failure or exc
			_record(row, exc)
			_ledger(
				row, index + 1, "failed", started, previous, exc, turn_id=turn_id
			)
			previous = row["name"]
			if on_switch and index + 1 < len(attempts):
				on_switch(row["name"], attempts[index + 1]["name"], exc)
			continue

		_ledger(row, index + 1, "answered", started, previous, None, turn_id=turn_id,
			usage=getattr(answer, "usage", None))
		return answer

	raise NoProviderAnswered(
		"Ни одна из моделей не ответила. "
		f"Первая причина: {first_failure}"
		if first_failure
		else "Ни одна из моделей не ответила."
	)


def _ledger(row, attempt, status, started, previous, exc, *, turn_id=None, usage=None):
	"""Строка в журнал на каждую попытку. Никогда не мешает работе.

	Наружу из этой функции не выходит ничего: журнал, уронивший ход, хуже
	отсутствующего журнала. По этим строкам потом отвечают на вопросы, на
	которые иначе отвечают догадками — сколько ходов дошло до нашего
	оплачиваемого резерва, какой провайдер чаще отказывает, стало ли медленнее.
	"""
	try:
		from korkem_ai.korkem_ai import usage as ledger

		ledger.record_attempt(
			provider=row.get("provider") or row["name"],
			model=row.get("model"),
			scope=row.get("scope") or USER,
			attempt=attempt,
			status=status,
			started=started,
			usage=usage,
			fallback_from=previous,
			# Класс ошибки, а не её текст: текст провайдера может содержать
			# что угодно, включая обрывки запроса человека.
			fallback_reason=type(exc).__name__ if exc else None,
			error_code=getattr(exc, "code", None) if exc else None,
			turn_id=turn_id,
		)
	except Exception:
		pass


def _adapter(row: dict):
	"""Построить адаптер для строки любого из двух пулов.

	Ключ резервного провайдера читается здесь и нигде больше: он не проходит
	ни через один whitelisted-эндпоинт и не попадает в ответ приложению.
	"""
	if row.get("scope") == SERVER:
		doc = frappe.get_doc(SERVER_DOCTYPE, row["name"])
		return llm._build(
			provider=doc.provider,
			model=doc.model,
			api_key=doc.get_password("api_key", raise_exception=False),
			base_url=(doc.base_url or "").strip()
			or llm.DEFAULT_BASE_URLS.get(doc.provider),
			effort="low",
		)
	return llm.resolve(row["name"], row["model"])


def _record(row: dict, exc: Exception) -> None:
	"""Запомнить отказ и отправить провайдера отдыхать.

	Две вещи сразу, и вторая важнее. Без отдыха исчерпанный провайдер
	спрашивается снова на каждое сообщение: человек ждёт лишний круг по
	цепочке, а провайдер получает запрос, на который заведомо ответит отказом.

	Владелец при этом должен видеть, какая модель кончилась и когда, не
	открывая журналов сервера.
	"""
	doctype = SERVER_DOCTYPE if row.get("scope") == SERVER else PROVIDER_DOCTYPE
	rest_until = frappe.utils.add_to_date(
		frappe.utils.now_datetime(), minutes=COOLDOWN_MINUTES
	)
	try:
		if not frappe.db.exists(doctype, row["name"]):
			return
		if doctype == SERVER_DOCTYPE:
			frappe.db.set_value(
				doctype,
				row["name"],
				{"cooldown_until": rest_until, "last_error": str(exc)[:500]},
				update_modified=False,
			)
			return
		frappe.db.set_value(
			doctype,
			row["name"],
			{
				"last_tested_at": frappe.utils.now_datetime(),
				"last_test_ok": 0,
				"last_test_error": str(exc)[:500],
				"cooldown_until": rest_until,
			},
			update_modified=False,
		)
	except Exception:
		# Запись о неудаче не имеет права стать второй неудачей.
		pass
