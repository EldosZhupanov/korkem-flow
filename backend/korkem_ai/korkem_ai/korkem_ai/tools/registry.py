# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The tool registry — everything a language model is allowed to do.

## The rule this module exists to enforce

A model may call **only** what is registered here, by name, with arguments that
validate against a declared schema. There is no generic `http_request` tool, no
`run_query`, no `execute`. That is not a limitation to be worked around later:
it is the only reason permissions, confirmation and audit are possible at all.
A model that can issue arbitrary requests has, by definition, whatever access
the process has, and nothing downstream can narrow it again.

## Permissions are Frappe's, not ours

Every read goes through `frappe.get_list`, which applies permission query
conditions — so a Sales User who cannot see a deal in the CRM cannot see it
through the assistant either. This is why tools run in-process under the
caller's own session rather than a service account: it makes

    AI permission <= ERP permission

true by construction instead of by our diligence. `frappe.db.get_all` would
bypass exactly this and must never appear in a tool.

## Risk is declared, not inferred

Each tool states what kind of thing it is. Read tools may run unattended; write
and destructive tools require a human to confirm the specific call before it
executes (ADR-0015). Nothing here decides that at the call site — the spec does,
so a reviewer can read the catalogue and see the whole blast radius in one
place.
"""

from __future__ import annotations

import enum
import hashlib
import time
from collections.abc import Callable
from dataclasses import dataclass, field

import frappe

from korkem_ai.korkem_ai.orchestrator.protocol import AITool
from korkem_ai.korkem_ai.tools import schema as schema_validator


class Risk(enum.Enum):
	"""What a tool can do to the business.

	The boundary that matters is READ vs everything else: reads may run while
	the user watches, and anything that changes state waits for a person.
	"""

	READ = "read"
	WRITE = "write"
	DESTRUCTIVE = "destructive"

	@property
	def requires_confirmation(self) -> bool:
		return self is not Risk.READ

	@property
	def permission_type(self) -> str:
		"""The Frappe permission a tool of this risk actually needs.

		Every tool used to be checked against `"read"`, which was invisible
		while the catalogue was read-only and became a hole the moment a write
		tool existed: anyone who could *see* a lead could have had the assistant
		create one. The permission asked for now follows the declared risk, so a
		new write tool inherits the right check by declaring what it is.
		"""
		return {
			Risk.READ: "read",
			Risk.WRITE: "create",
			Risk.DESTRUCTIVE: "delete",
		}[self]


class ToolError(frappe.ValidationError):
	"""A tool could not run. The message is safe to show a user."""


@dataclass(frozen=True)
class ToolSpec:
	name: str
	description: str
	input_schema: dict
	risk: Risk
	handler: Callable[..., object]

	#: Doctypes this tool reads or writes. Used to hide a tool from a user who
	#: has no access to them at all — offering a model a tool that will only
	#: ever return "permission denied" wastes a turn and invites it to retry.
	doctypes: tuple[str, ...] = field(default_factory=tuple)

	#: Seconds this tool may take before it is abandoned. A tool that hangs
	#: would otherwise hold a queue worker for as long as the whole turn is
	#: allowed, and a model waiting on it cannot tell slow from stuck.
	timeout: int = 30

	#: The Frappe permission this tool actually needs, when the declared risk
	#: implies the wrong one. A write that *updates* an existing row needs
	#: `write`, not `create`: an employee answering the job they were given
	#: holds one and must not hold the other. Left unset, the risk decides.
	permission: str | None = None

	#: Builds the sentence a person is asked to agree to, from the same
	#: arguments the call carries. Optional, and read-only by contract: it runs
	#: before anything has been approved. A tool without one is confirmed
	#: against the model's own prose, which is fine for "остановить производство"
	#: and not fine for an order with a price on it.
	summarise: Callable[..., str] | None = None

	#: What this tool belongs to in an audit — "crm", "production". Coarser
	#: than the tool name on purpose: an auditor asks "what did the assistant
	#: change in the CRM last week", not "how often was create_lead called".
	audit_category: str = "general"

	@property
	def requires_confirmation(self) -> bool:
		return self.risk.requires_confirmation

	def as_ai_tool(self) -> AITool:
		return AITool(
			name=self.name, description=self.description, input_schema=self.input_schema
		)


_REGISTRY: dict[str, ToolSpec] = {}


def register(spec: ToolSpec) -> ToolSpec:
	if spec.name in _REGISTRY:
		raise ValueError(f"Tool {spec.name} is already registered")
	_REGISTRY[spec.name] = spec
	return spec


def all_specs() -> list[ToolSpec]:
	return sorted(_REGISTRY.values(), key=lambda spec: spec.name)


def find(name: str) -> ToolSpec | None:
	"""The spec, or None. For callers that need to ask about a tool without
	asserting it exists — deciding whether a call needs confirmation, say."""
	return _REGISTRY.get(name)


def get(name: str) -> ToolSpec:
	spec = _REGISTRY.get(name)
	if spec is None:
		# Named explicitly: a model that hallucinated a tool should be told
		# which ones exist, so its next attempt is a real one.
		known = ", ".join(sorted(_REGISTRY)) or "none"
		frappe.throw(f"Unknown tool '{name}'. Available tools: {known}", exc=ToolError)
	return spec


def _required_permission(spec: ToolSpec, role: str) -> str:
	"""The Frappe permission this caller needs on the tool's doctypes.

	Normally the tool's declared risk decides: a write needs `create`. The one
	exception is a customer placing their own order, and it is an exception on
	purpose rather than an oversight. The `Korkem Customer` role is read-only —
	if it could create a Sales Order it could also do so straight through the
	desk API, choosing its own price. So the order is written on their behalf
	(see `tools/orders`), and what they must hold is `read` on the doctype: the
	right to see what they are buying.
	"""
	from korkem_ai.korkem_ai.tools import policy

	if role == policy.CUSTOMER and policy.allows_customer_write(spec.name):
		return "read"
	return spec.permission or spec.risk.permission_type


def available_to(user: str | None = None) -> list[ToolSpec]:
	"""The tools this user could actually use.

	Filtered on doctype-level read permission only. Row-level visibility is
	Frappe's job and is applied when the tool runs — a user with read access to
	`CRM Deal` and no deals assigned gets an empty list, which is a true answer.
	"""
	from korkem_ai.korkem_ai.tools import policy

	user = user or frappe.session.user
	role = policy.role_of(user)

	def readable(spec: ToolSpec) -> bool:
		# The role gate first, and it is coarse on purpose: a tool this role may
		# not reach should not be described to the model at all. A tool name and
		# its description are a description of the business.
		if not policy.allows(role, spec.name):
			return False
		required = _required_permission(spec, role)
		return all(
			frappe.has_permission(doctype, required, user=user) for doctype in spec.doctypes
		)

	return [spec for spec in all_specs() if readable(spec)]


def offered_to(user: str | None = None) -> list[AITool]:
	"""What to put in front of the model this turn."""
	return [spec.as_ai_tool() for spec in available_to(user)]


def validate_arguments(spec: ToolSpec, arguments: dict) -> list[str]:
	return schema_validator.validate(arguments or {}, spec.input_schema)


def execute(
	name: str, arguments: dict | None = None, *, run_id: str | None = None
) -> dict:
	"""Run a registered tool after checking it is allowed to run.

	Returns a structured result. Failures come back as data rather than
	exceptions so a turn survives one bad call: the model is told what went
	wrong and can correct itself, which is the whole point of a tool loop.

	This function does **not** decide whether a confirmation was obtained.
	That belongs to the agent loop, which knows whether a human said yes;
	`spec.requires_confirmation` is what it asks.

	## `run_id` и почему без него заказ может создаться дважды

	До появления этого аргумента от повторного действия защищало одно: порядок
	в цикле агента. Инструмент выполнялся, результат ложился в историю, и
	следующая модель его не повторяла. Это верно ровно для одного случая —
	**когда результат вернулся.**

	Случай, который так не закрывается:

	    crm.create_order()  →  заказ создан в ERPNext
	                        →  процесс упал до записи результата
	                        →  ход перезапустили
	                        →  модель просит то же самое снова

	Истории нет, потому что её не успели записать; модель не знает, что заказ
	уже есть; заказов становится два. С деньгами и производством это дороже
	любой другой ошибки в системе.

	`run_id` — ход, в котором инструмент вызвали. Пишущие инструменты проходят
	через `idempotency.execute`, где запись о выполнении и сам побочный эффект
	коммитятся **одной транзакцией**: повтор с тем же ключом упирается в замок
	первичного ключа и получает сохранённый ответ, ничего не выполняя.

	Ключ строится из хода, имени инструмента и отпечатка аргументов, а не из
	идентификатора вызова у модели. При перезапуске хода модель выдаёт новые
	идентификаторы вызовов — ключ на них не пережил бы именно тот сбой, ради
	которого он нужен. А «тот же ход, тот же инструмент, те же аргументы» это
	одно и то же намерение, сколько бы раз его ни повторили.

	Читающие инструменты идут мимо: у них нет побочного эффекта, и запись о
	каждом `get_order` была бы мусором в таблице.
	"""
	arguments = arguments or {}
	started = time.monotonic()

	try:
		spec = get(name)
	except frappe.ValidationError as exc:
		return _failure(name, str(exc), code="unknown_tool")

	# The role gate runs *before* the arguments are looked at. Validating first
	# would answer "your arguments are wrong" to somebody who may not reach the
	# tool at all — which tells them it exists and what it wants.
	#
	# Checked here as well as in `available_to`, and not only for tidiness: a
	# model can name a tool it was never offered, and the list it was offered
	# was built for whoever the turn started as.
	from korkem_ai.korkem_ai.tools import policy

	role = policy.role_of()
	if not policy.allows(role, name):
		return _failure(name, policy.refusal(name), code="not_permitted")

	# Belt and braces. Every tool on the customer allowlist is a read today, and
	# a test pins that — but the allowlist is edited by hand, and a write
	# slipping onto it would let a customer raise a Pending Action against the
	# factory. Cheap to check, and the failure mode it prevents is not.
	if role == policy.CUSTOMER and spec.requires_confirmation:
		if not policy.allows_customer_write(name):
			return _failure(name, policy.refusal(name), code="not_permitted")

	problems = validate_arguments(spec, arguments)
	if problems:
		return _failure(name, "; ".join(problems), code="invalid_arguments")

	# The permission asked for follows the tool's declared risk. Checking
	# `read` for everything — which is what this did — would have let anyone
	# who could see a record have the assistant create one.
	required = _required_permission(spec, role)
	for doctype in spec.doctypes:
		if not frappe.has_permission(doctype, required):
			return _failure(
				name,
				f"You do not have permission to {required} {doctype}.",
				code="permission_denied",
			)

	try:
		data = _run_handler(spec, arguments, run_id)
	except frappe.PermissionError:
		return _failure(name, "You do not have permission to do that.", code="permission_denied")
	except frappe.ValidationError as exc:
		return _failure(name, str(exc), code="invalid_request")
	except Exception:
		# The traceback goes to the server log, never to the model: it can
		# quote table names, file paths and other people's data.
		frappe.log_error(title=f"AI tool failed: {name}", message=frappe.get_traceback())
		return _failure(name, "That could not be completed.", code="tool_error")

	elapsed_ms = int((time.monotonic() - started) * 1000)
	_log(name, "success", elapsed_ms)
	return {"ok": True, "tool": name, "data": data}


def _run_handler(spec: ToolSpec, arguments: dict, run_id: str | None):
	"""Выполнить обработчик — один раз за ход, если он что-то меняет.

	Читающие идут напрямую: побочного эффекта нет, повторить нечего, а запись о
	каждом чтении была бы мусором.
	"""
	if spec.risk is Risk.READ or not run_id:
		return spec.handler(**arguments)

	from korkem_manufacturing.services import idempotency

	key = _turn_key(run_id, spec.name, arguments)
	# `idempotency.execute` требует от действия словарь: он его сохраняет и
	# возвращает при повторе. Обработчик инструмента может вернуть что угодно,
	# поэтому ответ заворачивается и разворачивается здесь.
	stored = idempotency.execute(
		action=f"ai_tool:{spec.name}",
		idempotency_key=key,
		arguments=arguments,
		callback=lambda: {"value": spec.handler(**arguments)},
	)
	return stored.get("value")


def _turn_key(run_id: str, tool: str, arguments: dict) -> str:
	"""Ход + инструмент + аргументы.

	Отпечаток аргументов входит в ключ, потому что один инструмент законно
	вызывают дважды за ход с разными аргументами — два задания, два замера. Без
	отпечатка второй вызов вернул бы результат первого, и это была бы уже не
	защита, а потеря работы.
	"""
	fingerprint = hashlib.sha256(
		frappe.as_json(arguments, indent=None, separators=(",", ":")).encode()
	).hexdigest()[:16]
	return f"turn:{run_id}:{tool}:{fingerprint}"


def _failure(name: str, message: str, code: str) -> dict:
	_log(name, code, None)
	return {"ok": False, "tool": name, "error": {"code": code, "message": message}}


def _log(name: str, status: str, elapsed_ms: int | None):
	"""Observability that is safe in production.

	Tool name, outcome and duration — never arguments or results, which carry
	customer data, and never a credential, which this layer never sees anyway.
	"""
	frappe.logger("korkem_ai.tools").info(
		{
			"tool": name,
			"status": status,
			"duration_ms": elapsed_ms,
			"user": frappe.session.user,
		}
	)
