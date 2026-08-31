# ADR-0012 — Why AI Memory Is Separated from ERP Data

**Status:** Accepted
**Date:** 2026-07-27

## Context

`04_system_architecture.md` §17 defines two tiers of AI memory: conversational memory (Agent Conversation/Agent Message doctypes in the `korkem_ai` app) and knowledge memory (a new retrieval/embeddings index over KORKEM documents, supporting the "Knowledge Retrieval" AI responsibility from `PROJECT.md`). ADR-0008 establishes that AI never owns a second copy of business data.

## Problem Statement

AI-related data (conversation transcripts, proposed actions, and eventually retrieval indices) has a different access pattern, growth rate, and schema-evolution speed than core ERP/CRM data (Customer, Production Order, Item). Storing it undifferentiated inside `erpnext`/`crm` doctypes — or worse, mixed into ERPNext's own tables — would couple AI-feature iteration speed to ERP core stability and complicate permission scoping (who can see AI conversations vs. who can see the underlying business records they reference).

## Decision

AI-related data is kept in its own dedicated schema — the `korkem_ai` custom Frappe app — separate from `erpnext`/`crm`/`korkem_manufacturing`/`korkem_workforce`, while still living in the same physical bench/database as everything else (per ADR-0008, not a second datastore). The one deliberate exception is Knowledge Memory's retrieval index (see ADR-0019), which may require a specialized vector-search technology Frappe's relational model doesn't naturally provide.

## Alternatives Considered

1. Store AI conversation/pending-action data as fields bolted directly onto existing ERPNext/CRM doctypes.
2. A dedicated `korkem_ai` app, same bench, separate schema (chosen) — with a narrow, explicit exception for vector/embedding storage.
3. A fully separate AI database (rejected already in ADR-0008).

## Pros

- AI-feature schema can evolve (new Pending Action fields, new agent metadata) at its own pace without touching ERPNext/CRM's own doctypes.
- Permission scoping for "who can see AI conversations" is independent of "who can see the underlying Production Order," even though both live in the same bench.
- Still satisfies ADR-0008's single-source-of-truth requirement, since it's schema separation, not physical separation.

## Cons

- Cross-schema queries (e.g. "show me the Production Order alongside the AI conversation that proposed a change to it") require joining across apps within the same bench — more deliberate query design than if everything were one flat schema, but well within Frappe's normal capabilities (Link fields already do this).
- The narrow exception for a vector store (ADR-0019) introduces the one piece of genuinely separate infrastructure in this architecture, requiring explicit justification each time it's touched.

## Trade-offs

Schema separation is accepted as a light, low-risk form of modularity that doesn't compromise the single-source-of-truth guarantee (ADR-0008) — a middle ground between "everything in one undifferentiated schema" and "AI gets its own database."

## Rejected Alternatives

- **Bolt AI fields directly onto ERPNext/CRM doctypes**: rejected — couples AI-feature iteration speed to ERP-core doctype stability, and blurs permission boundaries between business data and AI-conversation data.
- **Fully separate AI database**: rejected in ADR-0008 already; not reconsidered here.

## Consequences

- The `korkem_ai` app's doctype schema must be designed with cross-app Link references to `erpnext`/`crm`/other custom apps' doctypes in mind (this is what `Pending Action.entity_type` already generalizes for, per `domain_model.md`).

## Implementation Constraints

`korkem_ai` doctypes are the only place Agent Conversation/Message/Pending Action/AI Credit Ledger data lives; the vector-search exception (ADR-0019) is the only sanctioned deviation from "everything in the Frappe bench."

## Future Implications

If AI-feature growth eventually demands more than schema separation (e.g. genuinely different scaling characteristics), that would require revisiting ADR-0008's core guarantee explicitly — not silently drifting into it.

## Related ADRs

ADR-0008 (this ADR's necessary companion and the source of the "same bench, not same DB elsewhere" distinction), ADR-0019 (the vector-store exception).

## Review Notes

Explicitly cross-referenced with ADR-0008 to resolve what could otherwise read as a contradiction ("AI never owns data" vs. "AI memory is separated") — resolved as schema-level separation within the same single source of truth, not physical separation into a second store.
