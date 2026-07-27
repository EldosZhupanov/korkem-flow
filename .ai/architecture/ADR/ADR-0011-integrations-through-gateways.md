# ADR-0011 — Why All External Integrations Pass Through Gateways

**Status:** Accepted
**Date:** 2026-07-27

## Context

`04_system_architecture.md` §15 routes WhatsApp and Telegram integrations exclusively through the Notification Service, and all client-facing traffic through the Gateway. `PROJECT.md`'s Integrations list additionally names Google Calendar, Google Drive, Microsoft 365, IoT/CNC Controllers as future integrations. Frappe CRM already has a live precedent for centralizing third-party telephony configuration in dedicated settings doctypes (`crm_twilio_settings`, `crm_exotel_settings`).

## Problem Statement

Without a firm rule, individual features could call third-party APIs (WhatsApp, calendar providers, IoT devices) directly from wherever it's convenient — the Frontend, a Doctype controller, an agent skill — scattering credentials, rate-limit handling, and retry logic across the codebase and making it impossible to centrally audit or throttle external calls.

## Decision

All external, third-party integrations are called only from a designated gateway-layer service (the Notification Service for outbound messaging today; equivalent dedicated services/modules for future integrations) — never directly from the Frontend, Mobile client, or business-logic Doctype controllers.

## Alternatives Considered

1. Allow any service/layer to call third-party APIs directly where convenient.
2. Centralize all third-party calls through dedicated gateway-layer services, following CRM's existing settings-doctype precedent for configuration (chosen).

## Pros

- Single place to manage credentials, rate limits, and retries per integration.
- Centralized audit trail of all outbound external communication — directly supports `PROJECT.md`'s "everything must be traceable" principle.
- Reuses a pattern (settings doctype per integration) already proven in Frappe CRM, rather than inventing a new configuration convention.

## Cons

- Adds one hop of indirection even for simple integrations.
- The gateway-layer service becomes a dependency every integrating feature must route through, rather than calling the third party directly.

## Trade-offs

The added indirection is accepted because credential leakage and untracked external calls are a materially worse outcome than a small latency/complexity cost, especially for a system whose data includes customer contact details and payroll figures.

## Rejected Alternatives

- **Direct third-party calls from any layer**: rejected — leaks credentials to whichever layer makes the call (unacceptable from the Frontend), and produces no centralized audit trail, violating least-privilege (ADR-0013) and auditability (ADR-0014) principles.

## Consequences

- Every new integration (Google Calendar, IoT/CNC Controllers, etc., per `PROJECT.md`) requires a dedicated settings doctype and a gateway-layer service/module before any feature can use it — not an ad hoc client library call.

## Implementation Constraints

New integrations follow the CRM settings-doctype pattern (dedicated configuration doctype + a service that owns the actual outbound call) rather than inventing a new configuration style per integration.

## Future Implications

As more integrations are added (per `PROJECT.md`'s Integrations list), this pattern scales by adding more gateway-layer modules, not by relaxing the "no direct third-party calls" rule.

## Related ADRs

ADR-0006 (event-driven — most integration calls are triggered by domain events), ADR-0013 (least privilege).

## Review Notes

Consistent with `04_system_architecture.md` §15; extends the same reasoning to integrations not yet built, using CRM's already-confirmed precedent.
