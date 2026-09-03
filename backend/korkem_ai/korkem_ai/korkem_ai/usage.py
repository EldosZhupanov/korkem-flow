# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Recording what a model turn cost, without ever being able to break it.

## Why this exists

Token usage was reported to the client at the end of a turn and then thrown
away. Nothing summed it, nothing could answer "what did last month cost", and
nothing could refuse a turn from somebody who had already spent too much. In a
system where — until Horizon 1 lands — every write costs a model turn, that is
an unbounded bill nobody can see until it arrives.

## The rule that shapes this whole module

**Accounting must never damage the work it is accounting for.** A dropped usage
row costs a line in a report. A poisoned transaction costs a production order.
So every write here runs inside a savepoint and every failure is swallowed
after being logged: `record()` returns `None` rather than raising, and no
caller is expected to check.

That is the one place in this codebase where swallowing an exception is
correct, and it is correct only because the failure is logged where an operator
will see it, and because the alternative is worse.

## Two zeros

`AIUsage` distinguishes "the provider reported nothing" (`None`) from "the
provider reported zero". That distinction survives into `AI Usage Log` as
`tokens_reported`, because a budget that treats unreported turns as free can be
exhausted for nothing. See the doctype's own docstring.
"""

from __future__ import annotations

import random
import string
import time

import frappe

from korkem_ai.korkem_ai.orchestrator.protocol import AIUsage
from korkem_ai.korkem_ai.tools import scope

DOCTYPE = "AI Usage Log"

#: Every channel a turn can arrive through. Matches the doctype's Select.
CHANNELS = ("App", "Telegram", "WhatsApp", "Scheduled")


def recorded(request_id: str | None) -> bool:
	"""Whether this exact provider invocation already reached the ledger."""
	return bool(request_id and frappe.db.exists(DOCTYPE, {"request_id": request_id}))


def record(
	usage: AIUsage | None,
	*,
	provider: str | None,
	model: str | None,
	status: str,
	turn_id: str | None = None,
	request_id: str | None = None,
	conversation: str | None = None,
	channel: str = "App",
	user: str | None = None,
	extra: dict | None = None,
) -> str | None:
	"""Write one row for one finished turn. Never raises.

	`extra` — поля попытки: чей ключ, какая по счёту, с кого переключились и
	почему. Отдельный словарь, а не десять аргументов: их пишет только роутер,
	и остальным вызывающим они не нужны. Ключи, которых нет в доктайпе,
	отбрасываются молча — вызывающий не должен падать из-за поля, которое ещё
	не завели.

	Returns the row's name, or `None` if it could not be written — which is
	information for a log, not for the caller, who has real work to finish.
	"""
	savepoint = "korkem_usage_" + "".join(random.sample(string.ascii_lowercase, 8))
	try:
		frappe.db.savepoint(savepoint)
		name = _insert(
			usage,
			provider=provider,
			model=model,
			status=status,
			turn_id=turn_id,
			request_id=request_id,
			conversation=conversation,
			channel=channel,
			user=user or frappe.session.user,
			extra=extra,
		)
		frappe.db.release_savepoint(savepoint)
		return name
	except frappe.DuplicateEntryError:
		# A concurrent retry may pass the read below before the first insert
		# commits. The database's unique key is the final arbiter; the loser is
		# the same accounted provider request, not an accounting failure.
		frappe.db.rollback(save_point=savepoint)
		return frappe.db.get_value(DOCTYPE, {"request_id": request_id}, "name")
	except Exception:
		# Roll back only our own insert. Anything the turn did before this
		# point — a Sales Order, a Stock Entry — is on the far side of the
		# savepoint and survives untouched.
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title="AI usage accounting failed",
			message=frappe.get_traceback(with_context=True),
		)
		return None


def record_turn(
	result,
	*,
	adapter=None,
	provider: str | None = None,
	model: str | None = None,
	turn_id: str | None = None,
	request_id: str | None = None,
	conversation: str | None = None,
	channel: str = "App",
	user: str | None = None,
) -> str | None:
	"""Record a finished turn from the turn's own result object.

	Prefer this over `record()` at a call site that has a `TurnResult`.

	## Why it exists, which is worth reading before simplifying it away

	The first version of this wiring called `record()` directly and built its
	arguments at the call site:

	    usage.record(result.usage, provider=llm.get_settings().provider, ...)

	Both of those can raise, and **they are evaluated before `record()` is
	entered**, so the savepoint that is supposed to make accounting harmless
	never gets a chance. Fourteen channel tests went red: their turn stubs have
	no `usage` attribute, the `AttributeError` was caught by the gateway's own
	`except Exception`, and every proposal in those turns silently stopped
	being written. A person would have seen "The assistant could not answer
	just now" for a turn that had in fact succeeded.

	So everything uncertain is read **inside** the guard here. A module that
	promises it cannot break the work has to honour that at the boundary where
	it is called, not only in its own body.
	"""
	try:
		usage = getattr(result, "usage", None)
		status = getattr(result, "status", None) or "answered"
		if provider is None:
			provider = _default_provider()
		if model is None:
			model = getattr(adapter, "model", None)
	except Exception:
		frappe.log_error(
			title="AI usage accounting could not describe the turn",
			message=frappe.get_traceback(with_context=True),
		)
		return None

	return record(
		usage,
		provider=provider,
		model=model,
		status=status,
		turn_id=turn_id,
		request_id=request_id,
		conversation=conversation,
		channel=channel,
		user=user,
	)


def record_failure(
	*,
	adapter=None,
	provider: str | None = None,
	model: str | None = None,
	turn_id: str | None = None,
	request_id: str | None = None,
	conversation: str | None = None,
	channel: str = "App",
	user: str | None = None,
) -> str | None:
	"""Record a provider call that raised, without losing resolved attribution.

	The adapter may already exist when the provider fails. Reading its model or
	the configured provider at the exception call site would happen outside
	``record``'s guard and could replace the original failure with an accounting
	one, so the uncertain reads stay here.
	"""
	try:
		provider = provider or _default_provider()
		model = model or getattr(adapter, "model", None)
	except Exception:
		frappe.log_error(
			title="AI usage accounting could not describe the failed turn",
			message=frappe.get_traceback(with_context=True),
		)
		return None

	return record(
		None,
		provider=provider,
		model=model,
		status="failed",
		turn_id=turn_id,
		request_id=request_id,
		conversation=conversation,
		channel=channel,
		user=user,
	)


def _known_fields(extra: dict | None) -> dict:
	"""Только те поля, что и правда есть в доктайпе.

	Журнал не имеет права стать причиной падения: вызывающий занят настоящей
	работой, а неизвестное поле — это наша недоделанная миграция, а не его
	ошибка.
	"""
	if not extra:
		return {}
	meta = frappe.get_meta(DOCTYPE)
	return {k: v for k, v in extra.items() if v is not None and meta.has_field(k)}


def _default_provider() -> str | None:
	"""The configured provider name, or None. Never raises."""
	try:
		return frappe.db.get_single_value("AI Settings", "provider")
	except Exception:
		return None


def _insert(
	usage: AIUsage | None,
	*,
	provider: str | None,
	model: str | None,
	status: str,
	turn_id: str | None,
	request_id: str | None,
	conversation: str | None,
	channel: str,
	user: str,
	extra: dict | None = None,
) -> str:
	if request_id:
		existing = frappe.db.get_value(DOCTYPE, {"request_id": request_id}, "name")
		if existing:
			return existing

	reported = usage is not None and usage.total_tokens is not None
	cost, currency, basis = _price(provider, model, usage if reported else None)

	doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"user": user,
			"company": _company(),
			"channel": channel if channel in CHANNELS else "App",
			"status": status,
			"provider": provider,
			"model": model,
			"turn_id": turn_id,
			"request_id": request_id,
			"conversation": conversation,
			"tokens_reported": 1 if reported else 0,
			"input_tokens": (usage.input_tokens or 0) if reported else 0,
			"output_tokens": (usage.output_tokens or 0) if reported else 0,
			"cost_basis": basis,
			"estimated_cost": cost,
			"cost_currency": currency,
			**_known_fields(extra),
		}
	)
	# Nobody holds write permission on this doctype, deliberately: a user who
	# could insert here could forge their own spend, and one who could delete
	# could erase it. The system records it on their behalf.
	doc.insert(ignore_permissions=True)
	return doc.name


def _company() -> str | None:
	"""The session's company, or None.

	`scope.current_company()` throws when a session has none, which is right
	for a business question and wrong here — a turn by a user with no company
	still cost money and still has to be counted.
	"""
	try:
		return scope.current_company()
	except Exception:
		return None


def _price(provider: str | None, model: str | None, usage: AIUsage | None):
	"""Multiply tokens out by the rates on `AI Provider`, if any are set.

	Returns `(cost, currency, basis)`. No provider returns a charge with a
	completion, so this is always an estimate from a rate somebody typed; where
	no rate exists the answer is an explicit "not priced" rather than a zero
	that reads as free.
	"""
	if not usage or not provider:
		return 0.0, None, "not priced"

	row = frappe.db.get_value(
		"AI Provider",
		provider,
		["input_rate_per_1k", "output_rate_per_1k", "rate_currency"],
		as_dict=True,
	)
	if not row or not (row.input_rate_per_1k or row.output_rate_per_1k):
		return 0.0, None, "not priced"

	cost = (usage.input_tokens or 0) / 1000 * (row.input_rate_per_1k or 0) + (
		usage.output_tokens or 0
	) / 1000 * (row.output_rate_per_1k or 0)
	return round(cost, 6), row.rate_currency, "provider rate"


def spent_today(user: str | None = None) -> dict:
	"""What one user has spent since midnight, in tokens and estimated cost.

	The unit that always works is tokens: a provider that reports usage gives
	them for free, whereas cost needs a rate somebody configured. Both are
	returned so a limit can be expressed in either.
	"""
	user = user or frappe.session.user
	row = frappe.db.sql(
		"""
		SELECT COALESCE(SUM(total_tokens), 0) AS tokens,
		       COALESCE(SUM(estimated_cost), 0) AS cost,
		       COUNT(*) AS turns
		FROM `tabAI Usage Log`
		WHERE user = %s AND creation >= %s
		""",
		(user, frappe.utils.today()),
		as_dict=True,
	)[0]
	return {"tokens": int(row.tokens), "cost": float(row.cost), "turns": int(row.turns)}


def spent_today_by_company(company: str | None = None) -> dict:
	"""The same, for everybody in one company."""
	company = company or _company()
	if not company:
		return {"tokens": 0, "cost": 0.0, "turns": 0}
	row = frappe.db.sql(
		"""
		SELECT COALESCE(SUM(total_tokens), 0) AS tokens,
		       COALESCE(SUM(estimated_cost), 0) AS cost,
		       COUNT(*) AS turns
		FROM `tabAI Usage Log`
		WHERE company = %s AND creation >= %s
		""",
		(company, frappe.utils.today()),
		as_dict=True,
	)[0]
	return {"tokens": int(row.tokens), "cost": float(row.cost), "turns": int(row.turns)}


def record_attempt(
	*,
	provider: str,
	model: str | None,
	scope: str,
	attempt: int,
	status: str,
	started: float,
	usage: AIUsage | None = None,
	fallback_from: str | None = None,
	fallback_reason: str | None = None,
	error_code: str | None = None,
	turn_id: str | None = None,
	request_id: str | None = None,
) -> str | None:
	"""Одна попытка обращения к модели — успешная или нет.

	## Зачем отдельно от `record`

	`record` пишет **завершённый ход**: сколько он стоил и чем кончился. Этого
	достаточно для счёта и недостаточно для вопроса «почему стало медленно».
	Ход, ответивший с третьей попытки, в нём выглядит как обычный, и по такому
	журналу нельзя узнать ни что первые два провайдера отказали, ни сколько
	ходов вообще дошло до нашего оплачиваемого резерва.

	Строка на попытку отвечает ровно на это. Она же — основа счёта: платим мы
	только за строки с `scope = server`.

	## Чего здесь не будет никогда

	Ни вопроса человека, ни ответа модели, ни аргументов инструментов, ни ключа.
	Причина отказа записывается **классом ошибки**, а не текстом провайдера:
	текст может содержать что угодно, включая обрывки запроса.
	"""
	latency = int((time.monotonic() - started) * 1000)
	return record(
		usage,
		provider=provider,
		model=model,
		status=status,
		turn_id=turn_id,
		request_id=request_id,
		extra={
			"credential_scope": scope,
			"attempt": attempt,
			"fallback_from": fallback_from,
			"fallback_reason": fallback_reason,
			"provider_error_code": error_code,
			"latency_ms": latency,
		},
	)


def metrics(days: int = 30) -> dict:
	"""Ответы на вопросы, на которые иначе отвечают догадками.

	Считается по строкам попыток, а не по завершённым ходам: ход, ответивший с
	третьей попытки, в журнале ходов выглядит как обычный, и по нему нельзя
	узнать ни что два провайдера отказали, ни сколько ходов дошло до
	оплачиваемого резерва.

	`days` — окно. Тридцать дней по умолчанию, потому что счёт приходит за
	месяц; для суточного вопроса передают единицу.

	Слова статуса те же, что у завершённых ходов — `answered` и `failed`. Свой
	словарь для попыток означал бы два способа сказать одно и то же в одной
	таблице.
	"""
	since = frappe.utils.add_days(frappe.utils.nowdate(), -abs(days))
	rows = frappe.get_all(
		DOCTYPE,
		filters={"creation": [">=", since]},
		fields=[
			"provider",
			"model",
			"status",
			"credential_scope",
			"attempt",
			"fallback_reason",
			"latency_ms",
			"input_tokens",
			"output_tokens",
			"estimated_cost",
			"creation",
		],
		limit_page_length=0,
	)

	attempts = [r for r in rows if r["attempt"]]
	first_try = [r for r in attempts if r["attempt"] == 1 and r["status"] == "answered"]
	server = [r for r in attempts if r["credential_scope"] == "server"]
	server_success = [r for r in server if r["status"] == "answered"]
	latencies = sorted(r["latency_ms"] for r in attempts if r["latency_ms"])

	by_reason: dict[str, int] = {}
	for row in attempts:
		if row["fallback_reason"]:
			by_reason[row["fallback_reason"]] = by_reason.get(row["fallback_reason"], 0) + 1

	by_model: dict[str, dict] = {}
	for row in attempts:
		key = f"{row['provider']} · {row['model']}"
		bucket = by_model.setdefault(
			key, {"attempts": 0, "input_tokens": 0, "output_tokens": 0, "cost": 0.0}
		)
		bucket["attempts"] += 1
		bucket["input_tokens"] += row["input_tokens"] or 0
		bucket["output_tokens"] += row["output_tokens"] or 0
		bucket["cost"] += row["estimated_cost"] or 0

	month_start = frappe.utils.get_first_day(frappe.utils.nowdate())
	today = frappe.utils.nowdate()

	def spend(rows_, since_date):
		return round(
			sum(
				(r["estimated_cost"] or 0)
				for r in rows_
				if frappe.utils.getdate(r["creation"]) >= frappe.utils.getdate(since_date)
			),
			4,
		)

	return {
		"window_days": abs(days),
		"attempts": len(attempts),
		# Ходы, которым хватило первого же провайдера. Чем ближе к общему числу,
		# тем спокойнее живёт человек: переключение стоит ему ожидания.
		"answered_first_try": len(first_try),
		"fallbacks": len([r for r in attempts if r["attempt"] > 1]),
		"reached_korkem_reserve": len(server),
		# Доля, за которую платим мы. Это и есть себестоимость ассистента.
		"server_share": round(len(server) / len(attempts), 4) if attempts else 0,
		"server_answered": len(server_success),
		"by_failure": by_reason,
		"by_model": by_model,
		"latency_avg_ms": round(sum(latencies) / len(latencies)) if latencies else None,
		"latency_p95_ms": latencies[int(len(latencies) * 0.95)] if latencies else None,
		"server_cost_today": spend(server, today),
		"server_cost_month": spend(server, month_start),
	}
