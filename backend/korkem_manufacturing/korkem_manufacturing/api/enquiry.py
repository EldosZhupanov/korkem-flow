# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Turning a capture into a customer and an enquiry, from any client.

Thin over `services/enquiry.py`, with one thing worth doing here rather than
there: an ambiguous customer comes back as a **result with candidates**, not as
an exception. The person is standing in front of a screen deciding which Айгуль
this is; a red error tells them nothing, a list of two names tells them
everything.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import enquiry as service


@frappe.whitelist(methods=["POST"])
def convert(
	capture: str,
	customer: str | None = None,
	customer_name: str | None = None,
	assign_measurer: str | None = None,
	measure_on: str | None = None,
) -> dict:
	"""Create the customer and the enquiry behind one captured sentence."""
	try:
		return service.convert(
			capture=capture,
			customer=customer,
			customer_name=customer_name,
			assign_measurer=assign_measurer,
			measure_on=measure_on,
		)
	except service.AmbiguousCustomer as question:
		frappe.local.response["http_status_code"] = 409
		return {
			"status": "ambiguous_customer",
			"message": str(question),
			"candidates": service.candidates(
				customer_name or frappe.db.get_value("Capture", capture, "customer_hint") or ""
			),
		}


@frappe.whitelist(methods=["GET"])
def customer_candidates(name_said: str) -> dict:
	"""Who this might be, for a person to choose between."""
	return {"candidates": service.candidates(name_said)}
