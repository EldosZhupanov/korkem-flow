# ADR-0006 — Why Event-Driven Communication Is Required

**Status:** Accepted
**Date:** 2026-07-27

## Context

`domain_model.md` §11 catalogs domain events (`ProductionOrderStageCompleted`, `RestockThresholdBreached`, `PendingActionApproved`, etc.). `04_system_architecture.md` §8 carries these via two already-native Frappe mechanisms: `frappe.publish_realtime` (websocket pub/sub, confirmed used by ERPNext itself for stock-reposting progress) for live UI updates, and `frappe.enqueue` (Redis-backed background jobs, confirmed used by ERPNext for BOM cost recalculation) for asynchronous processing.

## Problem Statement

Several operations in this domain are either slow/unreliable (third-party WhatsApp API calls), naturally decoupled in time from their trigger (a restock scan doesn't need to run synchronously with every stock movement), or need to reach multiple observers without the triggering code knowing about them in advance (a stage completion should update the live Orders Table *and* potentially trigger a notification *and* potentially feed AI agent context). A purely synchronous, direct-call architecture would either block user-facing requests on slow operations or force every producer to know about every consumer.

## Decision

Domain events are published via Frappe's native realtime/queue mechanisms rather than direct synchronous calls between producer and consumer. This is "event-driven communication" in the pragmatic sense (decoupled pub/sub + background jobs) — explicitly **not** full event sourcing (see Rejected Alternatives).

## Alternatives Considered

1. Pure synchronous call chains (producer directly calls every consumer inline).
2. Event-driven via Frappe's native realtime + enqueue mechanisms (chosen).
3. Full event sourcing with a dedicated event store as the system of record.

## Pros

- Decouples slow/unreliable operations (WhatsApp send) from the request that triggers them.
- Enables genuinely live UI (stage completion pushed instantly to the Orders Table via websocket) without polling.
- No new infrastructure required — reuses mechanisms ERPNext itself already proves reliable at scale.

## Cons

- Eventual consistency window between an event firing and its downstream effect completing (e.g. a WhatsApp notification may arrive a few seconds after the status change, not instantaneously).
- Requires idempotent job handlers, since queued jobs can in principle be retried.

## Trade-offs

A small eventual-consistency window is accepted in exchange for never letting a third-party API's latency or failure block a user-facing request — judged clearly favorable since no requirement in `domain_model.md`/`korkem_flow_spec.md` demands synchronous, guaranteed-instant notification delivery.

## Rejected Alternatives

- **Pure synchronous call chains**: rejected — a slow WhatsApp API call would directly block the request that marks an order `Ready`, and every event producer would need hardcoded knowledge of every consumer, growing more tangled as automation opportunities (`domain_model.md` §16) are added over time.
- **Full event sourcing / dedicated event store**: rejected — no evidenced requirement for event replay or time-travel debugging at this stage; Frappe's own change-tracking (doc versions, Comments, `track_changes`) already provides the auditability `PROJECT.md` requires, without the operational overhead of maintaining an event store as a second system of record. Revisit only if a concrete need for full event replay emerges.

## Consequences

- Every new automation (§16 of the domain model) that reacts to a domain event should be implemented as an `enqueue`d job or a `publish_realtime` subscriber, not a new synchronous inline call inserted into existing controller code.
- Job handlers must be written idempotently from the start, anticipating retries.

## Implementation Constraints

Event names/payloads should stay aligned with the catalog in `domain_model.md` §11; new events introduced during implementation must be added back into that catalog, not left implicit in code.

## Future Implications

If multi-tenant/multi-bench deployment happens later (see ADR-0018), realtime/queue infrastructure would need to be evaluated per-tenant — deliberately out of scope until that future decision point.

## Related ADRs

ADR-0009 (queues mandatory), ADR-0014 (auditability), ADR-0017 (single queue technology).

## Review Notes

Clarifies explicitly that "event-driven" here does not imply event sourcing — this distinction is called out to prevent a future reader from over-interpreting this ADR as license to build event-store infrastructure.
