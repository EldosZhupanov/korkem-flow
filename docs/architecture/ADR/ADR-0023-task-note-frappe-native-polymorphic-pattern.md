# ADR-0023 — Why Task/Note Reuse Frappe's Native Polymorphic Pattern, Not Relaticle's

**Status:** Accepted
**Date:** 2026-07-27

## Context

`domain_model.md` §4 identifies that Task and Note are each solved twice, independently: Frappe CRM (`CRM Task`, `FCRM Note`, via the `reference_doctype`+`reference_docname` "Dynamic Link" pattern) and Relaticle (`Task`, `Note`, via Laravel's `morphToMany` polymorphic relations on a `taskable`/`noteable` pivot). The domain model chose CRM's pattern as canonical; this ADR formalizes that choice, identified as a gap during the collective validation pass since it wasn't yet documented as its own architectural decision.

## Problem Statement

Both implementations solve the identical structural problem (a Task or Note attaching to any one of several entity types) with genuinely equivalent design quality — this is not a case of one being obviously more mature than the other, unlike the Customer/Deal decision (ADR-0021). Without an explicit decision, either could be defensibly chosen, and choosing inconsistently across the platform (e.g. CRM's pattern for CRM-originated entities, Relaticle's for others) would fragment the data plane.

## Decision

Task and Note are modeled once, using Frappe's native `reference_doctype` (Link → DocType) + `reference_docname` (Dynamic Link) pattern — reusing the `CRM Task`/`FCRM Note` doctypes as-is, with their valid target-doctype list extended to include `Work Order` and other new entities as needed. Relaticle's `Task`/`Note` Eloquent models are not used anywhere in this platform.

## Alternatives Considered

1. Reuse CRM's Frappe-native polymorphic Task/Note pattern (chosen).
2. Reuse Relaticle's Laravel `morphToMany` Task/Note pattern.
3. Build a third, new implementation independent of both.

## Pros

- CRM's pattern already runs on the same bench/framework as ERPNext (ADR-0002) and Frappe CRM (ADR-0021) — a Task attached to a `Work Order` or a `CRM Deal` uses the exact same mechanism, with no cross-runtime translation needed.
- Frappe's `reference_doctype`/`reference_docname` pattern is framework-native, meaning any *future* doctype (in any custom app) automatically becomes a valid Task/Note target without new pivot-table migrations — Relaticle's `morphToMany` requires a new pivot relationship wired up per target model.
- Avoids a second runtime dependency (Laravel/Postgres) purely for task/note data, consistent with the "one transactional core" decision (`04_system_architecture.md` §1).

## Cons

- Frappe's Dynamic Link pattern is slightly less type-safe at the ORM level than Laravel's `morphToMany` (relies on a string doctype name + string document name pair rather than a strongly-typed pivot relation) — accepted as a standard, well-understood Frappe idiom rather than a platform-specific weakness.

## Trade-offs

Relaticle's marginally more type-safe pivot-relation approach is traded for zero cross-runtime friction and automatic extensibility to new doctypes — decisively in favor of the Frappe-native pattern given every entity Task/Note needs to attach to (Production Order, Deal, Customer) already lives in the Frappe bench (ADR-0001, ADR-0002, ADR-0021).

## Rejected Alternatives

- **Relaticle's `morphToMany` pattern**: rejected — would require either running Task/Note data in Relaticle's Laravel/Postgres stack (reintroducing a second transactional core, directly against `04_system_architecture.md` §1) or reimplementing the same `morphToMany` semantics natively in Frappe, which is simply reinventing what `reference_doctype`/`reference_docname` already provides.
- **A third, new implementation**: rejected — both existing implementations are mature and evidenced; building a third would violate the Primary Rule with no justification.

## Consequences

- Every new custom-app doctype that should be Task/Note-attachable (e.g. `Work Order`, `Payroll Period`) must be added to the valid `reference_doctype` target list — a small, explicit registration step per new entity, not automatic.

## Implementation Constraints

No Task/Note data is ever stored in a Relaticle-originated table structure; all Task/Note records are `CRM Task`/`FCRM Note` Frappe doctype records.

## Future Implications

If a future entity needs Task/Note attachment, extending the target list is additive and low-risk — no schema migration comparable to adding a new Laravel pivot table is required.

## Related ADRs

ADR-0002, ADR-0021 (this ADR extends that decision's reasoning to Task/Note specifically).

## Review Notes

Identified as a gap during the collective validation pass — `domain_model.md` §4's merge decision for Task/Note existed informally; this ADR gives it the full alternatives/trade-off treatment applied to every other decision in this set.
