# ADR-0021 — Why Frappe CRM (Not Relaticle) Is the Source of Truth for Sales & Relationship Data

**Status:** Accepted
**Date:** 2026-07-27

## Context

`domain_model.md` §2 and §4 assign Customer, Contact, Lead, and Deal to Frappe CRM, explicitly rejecting Relaticle's equivalent `Company`/`People`/`Opportunity` models as redundant. ADR-0001 covers the analogous decision for Manufacturing & Materials but does not itself address Sales & Relationship — this ADR closes that gap, identified during the collective validation pass over ADR-0001 through ADR-0020.

## Problem Statement

Two of the four vendored repos (Frappe CRM and Relaticle) independently model the same real-world concepts: a customer organization, a contact person, and a sales pipeline stage. Without an explicit, justified decision, either could plausibly be chosen as the platform's Sales & Relationship source of truth, and choosing wrong means inheriting the wrong integration surface for the manufacturing backbone.

## Decision

Frappe CRM (`CRM Organization`, core Frappe `Contact`, `CRM Lead`, `CRM Deal`) is the source of truth for all Sales & Relationship data. Relaticle's `Company`, `People`, and `Opportunity` models are not used anywhere in this platform.

## Alternatives Considered

1. Frappe CRM as the Sales & Relationship owner (chosen).
2. Relaticle as the Sales & Relationship owner.
3. A new, bespoke Sales/CRM data model independent of both.

## Pros

- Frappe CRM already runs on the same bench/framework as ERPNext (ADR-0002) and already has a **live, working integration bridge** to it — `CRM Deal.on_update` auto-creates an ERPNext `Customer` (`create_customer_in_erpnext`), and `CRM Product` syncs bidirectionally with ERPNext `Item`. This is a confirmed, evidenced integration, not a theoretical one.
- Frappe CRM's two-stage `CRM Lead → CRM Deal` model maps more precisely onto `PROJECT.md`'s multi-stage pre-production lifecycle ("Lead → Customer Qualification → … → Contract → Deposit") than Relaticle's single-stage `Opportunity`.
- Adopting CRM avoids a second, disconnected implementation of Customer/Contact/Deal that would need its own bridge to ERPNext built from scratch.

## Cons

- Frappe CRM's domain model is narrower in some respects (e.g. no dedicated "Comment" model — uses core Frappe `Comment`) — acceptable, since `domain_model.md`'s Collaboration context already reuses that same core mechanism deliberately (see ADR-0023).
- CRM's Lead has no direct Organization link (only free-text `organization` field until conversion to Deal) — a minor modeling gap inherited as-is rather than patched, since it reflects CRM's actual, confirmed behavior.

## Trade-offs

Choosing CRM over Relaticle for this domain sacrifices Relaticle's more modern Laravel/Eloquent tooling in exchange for an already-proven, already-integrated bridge to the manufacturing backbone — judged decisively in CRM's favor given the manufacturing backbone (ERPNext) was independently chosen in ADR-0001 and CRM already talks to it.

## Rejected Alternatives

- **Relaticle as Sales & Relationship owner**: rejected — would require building a new integration bridge from Relaticle's Laravel/Postgres stack to the ERPNext/Frappe manufacturing backbone from scratch, duplicating work Frappe CRM's existing bridge already does. Also introduces a second runtime/database dependency (Laravel/Postgres alongside Frappe/MariaDB) purely for sales data, contradicting the "one transactional core" decision in `04_system_architecture.md` §1.
- **A new bespoke Sales/CRM model**: rejected — reinvents both Lead/Deal pipeline modeling and the ERPNext integration bridge for no evidenced benefit, directly against the Primary Rule.

## Consequences

- Relaticle's own CRM-facing code (`app/Models/Company.php`, `People.php`, `Opportunity.php`, and their associated Actions) is not ported or referenced anywhere in this platform — only its AI/Chat subsystem (`packages/Chat`) is reused, per ADR-0008/ADR-0012/ADR-0019.
- Any future Sales & Relationship feature request is evaluated against Frappe CRM's existing doctypes first, per the reuse-first discipline already established.

## Implementation Constraints

Sales & Relationship writes go through Frappe CRM's doctypes and the existing CRM↔ERPNext sync hooks — extended (e.g. adding `originating_deal` propagation onto Work Order, per `domain_model.md` §3.4) rather than rebuilt.

## Future Implications

If a future vertical or tenant genuinely needs Relaticle's specific CRM UX/features that CRM lacks, that would require its own ADR evaluating a *targeted* feature port — not a wholesale replacement of the Sales & Relationship source of truth established here.

## Related ADRs

ADR-0001 (the analogous decision for Manufacturing & Materials), ADR-0004, ADR-0023.

## Review Notes

Identified as a gap during the collective validation pass: ADR-0001's title and scope covered ERPNext/manufacturing only, leaving the equally load-bearing CRM-vs-Relaticle decision undocumented. This ADR closes that gap.
