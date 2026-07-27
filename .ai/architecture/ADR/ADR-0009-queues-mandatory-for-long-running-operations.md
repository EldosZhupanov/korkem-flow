# ADR-0009 — Why Queues Are Mandatory for Long-Running Operations

**Status:** Accepted
**Date:** 2026-07-27

## Context

`04_system_architecture.md` §13-14 classifies WhatsApp/Telegram sends, material-consumption reconciliation, restock scanning, and payroll-period closing as asynchronous, enqueued operations — reusing Frappe's confirmed `frappe.enqueue` (Redis-backed RQ) mechanism, the same one ERPNext itself uses for BOM cost recalculation and stock-ledger reposting.

## Problem Statement

Several operations in this domain either depend on unreliable third-party services (WhatsApp Business API) or process non-trivial volumes of data (payroll period aggregation across many employees, stock reposting across many items). Executing these synchronously within a user-facing request risks blocking that request on unpredictable external latency or on a slow batch computation, degrading the "modern, fast, zero clutter" UX principle in `PROJECT.md`.

## Decision

Any operation with unbounded, third-party-dependent, or batch-scale latency must be executed via a queued background job (`frappe.enqueue`), never called synchronously inline from a request handler.

## Alternatives Considered

1. Call all operations synchronously inline, accepting variable request latency.
2. Queue only the operations empirically found to be slow, decided case by case.
3. Queue by rule, for a defined category of operation (third-party calls, batch aggregation, scheduled scans) — decided upfront (chosen).

## Pros

- User-facing requests never block on WhatsApp API latency or large batch computations.
- Matches an already-proven pattern (ERPNext's own use of `frappe.enqueue` for exactly this class of operation).
- Predictable, reviewable rule for engineers: "if it's third-party or batch-scale, it's a queued job" — no case-by-case judgment calls needed later.

## Cons

- Introduces eventual consistency for these operations (see ADR-0006).
- Requires idempotent, retry-safe job handlers.
- Adds operational surface (job monitoring/failure alerting) that must be maintained.

## Trade-offs

A small, well-understood set of operations move from synchronous to asynchronous, trading a moment of eventual consistency for guaranteed responsiveness of the primary user-facing request path — a clearly favorable trade for a shop-floor tool where workers are actively interacting with the UI.

## Rejected Alternatives

- **Call everything synchronously**: rejected — direct risk of the UI freezing on a slow WhatsApp call or a large payroll aggregation, unacceptable for a tool `PROJECT.md` explicitly wants to feel like Linear/Notion-grade fast.
- **Decide queuing case by case as problems are found**: rejected — reactive rather than architectural; would allow inconsistent handling of equivalent operations and rediscovering the same latency problem repeatedly during implementation.

## Consequences

- Every new feature touching a third-party integration or batch computation must be designed with a queued-job boundary from the start, not retrofitted later.
- Job failure handling/monitoring becomes a first-class operational concern (see Phase 13, Deployment Architecture, and Phase 14, Performance Architecture).

## Implementation Constraints

Only Frappe's native `frappe.enqueue`/RQ mechanism is used (see ADR-0017 — no second queue technology). Job handlers must be idempotent.

## Future Implications

As volume grows, RQ worker count scales horizontally (already Frappe's native scaling model) — no architecture change required, only more worker processes.

## Related ADRs

ADR-0006 (event-driven communication, which this ADR's queues implement), ADR-0017 (single queue technology).

## Review Notes

Directly consistent with `04_system_architecture.md` §13-14; no new claims introduced beyond formalizing the existing decision with fuller alternatives analysis.
