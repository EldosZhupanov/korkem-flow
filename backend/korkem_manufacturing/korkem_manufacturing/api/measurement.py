# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Результат замера — тонкая обёртка над services/measurement.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import measurement as service


@frappe.whitelist(methods=["POST"])
def record(
	enquiry: str,
	dimensions: str | None = None,
	notes: str | None = None,
	address_line: str | None = None,
	city: str | None = None,
	measured_on: str | None = None,
) -> dict:
	"""Записать замер на заявку и закрыть задачу замерщика."""
	return service.record(
		enquiry=enquiry,
		dimensions=dimensions,
		notes=notes,
		address_line=address_line,
		city=city,
		measured_on=measured_on,
	)


@frappe.whitelist(methods=["POST"])
def attach_photo(enquiry: str) -> dict:
	"""Принять снимок с замера.

	Файл приходит телом запроса, как его отправляет телефон, а не строкой в
	JSON: base64 в поле означало бы треть лишнего веса на мобильной сети и
	снимок целиком в памяти дважды.
	"""
	uploaded = (frappe.request.files or {}).get("file")
	if uploaded is None:
		frappe.throw("В запросе нет файла. Ожидается поле «file».")

	return service.attach_photo(
		enquiry=enquiry,
		filename=uploaded.filename or "",
		content=uploaded.stream.read(),
	)


@frappe.whitelist(methods=["GET"])
def photos(enquiry: str) -> list[dict]:
	"""Что уже приложено к заявке."""
	return service.photos(enquiry=enquiry)
