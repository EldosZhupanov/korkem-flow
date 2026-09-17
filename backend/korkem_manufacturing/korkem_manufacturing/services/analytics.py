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

	# Extract role-specific counts where possible
	owner_started = counts["onboarding_started"]
	owner_phone_verified = min(counts["phone_verified"], max(1, owner_started)) if owner_started else 0
	owner_profile = min(counts["profile_completed"], max(1, owner_phone_verified)) if owner_phone_verified else 0
	owner_company = min(counts["company_created"], max(1, owner_profile)) if owner_profile else 0
	owner_completed = min(counts["onboarding_completed"], max(1, owner_company)) if owner_company else 0

	owner_funnel = [
		{"step": "owner_onboarding_started", "count": owner_started, "conversion": "100.0%"},
		{
			"step": "phone_verified",
			"count": owner_phone_verified,
			"conversion": f"{(owner_phone_verified / max(1, owner_started) * 100):.1f}%",
		},
		{
			"step": "profile_completed",
			"count": owner_profile,
			"conversion": f"{(owner_profile / max(1, owner_phone_verified) * 100):.1f}%",
		},
		{
			"step": "company_created",
			"count": owner_company,
			"conversion": f"{(owner_company / max(1, owner_profile) * 100):.1f}%",
		},
		{
			"step": "owner_onboarding_completed",
			"count": owner_completed,
			"conversion": f"{(owner_completed / max(1, owner_company) * 100):.1f}%",
		},
	]

	invites_created = counts["invite_created"]
	invites_opened = min(counts["invite_opened"], max(1, invites_created)) if invites_created else 0
	emp_verified = min(counts["phone_verified"], max(1, invites_opened)) if invites_opened else 0
	invites_accepted = min(counts["invite_accepted"], max(1, emp_verified)) if emp_verified else 0
	emp_completed = min(counts["onboarding_completed"], max(1, invites_accepted)) if invites_accepted else 0

	employee_funnel = [
		{"step": "invites_created", "count": invites_created, "conversion": "100.0%"},
		{
			"step": "invites_opened",
			"count": invites_opened,
			"conversion": f"{(invites_opened / max(1, invites_created) * 100):.1f}%",
		},
		{
			"step": "phone_verified",
			"count": emp_verified,
			"conversion": f"{(emp_verified / max(1, invites_opened) * 100):.1f}%",
		},
		{
			"step": "invites_accepted",
			"count": invites_accepted,
			"conversion": f"{(invites_accepted / max(1, emp_verified) * 100):.1f}%",
		},
		{
			"step": "employee_onboarding_completed",
			"count": emp_completed,
			"conversion": f"{(emp_completed / max(1, invites_accepted) * 100):.1f}%",
		},
	]

	companies_count = max(1, counts["company_created"])
	team_activity = {
		"companies_count": counts["company_created"],
		"total_invites_created": invites_created,
		"total_invites_accepted": invites_accepted,
		"invites_created_per_company": round(invites_created / companies_count, 2) if counts["company_created"] else 0.0,
		"accepted_invites_per_company": round(invites_accepted / companies_count, 2) if counts["company_created"] else 0.0,
		"overall_acceptance_rate": f"{(invites_accepted / max(1, invites_created) * 100):.1f}%" if invites_created else "0.0%",
	}

	return {
		"raw_counts": counts,
		"owner_funnel": owner_funnel,
		"employee_invite_funnel": employee_funnel,
		"team_activity": team_activity,
	}
