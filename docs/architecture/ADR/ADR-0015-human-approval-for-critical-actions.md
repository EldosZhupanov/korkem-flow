# ADR-0015 — Why Human Approval Is Required for Critical Production Actions

**Status:** Accepted
**Date:** 2026-07-27

## Context

`PROJECT.md`'s Product Philosophy: "Humans supervise. AI operates." `domain_model.md` invariant 9: a Pending Action must be re-validated against current entity state at approval time, not just proposal time. `04_system_architecture.md` §6/§18 routes every AI-agent write through Pending Action with no exceptions.

## Problem Statement

An AI system operating a manufacturing/payroll platform will occasionally be wrong, or right based on stale information (e.g. proposing a Work Assignment split that made sense a minute ago but not after a worker just clocked out). Allowing any category of AI-proposed write to bypass human approval — even ones that seem "obviously safe" — creates an unbounded, hard-to-audit category of autonomous action in a domain where mistakes have real financial and production consequences.

## Decision

Every AI-agent-proposed write, without exception, is created as a Pending Action and requires explicit human approval before execution. There is no "auto-approve" tier for any category of action at this stage of the platform.

## Alternatives Considered

1. Auto-approve a defined "low-risk" category of AI actions (e.g. read-adjacent metadata updates) to reduce approval friction.
2. Require human approval for all AI-proposed writes, with no exceptions (chosen).
3. Require approval only above a configurable risk/value threshold (e.g. financial impact above X).

## Pros

- Simple, unambiguous rule with no risk-classification logic to get wrong.
- Matches `PROJECT.md`'s "Humans supervise, AI operates" philosophy literally, not as an approximation.
- Removes an entire class of "was this action supposed to be auto-approved?" ambiguity from both design and incident review.

## Cons

- Adds approval-queue friction even for genuinely low-risk actions, which may slow down some workflows the AI could otherwise safely accelerate.
- Requires a responsive, well-designed approval UI (Phase 15/16) so this friction doesn't become a bottleneck that pushes users to ignore or rubber-stamp proposals without real review.

## Trade-offs

Some workflow friction is accepted now in exchange for zero unmonitored AI-driven state changes during this platform's early operation — a deliberately conservative starting position that can be revisited later with real production evidence, rather than guessed at upfront.

## Rejected Alternatives

- **Auto-approve a "low-risk" category**: rejected for this stage — defining "low risk" correctly is itself a hard, evidence-dependent problem, and getting it wrong once in a manufacturing/payroll context is a worse failure than the added friction of universal approval. Revisit only with concrete operational data showing a specific action category is reliably safe.
- **Approval only above a value/risk threshold**: rejected for the same reason — introduces a threshold-tuning problem with no current data to tune it against, and risks the threshold itself being gamed or misconfigured.

## Consequences

- The approval UI (Pending Action review/approve/reject flow) is a first-class, must-be-excellent piece of the product — poor UX here directly undermines the "humans supervise" philosophy by pressuring users toward rubber-stamping.
- Every agent skill's throughput is bounded by human approval capacity — a deliberate, accepted limitation at this stage.

## Implementation Constraints

No code path exists anywhere that allows an AI Orchestrator agent to execute a Command directly without a resolved (approved) Pending Action record preceding it.

## Future Implications

If, after real operational history, specific action categories prove consistently safe and low-value-at-risk, a future ADR may introduce a narrow, evidence-justified auto-approval tier — explicitly superseding this one, not silently working around it.

## Related ADRs

ADR-0003, ADR-0008, ADR-0013, ADR-0014.

## Review Notes

No contradiction with any other ADR. This is the strictest, most conservative position in the entire ADR set by design — any future loosening must be its own explicit, evidence-backed decision.
