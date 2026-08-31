# ADR-0002 — Why Frappe Framework Remains the Application Platform

**Status:** Accepted
**Date:** 2026-07-27

## Context

ERPNext and Frappe CRM both run on the Frappe framework, sharing one bench, one database, one permission model, and — critically — an already-live integration bridge between them (CRM Deal auto-creates ERPNext Customer; CRM Product syncs with ERPNext Item). `report_erpnext.md` confirms the framework exposes a generic, doctype-agnostic CRUD API (`frappe/frappe/client.py`, `/api/resource/*`) plus native RBAC, background jobs (`frappe.enqueue`), and realtime pub/sub (`frappe.publish_realtime`).

## Problem Statement

Having chosen ERPNext and Frappe CRM as sources of truth (ADR-0001), the platform needs an application/runtime platform to extend them on. Building a separate backend stack alongside them would mean re-solving persistence, permissions, sync, and background-job infrastructure that Frappe already provides working and proven.

## Decision

Frappe remains the application platform for all transactional business data, permissions, and the internal (non-public) API. New business capability is added as new custom Frappe apps on the same bench, not a parallel backend framework.

## Alternatives Considered

1. A fresh custom backend (Node.js, Django, etc.) with its own schema, syncing to ERPNext/CRM as needed.
2. Frappe only for ERPNext/CRM, with all new (KORKEM-specific) logic in a separate stack.
3. Frappe throughout, including new custom apps (chosen).

## Pros

- Reuses a confirmed-generic, confirmed-stable API surface rather than building a new one.
- Native RBAC (role + per-doctype permission + `permlevel`) already proven and directly reusable for AI-agent permission scoping (see ADR-0013).
- Native background-job and realtime infrastructure removes the need to stand up new messaging infrastructure (see ADR-0009, ADR-0017).
- Frappe's own extension convention (Custom Field, Custom DocType, `hooks.py`) is exactly the mechanism needed to add KORKEM-specific entities without forking ERPNext/CRM (see ADR-0004).

## Cons

- Framework lock-in: Python 3.14+, MariaDB-or-Postgres, Frappe's own ORM-like Document pattern.
- Steep learning curve for engineers unfamiliar with Frappe conventions (confirmed maintainability concern in `report_erpnext.md`).
- Frappe's own Desk UI is legacy-feeling — irrelevant here since the platform builds its own frontend (see Phase 15, UI Architecture) and never exposes Desk to end users.

## Trade-offs

Framework lock-in is accepted in exchange for not re-implementing persistence, permissions, and sync from zero — a cost the reuse-first Primary Rule explicitly asks to avoid paying.

## Rejected Alternatives

- **Fresh custom backend**: rejected — would duplicate CRM/ERPNext's already-solved persistence, permissions, sync, and background-job handling, directly against the Primary Rule.
- **Frappe only for ERPNext/CRM, separate stack for new logic**: rejected — would immediately create the "two sources of truth" problem `domain_model.md`'s invariants explicitly forbid, and would need its own sync layer to stay consistent with the bench.

## Consequences

- All new engineering hires/contributors need Frappe framework fluency (custom doctypes, hooks, permissions) as a baseline skill.
- The platform's ceiling for backend flexibility is bounded by what Frappe's app model supports — acceptable, since nothing in the domain model or KORKEM spec requires capability Frappe doesn't already offer.

## Implementation Constraints

New business logic is added via Frappe custom apps (`korkem_manufacturing`, `korkem_workforce`, `korkem_documents`, `korkem_ai`) using Custom DocTypes/Custom Fields and `hooks.py` — never by editing `erpnext/`, `frappe/`, or `crm/` source directly (see ADR-0004).

## Future Implications

Frappe's own scaling model (multiple bench workers, Redis-backed queues) is inherited as this platform's scaling story (see ADR-0018 for the multi-tenancy deferral this implies).

## Related ADRs

ADR-0001, ADR-0004, ADR-0009, ADR-0013, ADR-0017.

## Review Notes

No contradiction with ADR-0001; this ADR specifically addresses the *platform* choice, ADR-0001 the *data ownership* choice — they are complementary, not overlapping decisions.
