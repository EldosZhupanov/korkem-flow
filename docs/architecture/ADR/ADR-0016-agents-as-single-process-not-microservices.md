# ADR-0016 — Why AI Agents Are Logical Roles in One Process, Not Microservices

**Status:** Accepted
**Date:** 2026-07-27

## Context

`domain_model.md` §15 defines seven agent responsibilities (Production, Warehouse, Sales, Planning, Finance, Quality, Supervisor). `04_system_architecture.md` §6/§19 implements all seven as logical roles inside one AI Orchestrator process — a system prompt, a scoped tool/Command allow-list, and a permission boundary each — rather than seven independently deployed services.

## Problem Statement

A superficially appealing design would give each agent its own deployable service (independent scaling, independent deployment). Without a clear justification for or against this, implementation could drift toward unjustified microservice sprawl, adding network hops, deployment complexity, and cross-service consistency problems for seven components that all share the same underlying data access pattern and approval mechanism.

## Decision

All seven agent skills run as logical roles within a single AI Orchestrator process. Splitting any of them into a separate deployable service requires an explicit, evidenced justification (e.g. a demonstrated independent scaling need) — it is not the default.

## Alternatives Considered

1. One microservice per agent (seven services).
2. All agents as logical roles in one Orchestrator process (chosen).
3. A hybrid — a few agents grouped by shared characteristics into 2-3 services.

## Pros

- No unjustified network hops between agents that frequently need to collaborate (e.g. Supervisor Agent reviewing another agent's proposal, per `domain_model.md` §15).
- Simpler deployment, monitoring, and versioning story — one service, not seven with independent lifecycles to coordinate.
- All seven share the same data-access pattern (`frappe-client`) and the same approval mechanism (Pending Action) — there's no evidenced technical reason for physical separation.

## Cons

- All seven agents share fault domain and resource pool — a resource-heavy Sales Agent workload could, in principle, affect Production Agent responsiveness within the same process (mitigated by normal in-process resource management, not requiring separate services to solve).
- Independent scaling per agent (if one specific agent's load grows disproportionately) is not available without revisiting this decision.

## Trade-offs

Losing per-agent independent scaling is accepted now because no agent has demonstrated a scaling profile different enough from the others to justify the complexity of separate services — this is a "don't build it until you need it" call consistent with the platform's stated aversion to over-engineering.

## Rejected Alternatives

- **One microservice per agent**: rejected — seven services for seven system prompts with no differing infrastructure needs is unjustified complexity; also fragments the Supervisor Agent's cross-cutting review responsibility across a network boundary for no benefit.
- **Hybrid grouping**: rejected — introduces an arbitrary grouping boundary (which agents go together?) without a clear rule, likely to be revisited anyway as agent responsibilities evolve; simpler to start unified and split later with evidence than to guess a grouping now.

## Consequences

- If one agent skill later proves to need genuinely independent scaling or a different runtime/language, that specific agent can be extracted into its own service without redesigning the others — the tool/Command allow-list boundary already provides a clean extraction seam.

## Implementation Constraints

Agent skills are implemented as internally modular components (distinct system prompts, distinct tool allow-lists) within the Orchestrator codebase, not as a monolithic undifferentiated prompt — modularity is preserved in code structure even without service-level separation.

## Future Implications

This decision should be revisited if/when real operational data shows a specific agent's resource or scaling profile diverging meaningfully from the others (see ADR-0018's similar "defer until evidenced" pattern for multi-tenancy).

## Related ADRs

ADR-0003, ADR-0010 (AI-side instance of plugin architecture), ADR-0015.

## Review Notes

Consistent with `04_system_architecture.md` §19 and §22's explicit non-goal ("No microservice-per-agent"); this ADR formalizes that decision with fuller alternatives analysis.
