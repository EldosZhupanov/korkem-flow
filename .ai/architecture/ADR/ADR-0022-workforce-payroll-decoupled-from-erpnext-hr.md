# ADR-0022 — Why Workforce & Payroll Is a New Custom App, Decoupled from ERPNext HR

**Status:** Accepted
**Date:** 2026-07-27

## Context

`domain_model.md` §17 flags that ERPNext's HR module (which would normally own an `Employee` doctype) was never confirmed present in the vendored `erpnext/` snapshot studied in `report_erpnext.md` — that research pass explicitly scoped out HR. Rather than leaving Employee/Payroll design blocked on this unresolved evidence gap, `domain_model.md` decided to build a lightweight, KORKEM-owned Workforce & Payroll subsystem instead. This ADR formalizes that decision, identified during the collective validation pass as a distinct, irreversible choice not yet covered by ADR-0001 or ADR-0004.

## Problem Statement

Two paths were available: (a) assume/confirm ERPNext HR exists and build Workforce/Payroll as an extension of it (consistent with ADR-0001's general "extend ERPNext" preference for anything ERPNext already solves), or (b) build a new, independent, KORKEM-scoped Employee/Payroll model decoupled from ERPNext HR entirely. Choosing (a) without confirming HR's presence would be exactly the kind of guess this project's "never guess, investigate" discipline forbids; blocking all Workforce/Payroll design indefinitely on that unresolved fact would stall a core part of the KORKEM spec (bonus/salary/advance management) with no forward progress.

## Decision

Workforce & Payroll (Employee, Role, Work Assignment, Bonus Rule, Advance, Defect Penalty, Payroll Period) is implemented as a new, independent `korkem_workforce` custom Frappe app, decoupled from ERPNext's HR module regardless of whether that module is confirmed present. If ERPNext HR is later confirmed present, reconciling the two becomes its own deliberate future decision — not a default assumption now.

## Alternatives Considered

1. Assume ERPNext HR exists and design Workforce/Payroll as an extension of it.
2. Block Workforce/Payroll design entirely until ERPNext HR's presence is verified.
3. Build a new, independent, KORKEM-scoped Workforce/Payroll subsystem now, decoupled from ERPNext HR (chosen).

## Pros

- Makes forward progress on a core KORKEM requirement (shop-floor bonus/salary/advance tracking) without waiting on an unresolved evidence gap.
- ERPNext HR, where it exists, is typically scoped for full statutory payroll compliance (tax withholding, leave management, full HR lifecycle) — a much heavier surface than KORKEM's actual need (daily/monthly area-based bonus targets, cash advances, defect penalties, PIN-based shop-floor identity). Building lightweight avoids importing that complexity prematurely.
- Keeps the "never guess" discipline intact: the decision doesn't pretend HR's presence is confirmed when it isn't.

## Cons

- If ERPNext HR does turn out to be present and heavily used elsewhere in a future integration, KORKEM's `Employee` doctype and ERPNext's `Employee` doctype (if it exists) would be two separate records for the same real person, requiring a deliberate reconciliation/linking decision later.
- Some payroll concepts (tax, statutory compliance) that a full HR module would provide are explicitly out of scope for `korkem_workforce` and would need to be added later if ever required.

## Trade-offs

The risk of a future reconciliation exercise (if ERPNext HR is confirmed present later) is accepted in exchange for not blocking on an unverified assumption and not importing ERPNext HR's full statutory-compliance complexity for a shop-floor bonus/advance use case that doesn't need it.

## Rejected Alternatives

- **Assume ERPNext HR exists and build on it**: rejected — this snapshot's HR presence was never confirmed by evidence (`report_erpnext.md` scoped it out); building on an unconfirmed foundation risks discovering mid-implementation that the assumed doctypes don't exist, forcing a late redesign.
- **Block until verified**: rejected — an open evidence gap doesn't need to block architectural progress when a clean, decoupled alternative (a new custom app) is available and doesn't foreclose reconciliation later.

## Consequences

- A future targeted research pass (flagged as an open question in `domain_model.md` §18.1) should confirm ERPNext HR's actual presence/absence in this workspace before any reconciliation work is considered.
- `korkem_workforce`'s `Employee` doctype must be designed generically enough (e.g. an optional Link to an ERPNext `Employee` if one exists) that reconciliation later is additive, not a breaking schema change.

## Implementation Constraints

`korkem_workforce` doctypes must not assume any ERPNext HR doctype exists at runtime — no hard dependency on an unconfirmed module.

## Future Implications

If ERPNext HR is confirmed present and a genuine need for its statutory-compliance features emerges (e.g. this platform expands into a jurisdiction requiring formal payroll tax handling), a superseding ADR should decide the reconciliation strategy explicitly, informed by real requirements at that time.

## Related ADRs

ADR-0001 (the general "extend ERPNext where it already solves the problem" principle this ADR deliberately departs from, with explicit justification), ADR-0004.

## Review Notes

Identified as a gap during the collective validation pass — `domain_model.md` §17 already made this decision informally; this ADR gives it the same rigor (alternatives, trade-offs, future path) as every other architectural commitment in this set.
