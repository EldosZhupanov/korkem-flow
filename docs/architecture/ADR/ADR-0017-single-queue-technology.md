# ADR-0017 — Why Redis/RQ Is the Only Queue Technology

**Status:** Accepted
**Date:** 2026-07-27

## Context

`report_erpnext.md` confirms ERPNext already uses Redis-backed RQ workers via `frappe.enqueue` for BOM cost recalculation, stock-ledger reposting, and bulk transaction processing. `04_system_architecture.md` §14 extends this same mechanism to the AI Orchestrator and Notification Service's own background job needs, explicitly rejecting a second broker technology (Kafka/RabbitMQ).

## Problem Statement

The AI Orchestrator and Notification Service each need background job processing (agent turn processing, notification delivery). The default instinct in a multi-service architecture is often to introduce a dedicated message broker for inter-service communication, separate from whatever the "legacy" bench already uses — resulting in two queue technologies to operate, monitor, and secure.

## Decision

Redis-backed RQ (Frappe's existing mechanism) is the only queue/broker technology in this platform. The AI Orchestrator and Notification Service reuse the same Redis instance/infrastructure the bench already requires, rather than introducing Kafka, RabbitMQ, or any second broker.

## Alternatives Considered

1. Introduce Kafka or RabbitMQ as a dedicated inter-service message bus, alongside Frappe's own Redis/RQ for bench-internal jobs.
2. Reuse Frappe's existing Redis/RQ for all queueing needs platform-wide (chosen).

## Pros

- One operational surface to monitor, secure, and scale instead of two.
- Redis is already a hard dependency of the Frappe bench — no new infrastructure is introduced at all.
- Job semantics (enqueue, retry, dead-letter handling) only need to be understood once across the whole platform.

## Cons

- Redis/RQ is a simpler queue model than Kafka (no durable log/replay semantics, no consumer-group fan-out at Kafka's scale) — acceptable given none of this platform's current event volumes or durability requirements demand Kafka-grade guarantees.
- If a genuinely high-throughput, multi-consumer streaming need emerges later, RQ may not be sufficient and would need re-evaluation.

## Trade-offs

Simplicity and zero new infrastructure are chosen over Kafka's more powerful (but currently unneeded) durability and fan-out guarantees — a clear case of not building for a scale that isn't evidenced yet.

## Rejected Alternatives

- **Kafka/RabbitMQ as a second broker**: rejected — no current requirement (message volume, consumer fan-out, replay/durability needs) evidences a need beyond what Redis/RQ already provides; introducing it now would be pure speculative infrastructure, directly against this platform's stated aversion to over-engineering (see `04_system_architecture.md` §22).

## Consequences

- All background job code (bench-internal, AI Orchestrator, Notification Service) shares one operational runbook for queue monitoring/alerting (a Phase 13 Deployment Architecture concern).

## Implementation Constraints

No service may introduce a second message-queue client library or broker dependency without a superseding ADR justified by concrete, measured throughput/durability requirements.

## Future Implications

If a future need for durable event replay or very high-throughput fan-out is evidenced (not merely anticipated), that would warrant a dedicated ADR re-evaluating this decision — not a quiet addition of a second broker alongside it.

## Related ADRs

ADR-0006, ADR-0009.

## Review Notes

Directly consistent with `04_system_architecture.md` §14/§22; no contradiction found.
