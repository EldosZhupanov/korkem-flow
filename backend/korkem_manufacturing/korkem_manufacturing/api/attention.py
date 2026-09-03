# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Что требует внимания сегодня — тонкая обёртка над services/attention.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import attention as service


@frappe.whitelist(methods=["GET"])
def today() -> dict:
	"""Всё, что застряло в цепочке, одним ответом."""
	return service.today()
