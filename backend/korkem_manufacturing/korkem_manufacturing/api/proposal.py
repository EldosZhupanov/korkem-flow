# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Черновик КП по заявке — тонкая обёртка над services/proposal.py."""

from __future__ import annotations

import json

import frappe

from korkem_manufacturing.services import proposal as service


@frappe.whitelist(methods=["POST"])
def draft(enquiry: str, items: str | list | None = None, valid_days: int = 14) -> dict:
	"""Собрать черновик коммерческого предложения по заявке."""
	return service.draft(
		enquiry=enquiry, items=_as_rows(items), valid_days=int(valid_days or 14)
	)


def _as_rows(value: str | list | None) -> list[dict] | None:
	if not value:
		return None
	if isinstance(value, list):
		return [row for row in value if isinstance(row, dict)]
	try:
		parsed = json.loads(value)
	except (TypeError, ValueError):
		# Испорченный список позиций не повод не создать черновик: клиент и
		# заявка важнее строк, которые всё равно правит человек.
		return None
	return [row for row in parsed if isinstance(row, dict)] if isinstance(parsed, list) else None
