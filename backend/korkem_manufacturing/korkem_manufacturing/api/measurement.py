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
