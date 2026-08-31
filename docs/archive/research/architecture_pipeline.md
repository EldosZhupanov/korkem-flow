> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Architecture Pipeline
## Governing sequence for this project — no implementation code until the final phase

This document records the expanded, mandatory sequence of architectural work approved for this project, superseding the shorter `Research → Blueprint → Domain Model → Code` chain implied earlier in `.ai/constitution/master_execution_prompt.md`. That file's Primary Rule, reuse-first mandate, and Stop Condition still apply — this document only expands *how many milestones* sit between Domain Model and Implementation, and what each one must answer.

**Rule: no new implementation code is written until the Implementation phase, and that phase only starts once every phase below is complete and reviewed.**

**Phase numbering is living, not fixed.** It has been renumbered three times so far as new phases were inserted: an ADR set within Phase 04; a Context Map and Event Storming phase added at 05-06; and a Command Catalogue inserted at 07 (per the classical-DDD ordering: Commands → State Machines → Read Models → Modules), pushing State Machines to 08 and adding a new Read Model Catalogue phase at 09. Treat the table below as authoritative for *current* numbering; expect it to shift again, and update it when that happens rather than letting file names and this table drift out of sync.

## The phases (25, as of this revision)

| # | Phase | File | Status |
|---|---|---|---|
| 01 | Research | `.ai/research/architecture_research.md` (prompt) + `.ai/research/report_erpnext.md` + CRM/Relaticle domain-model findings (folded into phase 03) | **Done** for ERPNext (deep) and CRM/Relaticle (targeted, domain-model level). `.ai/research/repository_deep_scan.md` (prompt) written but not yet executed on any repo — open. |
| 02 | Product Blueprint | `PROJECT.md`, `CLAUDE.md`, `.ai/roadmap/korkem_flow_spec.md` | **Done** |
| 03 | Domain Model | `.ai/architecture/domain_model.md` (v2.0) | **Done** — canonical, self-reviewed. One typo flagged for correction: `CloseBonlPayrollPeriod` → `ClosePayrollPeriod` (found in phase 07). |
| 04 | System Architecture + ADRs | `.ai/architecture/04_system_architecture.md` + `.ai/architecture/ADR/` (23 Architecture Decision Records) | **Done** |
| 05 | Context Map | `.ai/architecture/05_context_map_prompt.md` → `.ai/architecture/05_context_map.md` | **Done** — 17 bounded contexts, ownership verified. Gap found: Installation & After-Sales is currently ownerless (no owning entity). |
| 06 | Event Storming | `.ai/architecture/06_event_storming_prompt.md` → `.ai/architecture/06_event_storming.md` | **Done** — 58 domain events across 15 publishing contexts, 8 end-to-end workflows. Installation & After-Sales gap independently rediscovered from the events side. |
| 07 | Command Catalogue | `.ai/architecture/07_command_catalogue_prompt.md` → `.ai/architecture/07_command_catalogue.md` | **Done** — ~70 commands cataloged, every event traced to an originating command (or confirmed system-derived/implicit). Installation & After-Sales gap surfaced a *third* time, now from the commands side. Several missing commands found (ReleaseMaterial, cancellation commands, reopen/reversal paths) and two unsafe-command risks flagged (ConsumeMaterial, AdjustInventory). |
| 08 | State Machines | `.ai/architecture/08_state_machines.md` | **Pending — next** |
| 09 | Read Model Catalogue | `.ai/architecture/09_read_model_catalogue.md` | Pending |
| 10 | Module Architecture | `.ai/architecture/10_module_architecture.md` | Pending — must follow the Context Map (phase 05)'s ownership boundaries per its Quality Gate, and the Command Catalogue (phase 07)'s Quality Gate ("future State Machines must follow this document," transitively binding Module Architecture too) |
| 11 | Data Architecture | `.ai/architecture/11_data_architecture.md` | Pending |
| 12 | API Architecture | `.ai/architecture/12_api_architecture.md` | Pending |
| 13 | Event Architecture (technical transport) | `.ai/architecture/13_event_architecture.md` | Pending — the technical delivery-mechanism design for the events discovered in phase 06 (builds on ADR-0006/0009/0017's decisions) |
| 14 | AI Agent Architecture | `.ai/architecture/14_ai_agent_architecture.md` | Pending |
| 15 | MCP Architecture | `.ai/architecture/15_mcp_architecture.md` | Pending |
| 16 | Plugin Architecture | `.ai/architecture/16_plugin_architecture.md` | Pending |
| 17 | Security Architecture | `.ai/architecture/17_security_architecture.md` | Pending |
| 18 | Deployment Architecture | `.ai/architecture/18_deployment_architecture.md` | Pending |
| 19 | Performance Architecture | `.ai/architecture/19_performance_architecture.md` | Pending |
| 20 | UI Architecture | `.ai/architecture/20_ui_architecture.md` | Pending |
| 21 | UX Flow | `.ai/architecture/21_ux_flow.md` | Pending |
| 22 | Engineering Backlog | `.ai/roadmap/22_engineering_backlog.md` | Pending |
| 23 | Roadmap | `.ai/roadmap/23_roadmap.md` | Pending |
| 24 | Architecture Review | `.ai/reviews/24_architecture_review.md` | Pending — cross-checks phases 03-23 for contradictions before implementation is allowed to start |
| 25 | Implementation | `frontend/`, `backend/`, `telegram/`, `agents/`, or a new Frappe custom app | **Gated.** Not started. Requires phase 24 sign-off. |

## Open items carried across phases (do not let these get silently dropped)

- **Installation & After-Sales has no owning entity.** Found independently three times now: phase 05 (Context Map, entities), phase 06 (Event Storming, events), phase 07 (Command Catalogue, commands). Must be resolved with real entity/aggregate design — likely in phase 10 (Module Architecture) or a `domain_model.md` revision before it — not deferred a fourth time.
- **No cancellation or reopen/reversal commands exist**: `CancelProductionOrder`, `CancelDeal`, `CancelPurchaseOrder`, reopening a lost Deal, reversing a closed Payroll Period or an incorrect Bonus — all found missing in phase 07. Needs addressing before phase 08 (State Machines) finalizes lifecycle states, since a state machine without explicit cancelled/reopened states is incomplete.
- **Two unsafe-command risks** flagged in phase 07: `ConsumeMaterial` must stay strictly System-triggered, never directly user/AI-callable; `AdjustInventory` needs a mandatory reason-code field before implementation.
- **Typo in `domain_model.md`**: `CloseBonlPayrollPeriod` should read `ClosePayrollPeriod` — correct on that document's next revision.
- **ERPNext HR module presence** and **generic Frappe `Event`/calendar doctype presence** — evidence gaps flagged since phase 03 (`domain_model.md` §18), still unverified.
- **Minor gaps noted in phase 07, low priority**: no `RemoveFacadeItem`/`UpdateFacadeItem`, no `RemoveContact`, no `Logout` event, no dedicated `UpdateLead` command (folded into `QualifyLead`).

## Working rules for this pipeline

1. Each phase produces exactly one document (matching this project's established "one file, one job" convention) and builds on every phase before it — a later phase must not silently contradict an earlier one; if it needs to, the contradiction and its resolution are recorded explicitly (as `domain_model.md` §19 and `ADR/README.md` already model).
2. No phase skips ahead into implementation detail that belongs to a later phase (e.g. Module Architecture draws the directory tree; it does not write code inside those directories).
3. The Architecture Review phase is a dedicated re-read of every prior phase looking for conflicts — not a rubber stamp. If it finds conflicts, the offending phase document is revised before Implementation is allowed to begin.
4. The Stop Condition from `master_execution_prompt.md` still applies at the level of this pipeline: each phase is produced, then work pauses for approval before the next phase begins — matching how every phase so far has actually been run in this conversation.
5. Where a phase's own master prompt declares a Quality Gate (e.g. the Context Map's "Module Architecture must not contradict this document," or the Command Catalogue's "future State Machines must follow this document"), that gate is binding on every later phase, not just the next one.
