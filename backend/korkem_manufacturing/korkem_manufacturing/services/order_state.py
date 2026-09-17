# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Canonical Order State Machine for KORKEM Flow v2.

Управляет переходами жизненного цикла мебельного заказа:
Lead -> Measurement -> Design -> Quote -> Contract -> Deposit ->
Production -> Delivery -> Installation -> Acceptance -> Warranty.

Гарантирует:
1. Строгую валидацию допустимости перехода (FSM Graph);
2. Проверку необходимых предусловий (Preconditions: предоплата, замер, чертеж);
3. Проверку ролевых прав (RBAC);
4. Запись в журнал состояний (Order State Log) и аудит (AuditEvent);
5. Запись события в Transactional Outbox.
"""

from __future__ import annotations

import json
from typing import Any

import frappe
from frappe.utils import flt, now_datetime

from korkem_manufacturing.services import audit, outbox
from korkem_manufacturing.services.scope import current_company, scoped

# ----------------------------------------------------------------------
# 1. Канонические статусы заказа
# ----------------------------------------------------------------------
DRAFT = "Draft"
LEAD = "Lead"
MEASUREMENT_PENDING = "Measurement Pending"
MEASURED = "Measured"
DESIGN_PENDING = "Design Pending"
DESIGN_APPROVED = "Design Approved"
QUOTE_PENDING = "Quote Pending"
QUOTE_SENT = "Quote Sent"
CONTRACT_PENDING = "Contract Pending"
DEPOSIT_PENDING = "Deposit Pending"
READY_FOR_PRODUCTION = "Ready for Production"
IN_PRODUCTION = "In Production"
QUALITY_CONTROL = "Quality Control"
READY_FOR_DELIVERY = "Ready for Delivery"
DELIVERY = "Delivery"
INSTALLATION = "Installation"
ACCEPTANCE_PENDING = "Acceptance Pending"
COMPLETED = "Completed"
WARRANTY = "Warranty"
CANCELLED = "Cancelled"

ALL_STATES = {
	DRAFT,
	LEAD,
	MEASUREMENT_PENDING,
	MEASURED,
	DESIGN_PENDING,
	DESIGN_APPROVED,
	QUOTE_PENDING,
	QUOTE_SENT,
	CONTRACT_PENDING,
	DEPOSIT_PENDING,
	READY_FOR_PRODUCTION,
	IN_PRODUCTION,
	QUALITY_CONTROL,
	READY_FOR_DELIVERY,
	DELIVERY,
	INSTALLATION,
	ACCEPTANCE_PENDING,
	COMPLETED,
	WARRANTY,
	CANCELLED,
}

# ----------------------------------------------------------------------
# 2. Граф допустимых переходов
# ----------------------------------------------------------------------
ALLOWED_TRANSITIONS: dict[str, set[str]] = {
	DRAFT: {LEAD, CANCELLED},
	LEAD: {MEASUREMENT_PENDING, QUOTE_PENDING, CANCELLED},
	MEASUREMENT_PENDING: {MEASURED, CANCELLED},
	MEASURED: {DESIGN_PENDING, QUOTE_PENDING, CANCELLED},
	DESIGN_PENDING: {DESIGN_APPROVED, CANCELLED},
	DESIGN_APPROVED: {QUOTE_PENDING, CANCELLED},
	QUOTE_PENDING: {QUOTE_SENT, CANCELLED},
	QUOTE_SENT: {CONTRACT_PENDING, DEPOSIT_PENDING, CANCELLED},
	CONTRACT_PENDING: {DEPOSIT_PENDING, READY_FOR_PRODUCTION, CANCELLED},
	DEPOSIT_PENDING: {READY_FOR_PRODUCTION, CANCELLED},
	READY_FOR_PRODUCTION: {IN_PRODUCTION, CANCELLED},
	IN_PRODUCTION: {QUALITY_CONTROL, READY_FOR_DELIVERY, CANCELLED},
	QUALITY_CONTROL: {READY_FOR_DELIVERY, IN_PRODUCTION, CANCELLED},
	READY_FOR_DELIVERY: {DELIVERY, CANCELLED},
	DELIVERY: {INSTALLATION, ACCEPTANCE_PENDING},
	INSTALLATION: {ACCEPTANCE_PENDING},
	ACCEPTANCE_PENDING: {COMPLETED},
	COMPLETED: {WARRANTY},
	WARRANTY: {COMPLETED},
	CANCELLED: set(),  # Терминальное состояние
}

# ----------------------------------------------------------------------
# 3. Ролевые права на переходы
# ----------------------------------------------------------------------
REQUIRED_ROLES: dict[str, list[str]] = {
	LEAD: ["Sales User", "Sales Manager", "System Manager"],
	MEASUREMENT_PENDING: ["Sales User", "Sales Manager", "System Manager"],
	MEASURED: ["Maintenance User", "Sales User", "System Manager"],
	DESIGN_PENDING: ["Sales Manager", "System Manager"],
	DESIGN_APPROVED: ["Designer", "System Manager"],
	QUOTE_PENDING: ["Sales User", "Sales Manager", "System Manager"],
	QUOTE_SENT: ["Sales User", "Sales Manager", "System Manager"],
	CONTRACT_PENDING: ["Sales User", "Sales Manager", "System Manager"],
	DEPOSIT_PENDING: ["Accounts User", "Sales Manager", "System Manager"],
	READY_FOR_PRODUCTION: ["Accounts User", "Sales Manager", "System Manager"],
	IN_PRODUCTION: ["Manufacturing User", "Manufacturing Manager", "System Manager"],
	QUALITY_CONTROL: ["Manufacturing User", "Quality Manager", "System Manager"],
	READY_FOR_DELIVERY: ["Quality Manager", "Manufacturing Manager", "System Manager"],
	DELIVERY: ["Stock User", "Stock Manager", "System Manager"],
	INSTALLATION: ["Stock User", "Maintenance User", "System Manager"],
	ACCEPTANCE_PENDING: ["Maintenance User", "Sales Manager", "System Manager"],
	COMPLETED: ["Accounts Manager", "Sales Manager", "System Manager"],
	WARRANTY: ["Support Team", "Sales Manager", "System Manager"],
	CANCELLED: ["Sales Manager", "Accounts Manager", "System Manager"],
}


def get_order_state(sales_order: str) -> dict[str, Any]:
	"""Получить текущий канонический статус заказа."""
	order = _get_order_doc(sales_order)
	current_state = getattr(order, "korkem_state", None) or _infer_state_from_erpnext(order)
	
	allowed_targets = sorted(list(ALLOWED_TRANSITIONS.get(current_state, set())))
	return {
		"sales_order": order.name,
		"company": order.company,
		"customer": order.customer,
		"current_state": current_state,
		"allowed_next_states": allowed_targets,
		"total_amount": flt(order.grand_total),
		"advance_paid": flt(getattr(order, "advance_paid", 0)),
		"per_delivered": flt(getattr(order, "per_delivered", 0)),
		"per_billed": flt(getattr(order, "per_billed", 0)),
		"docstatus": order.docstatus,
	}


def can_transition(
	sales_order: str,
	target_state: str,
	user: str | None = None,
	context: dict[str, Any] | None = None,
) -> tuple[bool, str | None]:
	"""Проверить, возможен ли переход в target_state."""
	if target_state not in ALL_STATES:
		return False, f"Неизвестный статус заказа: {target_state}"

	info = get_order_state(sales_order)
	current = info["current_state"]

	# 1. Проверка допустимости перехода по графу
	allowed = ALLOWED_TRANSITIONS.get(current, set())
	if target_state not in allowed:
		return False, f"Переход из '{current}' в '{target_state}' недопустим по технологическому графу."

	# 2. Проверка ролевых прав
	active_user = user or frappe.session.user
	if active_user and active_user != "Administrator":
		roles = frappe.get_roles(active_user)
		allowed_roles = REQUIRED_ROLES.get(target_state, ["System Manager"])
		if not any(r in allowed_roles for r in roles):
			return False, f"Пользователь {active_user} не имеет роли для перевода заказа в '{target_state}'."

	# 3. Проверка специфических предусловий данных
	precondition_err = _check_preconditions(sales_order, current, target_state, context=context)
	if precondition_err:
		return False, precondition_err

	return True, None


def transition(
	*,
	sales_order: str,
	target_state: str,
	expected_state: str | None = None,
	reason: str | None = None,
	user: str | None = None,
	context: dict[str, Any] | None = None,
	channel: str = "System",
) -> dict[str, Any]:
	"""Атомарно перевести заказ в целевое состояние с защитой от гонок (Row Locking & Optimistic Concurrency)."""
	# 1. Захват блокировки строки для предотвращения состояния гонки
	locked_order = frappe.db.get_value(
		"Sales Order",
		sales_order,
		["name", "company", "korkem_state", "docstatus"],
		as_dict=True,
		for_update=True,
	)
	if not locked_order:
		frappe.throw(f"Заказ {sales_order} не найден.", frappe.DoesNotExistError)

	# 2. Изоляция арендаторов (Tenant Isolation)
	from korkem_manufacturing.services.scope import enforce_tenant_scope
	enforce_tenant_scope(locked_order.company)

	order = frappe.get_doc("Sales Order", sales_order)
	active_user = user or frappe.session.user
	current_state = locked_order.korkem_state or _infer_state_from_erpnext(order)

	# 3. Optimistic concurrency check
	if expected_state and current_state != expected_state:
		frappe.throw(
			f"Конфликт конкурентного обновления: ожидалось состояние '{expected_state}', "
			f"но текущее состояние '{current_state}'. Обновите данные перед повтором.",
			frappe.ValidationError,
		)

	ok, err = can_transition(sales_order, target_state, user=active_user, context=context)
	if not ok:
		frappe.throw(err or "Переход статуса заблокирован.")

	now_ts = now_datetime()

	# 1. Интеграция с производственным контуром (Stock Reservations)
	if target_state == CANCELLED:
		try:
			from korkem_manufacturing.services.stock_reservation import release_reservations_for_order
			release_reservations_for_order(order.name, reason=reason or "Заказ отменен", user=active_user)
		except Exception:
			pass
	elif target_state == IN_PRODUCTION:
		try:
			from korkem_manufacturing.services.stock_reservation import consume_reservations_for_order
			consume_reservations_for_order(order.name, user=active_user)
		except Exception:
			pass

	# 2. Сохранение нового статуса
	frappe.db.set_value(
		"Sales Order",
		order.name,
		{"korkem_state": target_state},
		update_modified=True,
	)

	# 3. Запись в Order State Log (если таблица существует)
	try:
		roles = frappe.get_roles(active_user)
		actor_role = roles[0] if roles else "Guest"
		log_id = f"ordst-{frappe.generate_hash(length=12)}"
		frappe.get_doc(
			{
				"doctype": "Order State Log",
				"name": log_id,
				"sales_order": order.name,
				"company": order.company,
				"from_state": current_state,
				"to_state": target_state,
				"actor": active_user,
				"actor_role": actor_role,
				"transition_time": now_ts,
				"reason": reason,
				"preconditions_json": json.dumps(context or {}, ensure_ascii=False),
			}
		).insert(ignore_permissions=True)
	except Exception:
		pass

	# 3. Запись в Domain Audit Trail
	audit.record_audit(
		action="order.state_transition",
		entity_type="Sales Order",
		entity_id=order.name,
		diff={"from": current_state, "to": target_state},
		reason=reason,
		channel=channel,
		company=order.company,
		actor=active_user,
	)

	# 4. Запись в Transactional Outbox
	event_name = f"order.{target_state.lower().replace(' ', '_')}"
	outbox.record_event(
		event_name=event_name,
		aggregate_type="Sales Order",
		aggregate_id=order.name,
		payload={
			"sales_order": order.name,
			"company": order.company,
			"customer": order.customer,
			"from_state": current_state,
			"to_state": target_state,
			"reason": reason,
			"actor": active_user,
			"timestamp": str(now_ts),
		},
		company=order.company,
		actor=active_user,
	)

	return {
		"sales_order": order.name,
		"previous_state": current_state,
		"new_state": target_state,
		"transitioned_at": str(now_ts),
		"status": "success",
	}


def list_available_transitions(sales_order: str, user: str | None = None) -> list[dict[str, Any]]:
	"""Список доступных целевых статусов для UI с отметкой, готов ли переход."""
	info = get_order_state(sales_order)
	allowed = info["allowed_next_states"]
	results = []
	for target in allowed:
		can_go, reason = can_transition(sales_order, target, user=user)
		results.append(
			{
				"target_state": target,
				"available": can_go,
				"block_reason": reason,
			}
		)
	return results


def _check_preconditions(
	sales_order: str,
	current: str,
	target: str,
	context: dict[str, Any] | None = None,
) -> str | None:
	"""Бизнес-правила готовности к переходу."""
	if target == READY_FOR_PRODUCTION:
		order = _get_order_doc(sales_order)
		total = flt(order.grand_total)
		paid = flt(getattr(order, "advance_paid", 0))
		skip_check = context and context.get("skip_deposit_check")
		if not skip_check and total > 0 and (paid / total) < 0.5:
			return f"Для готовности к производству требуется предоплата не менее 50% (оплачено: {paid} из {total} KZT)."

	if target == IN_PRODUCTION:
		# 1. Проверка спецификации (BOM) и резервирования материалов
		bypass = context and (context.get("bypass_material_reservation") or context.get("skip_material_check"))
		if not bypass:
			from korkem_manufacturing.services.stock_reservation import check_materials_reserved_for_order
			res_check = check_materials_reserved_for_order(sales_order)
			if not res_check.get("has_bom"):
				return "Заказ не может быть передан в производство: не привязана спецификация материалов (BOM)."
			if res_check.get("shortages"):
				shortage_details = [
					f"{s['item_code']} (дефицит: {s['shortage_qty']})"
					for s in res_check["shortages"]
				]
				# Запись события дефицита в Outbox для службы снабжения
				try:
					from korkem_manufacturing.services import outbox
					order = _get_order_doc(sales_order)
					outbox.record_event(
						event_name="material.shortage_detected",
						aggregate_type="Sales Order",
						aggregate_id=sales_order,
						payload={
							"sales_order": sales_order,
							"company": order.company,
							"shortages": res_check["shortages"],
						},
						company=order.company,
					)
				except Exception:
					pass
				return (
					f"Заказ не может быть передан в производство: дефицит зарезервированных материалов "
					f"({'; '.join(shortage_details)})."
				)

	if target == READY_FOR_DELIVERY:
		from korkem_manufacturing.services import qc
		bypass = context and context.get("skip_qc_check")
		if not bypass and not qc.is_qc_passed_for_order(sales_order):
			return "Заказ не может быть передан в доставку: контроль качества (ОТК) не пройден."

	if target == DELIVERY:
		order = _get_order_doc(sales_order)
		if order.docstatus != 1:
			return f"Заказ {sales_order} не проведен (Draft)."

	if target == COMPLETED:
		order = _get_order_doc(sales_order)
		# 1. Проверка отгрузки
		if flt(getattr(order, "per_delivered", 0)) < 100 and not (context and context.get("skip_delivery_check")):
			return "Заказ не может быть завершен: мебель отгружена клиенту не полностью."

		# 2. Проверка подписанного акта приема-передачи
		from korkem_manufacturing.services import acceptance
		if not (context and context.get("skip_acceptance_check")) and not acceptance.is_acceptance_signed(sales_order):
			return "Заказ не может быть завершен: не подписан Акт сдачи-приемки клиентом."

		# 3. Проверка 100% оплаты
		total = flt(order.grand_total)
		paid = flt(getattr(order, "advance_paid", 0))
		if not (context and context.get("skip_payment_check")) and total > 0 and paid < total:
			return f"Заказ не может быть завершен: заказ оплачен не полностью (оплачено {paid} из {total} KZT)."

	if target == WARRANTY:
		order = _get_order_doc(sales_order)
		has_claim = frappe.db.exists("Warranty Claim", {"customer": order.customer})
		if not has_claim and not (context and context.get("skip_claim_check")):
			return "Перевод в гарантийный статус требует зафиксированной рекламации (Warranty Claim)."

	return None


def _get_order_doc(sales_order: str) -> Any:
	if not sales_order:
		frappe.throw("sales_order обязателен.")
	if not frappe.db.exists("Sales Order", sales_order):
		frappe.throw(f"Заказ {sales_order} не найден.", frappe.DoesNotExistError)
	doc = frappe.get_doc("Sales Order", sales_order)
	return doc


def _infer_state_from_erpnext(order: Any) -> str:
	"""Определение канонического статуса из имеющихся полей ERPNext (обратная совместимость)."""
	if order.docstatus == 0:
		return DRAFT
	if order.docstatus == 2:
		return CANCELLED

	status = getattr(order, "status", "")
	if status == "Closed":
		return COMPLETED
	if status == "Cancelled":
		return CANCELLED

	per_delivered = flt(getattr(order, "per_delivered", 0))
	per_billed = flt(getattr(order, "per_billed", 0))

	if per_delivered >= 100 and per_billed >= 100:
		return COMPLETED
	if per_delivered >= 100:
		return ACCEPTANCE_PENDING
	if per_delivered > 0:
		return DELIVERY

	# Проверка наличия Work Order
	work_orders = frappe.get_all(
		"Work Order",
		filters={"sales_order": order.name, "docstatus": ["<", 2]},
		limit=1,
	)
	if work_orders:
		return IN_PRODUCTION

	# Проверка наличия договора
	contracts = frappe.get_all(
		"Contract",
		filters={"document_name": order.name, "docstatus": ["<", 2]},
		limit=1,
	)
	if contracts:
		return READY_FOR_PRODUCTION

	return LEAD
