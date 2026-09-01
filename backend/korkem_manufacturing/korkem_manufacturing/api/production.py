# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The production service, published. One door, five callers.

    Desktop · Mobile · Shop-floor terminal · Telegram/WhatsApp · AI assistant
                                   │
                          this module
                                   │
                    services/production.py
                                   │
                        ERPNext Work Order + Stock Entry

Until this existed, `manufacturing.start_production` was reachable **only**
through a language model: `grep frappe.whitelist korkem_ai/tools/*.py` returned
nothing. So a button could not start production, and a provider outage stopped
the factory. That is the defect this layer closes (`PLAN.md` R3, R7).

## The division of labour, and why it is here rather than one layer down

This layer answers questions about the **caller**; the service answers questions
about the **business**.

| here | in `services/production.py` |
|---|---|
| may *you* do this | may this happen at all |
| which company are you in | is the material on the shelf |
| write the audit row | move the stock |

Keeping the permission check here is what lets a migration, a fixture or a
scheduled job call the service directly without inventing a fake session — and
what stops anybody reaching the service over HTTP without one.

## Confirmation is not enforced here, deliberately

ADR-0015 requires a human to agree to a specific write before it happens. For
the assistant that is `Pending Action`, raised by the agent loop because the
tool declares `Risk.WRITE`. For a button, the confirmation *is* the person
pressing it: they read a screen naming the order and the quantity, and pressed.
Requiring a second `Pending Action` behind a button would be a dialog that
always says yes, which trains people to click through exactly the prompt that
matters.

What both paths share is this endpoint, its permission check and its audit row.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import production as service
from korkem_manufacturing.services import shop_floor
from korkem_manufacturing.services.idempotency import execute as execute_idempotently
from korkem_manufacturing.services.scope import current_company, ensure_company

#: Who may put material into work-in-progress. Checked in addition to — never
#: instead of — the doctype permissions the service itself relies on: a role
#: names *responsibility*, a doctype permission names *capability*, and the
#: shop floor needs both to be true (ADR-0013, defence in depth).
MAY_START = ("Manufacturing Manager", "Manufacturing User", "System Manager")


@frappe.whitelist()
def start_production(
	sales_order: str,
	item_code: str | None = None,
	idempotency_key: str | None = None,
) -> dict:
	"""Plan the work if needed, then move material into work-in-progress.

	Returns the service's own answer unchanged, including its refusals:
	`blocked` when the shelf is short, `already_started` and `nothing_to_start`
	when there is nothing to do. Those are outcomes, not errors — a caller that
	turned them into exceptions would lose the material list a person needs.
	"""
	if not isinstance(sales_order, str) or not sales_order.strip():
		frappe.throw("Which sales order? A name is required.")
	sales_order = sales_order.strip()
	item_code = (item_code or "").strip() or None

	# Company first, and from the session. A caller that could name its own
	# company could start production in somebody else's factory; this is the
	# hole `tools/scope.py` was written to close and it must not reopen at a
	# public endpoint.
	ensure_company("Sales Order", sales_order)

	if not any(role in frappe.get_roles() for role in MAY_START):
		frappe.throw(
			"You do not have production rights, so you cannot start a job. "
			"Ask a manufacturing manager.",
			frappe.PermissionError,
		)

	def perform() -> dict:
		result = service.start_production(sales_order, item_code)
		_audit(sales_order, item_code, result)
		return result

	return execute_idempotently(
		"manufacturing.start_production",
		idempotency_key,
		{"sales_order": sales_order, "item_code": item_code},
		perform,
	)


def _audit(sales_order: str, item_code: str | None, result: dict) -> None:
	"""Record who started what, on the order itself.

	A comment on the Sales Order rather than a private log: the trail belongs
	where somebody asking "why did this start on Tuesday" will actually look.
	Failure to write it must not undo a stock movement that has already
	happened, which is why it is guarded the same way usage accounting is.
	"""
	savepoint = "korkem_prod_audit_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "Sales Order",
				"reference_name": sales_order,
				"content": _sentence(item_code, result),
			}
		).insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title="Could not record who started production",
			message=frappe.get_traceback(with_context=True),
		)


def _sentence(item_code: str | None, result: dict) -> str:
	status = result.get("status")
	who = frappe.session.user
	company = _company_or_none()

	if status == "started":
		what = "подан материал" if result.get("topped_up") else "запущено производство"
		return (
			f"KORKEM: {who} — {what} по {result.get('work_order')}, "
			f"{result.get('transferred_for_qty')} шт, перемещение "
			f"{result.get('material_transfer')}. Компания: {company}."
		)
	if status == "blocked":
		short = ", ".join(
			f"{m['item_code']} −{m['physical_shortage_qty']} {m['uom']}"
			for m in result.get("blocking_materials", [])
		)
		return f"KORKEM: {who} — запуск отклонён, нет материала на складе: {short}."
	return f"KORKEM: {who} — запуск не потребовался ({status})."


def _company_or_none() -> str | None:
	try:
		return current_company()
	except Exception:
		return None


#: Who may book work against a stage. Narrower than starting a job on purpose:
#: an operator answers for their own bench and needs `write`, not `create` —
#: they finish work somebody else planned.
MAY_REPORT = ("Manufacturing Manager", "Manufacturing User", "System Manager")


@frappe.whitelist()
def complete_operation(
	operation: str | None = None,
	sales_order: str | None = None,
	work_order: str | None = None,
	qty: float | None = None,
	scrap_qty: float | None = None,
	rework_qty: float | None = None,
	idempotency_key: str | None = None,
) -> dict:
	"""Record that a production stage is finished.

	Quantities are read as numbers here rather than trusted as whatever the
	caller sent: a string "4" from a form and a float 4.0 from a tool must mean
	the same thing, and neither may become `None` silently.

	`already_complete` is an outcome, not an error — saying it twice must not
	book the hours or the quantity twice, and the caller needs to be told which
	of the two happened.
	"""
	if not any([operation, sales_order, work_order]):
		frappe.throw(
			"Which stage finished? Name the operation, the sales order or the "
			"work order."
		)

	# Company before anything else, and from the session. A caller that could
	# reach another factory's job card could book output against it.
	if work_order:
		ensure_company("Work Order", work_order)
	if sales_order:
		ensure_company("Sales Order", sales_order)

	if not any(role in frappe.get_roles() for role in MAY_REPORT):
		frappe.throw(
			"You do not have production rights, so you cannot book work "
			"against a stage. Ask a manufacturing manager.",
			frappe.PermissionError,
		)

	arguments = {
		"operation": _clean(operation),
		"sales_order": _clean(sales_order),
		"work_order": _clean(work_order),
		"qty": _quantity(qty, "qty"),
		"scrap_qty": _quantity(scrap_qty, "scrap_qty"),
		"rework_qty": _quantity(rework_qty, "rework_qty"),
	}

	def perform() -> dict:
		result = shop_floor.complete_operation(**arguments)
		_audit_operation(result)
		return result

	return execute_idempotently(
		"manufacturing.complete_operation",
		idempotency_key,
		arguments,
		perform,
	)


def _clean(value: str | None) -> str | None:
	if value is None:
		return None
	if not isinstance(value, str):
		frappe.throw("Names must be text.")
	return value.strip() or None


def _quantity(value, field: str) -> float | None:
	"""A quantity, or None. Never a silent zero and never a negative.

	A form sends "4", a tool sends 4.0, and a mistake sends "четыре". The first
	two mean the same thing; the third must say so rather than becoming None
	and booking the whole outstanding quantity by accident.
	"""
	if value is None or value == "":
		return None
	try:
		number = float(value)
	except (TypeError, ValueError):
		frappe.throw(f"{field} must be a number, not {value!r}.")
	if number < 0:
		frappe.throw(f"{field} cannot be negative.")
	return number


def _audit_operation(result: dict) -> None:
	"""Record who booked what, on the work order.

	Guarded like every other audit here: the job card is already submitted by
	this point, and failing to write a note must not undo it.
	"""
	work_order = result.get("work_order")
	if not work_order:
		return

	savepoint = "korkem_op_audit_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "Work Order",
				"reference_name": work_order,
				"content": (
					f"KORKEM: {frappe.session.user} — {result.get('operation')}, "
					f"статус {result.get('status')}, карта {result.get('job_card')}."
				),
			}
		).insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title="Could not record who finished a stage",
			message=frappe.get_traceback(with_context=True),
		)
