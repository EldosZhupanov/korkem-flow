# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Раскрой на форматно-раскроечной пиле — тонкая обёртка над services/saw_cutting.py.

Права и запись в журнал — в сервисе: экран, наклейка и будущий экран у пилы
идут одной дорогой."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import saw_cutting as service


@frappe.whitelist(methods=["GET"])
def settings() -> dict:
	"""Пила: пропил, обрезка края, обрезок на склад, сторона упора, кромка, листы по толщине."""
	return service.saw_settings()


@frappe.whitelist(methods=["POST"])
def save_settings(
	kerf_mm: float | str | None = None,
	trim_mm: float | str | None = None,
	offcut_min_length_mm: int | str | None = None,
	offcut_min_width_mm: int | str | None = None,
	fence_side: str | None = None,
	edge_deduct: bool | int | str | None = None,
	sheets: str | list | None = None,
) -> dict:
	"""Сохранить настройки пилы (менеджеры, начальник производства)."""
	return service.save_saw_settings(
		kerf_mm=kerf_mm, trim_mm=trim_mm, offcut_min_length_mm=offcut_min_length_mm,
		offcut_min_width_mm=offcut_min_width_mm, fence_side=fence_side, edge_deduct=edge_deduct, sheets=sheets,
	)


@frappe.whitelist(methods=["GET"])
def journal(status: str | None = None, search: str | None = None, material: str | None = None,
			sawyer: str | None = None) -> dict:
	"""Журнал раскроев: что пилить первым и что распилено; подсказки «пилить вместе»."""
	return service.listing(status=status, search=search, material=material, sawyer=sawyer)


@frappe.whitelist(methods=["GET"])
def job(name: str) -> dict:
	"""Раскрой целиком: детали, пила, листы, кто пилил, история."""
	return service.job(name)


@frappe.whitelist(methods=["POST"])
def parse(text: str | None = None, content: str | None = None, filename: str | None = None) -> dict:
	"""Прочитать детали из вставки или файла (.xlsx, .xls, .csv, .txt) — ничего не сохраняется."""
	return service.parse_parts(text=text, content=content, filename=filename)


@frappe.whitelist(methods=["POST"])
def calculate(material_item: str, parts: str | list) -> dict:
	"""Варианты раскроя — ничего не сохраняется."""
	return service.calculate(material_item, parts)


@frappe.whitelist(methods=["POST"])
def save(material_item: str, parts: str | list, name: str | None = None, orders: str | list | None = None,
		 choice: str | None = None, due_date: str | None = None) -> dict:
	"""Составить раскрой или изменить, пока не распилен ни один лист (новая версия)."""
	return service.save_job(name=name, material_item=material_item, parts=parts, orders=orders, choice=choice,
							due_date=due_date)


@frappe.whitelist(methods=["POST"])
def check(name: str, checked: bool | int | str = True) -> dict:
	"""«Проверено» — или снять отметку."""
	return service.check_job(name, checked=checked)


@frappe.whitelist(methods=["POST"])
def sheet_done(name: str, sheet_no: int | str, done: bool | int | str = True, sawn_by: str | None = None,
			   defects: str | None = None) -> dict:
	"""Лист распилен — кто пилил, что испорчено; обрезки на склад. Или снять отметку."""
	return service.sheet_done(name, sheet_no, done=done, sawn_by=sawn_by, defects=defects)


@frappe.whitelist(methods=["POST"])
def note_defect(name: str, sheet_no: int | str, defects: str | None = None) -> dict:
	"""Брак на распиленном листе — перенесён с бумажной карты."""
	return service.note_defect(name, sheet_no, defects=defects)


@frappe.whitelist(methods=["POST"])
def cancel(name: str, reason: str) -> dict:
	"""Отменить раскрой — с причиной."""
	return service.cancel_job(name, reason)


@frappe.whitelist(methods=["POST"])
def merge(names: str | list) -> dict:
	"""Пилить вместе: раскрои одного материала одним раскроем."""
	return service.merge_jobs(names)


@frappe.whitelist(methods=["GET"])
def scan(code: str) -> dict:
	"""Что за лист на карте: QR «SAW:Р-0042:1»."""
	return service.scan(code)
