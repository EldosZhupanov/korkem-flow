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
from korkem_manufacturing.services.scope import current_company, ensure_company

#: Who may put material into work-in-progress. Checked in addition to — never
#: instead of — the doctype permissions the service itself relies on: a role
#: names *responsibility*, a doctype permission names *capability*, and the
#: shop floor needs both to be true (ADR-0013, defence in depth).
MAY_START = ("Manufacturing Manager", "Manufacturing User", "System Manager")


@frappe.whitelist()
def start_production(sales_order: str, item_code: str | None = None) -> dict:
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

	result = service.start_production(sales_order, item_code)
	_audit(sales_order, item_code, result)
	return result


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
