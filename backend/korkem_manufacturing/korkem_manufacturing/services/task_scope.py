# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Company boundary for CRM Tasks whose subject is a Capture.

CRM Task has no company field. For the new enquiry chain it nevertheless has
an unambiguous company: the Capture named by its polymorphic reference. This
module narrows only that shape. Other CRM Task reference types keep their
existing behaviour, including the recorded product decision around CRM records
that carry no company at all.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import current_company


def get_permission_query_conditions(user: str | None = None) -> str:
	"""Hide another company's Capture tasks from collection GET."""
	user = user or frappe.session.user
	if user == "Administrator":
		return ""
	company = frappe.db.escape(current_company())
	return f"""
		(
			COALESCE(`tabCRM Task`.`reference_doctype`, '') != 'Capture'
			OR EXISTS (
				SELECT 1
				FROM `tabCapture`
				WHERE `tabCapture`.`name` = `tabCRM Task`.`reference_docname`
				  AND `tabCapture`.`company` = {company}
			)
		)
	"""


def has_permission(doc, ptype: str, user: str | None = None, debug: bool = False) -> bool:
	"""Apply the same boundary to named GET and document operations."""
	del ptype, debug
	user = user or frappe.session.user
	if user == "Administrator" or doc.reference_doctype != "Capture":
		return True
	company = frappe.db.get_value("Capture", doc.reference_docname, "company")
	return bool(company) and company == current_company()
