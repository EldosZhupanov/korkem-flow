# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Analytics and telemetry event tracking for onboarding and production funnel.

Guarantees:
- Strict sanitization: NEVER logs OTP, token, secret or password.
- Lightweight: Stored in Activity Log.
- Guest-friendly: Allows recording early unauthenticated steps.
"""

from __future__ import annotations

import json
import frappe
from frappe.utils import now_datetime

# Whitelist of allowed funnel events
ALLOWED_EVENTS = {
	"onboarding_started",
	"phone_verified",
	"profile_completed",
	"company_created",
	"invite_created",
	"invite_opened",
	"invite_accepted",
	"onboarding_completed",
}

# Redact sensitive parameters
SENSITIVE_KEYS = {"otp", "otp_code", "token", "raw_token", "phone_token", "password", "secret", "api_secret"}


def sanitize_properties(props: dict | None) -> dict:
	"""Remove sensitive credentials and tokens from analytics payload."""
	if not props or not isinstance(props, dict):
		return {}
	sanitized = {}
	for k, v in props.items():
		lower_k = str(k).lower()
		if any(s in lower_k for s in SENSITIVE_KEYS):
			sanitized[k] = "[REDACTED]"
		elif isinstance(v, dict):
			sanitized[k] = sanitize_properties(v)
		else:
			sanitized[k] = v
	return sanitized


def track_event(
	event_name: str,
	*,
	user: str | None = None,
	company: str | None = None,
	properties: dict | None = None,
	reference_doctype: str | None = None,
	reference_name: str | None = None,
) -> str:
	"""Record an analytics event into Activity Log."""
	event_name = (event_name or "").strip().lower()
	if event_name not in ALLOWED_EVENTS:
		# Accept custom event if prefixed with allowed category
		if not event_name.startswith("onboarding_") and not event_name.startswith("invite_"):
			return ""

	user = user or (frappe.session.user if frappe.session else "Guest")
	clean_props = sanitize_properties(properties)
	if company:
		clean_props["company"] = company

	try:
		doc = frappe.get_doc(
			{
				"doctype": "Activity Log",
				"subject": f"[ANALYTICS] {event_name}",
				"content": json.dumps(clean_props, ensure_ascii=False),
				"user": user,
				"reference_doctype": reference_doctype or "",
				"reference_name": reference_name or "",
				"communication_date": now_datetime(),
			}
		)
		doc.insert(ignore_permissions=True)
		frappe.db.commit()
		return doc.name
	except Exception as e:
		frappe.logger("analytics").warning(f"Failed to record event {event_name}: {e}")
		return ""


def get_funnel_summary(company: str | None = None) -> dict:
	"""Retrieve the onboarding & invitation conversion funnel."""
	filters = {"subject": ["like", "%[ANALYTICS] %"]}
	
	events = frappe.get_all(
		"Activity Log",
		filters=filters,
		fields=["subject", "content", "creation"],
		order_by="creation asc",
		limit_page_length=0,
	)

	counts = {event: 0 for event in [
		"onboarding_started",
		"phone_verified",
		"profile_completed",
		"company_created",
		"invite_created",
		"invite_opened",
		"invite_accepted",
		"onboarding_completed",
	]}

	for row in events:
		subject = row.get("subject") or ""
		op = subject.replace("[ANALYTICS] ", "").strip()
		if op in counts:
			# If company filter specified, check content
			if company:
				try:
					content = json.loads(row.get("content") or "{}")
					event_comp = content.get("company")
					if event_comp and event_comp != company:
						continue
				except Exception:
					continue
			counts[op] += 1

	started = counts["onboarding_started"]
	verified = counts["phone_verified"]
	created = counts["company_created"]
	invited = counts["invite_created"]
	accepted = counts["invite_accepted"]

	funnel_steps = [
		{"step": "1. started", "count": started, "conversion": "100%"},
		{
			"step": "2. phone_verified",
			"count": verified,
			"conversion": f"{(verified / started * 100):.1f}%" if started else "0%",
		},
		{
			"step": "3. company_created",
			"count": created,
			"conversion": f"{(created / verified * 100):.1f}%" if verified else "0%",
		},
		{
			"step": "4. first_employee_invited",
			"count": invited,
			"conversion": f"{(invited / created * 100):.1f}%" if created else "0%",
		},
		{
			"step": "5. invite_accepted",
			"count": accepted,
			"conversion": f"{(accepted / invited * 100):.1f}%" if invited else "0%",
		},
	]

	return {
		"raw_counts": counts,
		"funnel": funnel_steps,
	}
