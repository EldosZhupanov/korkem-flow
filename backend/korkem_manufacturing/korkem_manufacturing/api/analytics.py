# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""REST API endpoints for client analytics telemetry and funnel tracking."""

from __future__ import annotations

import json
import frappe
from korkem_manufacturing.services import analytics as service


@frappe.whitelist(allow_guest=True, methods=["POST"])
def log_event(event_name: str, properties: str | dict | None = None) -> dict:
	"""Public telemetry endpoint to record user onboarding progression."""
	props = properties
	if isinstance(properties, str):
		try:
			props = json.loads(properties)
		except Exception:
			props = {}

	docname = service.track_event(event_name=event_name, properties=props)
	return {"status": "ok", "logged": bool(docname)}


@frappe.whitelist(methods=["GET"])
def get_funnel(company: str | None = None) -> dict:
	"""Retrieve onboarding and employee invite conversion funnel."""
	return service.get_funnel_summary(company=company)
