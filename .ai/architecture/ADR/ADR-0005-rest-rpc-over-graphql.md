# ADR-0005 — Why REST/RPC Is Selected and GraphQL Is Rejected

**Status:** Accepted
**Date:** 2026-07-27

## Context

`04_system_architecture.md` §7 defines the Gateway API as one endpoint per Command/Query already cataloged in `domain_model.md` §12-13 (`GetOrdersTable`, `GetOrderDetail`, `ConvertDealToProductionOrder`, etc.). This mirrors Frappe's own native API style (`/api/resource/*`, whitelisted RPC), which `report_erpnext.md` confirmed is generic and stable.

## Problem Statement

The platform's clients (web frontend, shop-floor mobile/PWA, Telegram) have different data-shaping needs — a compact Orders Table view versus a full Order Detail drawer versus a minimal mobile task list. A general-purpose query layer (GraphQL) would let each client shape its own response, but introduces a schema-stitching paradigm layered on top of an already REST-shaped underlying API.

## Decision

The Gateway API is REST/RPC-style, with one endpoint per Command/Query already defined in the domain model (compact vs. detailed variants defined explicitly where needed, e.g. `GetOrdersTable` with a compact/full toggle). GraphQL is rejected for this platform's Gateway layer.

## Alternatives Considered

1. GraphQL Gateway with a unified schema over all entities.
2. REST/RPC Gateway, 1:1 with the Command/Query catalog (chosen).
3. A hybrid — REST for commands, GraphQL for queries only.

## Pros

- Endpoint-level permission checks map directly onto Frappe's own doctype-level permission model — no separate field-level authorization layer needed, which a general GraphQL schema would otherwise require to prevent over-fetching sensitive fields (e.g. financials on a Shop Sheet view).
- Simpler caching: each endpoint has a well-defined cache key and TTL, versus GraphQL's more complex per-field/per-query caching story.
- No new query paradigm/tooling (schema registry, resolver layer) needs to be learned or maintained by the team.
- Matches Frappe's own native API shape, avoiding an impedance-mismatch translation layer.

## Cons

- Less flexible for client-driven response shaping — a new client-specific view requires a new (or parameterized) endpoint rather than an arbitrary client-composed query.
- Risk of endpoint proliferation if client needs diverge significantly over time.

## Trade-offs

Flexibility is traded for security-boundary simplicity and lower operational complexity. This is judged acceptable because the domain model's Command/Query catalog is already a closed, well-understood, finite set of operations — not an open-ended reporting surface where GraphQL's flexibility would pay for itself.

## Rejected Alternatives

- **Full GraphQL Gateway**: rejected — adds a schema-stitching layer over an already REST-shaped underlying API for a flexibility benefit that isn't evidenced as needed; revisit only if concrete over/under-fetching problems are measured in production.
- **Hybrid REST+GraphQL**: rejected — introduces two paradigms to secure, cache, and maintain instead of one, without a clear boundary rule for which new features go where.

## Consequences

- New client-facing data needs require a new or extended Gateway endpoint (and a corresponding Command/Query addition to `domain_model.md` if it's a new logical operation) — not an ad hoc client-side query.
- Endpoint growth should be monitored; if it becomes unwieldy, this ADR should be revisited with concrete evidence, not assumption.

## Implementation Constraints

Every Gateway endpoint must correspond to an entry in `domain_model.md` §12-13; no endpoint should exist that isn't backed by a cataloged Command or Query.

## Future Implications

If a genuinely flexible, client-driven query need emerges (e.g. a future analytics/BI tool needing ad hoc queries), it should be evaluated as a narrowly-scoped addition (e.g. a dedicated reporting endpoint or read-replica query tool), not a wholesale migration of the whole Gateway to GraphQL.

## Related ADRs

ADR-0002 (Frappe platform, whose native API shape this decision mirrors), ADR-0011 (integrations through gateways).

## Review Notes

No contradiction with any other ADR. Explicitly listed as a rejected alternative in `04_system_architecture.md` §22 already — this ADR formalizes that decision with fuller alternatives analysis.
