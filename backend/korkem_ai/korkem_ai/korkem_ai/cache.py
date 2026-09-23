# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Semantic & short-term response cache in Redis for KORKEM AI.

## Why this exists

In a furniture workshop, workers and managers frequently ask identical or closely
related status questions throughout the day:
  - "где заказ 104?" / "заказ 104 где?" / "тапсырыс 104 қайда?"
  - "сколько ЛДСП на складе?" / "остаток ЛДСП"
  - "кто сейчас на смене?" / "кто на смене"
  - "привет" / "кто ты?"

Without caching, every repetition runs a full multi-turn agent loop, pulls schemas,
and calls third-party LLMs (5–10 seconds, thousands of tokens, spending rate limits).

With Redis caching:
  - Normalized questions hit Redis and return within ~10ms.
  - Zero tokens spent.
  - Zero load on LLM rate limits (TPM/RPM).
  - High availability: answers even if external LLM provider has a temporary blip.

## Multi-tenant Isolation & Safety Rules

1. Tenant & Role Scoping:
   Every cache key is scoped by (company, role, normalized_query).
   Tenant A never sees Tenant B's cached answers. A measurer never sees
   confidential financial calculations intended for an owner/accountant.

2. Read-Only Safety:
   Mutations or actions requiring confirmation (proposals, writes) are NEVER cached.
   Only completed, read-only answers ('answered') are cached.

3. Time-To-Live (TTL):
   Factory state changes over time (materials are consumed, operations complete).
   Default TTL is 300 seconds (5 minutes) — fresh enough for real-time operations,
   long enough to absorb bursts of repeated queries.
   Greetings and informational queries have a longer TTL (3600 seconds).
"""

from __future__ import annotations

import hashlib
import json
import re
from typing import Any

import frappe
from korkem_ai.korkem_ai.tools import policy, scope

DEFAULT_CACHE_TTL = 300  # 5 minutes
STATIC_CACHE_TTL = 3600  # 1 hour for greetings / static help
CACHE_KEY_PREFIX = "korkem_ai:cache:"

# Filler words to strip during query normalization
_FILLER_WORDS = (
	"подскажи пожалуйста",
	"скажи пожалуйста",
	"айтып жіберші",
	"айтшы",
	"пожалуйста",
	"подскажи",
	"скажи",
	"айтыңызшы",
	"сұрақ",
	"вопрос",
)

# Common greetings that have static / evergreen answers
_GREETING_PATTERNS = (
	"привет",
	"здравствуй",
	"здравствуйте",
	"добрый день",
	"доброе утро",
	"добрый вечер",
	"салам",
	"сәлем",
	"ассаламу алейкум",
	"ассалам алейкум",
	"как дела",
	"қалайсың",
	"кто ты",
	"сен кімсің",
	"что ты умеешь",
	"не істей аласың",
	"помощь",
	"көмек",
	"спасибо",
	"рахмет",
)


def normalize(query: str) -> str:
	"""Normalize a question for semantic/exact matching.

	Strips punctuation, casing, redundant spaces, and common conversational fillers.
	Example:
	  'Подскажи пожалуйста, где заказ 104???' -> 'где заказ 104'
	"""
	text = (query or "").lower().strip()
	for filler in _FILLER_WORDS:
		text = text.replace(filler, " ")

	# Replace punctuation with spaces
	text = re.sub(r"[^\w\s]", " ", text, flags=re.UNICODE)
	# Collapse multiple whitespace
	text = re.sub(r"\s+", " ", text).strip()
	return text


def is_greeting(query: str) -> bool:
	norm = normalize(query)
	return any(norm.startswith(p) or norm == p for p in _GREETING_PATTERNS)


def make_key(query: str, company: str | None = None, role: str | None = None) -> str:
	"""Tenant-isolated, role-isolated Redis cache key."""
	norm = normalize(query)
	query_hash = hashlib.sha256(norm.encode("utf-8")).hexdigest()[:16]
	try:
		comp = (company or scope.current_company() or "global").strip()
	except Exception:
		comp = "global"
	try:
		r = (role or policy.role_of() or "default").strip()
	except Exception:
		r = "default"
	return f"{CACHE_KEY_PREFIX}{comp}:{r}:{query_hash}"


def get(query: str, company: str | None = None, role: str | None = None) -> dict[str, Any] | None:
	"""Retrieve cached answer from Redis if fresh."""
	if not query or not query.strip():
		return None

	key = make_key(query, company=company, role=role)
	try:
		cache = frappe.cache()
		raw = cache.get_value(key)
		if not raw:
			return None
		data = json.loads(raw) if isinstance(raw, str) else raw
		return data
	except Exception:
		# Cache failures must never break the main chat workflow
		return None


def put(
	query: str,
	text: str,
	*,
	company: str | None = None,
	role: str | None = None,
	executed_tools: list[str] | None = None,
	ttl: int | None = None,
) -> bool:
	"""Store read-only answer in Redis."""
	if not query or not text:
		return False

	if ttl is None:
		ttl = STATIC_CACHE_TTL if is_greeting(query) else DEFAULT_CACHE_TTL

	key = make_key(query, company=company, role=role)
	payload = {
		"query": normalize(query),
		"text": text,
		"cached_at": frappe.utils.now(),
		"executed_tools": executed_tools or [],
	}
	try:
		cache = frappe.cache()
		cache.set_value(key, json.dumps(payload, ensure_ascii=False), expires_in_sec=ttl)
		return True
	except Exception:
		return False


def is_cacheable(result: Any, history: list | None = None) -> bool:
	"""Decide whether a turn result is safe to cache.

	Safe to cache when:
	- Turn succeeded with status 'answered'.
	- No unapproved pending proposals (needs_confirmation).
	- No state-modifying write tools executed.
	- Not an interactive sub-turn of an active multi-turn conversation.
	"""
	if getattr(result, "status", None) != "answered":
		return False
	if getattr(result, "pending", None):
		return False

	# If write tools were executed, do not cache
	executed = getattr(result, "executed", [])
	write_verbs = (
		"create", "update", "delete", "start", "stop", "complete",
		"assign", "log", "accept", "reject", "cancel", "submit",
	)
	for item in executed:
		tool_name = item.get("tool", "") if isinstance(item, dict) else getattr(item, "name", "")
		if any(w in tool_name for w in write_verbs):
			return False

	# If multi-turn dialogue with lots of specific context, do not cache
	if history and len(history) > 2:
		return False

	return bool(getattr(result, "text", None))


def clear_cache(company: str | None = None) -> None:
	"""Flush cached responses for a company or all."""
	try:
		cache = frappe.cache()
		pattern = f"{CACHE_KEY_PREFIX}{company or '*'}:*"
		cache.delete_keys(pattern)
	except Exception:
		pass
