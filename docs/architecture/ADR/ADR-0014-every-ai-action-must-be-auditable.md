# ADR-0014 — Why Every AI Action Must Be Auditable

**Status:** Accepted
**Date:** 2026-07-27

## Context

`PROJECT.md`'s Data Philosophy states "every change should be auditable" and its Product Philosophy states "Humans supervise. AI operates." The Pending Action mechanism (`domain_model.md`, reused from Relaticle's pattern per ADR-0008) already carries `action_class`, `action_data`, `display_data` (the human-readable diff), `status`, and timestamps.

## Problem Statement

An AI system that can propose changes to production orders, materials, and payroll without a durable, queryable record of what it proposed, when, and what happened to the proposal would make it impossible to answer "why did this change happen" after the fact — a critical failure mode for a system managing real financial and manufacturing outcomes.

## Decision

Every AI-proposed action, whether approved, rejected, or expired, is durably recorded (as a Pending Action doctype record, per ADR-0008/ADR-0012) with enough detail to reconstruct: who/what proposed it, what it would have changed (`display_data`), who resolved it and when, and what the resulting Command execution actually did.

## Alternatives Considered

1. Log AI actions only at the application/infrastructure log level (e.g. text logs), not as durable, queryable business records.
2. Durable, queryable Pending Action records as the audit trail, with lifecycle status (chosen).
3. A separate, dedicated audit-log service distinct from Pending Action.

## Pros

- A manager can query "all AI proposals touching Production Order #103" the same way they'd query any other business record — no separate log-mining tooling required.
- Directly satisfies `PROJECT.md`'s explicit auditability requirement.
- Reuses the Pending Action mechanism already justified in ADR-0008/ADR-0015 rather than building a second audit system alongside it.

## Cons

- Every AI proposal, even trivial ones, adds a durable record — some volume growth to manage over time (mitigated by normal data-retention/archival policy, not an architectural concern).

## Trade-offs

Some storage growth from recording every proposal (even rejected/expired ones) is accepted in exchange for a complete, gap-free audit trail — a rejected proposal is often exactly the record most worth keeping (it shows what the AI *tried* to do and why a human said no).

## Rejected Alternatives

- **Log-level only, not durable business records**: rejected — application logs are not designed for business-level querying/reporting and are typically rotated/discarded, failing the durability auditability requires.
- **Separate dedicated audit-log service**: rejected — would duplicate what Pending Action already captures, and would need its own sync with the Pending Action lifecycle to stay consistent, recreating a dual-source-of-truth problem for no added benefit.

## Consequences

- Pending Action records are never hard-deleted; expired/rejected ones are retained as part of the audit history (subject to normal data-retention policy, a Phase 12/13 concern, not a Phase-04-level one).

## Implementation Constraints

Every Command executed on the AI Orchestrator's behalf must trace back to a Pending Action record; no agent-initiated write may bypass this trail.

## Future Implications

If regulatory/compliance auditing needs grow (e.g. for the payroll domain specifically), this same mechanism is the foundation to build additional reporting on top of — no redesign needed, only new queries.

## Related ADRs

ADR-0008, ADR-0012, ADR-0015, ADR-0006.

## Review Notes

No contradiction with any other ADR; this ADR states the auditability rationale that ADR-0008/ADR-0012's design already structurally supports.
