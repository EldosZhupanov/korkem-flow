# ADR-0010 — Why Plugin Architecture Is Preferred Over Forks

**Status:** Accepted
**Date:** 2026-07-27

## Context

`04_system_architecture.md` §5 defines two plugin surfaces: Frappe-side (new custom apps, per ADR-0004) and AI-side (agent "skills" registered into the Orchestrator, per ADR-0016). `PROJECT.md`'s Long-Term Expansion (furniture → wood → metal → construction) and Architecture Goals ("Plugin friendly") both require the platform to grow without repeatedly forking or rewriting its core.

## Problem Statement

Without a declared plugin convention, every new capability (a new vertical's manufacturing rules, a new AI agent responsibility, a new integration) risks being implemented as a one-off modification to existing core code — increasing the odds that the next addition requires understanding and touching code unrelated to it, and that two additions collide.

## Decision

Every extension point in this platform — new business modules, new AI agent skills, new verticals — is added as a plugin: a new Frappe custom app for business logic (ADR-0004), or a new registered agent skill (system prompt + tool allow-list) for AI capability (ADR-0016). Core code (ERPNext, CRM, the Orchestrator's routing logic) is never modified to accommodate a single new plugin.

## Alternatives Considered

1. Fork/modify core code per new capability, as capabilities are added.
2. A formal plugin architecture with a stable extension contract on both the Frappe side and the AI side (chosen).
3. Plugin architecture on the Frappe side only, ad hoc modification on the AI side.

## Pros

- New verticals or agent responsibilities are additive, reducing regression risk to existing functionality.
- Matches `PROJECT.md`'s explicit "Plugin friendly" architecture goal directly.
- Frappe's own app/hooks system and the Orchestrator's skill-registration model both already provide a natural contract for this — no need to invent a new plugin framework from scratch.

## Cons

- Requires discipline to keep the plugin contract stable — a breaking change to what a "custom app" or "agent skill" must implement affects every existing plugin.
- Some genuinely cross-cutting changes (e.g. a new universally-needed field) may not fit cleanly as a single plugin and require a deliberate, reviewed core change instead of being forced into plugin form artificially.

## Trade-offs

Slight rigidity (not every change fits a plugin shape) is accepted in exchange for long-term extensibility without repeated core rewrites — directly serving `PROJECT.md`'s "optimize for the next ten years" principle.

## Rejected Alternatives

- **Fork/modify core per capability**: rejected — this is the exact anti-pattern ADR-0004 already rejects at the Frappe level, generalized here to the whole platform including the AI layer.
- **Plugin architecture on Frappe side only**: rejected — would leave AI agent capability growth unstructured, risking the same core-modification anti-pattern on the AI side that this ADR exists to prevent everywhere else.

## Consequences

- A genuinely cross-cutting core change must be explicitly justified and reviewed (see Phase 19, Architecture Review) rather than smuggled in as "just this one plugin needs a core tweak."

## Implementation Constraints

New Frappe apps follow the pattern established in ADR-0004; new agent skills follow the pattern established in ADR-0016 (system prompt + tool allow-list + permission scope, no direct code changes to the Orchestrator's routing core).

## Future Implications

Directly enables `PROJECT.md`'s vertical-expansion vision without major redesign, as explicitly required by that document's Long-Term Expansion section.

## Related ADRs

ADR-0004 (Frappe-side instance), ADR-0016 (AI-side instance).

## Review Notes

This ADR states the general principle; ADR-0004 and ADR-0016 are its two concrete applications. No duplication — each is scoped to its own layer.
