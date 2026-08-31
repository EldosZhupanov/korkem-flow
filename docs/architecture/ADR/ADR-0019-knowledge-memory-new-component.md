# ADR-0019 — Why Knowledge Memory Is a New Component, Not Reused from Any Source Repo

**Status:** Accepted
**Date:** 2026-07-27

## Context

`PROJECT.md` names "Knowledge Retrieval" as an AI responsibility. `04_system_architecture.md` §17 splits AI memory into conversational memory (reused Relaticle pattern, per ADR-0008/ADR-0012) and knowledge memory (retrieval over KORKEM's own documents/history) — flagged there as "the one genuinely new piece of infrastructure in this document rather than a reuse of an existing mechanism."

## Problem Statement

None of the four source repos (ERPNext, Frappe, Frappe CRM, Relaticle) provide a retrieval/embeddings mechanism for semantic search over documents — this platform's Primary Rule ("reuse before rebuilding") has nothing to reuse here. Frappe's relational/MariaDB-or-Postgres model is not naturally suited to similarity search over embeddings at the fidelity a genuine knowledge-retrieval feature needs.

## Decision

A new, minimal knowledge-retrieval component is introduced: an embeddings/vector index built from bench data (Approval Sheets, specs, past order history, and other documents) on a schedule, queried by the Knowledge Agent skill when a user/agent needs retrieval-augmented context. This is explicitly acknowledged as new infrastructure, not a reused pattern, and is scoped small until real usage demonstrates a need for more.

## Alternatives Considered

1. Skip Knowledge Retrieval entirely for now, since no source repo provides it.
2. Build a full-featured, continuously-synced knowledge/RAG pipeline immediately.
3. Build a small, schedule-synced embeddings index scoped to genuine current needs, explicitly flagged as new (chosen).

## Pros

- Directly satisfies a named `PROJECT.md` AI responsibility rather than silently dropping it because no existing repo solves it.
- Kept intentionally small (scheduled sync, not live) to avoid over-building speculative infrastructure — matches the platform's general anti-over-engineering posture (see ADR-0006, ADR-0017, ADR-0018).
- Explicit flagging (rather than presenting it as "just another reuse") keeps the architecture's overall "reuse-first" narrative honest — this is the one place that principle doesn't apply, and pretending otherwise would undermine trust in every other ADR's reuse claims.

## Cons

- Requires selecting and operating a vector-search technology (the one piece of infrastructure this platform doesn't get "for free" from an existing repo) — a genuine new operational dependency.
- Scheduled (not live) sync means the knowledge index can lag behind the freshest bench data by up to one sync interval.

## Trade-offs

Accepting a lag window and one new infrastructure dependency is judged necessary because retrieval-augmented knowledge lookup is a named product requirement, not an optional nice-to-have — the alternative (skipping it) would silently under-deliver on `PROJECT.md`.

## Rejected Alternatives

- **Skip Knowledge Retrieval entirely**: rejected — it's an explicitly named AI responsibility in `PROJECT.md`; silently dropping it because it doesn't fit the reuse-first pattern would be avoiding the requirement, not architecting for it.
- **Full continuously-synced RAG pipeline immediately**: rejected — no current evidence of a scale or freshness requirement that justifies the added complexity of live sync versus scheduled sync; build the smaller version first, revisit if it proves insufficient.

## Consequences

- A vector-search technology choice (and its own operational runbook) becomes a Phase 06 (Data Architecture) / Phase 13 (Deployment Architecture) concern that doesn't exist for any other part of this platform.
- The Knowledge Agent skill's responses are only as fresh as the last scheduled sync — this must be communicated honestly in the product UX (e.g. "based on data as of [sync time]"), not presented as always-live.

## Implementation Constraints

The knowledge index is built *from* bench data (read-only extraction) — it never becomes a place where new business facts are written; the bench remains the sole source of truth for anything the index reflects (consistent with ADR-0008's principle, applied here to a read-side derivative rather than a competing store).

## Future Implications

If retrieval freshness or scale requirements grow, this ADR should be revisited with concrete evidence before investing in live sync or a more sophisticated retrieval architecture.

## Related ADRs

ADR-0008, ADR-0012 (this ADR is the explicit exception those two ADRs flag).

## Review Notes

This is the one ADR in the set that introduces genuinely new infrastructure rather than formalizing a reuse decision — flagged deliberately, consistent with this project's "never guess, never silently introduce new complexity" discipline.
