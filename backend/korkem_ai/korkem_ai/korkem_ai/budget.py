# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Refusing a turn that would go over budget, before it costs anything.

## Why a guard and not a report

Until Horizon 1 lands, every write in this system costs a model turn. That
makes the monthly bill a function of how much work the factory did, with no
ceiling anywhere — and the first time anybody would find out is when it
arrives. `usage.py` made the spend visible; this makes it bounded.

## Where it is enforced, and where it is not

**Here, on the server, and nowhere else.** A limit checked in the Flutter
client is a suggestion: the same endpoint is reachable from Telegram, from
WhatsApp, and from `curl`. Every entry point that can start a turn calls
`check()` first, and `check()` reads its numbers from `AI Settings` rather than
from anything the caller sent.

## Three limits, because they fail differently

* **A daily token budget** is the real ceiling. Tokens are the unit that always
  works — any provider that reports usage reports them.
* **A daily cost budget** is the one an owner actually thinks in, and it is
  inert until somebody configures rates on `AI Provider`. That is stated in the
  field's own description rather than hidden, because a money limit that
  silently never triggers is worse than none.
* **A rate limit** catches a different failure: a stuck client or a retry loop
  burning a month's budget in four minutes. A daily budget would let that run
  to completion and only then refuse.

All three default to zero, meaning unlimited. That is deliberate: switching
this on for an existing pilot with a number somebody guessed would stop the
factory mid-shift. The numbers are set once there is a week of real usage to
set them from.

## One consequence worth knowing

`chat.confirm` is checked too, so somebody who has hit their limit cannot
approve a proposal that is already waiting. Nothing is lost — the proposal is a
`Pending Action` and survives until tomorrow or until an administrator raises
the limit — but a half-finished operation does stall. The alternative, letting
confirmations through, turns propose-then-confirm into a way around the budget.
Chosen this way deliberately; revisit it if a real pilot finds it annoying,
which is the only evidence that would settle it.

## What the person sees

A sentence naming which limit was hit, what they have used, and when it
resets — never a generic failure. Somebody who cannot start work needs to know
whether to wait, ask for a bigger budget, or report a bug.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai import errors, usage

SETTINGS = "AI Settings"

#: Redis key prefix for the burst counter. Not a database table: a rate limit
#: that writes a row per attempt is itself a load problem.
RATE_KEY = "korkem:ai:turns:"


class BudgetExceeded(errors.AIError):
	"""A turn was refused because a configured limit is already reached.

	Carries `RATE_LIMITED` so existing clients classify it as "try later"
	rather than as a bug. It is raised **synchronously**, from the whitelisted
	entry point and before anything is enqueued, so its own sentence reaches
	the person — the background path replaces a message with a generic one
	looked up from the code, which would throw away exactly the detail that
	makes this actionable.
	"""

	code = errors.AIErrorCode.RATE_LIMITED


def _settings() -> dict:
	return (
		frappe.db.get_value(
			SETTINGS,
			SETTINGS,
			[
				"daily_tokens_per_user",
				"daily_cost_per_user",
				"daily_tokens_per_company",
				"daily_cost_per_company",
				"turns_per_minute_per_user",
			],
			as_dict=True,
		)
		or {}
	)


def check(user: str | None = None) -> None:
	"""Raise `BudgetExceeded` if this user may not start another turn.

	Called before a turn is enqueued, not after it runs: the point is to spend
	nothing, so the check has to happen while there is still nothing to spend.
	"""
	user = user or frappe.session.user
	limits = _settings()
	if not limits:
		return

	_check_rate(user, int(limits.get("turns_per_minute_per_user") or 0))

	spent = usage.spent_today(user)
	_check_one(
		"tokens",
		spent["tokens"],
		int(limits.get("daily_tokens_per_user") or 0),
		"Дневной лимит по токенам исчерпан",
	)
	_check_one(
		"cost",
		spent["cost"],
		float(limits.get("daily_cost_per_user") or 0),
		"Дневной лимит по стоимости исчерпан",
	)

	company_tokens = int(limits.get("daily_tokens_per_company") or 0)
	company_cost = float(limits.get("daily_cost_per_company") or 0)
	if company_tokens or company_cost:
		# Only queried when a company limit is actually set — this is a table
		# scan over a day, and running it for every turn on a site that does
		# not use company budgets would be work for nothing.
		shared = usage.spent_today_by_company()
		_check_one(
			"tokens",
			shared["tokens"],
			company_tokens,
			"Дневной лимит по токенам исчерпан для всей компании",
		)
		_check_one(
			"cost",
			shared["cost"],
			company_cost,
			"Дневной лимит по стоимости исчерпан для всей компании",
		)


def _check_one(unit: str, used, limit, headline: str) -> None:
	if not limit or used < limit:
		return
	amount = f"{used:,.0f}" if unit == "tokens" else f"{used:,.2f}"
	cap = f"{limit:,.0f}" if unit == "tokens" else f"{limit:,.2f}"
	raise BudgetExceeded(
		f"{headline}: израсходовано {amount} из {cap}. "
		"Лимит обновится в полночь. Изменить его может администратор "
		"в настройках AI."
	)


def _check_rate(user: str, per_minute: int) -> None:
	"""A per-minute burst guard, counted in Redis.

	The counter is keyed by user *and* minute and expires on its own, so there
	is nothing to clean up and a restart cannot leave somebody locked out.

	Redis being unavailable does **not** refuse the turn. A cache outage should
	degrade the guard, not the factory — and the daily budget below is still
	enforced from the database.
	"""
	if not per_minute:
		return
	try:
		# `make_key` prefixes the site. `incr`/`expire` are not overridden by
		# Frappe's wrapper, so they would otherwise hit an unprefixed key and
		# two sites on one bench would share a counter.
		cache = frappe.cache()
		key = cache.make_key(f"{RATE_KEY}{user}:{frappe.utils.now_datetime():%Y%m%d%H%M}")
		count = cache.incr(key)
		if count == 1:
			cache.expire(key, 120)
	except Exception:
		frappe.log_error(
			title="AI rate limit check could not read the cache",
			message=frappe.get_traceback(with_context=True),
		)
		return

	if count > per_minute:
		raise BudgetExceeded(
			f"Слишком много запросов: больше {per_minute} в минуту. "
			"Подождите минуту и повторите."
		)
