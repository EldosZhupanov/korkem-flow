# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Склад материалов — тонкая обёртка над services/material_stock.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import material_stock as service


@frappe.whitelist(methods=["GET"])
def lists() -> dict:
	"""Справочники: толщины, производители, цвета, ширины; поставщики; единицы."""
	return service.lists()


@frappe.whitelist(methods=["POST"])
def add_option(kind: str, value: str) -> dict:
	"""Добавить значение в справочник (администратор, менеджеры)."""
	return service.add_option(kind, value)


@frappe.whitelist(methods=["POST"])
def remove_option(option: str) -> dict:
	"""Убрать значение: неиспользуемое удаляется, использованное — отключается."""
	return service.remove_option(option)


@frappe.whitelist(methods=["POST"])
def add_supplier(name: str) -> dict:
	"""Добавить поставщика (или включить отключённого)."""
	return service.add_supplier(name)


@frappe.whitelist(methods=["POST"])
def disable_supplier(supplier: str) -> dict:
	"""Отключить поставщика. Поставщики не удаляются — на них ссылаются приходы."""
	return service.disable_supplier(supplier)


@frappe.whitelist(methods=["POST"])
def define_material(
	kind: str,
	unit: str,
	thickness: str | None = None,
	manufacturer: str | None = None,
	color: str | None = None,
	width: str | None = None,
	film_thickness: str | None = None,
	name: str | None = None,
) -> dict:
	"""Описать материал из справочников. То же описание — тот же материал."""
	return service.define_material(
		kind, unit, thickness=thickness, manufacturer=manufacturer, color=color,
		width=width, film_thickness=film_thickness, name=name,
	)


@frappe.whitelist(methods=["POST"])
def set_material_enabled(item: str, enabled: bool | int | str) -> dict:
	"""Включить или отключить материал."""
	return service.set_material_enabled(item, enabled)


@frappe.whitelist(methods=["POST"])
def set_film_textured(item: str, textured: bool | int | str) -> dict:
	"""«Текстурная» плёнка: на прессе её детали не вращают."""
	return service.set_film_textured(item, textured)


@frappe.whitelist(methods=["GET"])
def materials(kind: str | None = None, include_disabled: bool | int | str = 0) -> dict:
	"""Материалы с остатком; средняя цена — только тем, кому видны цены."""
	flag = bool(int(include_disabled)) if isinstance(include_disabled, str) else bool(include_disabled)
	return service.materials(kind=kind, include_disabled=flag)


@frappe.whitelist(methods=["POST"])
def receive(
	item: str,
	qty: float | str,
	price_per_unit: float | str,
	supplier: str,
	warehouse: str | None = None,
	received_on: str | None = None,
	note: str | None = None,
	idempotency_key: str | None = None,
) -> dict:
	"""Оприходовать покупку: сколько, по какой цене, у кого. Проводится в ERPNext."""
	from korkem_manufacturing.services.idempotency import execute as execute_idempotently

	arguments = {
		"item": item, "qty": qty, "price_per_unit": price_per_unit, "supplier": supplier,
		"warehouse": warehouse, "received_on": received_on, "note": note,
	}
	return execute_idempotently(
		"stock.material_received", idempotency_key, arguments, lambda: service.receive(**arguments)
	)


@frappe.whitelist(methods=["POST"])
def cancel_receipt(receipt: str) -> dict:
	"""Отменить ошибочный приход. ERPNext откажет, если материал уже израсходован."""
	return service.cancel_receipt(receipt)


@frappe.whitelist(methods=["GET"])
def receipts(item: str | None = None, limit: int = 100) -> dict:
	"""История приходов."""
	return service.receipts(item=item, limit=limit)
