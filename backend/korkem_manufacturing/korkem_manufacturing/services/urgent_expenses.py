# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Urgent expenses: a quick, honest record of money spent outside a purchase.

A driver buys fuel, a cutter runs out of saw blades at 19:00, someone pays for
a part to get the edge bander running. It happens; what matters is that it is
written down when it happens, with a receipt, and that a person with the right
to say yes says yes.

- **Anyone on staff** may file one, for themselves. A photo of the receipt is
  optional and private (`photo_files` — EXIF stripped, JPEG/PNG only).
- **The administrator or accounting** (`DECIDERS`) approves or rejects, with a
  note on rejection. Nobody decides their own.
- **Who sees what:** a person sees their own; deciders see the company's. An
  expense is the filer's own money matter, so the price switch does not hide it
  from them.

Nothing here posts to the ledger: approval says the factory accepts the
expense; how it is reimbursed stays accounting's call in ERPNext.
"""

from __future__ import annotations

from decimal import Decimal, InvalidOperation

import frappe
from frappe.utils import flt, now_datetime

from korkem_manufacturing.services import audit, photo_files
from korkem_manufacturing.services.identity import is_staff
from korkem_manufacturing.services.scope import current_company, ensure_company


DOCTYPE = "Urgent Expense"
DECIDERS = frozenset({"System Manager", "Accounts Manager"})
PENDING, APPROVED, REJECTED = "Ждёт решения", "Одобрено", "Отклонено"
CATEGORIES = ("Материалы", "Инструмент", "Транспорт", "Ремонт", "Другое")
#: A sanity bound, not a policy: an «urgent» expense above this is a purchase.
MAX_AMOUNT = Decimal("5000000")
MAX_PHOTOS = 3


def _is_decider() -> bool:
	return bool(DECIDERS.intersection(frappe.get_roles()))


def _ensure_staff() -> None:
	if not is_staff():
		frappe.throw("Расходы записывают сотрудники.", frappe.PermissionError)


def file(amount, purpose: str, category: str = "Другое", sales_order: str | None = None) -> dict:
	_ensure_staff()
	company = current_company()
	try:
		value = Decimal(str(amount))
	except (InvalidOperation, ValueError):
		frappe.throw("Сумма должна быть числом.")
	if not value.is_finite() or value <= 0:
		frappe.throw("Сумма должна быть больше нуля.")
	if value > MAX_AMOUNT:
		frappe.throw("Такая сумма — это закупка, а не срочный расход. Оформите заказ поставщику.")
	purpose = (purpose or "").strip()
	if len(purpose) < 3:
		frappe.throw("Напишите, на что потрачено.")
	if category not in CATEGORIES:
		frappe.throw(f"Категория — одна из: {', '.join(CATEGORIES)}.")
	if sales_order:
		ensure_company("Sales Order", sales_order)

	doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"company": company,
			"requested_by": frappe.session.user,
			"amount": float(value),
			"purpose": purpose[:140],
			"category": category,
			"sales_order": sales_order or None,
			"status": PENDING,
		}
	)
	doc.insert(ignore_permissions=True)
	audit.record_audit(
		action="expense.filed", entity_type=DOCTYPE, entity_id=doc.name,
		diff={"amount": float(value), "purpose": doc.purpose, "category": category},
	)
	return _row(doc)


def attach_receipt(expense: str, filename: str, content: bytes) -> dict:
	doc = _visible(expense)
	if doc.requested_by != frappe.session.user:
		frappe.throw("Чек прикладывает тот, кто потратил.", frappe.PermissionError)
	if doc.status != PENDING:
		frappe.throw("Решение уже принято — чек больше не меняется.")
	if frappe.db.count("File", {"attached_to_doctype": DOCTYPE, "attached_to_name": doc.name}) >= MAX_PHOTOS:
		frappe.throw(f"К расходу уже приложено {MAX_PHOTOS} фото.")
	file_name, cleaned = photo_files.cleaned(filename, content, fallback_name="чек")
	stored = frappe.get_doc(
		{
			"doctype": "File",
			"file_name": file_name,
			"attached_to_doctype": DOCTYPE,
			"attached_to_name": doc.name,
			"is_private": 1,
			"content": cleaned,
		}
	)
	stored.insert(ignore_permissions=True)
	audit.record_audit(action="expense.receipt", entity_type=DOCTYPE, entity_id=doc.name, diff={"file": stored.name})
	return {"expense": doc.name, "file": stored.name, "status": "attached"}


def decide(expense: str, approve: bool | int | str, note: str | None = None) -> dict:
	if not _is_decider():
		frappe.throw("Решение по расходам принимает администратор или бухгалтерия.", frappe.PermissionError)
	approve = bool(int(approve)) if isinstance(approve, str) else bool(approve)
	doc = _visible(expense)
	if doc.requested_by == frappe.session.user:
		frappe.throw("Свой расход одобряет другой человек.", frappe.PermissionError)
	if doc.status != PENDING:
		frappe.throw(f"По этому расходу уже решено: {doc.status}.")
	note = (note or "").strip()
	if not approve and not note:
		frappe.throw("Напишите причину отказа — сотрудник её увидит.")
	doc.status = APPROVED if approve else REJECTED
	doc.decided_by = frappe.session.user
	doc.decided_at = now_datetime()
	doc.decision_note = note or None
	doc.save(ignore_permissions=True)
	audit.record_audit(
		action="expense.approved" if approve else "expense.rejected",
		entity_type=DOCTYPE, entity_id=doc.name, diff={"amount": flt(doc.amount), "note": note},
	)
	return _row(doc)


def listing(status: str | None = None, mine_only: bool | int | str = False, limit: int = 100) -> dict:
	"""Own expenses for everybody; the company's for deciders (unless mine_only)."""
	_ensure_staff()
	mine_only = bool(int(mine_only)) if isinstance(mine_only, str) else bool(mine_only)
	filters: dict = {"company": current_company()}
	if not _is_decider() or mine_only:
		filters["requested_by"] = frappe.session.user
	if status:
		if status not in (PENDING, APPROVED, REJECTED):
			frappe.throw("Неизвестный статус.")
		filters["status"] = status
	rows = frappe.get_all(
		DOCTYPE,
		filters=filters,
		fields=["name", "requested_by", "amount", "purpose", "category", "sales_order", "status",
				"decided_by", "decided_at", "decision_note", "creation"],
		order_by="creation desc",
		limit_page_length=max(1, min(int(limit or 100), 500)),
	)
	names = {
		u.name: u.full_name or u.name
		for u in frappe.get_all("User", filters={"name": ["in", list({r.requested_by for r in rows})]}, fields=["name", "full_name"])
	} if rows else {}
	pending_total = sum(flt(r.amount) for r in rows if r.status == PENDING)
	return {
		"expenses": [_row(r, names.get(r.requested_by)) for r in rows],
		"pending_total": round(pending_total, 2),
		"can_decide": _is_decider(),
	}


def _visible(expense: str):
	row = frappe.db.get_value(DOCTYPE, expense, ["name", "company", "requested_by"], as_dict=True)
	# Another company's, or somebody else's for a non-decider: «not found».
	if (
		not row
		or row.company != current_company()
		or (row.requested_by != frappe.session.user and not _is_decider())
	):
		frappe.throw("Расход не найден.", frappe.DoesNotExistError)
	return frappe.get_doc(DOCTYPE, expense)


def _row(r, full_name: str | None = None) -> dict:
	return {
		"expense": r.name,
		"requested_by": r.requested_by,
		"requested_by_name": full_name or r.requested_by,
		"amount": flt(r.amount),
		"purpose": r.purpose,
		"category": r.category,
		"sales_order": r.sales_order,
		"status": r.status,
		"decided_by": r.decided_by,
		"decision_note": r.decision_note,
		"at": str(r.creation),
	}
