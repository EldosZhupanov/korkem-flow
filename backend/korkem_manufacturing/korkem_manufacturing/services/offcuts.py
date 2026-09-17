# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Stock Offcut Domain Service.

Управление деловыми остатками листовых материалов (ЛДСП, МДФ, фанера, столешницы):
- Регистрация остатка после раскроя с генерацией QR/Barcode;
- Поиск подходящих деловых остатков под деталь (с учетом и без учета поворота на 90°);
- Бронирование остатка под конкретный заказ;
- Списание и списание в утиль (Scrap);
- Конкурентная безопасность (Row-locking) и изоляция арендаторов.
"""

from __future__ import annotations

from typing import Any

import frappe
from frappe.utils import flt, now_datetime

from korkem_manufacturing.services import audit, outbox
from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope

DOCTYPE = "Stock Offcut"


def create_offcut(
	*,
	company: str | None = None,
	material_item: str,
	length_mm: float,
	width_mm: float,
	warehouse: str,
	storage_cell: str | None = None,
	decor: str | None = None,
	thickness_mm: float | None = None,
	source_stock_entry: str | None = None,
	source_work_order: str | None = None,
	source_job_card: str | None = None,
	source_order: str | None = None,
	notes: str | None = None,
	user: str | None = None,
) -> Any:
	"""Зарегистрировать новый деловой остаток на складе."""
	company = company or current_company()
	enforce_tenant_scope(company)
	actor = user or frappe.session.user or "Administrator"

	doc = frappe.get_doc(
		{
			"doctype": DOCTYPE,
			"company": company,
			"material_item": material_item,
			"decor": decor,
			"thickness_mm": flt(thickness_mm),
			"length_mm": flt(length_mm),
			"width_mm": flt(width_mm),
			"warehouse": warehouse,
			"storage_cell": storage_cell,
			"source_stock_entry": source_stock_entry,
			"source_work_order": source_work_order,
			"source_job_card": source_job_card,
			"source_order": source_order,
			"status": "Available",
			"created_by": actor,
			"notes": notes,
		}
	)
	doc.insert(ignore_permissions=True)

	# 1. Audit trail
	audit.record_audit(
		action="stock.offcut_created",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={
			"material": material_item,
			"dimensions": f"{length_mm}x{width_mm}",
			"area_m2": doc.area_m2,
			"warehouse": warehouse,
		},
		company=company,
		actor=actor,
	)

	# 2. Transactional Outbox
	outbox.record_event(
		event_name="stock.offcut_created",
		aggregate_type=DOCTYPE,
		aggregate_id=doc.name,
		payload={
			"offcut": doc.name,
			"company": company,
			"material_item": material_item,
			"length_mm": doc.length_mm,
			"width_mm": doc.width_mm,
			"area_m2": doc.area_m2,
			"warehouse": warehouse,
			"qr_code": doc.qr_code,
			"barcode": doc.barcode,
			"source_order": source_order,
		},
		company=company,
		actor=actor,
	)

	return doc


def reserve_offcut(
	offcut_name: str,
	sales_order: str,
	user: str | None = None,
) -> Any:
	"""Забронировать деловой остаток под заказ с пессимистической блокировкой."""
	actor = user or frappe.session.user or "Administrator"

	# Pessimistic row locking
	locked = frappe.db.get_value(
		DOCTYPE,
		offcut_name,
		["name", "company", "status", "reserved_for_order"],
		as_dict=True,
		for_update=True,
	)
	if not locked:
		frappe.throw(f"Деловой остаток {offcut_name} не найден.", frappe.DoesNotExistError)

	enforce_tenant_scope(locked.company)

	# Cross-tenant check between offcut and target sales order
	if sales_order:
		order_company = frappe.db.get_value("Sales Order", sales_order, "company")
		if order_company and order_company != locked.company:
			frappe.throw(
				f"Деловой остаток компании '{locked.company}' не может быть забронирован под заказ компании '{order_company}'.",
				frappe.PermissionError,
			)

	if locked.status != "Available":
		frappe.throw(
			f"Деловой остаток {offcut_name} недоступен для резерва (текущий статус: '{locked.status}').",
			frappe.ValidationError,
		)

	doc = frappe.get_doc(DOCTYPE, offcut_name)
	doc.status = "Reserved"
	doc.reserved_for_order = sales_order
	doc.save(ignore_permissions=True)

	audit.record_audit(
		action="stock.offcut_reserved",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={"status": "Reserved", "reserved_for_order": sales_order},
		company=doc.company,
		actor=actor,
	)

	outbox.record_event(
		event_name="stock.offcut_reserved",
		aggregate_type=DOCTYPE,
		aggregate_id=doc.name,
		payload={
			"offcut": doc.name,
			"company": doc.company,
			"sales_order": sales_order,
			"reserved_at": str(now_datetime()),
		},
		company=doc.company,
		actor=actor,
	)

	return doc


def release_offcut(
	offcut_name: str,
	sales_order: str | None = None,
	user: str | None = None,
) -> Any:
	"""Освободить ранее забронированный деловой остаток."""
	actor = user or frappe.session.user or "Administrator"

	locked = frappe.db.get_value(
		DOCTYPE,
		offcut_name,
		["name", "company", "status", "reserved_for_order"],
		as_dict=True,
		for_update=True,
	)
	if not locked:
		frappe.throw(f"Деловой остаток {offcut_name} не найден.", frappe.DoesNotExistError)

	enforce_tenant_scope(locked.company)

	if locked.status != "Reserved":
		frappe.throw(
			f"Деловой остаток {offcut_name} не забронирован (текущий статус: '{locked.status}').",
			frappe.ValidationError,
		)

	if sales_order and locked.reserved_for_order and locked.reserved_for_order != sales_order:
		frappe.throw(
			f"Деловой остаток {offcut_name} забронирован под другой заказ ({locked.reserved_for_order}), а не {sales_order}.",
			frappe.PermissionError,
		)

	prev_order = locked.reserved_for_order
	doc = frappe.get_doc(DOCTYPE, offcut_name)
	doc.status = "Available"
	doc.reserved_for_order = None
	doc.save(ignore_permissions=True)

	audit.record_audit(
		action="stock.offcut_released",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={"status": "Available", "released_from_order": prev_order},
		company=doc.company,
		actor=actor,
	)

	outbox.record_event(
		event_name="stock.offcut_released",
		aggregate_type=DOCTYPE,
		aggregate_id=doc.name,
		payload={
			"offcut": doc.name,
			"company": doc.company,
			"previous_order": prev_order,
		},
		company=doc.company,
		actor=actor,
	)

	return doc


def consume_offcut(
	offcut_name: str,
	sales_order: str | None = None,
	work_order: str | None = None,
	job_card: str | None = None,
	user: str | None = None,
) -> Any:
	"""Списать деловой остаток в производство (расход). Нельзя списать дважды."""
	actor = user or frappe.session.user or "Administrator"

	locked = frappe.db.get_value(
		DOCTYPE,
		offcut_name,
		["name", "company", "status", "reserved_for_order"],
		as_dict=True,
		for_update=True,
	)
	if not locked:
		frappe.throw(f"Деловой остаток {offcut_name} не найден.", frappe.DoesNotExistError)

	enforce_tenant_scope(locked.company)

	if locked.status == "Consumed":
		frappe.throw(f"Деловой остаток {offcut_name} уже списан в производство.", frappe.ValidationError)

	if locked.status == "Scrapped":
		frappe.throw(f"Деловой остаток {offcut_name} списан в брак/утиль и не может быть использован.", frappe.ValidationError)

	doc = frappe.get_doc(DOCTYPE, offcut_name)
	doc.status = "Consumed"
	if sales_order:
		doc.source_order = sales_order
	if work_order:
		doc.source_work_order = work_order
	if job_card:
		doc.source_job_card = job_card
	doc.save(ignore_permissions=True)

	audit.record_audit(
		action="stock.offcut_consumed",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={"status": "Consumed", "order": sales_order, "work_order": work_order},
		company=doc.company,
		actor=actor,
	)

	outbox.record_event(
		event_name="stock.offcut_consumed",
		aggregate_type=DOCTYPE,
		aggregate_id=doc.name,
		payload={
			"offcut": doc.name,
			"company": doc.company,
			"sales_order": sales_order,
			"work_order": work_order,
			"job_card": job_card,
		},
		company=doc.company,
		actor=actor,
	)

	return doc


def scrap_offcut(
	offcut_name: str,
	reason: str,
	user: str | None = None,
) -> Any:
	"""Списать поврежденный деловой остаток в утиль (Scrap)."""
	actor = user or frappe.session.user or "Administrator"

	locked = frappe.db.get_value(
		DOCTYPE,
		offcut_name,
		["name", "company", "status"],
		as_dict=True,
		for_update=True,
	)
	if not locked:
		frappe.throw(f"Деловой остаток {offcut_name} не найден.", frappe.DoesNotExistError)

	enforce_tenant_scope(locked.company)

	if locked.status == "Consumed":
		frappe.throw(f"Деловой остаток {offcut_name} уже израсходован в производстве и не может быть списан.", frappe.ValidationError)

	doc = frappe.get_doc(DOCTYPE, offcut_name)
	doc.status = "Scrapped"
	doc.notes = f"{doc.notes or ''}\nПричина списания: {reason}".strip()
	doc.save(ignore_permissions=True)

	audit.record_audit(
		action="stock.offcut_scrapped",
		entity_type=DOCTYPE,
		entity_id=doc.name,
		diff={"status": "Scrapped", "reason": reason},
		company=doc.company,
		actor=actor,
	)

	outbox.record_event(
		event_name="stock.offcut_scrapped",
		aggregate_type=DOCTYPE,
		aggregate_id=doc.name,
		payload={
			"offcut": doc.name,
			"company": doc.company,
			"reason": reason,
		},
		company=doc.company,
		actor=actor,
	)

	return doc


def find_usable_offcuts(
	*,
	company: str | None = None,
	material_item: str,
	min_length: float,
	min_width: float,
	allow_rotation: bool = True,
	thickness_mm: float | None = None,
	decor: str | None = None,
	limit: int = 20,
) -> list[dict[str, Any]]:
	"""Поиск деловых остатков под заготовку с алгоритмом Best-Fit (наименьший подходящий остаток)."""
	comp = company or current_company()
	enforce_tenant_scope(comp)

	filters: dict[str, Any] = {
		"company": comp,
		"material_item": material_item,
		"status": "Available",
	}
	if thickness_mm:
		filters["thickness_mm"] = flt(thickness_mm)
	if decor:
		filters["decor"] = decor

	candidates = frappe.get_all(
		DOCTYPE,
		filters=filters,
		fields=[
			"name",
			"company",
			"material_item",
			"decor",
			"thickness_mm",
			"length_mm",
			"width_mm",
			"area_m2",
			"warehouse",
			"storage_cell",
			"qr_code",
			"barcode",
			"status",
		],
		order_by="area_m2 asc",  # Best-fit: сначала наименьшие, чтобы минимизировать отход
		limit=limit * 3,
	)

	req_len = flt(min_length)
	req_wid = flt(min_width)

	matched: list[dict[str, Any]] = []
	for offcut in candidates:
		olen = flt(offcut["length_mm"])
		owid = flt(offcut["width_mm"])

		direct_fit = olen >= req_len and owid >= req_wid
		rotated_fit = allow_rotation and (olen >= req_wid and owid >= req_len)

		if direct_fit or rotated_fit:
			offcut["is_rotated"] = not direct_fit and rotated_fit
			matched.append(offcut)
			if len(matched) >= limit:
				break

	return matched


def get_offcut_by_qr(qr_code: str, company: str | None = None) -> dict[str, Any] | None:
	"""Найти деловой остаток по QR коду или штрихкоду."""
	comp = company or current_company()
	enforce_tenant_scope(comp)

	offcut = frappe.db.get_value(
		DOCTYPE,
		{"company": comp, "qr_code": qr_code},
		["name", "material_item", "decor", "length_mm", "width_mm", "area_m2", "warehouse", "storage_cell", "status", "reserved_for_order"],
		as_dict=True,
	)
	if not offcut:
		offcut = frappe.db.get_value(
			DOCTYPE,
			{"company": comp, "barcode": qr_code},
			["name", "material_item", "decor", "length_mm", "width_mm", "area_m2", "warehouse", "storage_cell", "status", "reserved_for_order"],
			as_dict=True,
		)
	return offcut
