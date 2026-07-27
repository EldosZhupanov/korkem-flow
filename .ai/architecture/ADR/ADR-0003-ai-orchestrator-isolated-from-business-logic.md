# ADR-0003 — Why the AI Orchestrator Is Isolated from Business Logic

**Status:** Accepted
**Date:** 2026-07-27

## Context

`04_system_architecture.md` defines two cores: the Frappe Bench (transactional core) and the AI Orchestrator (control core). The Orchestrator owns conversation routing, intent classification, and agent-skill dispatch; it must not itself encode business rules such as validation logic, invariants, or state-transition constraints.

## Problem Statement

If business rules (e.g. "a Work Assignment split must sum to 100%") were implemented independently inside the AI Orchestrator (for speed, or to avoid a round-trip), they would inevitably drift from the same rules enforced in the Frappe bench's Doctype controllers — producing a system where the AI "thinks" an action is valid, proposes it, and the bench then rejects it for reasons the AI never modeled, or worse, where the two enforce subtly different rules and both accept an invalid state.

## Decision

The AI Orchestrator contains only routing, intent classification, conversation state management, and agent-skill dispatch logic. All business validation, invariants, and state-transition rules live exclusively in the Frappe bench's domain layer (Doctype controllers / Command handlers). The Orchestrator calls the bench to validate and execute; it never re-implements what the bench already enforces.

## Alternatives Considered

1. Embed a copy of key business rules in the Orchestrator for faster agent reasoning and fewer round-trips.
2. Make the Orchestrator a zero-logic passthrough with no routing/classification capability of its own.
3. Strict separation: routing/orchestration logic in the Orchestrator, all business rules in the bench (chosen).

## Pros

- Single enforcement point for every invariant — no drift risk between "what the AI assumes is valid" and "what actually gets persisted."
- The Orchestrator (and the underlying LLM/agent stack) can be replaced or upgraded without touching business logic at all.
- Matches `CLAUDE.md`'s explicit Clean Architecture mandate ("Domain never depends on Framework. Business logic never lives inside UI" — extended here to "never lives inside the AI layer either").

## Cons

- Added latency: every agent action that needs validation requires a round trip to the bench rather than an instant in-process check.
- Requires ongoing discipline to prevent business rules from "sneaking" into agent system prompts (e.g. an agent prompt that says "never propose splits that don't sum to 100%" is a soft duplication of a hard invariant — acceptable as a prompt-level hint, but the bench must still reject it if violated).

## Trade-offs

Latency is accepted in exchange for correctness guarantees; the alternative (embedded rules) risks silent invariant drift, which is a far more expensive failure mode in a manufacturing/payroll context than a few hundred milliseconds of round-trip time.

## Rejected Alternatives

- **Embedded business rules in the Orchestrator**: rejected — direct risk of invariant drift; also violates ADR-0007 (business logic only in the domain layer).
- **Zero-logic passthrough Orchestrator**: rejected — routing and intent classification are legitimate orchestration concerns distinct from business rules; removing them entirely would just move that logic into the Gateway or Frontend, which is a worse boundary.

## Consequences

- Every agent skill's "proposal" must be treated as provisional until the bench validates it at approval time (see ADR-0015, and `domain_model.md` invariant 9: re-validate at approval time, not just proposal time).
- System prompts for agent skills should describe business rules as *hints* to guide good proposals, never as the enforcement mechanism itself.

## Implementation Constraints

The Orchestrator must call the bench (via the shared `frappe-client` library) for any check that touches business data — it must not hardcode duplicate validation logic anywhere in its own codebase.

## Future Implications

If the LLM/agent stack is swapped (e.g. different model provider) or the Orchestrator is rewritten in a different language/runtime, business correctness is unaffected because it never lived there.

## Related ADRs

ADR-0007 (business logic only in domain layer), ADR-0008 (AI never owns business data), ADR-0015 (human approval required).

## Review Notes

Reinforces rather than duplicates ADR-0007 — this ADR is scoped specifically to the AI Orchestrator; ADR-0007 states the general principle across all non-domain services (Gateway, Frontend included).
