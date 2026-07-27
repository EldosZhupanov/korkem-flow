# ADR-0007 — Why Business Logic Belongs Only in the Domain Layer

**Status:** Accepted
**Date:** 2026-07-27

## Context

`CLAUDE.md` mandates Clean Architecture layering (`Presentation → Application → Domain → Infrastructure`) with the explicit rule "Business logic never lives inside UI," and "Domain never depends on Framework." `04_system_architecture.md` operationalizes this as: business rules live in Frappe Doctype controllers / Command handlers within the bench's custom apps — never in the Gateway, Frontend, Mobile, Telegram Bot, or AI Orchestrator.

## Problem Statement

With multiple client surfaces (web, mobile/PWA, Telegram) and multiple backend-adjacent services (Gateway, AI Orchestrator, Notification Service), there is constant temptation to add "just a quick validation check" at the edge — in the Gateway for performance, in the Frontend for responsiveness, in the Orchestrator for agent safety. Each instance of this duplicates a rule that must also exist authoritatively in the domain layer, and duplicated rules drift.

## Decision

All validation, invariants, and business state-transition rules are implemented exactly once, in the domain layer (Frappe Doctype controllers and Command handlers in the bench's custom apps). Every other layer treats its own checks (if any) as non-authoritative UX hints only.

## Alternatives Considered

1. Duplicate critical validations at the edge (Gateway/Frontend) for responsiveness, in addition to the domain layer.
2. Single authoritative enforcement point in the domain layer only (chosen).
3. No client-side validation hints at all (rejected as poor UX, not architecturally necessary to reject).

## Pros

- One place to change a business rule; no risk of the Gateway and the bench silently disagreeing about what's valid.
- Matches `CLAUDE.md`'s explicit mandate directly, with no interpretation gap.
- Simplifies reasoning about correctness for AI-agent-proposed actions (ADR-0003): the Orchestrator never needs its own copy of the rules to reason about validity, just calls the bench.

## Cons

- A Frontend/Mobile client-side "hint" validation (e.g. "dimensions must be positive," shown instantly before the request round-trips) must be kept clearly labeled as a UX convenience, not a security or correctness boundary — a discipline risk if engineers conflate the two.
- Every business-rule check requires a round trip to the bench; no in-process shortcut anywhere else.

## Trade-offs

Slightly slower edge-side feedback (must wait for a round trip for authoritative validation) is accepted in exchange for a single, unambiguous source of truth for correctness — especially important since AI agents (ADR-0003) and multiple human-facing clients all depend on the same rules holding consistently.

## Rejected Alternatives

- **Duplicate critical validations at the edge**: rejected — even "critical" validations duplicated for performance create exactly the drift risk this ADR exists to prevent; the honest fix for perceived latency is optimizing the domain-layer path, not duplicating logic around it.

## Consequences

- Gateway/Frontend/Mobile validation code, where it exists for UX responsiveness, must be reviewed periodically to confirm it hasn't silently become the *only* place a rule is enforced (i.e. domain-layer enforcement must never be skipped "because the frontend already checks it").

## Implementation Constraints

Command handlers and Doctype controllers in `korkem_manufacturing`/`korkem_workforce`/`korkem_documents`/`korkem_ai` are the only place invariants from `domain_model.md` §9 and validation rules from §10 may be authoritatively implemented.

## Future Implications

If the Gateway or Frontend stack is ever replaced, correctness is unaffected, since neither ever held authoritative business logic.

## Related ADRs

ADR-0003 (AI Orchestrator isolation, the AI-specific instance of this same principle), ADR-0001, ADR-0002.

## Review Notes

This ADR is the general statement of the principle; ADR-0003 is its specific application to the AI Orchestrator. No contradiction, and no duplication beyond the intentional cross-reference.
