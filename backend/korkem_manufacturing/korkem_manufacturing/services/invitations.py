# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Invite the rest of a factory after its one owner has claimed the node.

The caller chooses a job, never Frappe roles.  The mapping below is server-owned
and uses stock ERPNext roles; accepting an arbitrary role list here would make
this endpoint a privilege editor and violate R5 by construction.
"""

from __future__ import annotations

import frappe

from korkem_ai.korkem_ai import onboarding
from korkem_manufacturing.services.scope import current_company

#: Роли цеха, одинаковые для всех, кто стоит у станка. Раскройщик, кромщик,
#: оператор ЧПУ, маляр и сборщик видят и делают одно и то же: свои задания и
#: списание материала. Различает их не право, а участок — операция и рабочее
#: место, по которым им приходит работа.
_STANDS_AT_A_MACHINE = onboarding.DEFAULT_EMPLOYEE_ROLES

#: Должности завода. Ключ уходит на клиент и в аудит; кортеж — то, что реально
#: получает человек.
#:
#: **Должностей больше, чем наборов прав, и это не дублирование.** Владелец
#: назвал свой цех поимённо — раскройщик, кромщик, фрезеровщик, маляр,
#: сборщик, — и в мебельном производстве это разные люди у разных станков.
#: Права у них совпадают, потому что каждый из них делает ровно одно: закрывает
#: свою операцию. Свести их в одного «рабочего цеха» значило бы потерять то,
#: по чему распределяется работа и считается загрузка участка, — ради экономии
#: четырёх строк словаря.
#:
#: Порядок — по ходу заказа: продажа, замер, конструктор, цех, склад, монтаж,
#: деньги. Клиент показывает список так, как его отдаёт сервер.
POSITIONS = {
	"manager": ("Sales User", "Sales Manager"),
	"measurer": ("Sales User",),
	"designer": ("Manufacturing User", "Item Manager"),
	"shop_manager": ("Manufacturing Manager", "Manufacturing User", "Stock User"),
	"cutter": _STANDS_AT_A_MACHINE,
	"edge_banding": _STANDS_AT_A_MACHINE,
	"cnc": _STANDS_AT_A_MACHINE,
	"painter": _STANDS_AT_A_MACHINE,
	"assembler": _STANDS_AT_A_MACHINE,
	"warehouse": ("Stock User",),
	"installer": ("Manufacturing User", "Stock User"),
	"accountant": ("Accounts User",),
	# Сохранён намеренно: им приглашали до 4 сентября 2026, и он стоит на живых
	# учётных записях. Убрать ключ — значит сломать их должность задним числом.
	"shop_floor": _STANDS_AT_A_MACHINE,
}


def prevent_self_role_change(doc, method=None) -> None:
	"""R5 at the generic Frappe boundary, not only at our invitation API.

	Frappe lets a system user save parts of their own ``User`` document. That is
	useful for profile data, but on this version the same save can carry a changed
	roles child table. Compare against the stored document and refuse any self
	change to authorization; an owner editing somebody else's account is not a
	self-escalation and remains governed by Frappe's ordinary permissions.
	"""
	del method
	if doc.name != frappe.session.user or doc.name == "Administrator" or doc.is_new():
		return
	before = doc.get_doc_before_save()
	if not before:
		return
	old_roles = {row.role for row in before.get("roles") or []}
	new_roles = {row.role for row in doc.get("roles") or []}
	if new_roles != old_roles:
		frappe.throw(
			"You cannot change your own roles. Ask the factory owner.",
			frappe.PermissionError,
		)


def invite_employee(*, email: str, first_name: str = "", position: str) -> dict:
	"""Create one company-bound employee with the roles for ``position``.

	Only the owner may cross this boundary.  ``create_employee`` repeats the
	System Manager check as defence in depth, but it is not a substitute for a
	domain service deciding who may invite before it parses a job or an email.
	"""
	frappe.only_for("System Manager")

	position = (position or "").strip().lower()
	roles = POSITIONS.get(position)
	if not roles:
		frappe.throw(
			"Unknown position. Choose manager, warehouse, accountant or shop_floor."
		)

	company = current_company()
	result = onboarding.create_employee(
		email=email,
		first_name=first_name,
		roles=list(roles),
		company=company,
	)
	_audit(company, result["user"], position)
	return {**result, "position": position}


def _audit(company: str, invited: str, position: str) -> None:
	"""R9: who invited whom, to which company and job."""
	savepoint = "korkem_invitation_audit_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "Company",
				"reference_name": company,
				"content": (
					f"KORKEM: {frappe.session.user} пригласил {invited}; "
					f"должность {position}."
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
			title="Could not record an employee invitation",
			message=frappe.get_traceback(with_context=True),
		)
