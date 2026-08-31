# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""`/health` and `/health/ready` — is this deployment alive, and is it working.

## Two questions, deliberately not one

**`/health`** answers *is this process serving requests*. It touches nothing but
the request itself, and an orchestrator that restarts on its failure is
restarting for a reason that restarting can fix.

**`/health/ready`** answers *is every part this site depends on actually there*
— database, both Redis instances, background workers, the scheduler, ERPNext.
A site whose queue workers are dead answers `/health` perfectly and cannot send
a single notification, which is precisely the failure Phase 31 built the
delivery centre to make visible. This is the same question asked from outside.

## What an anonymous caller is told, and what they are not

A readiness endpoint has to be reachable without a session — the thing checking
it is a load balancer, a Docker healthcheck or an uptime monitor, none of which
can log in. So the public answer is deliberately **shaped like a traffic light**:
each component is `ok`, `down` or `unknown`, and nothing else.

Versions, queue depths, the environment name and the *reason* a component is
down are detail, and detail is for a **System Manager**. Not because a version
string is a credential, but because "which ERPNext, how far behind, how deep is
the queue" is exactly the reconnaissance an attacker does first, and there is no
operational reason for a stranger to have it. An operator who needs the detail
has an account.

Nothing on either path returns a password, a token, a database credential, a
host, a path or a stack trace. Failures are caught and reduced to their
exception *class* — `OperationalError`, not the message, which on a database
error can carry the connection string.

## How the pretty paths exist

`page_renderer` in `hooks.py` — Frappe's own hook for a route that is not a web
page. That is why `/health` works on a bare bench with no proxy in front of it,
which matters: the Docker healthcheck calls it before any proxy exists, and the
pre-domain checklist is verified on a bench that has no domain.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai import environment

OK = "ok"
DOWN = "down"
UNKNOWN = "unknown"

#: Apps whose presence is part of "this is a KORKEM site". Reported by name so
#: a deployment that is missing one says so instead of failing later, obscurely.
EXPECTED_APPS = ("frappe", "erpnext", "korkem_manufacturing", "korkem_ai")


def _reason(exc: Exception) -> str:
	"""The class of the failure, never its message.

	A `pymysql.err.OperationalError` stringifies to something that has included
	a host, a port and a user name; a Redis error to a URL. The class alone is
	enough to tell an operator which of these five checks to go and look at.
	"""
	return type(exc).__name__


def _database() -> dict:
	try:
		frappe.db.sql("select 1")
		return {"status": OK}
	except Exception as exc:
		return {"status": DOWN, "reason": _reason(exc)}


def _redis_cache() -> dict:
	try:
		frappe.cache.ping()
		return {"status": OK}
	except Exception as exc:
		return {"status": DOWN, "reason": _reason(exc)}


def _redis_queue() -> dict:
	from frappe.utils.background_jobs import get_redis_conn

	try:
		get_redis_conn().ping()
		return {"status": OK}
	except Exception as exc:
		return {"status": DOWN, "reason": _reason(exc)}


def _workers() -> dict:
	"""Are there RQ workers attached to this bench's queue.

	Zero workers is `down` and not a warning. Every outbound message, every
	retry and every scheduled job runs on one; with none, the system looks
	healthy from the outside and quietly stops doing anything.
	"""
	from frappe.utils.background_jobs import get_workers

	try:
		workers = get_workers()
	except Exception as exc:
		return {"status": DOWN, "reason": _reason(exc)}

	return {"status": OK if workers else DOWN, "count": len(workers)}


def _scheduler() -> dict:
	"""Is the scheduler going to run the hourly and five-minute jobs.

	`Notification Delivery.retry_due` is on a cron entry, so a paused scheduler
	means every retryable failure stays failed for ever.
	"""
	from frappe.utils.scheduler import is_scheduler_inactive

	try:
		inactive = is_scheduler_inactive(verbose=False)
	except Exception as exc:
		return {"status": UNKNOWN, "reason": _reason(exc)}

	return {"status": DOWN if inactive else OK}


def _erpnext() -> dict:
	"""Is ERPNext installed *and set up* — not merely importable.

	A company is the cheapest proof that its schema exists and has been through
	setup: every tool in the registry resolves one before it does anything.
	"""
	try:
		if "erpnext" not in frappe.get_installed_apps():
			return {"status": DOWN, "reason": "not_installed"}
		if not frappe.db.count("Company"):
			return {"status": DOWN, "reason": "no_company"}
		return {"status": OK}
	except Exception as exc:
		return {"status": DOWN, "reason": _reason(exc)}


#: The checks, in the order a reader wants them: what everything else stands on
#: first, what is easiest to lose last.
CHECKS = (
	("database", _database),
	("redis_cache", _redis_cache),
	("redis_queue", _redis_queue),
	("workers", _workers),
	("scheduler", _scheduler),
	("erpnext", _erpnext),
)


def _versions() -> dict:
	versions = {}
	for app in EXPECTED_APPS:
		try:
			versions[app] = frappe.get_attr(f"{app}.__version__")
		except Exception:
			versions[app] = None
	return versions


def _queue_depth() -> dict:
	from frappe.utils.background_jobs import get_queue

	depths = {}
	for name in ("short", "default", "long"):
		try:
			depths[name] = get_queue(name).count
		except Exception:
			depths[name] = None
	return depths


def _may_see_detail() -> bool:
	return frappe.session.user != "Guest" and "System Manager" in frappe.get_roles()


def live() -> dict:
	"""Liveness. Deliberately answers without asking anything else a question."""
	return {"status": OK, "service": "korkem"}


def ready(detail: bool | None = None) -> dict:
	"""Readiness. `detail` is honoured only for a System Manager.

	Returns `status: ok` when every component is, and `degraded` otherwise — not
	`down`, because the process answering at all is itself information and the
	caller can read which component failed.
	"""
	components = {name: check() for name, check in CHECKS}
	healthy = all(component["status"] == OK for component in components.values())

	privileged = _may_see_detail()
	if not privileged:
		# A traffic light and nothing else: no reason, no counts.
		components = {name: {"status": value["status"]} for name, value in components.items()}

	body: dict = {
		"status": OK if healthy else "degraded",
		"service": "korkem",
		"components": components,
	}

	if privileged and detail is not False:
		body["environment"] = environment.describe()
		body["versions"] = _versions()
		body["queues"] = _queue_depth()
		body["site"] = frappe.local.site

	return body


class HealthPage:
	"""Serves `/health` and `/health/ready` as JSON, for callers with no session.

	Registered through Frappe's `page_renderer` hook, which is consulted before
	every other renderer — so these two paths never reach the website router,
	are never redirected to a login page, and never render a 404 template.

	A readiness failure answers **503**. An orchestrator reads the status code,
	not the body, and a degraded site that answers 200 will be sent traffic.
	"""

	#: Path (without slashes, as Frappe normalises it) → what to call.
	ROUTES = {
		"health": live,
		"health/ready": ready,
	}

	def __init__(self, path=None, http_status_code=None):
		self.path = (path if path is not None else frappe.local.request.path).strip("/ ")
		self.http_status_code = http_status_code

	def can_render(self) -> bool:
		return self.path in self.ROUTES

	def render(self):
		import json

		from werkzeug.wrappers import Response

		body = self.ROUTES[self.path]()
		status = 503 if body.get("status") not in (OK,) else 200
		response = Response(
			json.dumps(body),
			status=status,
			mimetype="application/json",
		)
		# A health answer that a proxy or a browser may serve from cache is
		# worse than no health answer: it reports a state that has passed.
		response.headers["Cache-Control"] = "no-store"
		return response
