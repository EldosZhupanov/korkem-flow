# ADR-0008 — Why AI Never Owns Business Data

**Status:** Accepted
**Date:** 2026-07-27

## Context

`04_system_architecture.md` §10-11 establishes the Frappe Bench as owner of 100% of durable business data, including Agent Conversation, Agent Message, and Pending Action records (stored in the new `korkem_ai` custom app rather than a separate AI-Orchestrator-owned datastore).

## Problem Statement

The natural implementation shortcut for an AI Orchestrator is to give it its own database (a common pattern in generic chatbot architectures) for conversation history and any working state. In this domain, that shortcut would mean the record of "what did the AI propose and who approved it" — itself a business fact, per `PROJECT.md`'s auditability principle — lives outside the one place that's supposed to hold all business truth.

## Decision

The AI Orchestrator holds no persistent business data of its own. Agent Conversation, Agent Message, Pending Action, and AI Credit Ledger are all Frappe doctypes in the `korkem_ai` custom app, physically stored in the same bench/database as every other business entity. The Orchestrator's own process memory is transient only (in-flight turn processing), written back to the bench at each turn boundary.

## Alternatives Considered

1. AI Orchestrator with its own database (e.g. Postgres/Mongo) for conversations and pending actions.
2. AI Orchestrator with no persistent state of its own; all AI-related business data lives in the bench (chosen).
3. Hybrid: conversation transcripts in the Orchestrator's own store, only the final approved-action outcome written to the bench.

## Pros

- Guarantees a single source of truth for "what did AI do and who approved it" — directly satisfies `PROJECT.md`'s "every action must be traceable/auditable" and the platform-wide "never duplicate data" invariant.
- Conversation and Pending Action history is queryable/reportable alongside the rest of the business (e.g. "show me all AI proposals related to Production Order #103") without cross-database joins.
- If the AI Orchestrator is replaced or rebuilt, no data migration is needed — the data was never there to begin with.

## Cons

- Every conversation turn requires a round trip to the bench to persist state — no purely in-memory fast path.
- The Orchestrator cannot optimize its own storage schema independently of Frappe's doctype model (e.g. can't easily adopt a specialized conversation-optimized database without also solving how that data still counts as "in the bench").

## Trade-offs

Round-trip latency per turn is accepted in exchange for eliminating an entire class of data-integrity bug (AI-side and bench-side disagreeing about what actually happened) — judged a clearly favorable trade given the stakes of production/payroll actions this AI can propose.

## Rejected Alternatives

- **AI Orchestrator with its own database**: rejected — directly creates the duplicate-source-of-truth problem `domain_model.md`'s invariants forbid; also breaks unified auditability (a report on "all actions on Production Order X" would need to query two systems).
- **Hybrid (transcripts in Orchestrator, only outcomes in bench)**: rejected — partial solution that still leaves conversational context outside the auditable system of record; a manager reviewing why an AI proposal was made would need to consult a second system.

## Consequences

- The `korkem_ai` app's doctype design must be efficient enough for frequent read/write (every conversation turn) — a real, evidenced engineering constraint the Module/Data Architecture phases (05-06) must account for.
- Conversation history naturally inherits Frappe's existing permission model (who can see which conversations) rather than needing a bespoke access-control layer.

## Implementation Constraints

The AI Orchestrator's codebase must contain no persistent storage layer of its own for business/conversation data — only the shared `frappe-client` library for reads/writes to the bench.

## Future Implications

If conversation volume ever demands a genuinely different storage technology (e.g. very high-frequency streaming interactions), that would be a deliberate, explicitly-justified exception requiring its own ADR — not a default assumption.

## Related ADRs

ADR-0003, ADR-0012 (this ADR's necessary companion — see Review Notes for the distinction), ADR-0014.

## Review Notes

**Important clarification vs. ADR-0012** ("AI memory is separated from ERP data"): "separated" in ADR-0012 means *logically/schematically* separated — a distinct Frappe app/doctype set (`korkem_ai`) with its own permission scoping — not *physically* separated into a different datastore. This ADR (0008) and ADR-0012 are complementary, not contradictory: AI data is schema-separated from ERP/CRM data, but both live in the same bench, satisfying both "AI never owns a second source of truth" (this ADR) and "AI's schema can evolve independently" (ADR-0012). The one narrow exception (a vector/embeddings store for Knowledge Memory) is called out explicitly in ADR-0012 and ADR-0019, not silently introduced here.
