# ADR-0001 — Why ERPNext is the Source of Truth for Manufacturing & Materials

**Status:** Accepted
**Date:** 2026-07-27

## Context

`domain_model.md` assigns the Manufacturing and Materials & Warehouse bounded contexts to ERPNext (`Work Order`, `BOM`, `Job Card`, `Item`, `Warehouse`, `Stock Entry`), extended by new custom Frappe apps rather than replaced. `report_erpnext.md` confirmed this domain model is mature: the Sales Order → Work Order → BOM → Job Card → Stock Entry chain is backed by real, evidenced business-rule pipelines (`validate()` methods with 15-20 sub-validators each) and a generic, stable API surface.

## Problem Statement

The platform needs exactly one authoritative place for production-order and inventory facts. Without a declared source of truth, KORKEM-specific code (Facade Item, Decor, stage tracking) risks silently re-deriving or duplicating what ERPNext already computes correctly (stock levels, BOM costing, work-order status), reintroducing the class of bug `PROJECT.md`'s Data Philosophy explicitly forbids ("never duplicate data").

## Decision

ERPNext (`Work Order`, `BOM`, `Job Card`, `Item`, `Warehouse`, `Stock Entry`, plus the four new custom apps layered on top) is the single source of truth for all manufacturing and inventory data on this platform. No other service may persist a parallel copy of this data; all reads/writes go through it.

## Alternatives Considered

1. Build a bespoke manufacturing/inventory schema from scratch for KORKEM.
2. Adopt Relaticle's data model as the manufacturing owner.
3. Adopt a different open-source ERP not present in this workspace (e.g. Odoo).
4. Use ERPNext as-is (chosen).

## Pros

- Years of validated business logic (BOM explosion, stock valuation, work-order lifecycle) reused for free.
- Confirmed generic, stable CRUD API (`report_erpnext.md`) already suitable for AI/automation access.
- Dual-database (MariaDB/Postgres) discipline already engineered and CI-enforced upstream.
- Native RBAC and background-job infrastructure already proven at ERP scale.

## Cons

- Confirmed maintainability debt: several multi-thousand-line procedural controller files (`stock_ledger.py`, `serial_and_batch_bundle.py`) that this platform cannot refactor (they're upstream code).
- Framework lock-in to Frappe/Python/MariaDB-or-Postgres.
- ERPNext's own release cadence and breaking changes must be tracked.

## Trade-offs

Reuse maturity is weighed against inherited code-quality debt. The debt is accepted because it lives entirely upstream — this platform only calls ERPNext's API surface, it does not inherit or need to maintain the internals of `stock_ledger.py` itself.

## Rejected Alternatives

- **Bespoke schema from scratch**: rejected — reinvents a decade of validated manufacturing business rules for no evidenced benefit, directly against the Primary Rule in `master_execution_prompt.md`.
- **Relaticle as manufacturing owner**: rejected — confirmed zero manufacturing/production/inventory concepts exist anywhere in Relaticle's codebase (verified by direct grep during domain-model research).
- **A different ERP (e.g. Odoo)**: rejected — not part of the workspace, would require net-new research and integration work with no advantage over the already-vendored, already-researched ERPNext.

## Consequences

- The platform inherits ERPNext's dual-DB compatibility constraints if self-hosting the bench.
- Every manufacturing feature request must first be checked against existing ERPNext doctypes before any new entity is proposed (already the discipline enforced in `domain_model.md`).
- Upstream ERPNext security/bugfix updates must be tracked and applied to the bench.

## Implementation Constraints

All manufacturing/inventory writes go through ERPNext's whitelisted API or the new custom apps' doctypes — never direct database access, never a bypass of `frappe.has_permission`.

## Future Implications

Multi-vertical expansion (furniture → wood → metal → construction, per `PROJECT.md`) remains viable because ERPNext's manufacturing model is generic, not furniture-specific — extending it for a new vertical means new custom-app doctypes, not replacing the core.

## Related ADRs

ADR-0002 (Frappe as platform), ADR-0004 (custom apps over forks), ADR-0010 (plugin architecture).

## Review Notes

Consistent with `domain_model.md` §2 Ownership Map and §17 Rejected Entities. No contradiction found with any other ADR in this set as of the collective validation pass (see `ADR/README.md`).
