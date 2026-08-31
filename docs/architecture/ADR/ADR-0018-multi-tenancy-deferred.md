# ADR-0018 — Why Multi-Tenancy Is Deferred

**Status:** Accepted
**Date:** 2026-07-27

## Context

`PROJECT.md`'s Long-Term Expansion envisions growth from furniture into wood/metal/construction manufacturing generally, implying eventual multi-company or multi-tenant use. `04_system_architecture.md` §20 chooses vertical scaling first (one bench, one site, horizontally-scaled RQ workers) and explicitly defers multi-tenant architecture.

## Problem Statement

Designing for multi-tenancy upfront (e.g. per-tenant data isolation within a shared bench, or automated per-tenant bench provisioning) is a significant architectural commitment that shapes data modeling, permissions, and deployment from day one. Committing to a specific multi-tenancy strategy now, before a second tenant (a second factory/company) is a real, concrete requirement, risks over-engineering for a scale that may never materialize in the assumed shape, or under-engineering for the shape it actually takes.

## Decision

Multi-tenancy is explicitly out of scope for the current architecture. The platform is designed for one company (KORKEM) on one Frappe bench. When a second tenant becomes a real requirement, the choice between "one bench per tenant" versus "shared bench with tenant scoping" is made then, with real requirements in hand — not guessed now.

## Alternatives Considered

1. Design in-bench tenant scoping now (shared database, tenant-scoped queries/permissions) in anticipation of future multi-company use.
2. Design for "one bench per tenant" now (fully isolated deployments per company).
3. Defer the decision entirely; build for single-tenant use now (chosen).

## Pros

- Avoids committing to a specific multi-tenancy shape before real requirements (how many tenants, how much cross-tenant data sharing, if any) are known.
- Keeps the current architecture simpler and faster to implement and reason about.
- ERPNext/Frappe CRM themselves already assume a fairly single-company-centric context in several places (confirmed in `report_erpnext.md`'s domain model, e.g. Company-scoped Work Orders) — fighting that assumption prematurely would add complexity without a concrete second tenant to validate the design against.

## Cons

- If multi-tenancy is needed sooner than expected, some rework may be required (e.g. retrofitting tenant scoping onto doctypes not designed with it in mind).
- Some future features (e.g. a shared decor/supplier catalog across multiple factories) may be harder to retrofit than if designed for from the start.

## Trade-offs

The risk of some future rework is accepted in exchange for not carrying unused multi-tenancy complexity through every current design decision (data model, permissions, deployment) for a requirement that isn't concrete yet.

## Rejected Alternatives

- **In-bench tenant scoping now**: rejected — no second tenant exists to validate the design against; premature abstraction risk is high given ERPNext/CRM's existing single-company-centric assumptions.
- **One-bench-per-tenant now**: rejected — same reasoning; also implies provisioning/deployment automation work with no current second tenant to justify it.

## Consequences

- Data modeling and deployment decisions in Phases 05-13 should not silently assume single-tenancy will hold forever, but they also should not be complicated by hypothetical multi-tenant requirements not yet specified.

## Implementation Constraints

None imposed now; this is explicitly a deferred decision, not a constraint on current implementation.

## Future Implications

When a second tenant becomes real, this ADR should be explicitly superseded by a new one that chooses a concrete multi-tenancy strategy based on that tenant's actual requirements.

## Related ADRs

ADR-0001, ADR-0002 (both assume single-bench operation currently).

## Review Notes

Explicitly framed as a deferral, not a permanent rejection — flagged so a future reader doesn't mistake "not now" for "never."
