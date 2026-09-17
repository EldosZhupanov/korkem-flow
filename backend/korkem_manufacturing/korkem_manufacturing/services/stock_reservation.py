# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Stock Reservation Service.

Управление бронированием материалов под конкретные производственные заказы:
- Резервирование целых плит (Full Sheet), деловых остатков (Offcut), кромки и фурнитуры;
- Конкурентная защита от двойного бронирования (Row-locking);
- Идемпотентность по уникальному ключу брони;
- Автоматическое освобождение резервов при отмене заказа (Order State Machine Integration);
- Проверка покрытия спецификации заказа резервами перед запуском в производство (Preconditions Gate).
"""

from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import flt, now_datetime

from korkem_manufacturing.services import audit, outbox
from korkem_manufacturing.services.offcuts import consume_offcut, release_offcut, reserve_offcut
from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope
from korkem_manufacturing.services.stock_movement import record_movement

DOCTYPE = "Stock Reservation"


def get_available_unreserved_qty(company: str | None, warehouse: str, item_code: str) -> float:
	"""Получить доступный для бронирования остаток: физический остаток минус активные брони."""
	comp = company or current_company()
	enforce_tenant_scope(comp)

	# 1. Физический остаток из ERPNext Bin
	actual_qty = frappe.db.get_value(
		"Bin",
		{"warehouse": warehouse, "item_code": item_code},
		"actual_qty",
	)
	physical_qty = flt(actual_qty) if actual_qty is not None else 0.0

	# 2. Если в Bin пусто, проверим регистр Domain Stock Movement
	if physical_qty == 0.0:
		from korkem_manufacturing.services.stock_movement import get_balance
		physical_qty = max(0.0, get_balance(comp, warehouse, item_code))

	# 3. Сумма активных броней на этом складе
	reserved_qty = frappe.db.sql(
		"""
		SELECT COALESCE(SUM(qty), 0)
		FROM `tabStock Reservation`
		WHERE company = %s AND warehouse = %s AND item_code = %s AND status = 'Active'
		""",
		(comp, warehouse, item_code),
	)[0][0]

	return physical_qty - flt(reserved_qty)


def reserve_stock(
	*,
	company: str | None = None,
	sales_order: str,
	item_code: str,
	qty: float,
	warehouse: str,
	reservation_type: str = "Full Sheet",
	offcut: str | None = None,
	work_order: str | None = None,
	bom: str | None = None,
	idempotency_key: str | None = None,
	user: str | None = None,
	strict_stock_check: bool = False,
) -> Any:
	"""Забронировать материал или деловой остаток под заказ клиента."""
	comp = company or current_company()
	enforce_tenant_scope(comp)
	actor = user or frappe.session.user or "Administrator"

	# 1. Идемпотентность
	if idempotency_key:
		existing = frappe.db.get_value(
			DOCTYPE,
			{"company": comp, "idempotency_key": idempotency_key},
			"name",
		)
		if existing:
			return frappe.get_doc(DOCTYPE, existing)

	q = flt(qty)
	if q <= 0:
		frappe.throw(f"Количество для бронирования должно быть положительным (передано: {qty}).", frappe.ValidationError)

	# 2. Если бронируется деловой остаток — захватываем и бронируем его
	if offcut:
		reservation_type = "Offcut"
		reserve_offcut(offcut, sales_order=sales_order, user=actor)

	# 3. Если строгая проверка остатка запрошена
	if strict_stock_check and not offcut:
		avail = get_available_unreserved_qty(comp, warehouse, item_code)
		if avail < q:
			frappe.throw(
				f"Недостаточно свободного остатка на складе {warehouse} для {item_code}. "
				f"Доступно: {avail}, запрошено в резерв: {q}.",
				frappe.ValidationError,
			)

	now_ts = now_datetime()
	doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"company": comp,
			"sales_order": sales_order,
			"work_order": work_order,
			"bom": bom,
			"item_code": item_code,
			"reservation_type": reservation_type,
			"offcut": offcut,
			"qty": q,
			"warehouse": warehouse,
			"status": "Active",
			"reserved_by": actor,
			"reserved_at": now_ts,
			"idempotency_key": idempotency_key,
		}
	)
	doc.insert(ignore_permissions=True)

	# Двойная запись в складской регистр
	record_movement(
		company=comp,
		from_location=warehouse,
		to_location=f"Reserved:{sales_order}",
		item_code=item_code,
		qty=q,
		reason="Stock Reservation",
		sales_order=sales_order,
		work_order=work_order,
		offcut=offcut,
		correlation_id=idempotency_key,
		actor=actor,
		timestamp=now_ts,
	)

	audit.record_audit(
		action="stock.reservation_created",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={
			"sales_order": sales_order,
			"item_code": item_code,
			"qty": q,
			"type": reservation_type,
			"offcut": offcut,
		},
		company=comp,
		actor=actor,
	)

	outbox.record_event(
		event_name="stock.reservation_created",
		aggregate_type=DOCTYPE,
		aggregate_id=doc.name,
		payload={
			"reservation": doc.name,
			"company": comp,
			"sales_order": sales_order,
			"item_code": item_code,
			"qty": q,
			"reservation_type": reservation_type,
			"offcut": offcut,
			"warehouse": warehouse,
		},
		company=comp,
		actor=actor,
	)

	return doc


def release_reservations_for_order(
	sales_order: str,
	reason: str = "Order released or cancelled",
	user: str | None = None,
) -> list[str]:
	"""Освободить все активные брони материалов для заказа (например, при отмене заказа)."""
	actor = user or frappe.session.user or "Administrator"
	now_ts = now_datetime()

	# Pessimistic row locking on active reservations
	reservations = frappe.db.sql(
		"""
		SELECT name, company, item_code, qty, warehouse, offcut
		FROM `tabStock Reservation`
		WHERE sales_order = %s AND status = 'Active'
		FOR UPDATE
		""",
		(sales_order,),
		as_dict=True,
	)

	released_ids = []
	for res in reservations:
		enforce_tenant_scope(res.company)

		# Освобождение делового остатка, если был привязан
		if res.offcut:
			try:
				release_offcut(res.offcut, sales_order=sales_order, user=actor)
			except Exception:
				pass

		# Обновление статуса брони
		frappe.db.set_value(
			DOCTYPE,
			res.name,
			{"status": "Released", "released_at": now_ts, "notes": reason},
			update_modified=True,
		)

		# Сторнирующее движение в складском регистре
		record_movement(
			company=res.company,
			from_location=f"Reserved:{sales_order}",
			to_location=res.warehouse,
			item_code=res.item_code,
			qty=flt(res.qty),
			reason="Reservation Release",
			sales_order=sales_order,
			offcut=res.offcut,
			actor=actor,
			timestamp=now_ts,
			is_compensation=1,
		)

		released_ids.append(res.name)

		audit.record_audit(
			action="stock.reservation_released",
			entity_type=DOCTYPE,
			entity_id=res.name,
			diff={"status": "Released", "sales_order": sales_order, "reason": reason},
			company=res.company,
			actor=actor,
		)

		outbox.record_event(
			event_name="stock.reservation_released",
			aggregate_type=DOCTYPE,
			aggregate_id=res.name,
			payload={
				"reservation": res.name,
				"company": res.company,
				"sales_order": sales_order,
				"item_code": res.item_code,
				"qty": res.qty,
				"reason": reason,
			},
			company=res.company,
			actor=actor,
		)

	return released_ids


def consume_reservations_for_order(
	sales_order: str,
	work_order: str | None = None,
	user: str | None = None,
) -> list[str]:
	"""Списать забронированные материалы в производство."""
	actor = user or frappe.session.user or "Administrator"
	now_ts = now_datetime()

	reservations = frappe.db.sql(
		"""
		SELECT name, company, item_code, qty, warehouse, offcut
		FROM `tabStock Reservation`
		WHERE sales_order = %s AND status = 'Active'
		FOR UPDATE
		""",
		(sales_order,),
		as_dict=True,
	)

	consumed_ids = []
	for res in reservations:
		enforce_tenant_scope(res.company)

		if res.offcut:
			consume_offcut(res.offcut, sales_order=sales_order, work_order=work_order, user=actor)

		frappe.db.set_value(
			DOCTYPE,
			res.name,
			{"status": "Consumed", "consumed_at": now_ts},
			update_modified=True,
		)

		record_movement(
			company=res.company,
			from_location=f"Reserved:{sales_order}",
			to_location=f"WIP:{sales_order}",
			item_code=res.item_code,
			qty=flt(res.qty),
			reason="Production Consumption",
			sales_order=sales_order,
			work_order=work_order,
			offcut=res.offcut,
			actor=actor,
			timestamp=now_ts,
		)

		consumed_ids.append(res.name)

		audit.record_audit(
			action="stock.reservation_consumed",
			entity_type=DOCTYPE,
			entity_id=res.name,
			diff={"status": "Consumed", "sales_order": sales_order, "work_order": work_order},
			company=res.company,
			actor=actor,
		)

		outbox.record_event(
			event_name="stock.reservation_consumed",
			aggregate_type=DOCTYPE,
			aggregate_id=res.name,
			payload={
				"reservation": res.name,
				"company": res.company,
				"sales_order": sales_order,
				"work_order": work_order,
				"item_code": res.item_code,
				"qty": res.qty,
			},
			company=res.company,
			actor=actor,
		)

	return consumed_ids


def check_materials_reserved_for_order(sales_order: str) -> dict[str, Any]:
	"""Проверить, полностью ли зарезервированы материалы для запуска заказа в производство.

	Возвращает:
	{
	    "has_bom": bool,
	    "is_fully_reserved": bool,
	    "boms": list,
	    "shortages": [{"item_code": str, "required_qty": float, "reserved_qty": float, "shortage_qty": float}],
	    "reservations": list
	}
	"""
	order = frappe.get_doc("Sales Order", sales_order)
	enforce_tenant_scope(order.company)

	# 1. Поиск спецификаций (BOM) для позиций заказа
	boms = []
	required_materials: dict[str, float] = {}

	for item in order.items:
		# Находим активный BOM для номенклатуры
		bom_name = frappe.db.get_value(
			"BOM",
			{"item": item.item_code, "is_active": 1, "docstatus": 1},
			"name",
		)
		if bom_name:
			boms.append(bom_name)
			bom_items = frappe.get_all(
				"BOM Item",
				filters={"parent": bom_name},
				fields=["item_code", "qty"],
			)
			for b_item in bom_items:
				needed = flt(b_item.qty) * flt(item.qty)
				required_materials[b_item.item_code] = required_materials.get(b_item.item_code, 0.0) + needed

	# Если BOM не найдены по позициям, проверим напрямую привязанные Work Order или custom BOM
	if not boms:
		work_orders = frappe.get_all("Work Order", filters={"sales_order": sales_order, "docstatus": ["<", 2]}, fields=["bom_no", "name"])
		for wo in work_orders:
			if wo.bom_no and wo.bom_no not in boms:
				boms.append(wo.bom_no)
				bom_items = frappe.get_all("BOM Item", filters={"parent": wo.bom_no}, fields=["item_code", "qty"])
				for b_item in bom_items:
					required_materials[b_item.item_code] = required_materials.get(b_item.item_code, 0.0) + flt(b_item.qty)

	# 2. Получение всех активных резервов для этого заказа
	active_res = frappe.get_all(
		DOCTYPE,
		filters={"sales_order": sales_order, "status": "Active"},
		fields=["name", "item_code", "qty", "reservation_type", "offcut", "warehouse"],
	)

	reserved_totals: dict[str, float] = {}
	for r in active_res:
		reserved_totals[r.item_code] = reserved_totals.get(r.item_code, 0.0) + flt(r.qty)

	# 3. Расчет дефицитов (Shortages)
	shortages: list[dict[str, Any]] = []
	for item_code, req_qty in required_materials.items():
		res_qty = reserved_totals.get(item_code, 0.0)
		if res_qty < req_qty:
			shortages.append(
				{
					"item_code": item_code,
					"required_qty": req_qty,
					"reserved_qty": res_qty,
					"shortage_qty": round(req_qty - res_qty, 4),
				}
			)

	has_bom = len(boms) > 0
	is_fully_reserved = has_bom and len(shortages) == 0

	return {
		"sales_order": sales_order,
		"company": order.company,
		"has_bom": has_bom,
		"boms": boms,
		"is_fully_reserved": is_fully_reserved,
		"shortages": shortages,
		"reservations": active_res,
	}


def reserve_materials_for_order(
	sales_order: str,
	user: str | None = None,
	warehouse: str | None = None,
) -> dict[str, Any]:
	"""Автоматически зарезервировать материалы по спецификации заказа (BOM):
	- Приоритет отдается доступным деловым остаткам (Offcuts);
	- Оставшееся количество бронируется со склада сырья (Stores);
	- При нехватке физического остатка фиксируется дефицит и отправляется Outbox event 'material.shortage_detected'.
	"""
	order = frappe.get_doc("Sales Order", sales_order)
	comp = order.company
	enforce_tenant_scope(comp)
	actor = user or frappe.session.user or "Administrator"

	target_warehouse = warehouse or frappe.db.get_value(
		"Warehouse", {"company": comp, "warehouse_name": ["in", ["Stores", "Склад сырья", "Stores - KRK"]]}, "name"
	) or frappe.db.get_value("Warehouse", {"company": comp}, "name") or "Stores"

	# Получаем текущее состояние потребности в материалах
	check = check_materials_reserved_for_order(sales_order)
	shortages_before = check["shortages"]

	reservations_created = []

	for item_short in shortages_before:
		item_code = item_short["item_code"]
		needed_qty = item_short["shortage_qty"]

		# 1. Попытка покрыть деловыми остатками, если материал листовой
		from korkem_manufacturing.services import offcuts
		try:
			usable = offcuts.find_usable_offcuts(
				company=comp,
				material_item=item_code,
				min_length=500,
				min_width=300,
				allow_rotation=True,
				limit=5,
			)
			for off in usable:
				if needed_qty <= 0:
					break
				res_doc = reserve_stock(
					company=comp,
					sales_order=sales_order,
					item_code=item_code,
					qty=1.0,
					warehouse=off.get("warehouse") or target_warehouse,
					reservation_type="Offcut",
					offcut=off["name"],
					idempotency_key=f"res-offcut-{sales_order}-{off['name']}",
					user=actor,
					strict_stock_check=False,
				)
				reservations_created.append(res_doc.name)
				needed_qty = max(0.0, round(needed_qty - 1.0, 4))
		except Exception:
			pass

		# 2. Покрытие со склада сырья целыми листами / единицами
		if needed_qty > 0:
			avail_qty = get_available_unreserved_qty(comp, target_warehouse, item_code)
			qty_to_reserve = min(needed_qty, avail_qty) if avail_qty > 0 else 0.0

			if qty_to_reserve > 0:
				res_doc = reserve_stock(
					company=comp,
					sales_order=sales_order,
					item_code=item_code,
					qty=qty_to_reserve,
					warehouse=target_warehouse,
					reservation_type="Full Sheet",
					idempotency_key=f"res-stock-{sales_order}-{item_code}",
					user=actor,
					strict_stock_check=False,
				)
				reservations_created.append(res_doc.name)

	# 3. Финальная проверка покрытия и фиксация дефицитов
	final_check = check_materials_reserved_for_order(sales_order)
	if final_check["shortages"]:
		outbox.record_event(
			event_name="material.shortage_detected",
			aggregate_type="Sales Order",
			aggregate_id=sales_order,
			payload={
				"sales_order": sales_order,
				"company": comp,
				"shortages": final_check["shortages"],
			},
			company=comp,
			actor=actor,
		)

	return {
		"sales_order": sales_order,
		"reservations_created": reservations_created,
		"is_fully_reserved": final_check["is_fully_reserved"],
		"shortages": final_check["shortages"],
	}

