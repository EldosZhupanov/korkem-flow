# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Каталоги поставщиков с картинками декоров — тонкая обёртка над services/film_decors.py."""

from __future__ import annotations

import base64

import frappe

from korkem_manufacturing.services import film_catalog
from korkem_manufacturing.services import film_decors as service


@frappe.whitelist(methods=["GET"])
def decors(maker: str | None = None) -> dict:
	"""Декоры производителей: картинка, коллекция, код и какая плёнка из них уже заведена."""
	return service.decors(maker)


@frappe.whitelist(methods=["POST"])
def import_pack(content_b64: str, maker: str | None = None, source: str | None = None) -> dict:
	"""Загрузить каталог: zip с manifest.json и картинками. Повторная загрузка обновляет, не удваивает."""
	try:
		content = base64.b64decode(content_b64.split(",")[-1])
	except (ValueError, TypeError):
		frappe.throw("Архив не прочитался.")
	return service.import_pack(content, maker, source)


@frappe.whitelist(methods=["POST"])
def from_decor(decor: str, thickness: str | None = None, width: str | None = None) -> dict:
	"""Завести плёнку из декора каталога: производитель, название, коллекция, код и цвет — из каталога."""
	form = frappe.form_dict
	card = {k: form.get(k) for k in film_catalog.CARD if k in form}
	return service.from_decor(decor, thickness, width, **card)


@frappe.whitelist(methods=["POST"])
def set_film_image(item: str, file_name: str, content_b64: str) -> dict:
	"""Своё фото образца плёнки — на все её толщины."""
	return service.set_film_image(item, file_name, content_b64)


@frappe.whitelist(methods=["POST"])
def clear_film_image(item: str) -> dict:
	"""Убрать своё фото — плёнка снова показывает картинку каталога."""
	return service.clear_film_image(item)


@frappe.whitelist(methods=["POST"])
def set_decor_image(decor: str, file_name: str, content_b64: str) -> dict:
	"""Заменить картинку декора в каталоге."""
	return service.set_decor_image(decor, file_name, content_b64)


@frappe.whitelist(methods=["POST"])
def delete_maker(maker: str) -> dict:
	"""Убрать весь каталог производителя; плёнки остаются."""
	return service.delete_maker(maker)


@frappe.whitelist(methods=["POST"])
def match_photo(content_b64: str) -> dict:
	"""Подбор по фото образца: самые похожие декоры всех каталогов, что есть на складе — отмечено."""
	from korkem_manufacturing.services import decor_colors

	return decor_colors.match_photo(content_b64)


@frappe.whitelist(methods=["GET"])
def analogues(decor: str | None = None, item: str | None = None) -> dict:
	"""Аналоги декора или плёнки у других производителей, ближайшие по цвету и рисунку."""
	from korkem_manufacturing.services import decor_colors

	return decor_colors.analogues(decor, item)
