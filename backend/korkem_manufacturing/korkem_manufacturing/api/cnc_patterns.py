# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Узоры ЧПУ» — тонкая обёртка над services/cnc_patterns.py."""

from __future__ import annotations

import json

import frappe

from korkem_manufacturing.services import cnc_patterns as service

MACHINE = ("ext", "comments", "arcs", "line_numbers", "swap_xy", "safe_z", "clear_z", "rapid", "dwell")


def _list(value) -> list | None:
	if value is None or isinstance(value, list):
		return value
	try:
		parsed = json.loads(value)
	except (TypeError, ValueError):
		frappe.throw("Ожидался список.")
	return parsed if isinstance(parsed, list) else frappe.throw("Ожидался список.")


@frappe.whitelist(methods=["GET"])
def status() -> dict:
	"""Включён ли модуль и видит ли его спрашивающий; фрезы, узоры, станок."""
	return service.status()


@frappe.whitelist(methods=["POST"])
def set_enabled(enabled: int = 0, users: str | list | None = None) -> dict:
	"""Включить или выключить модуль на этой базе и сказать, кто кроме владельца его видит."""
	return service.set_enabled(bool(int(enabled or 0)), _list(users))


@frappe.whitelist(methods=["POST"])
def save_tool(name: str, kind: str, diameter: float, angle: float | None = None, feed: float | None = None,
			  plunge: float | None = None, rpm: float | None = None, pass_depth: float | None = None,
			  old_name: str | None = None) -> dict:
	"""Фреза: форма, диаметр, угол, подачи, обороты, глубина за проход."""
	return service.save_tool(name, kind, diameter, angle, feed, plunge, rpm, pass_depth, old_name)


@frappe.whitelist(methods=["POST"])
def delete_tool(name: str) -> dict:
	"""Убрать фрезу, если ей не режет ни один узор."""
	return service.delete_tool(name)


@frappe.whitelist(methods=["POST"])
def save_pattern(name: str, elements: str | list, milling: str | None = None, min_w: int = 0, min_h: int = 0,
				 fallback: str | None = None, old_name: str | None = None) -> dict:
	"""Узор: элементы, фрезеровка, наименьший фасад и запасной узор."""
	return service.save_pattern(name, elements, milling, min_w, min_h, fallback, old_name)


@frappe.whitelist(methods=["POST"])
def delete_pattern(name: str) -> dict:
	"""Убрать узор."""
	return service.delete_pattern(name)


@frappe.whitelist(methods=["POST"])
def set_machine() -> dict:
	"""Станок: расширение файла, дуги, комментарии, номера строк, высоты, скорость, оси."""
	form = frappe.form_dict
	return service.set_machine(**{k: form.get(k) for k in MACHINE if k in form})


@frappe.whitelist(methods=["POST"])
def preview(pattern: str, width: float, height: float) -> dict:
	"""Узор (по имени или как есть в редакторе) на фасаде этого размера: резы, программа, минуты."""
	return service.preview(pattern, width, height)


@frappe.whitelist(methods=["GET"])
def for_order(order: str) -> dict:
	"""Позиции заказа глазами станка: узор, помещается ли, сколько минут. Только чтение."""
	return service.for_order(order)


@frappe.whitelist(methods=["POST"])
def order_files(order: str, line: str | None = None) -> dict:
	"""Программы для позиций заказа (или одной) — текстом, с именами файлов."""
	return service.order_files(order, line)


@frappe.whitelist(methods=["POST"])
def artcam_preview(content_b64: str) -> dict:
	"""База инструмента ArtCAM (.tdb): что в ней и что из этого можно завести."""
	return service.artcam_preview(content_b64)


@frappe.whitelist(methods=["POST"])
def artcam_add(content_b64: str, picked: str | list) -> dict:
	"""Выбранные фрезы из базы ArtCAM — в «Фрезы»."""
	return service.artcam_add(content_b64, picked)
