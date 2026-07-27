# Sprint 1 — First Vertical Slice

Status: **in progress**. Architecture frozen per `.ai/architecture/*` (phases 01-07 complete; 08-25 intentionally not pursued further unless implementation reveals a blocking flaw, per the current instruction). This is an execution/roadmap document, not a new architecture document.

## Slice

Customer sends a WhatsApp message → AI classifies intent → Create/find Customer → Create CRM Deal → Create Quote → Manager approves Quote (via Pending Action) → Create Production Order (Work Order) → Assign Production Task → Worker completes Task → Notify Customer.

## Scoping decisions made to keep this slice minimal but real (no placeholders)

- **Task, not Work Assignment**: "Assign Production Task" uses the existing Collaboration `Task` (reused CRM Task doctype, extended to target `Work Order`), not `korkem_workforce`'s percentage-split Work Assignment. Upgradable later; not required to prove this flow end-to-end.
- **No Facade Item / Decor / BOM detail**: the Production Order created in this slice is a bare `Work Order` (item, qty, customer link) — KORKEM-specific manufacturing detail (facade items, decor, milling) is out of scope for Sprint 1.
- **Approval UI is Frappe Desk-native for now**: the Pending Action approve/reject step uses a plain Desk list view with action buttons, not the dark-UI frontend (Phase 18/19, not yet built). Real functionality, minimal UI investment.
- **Inbound WhatsApp**: new, small addition to the Integrations context (symmetric to the already-designed outbound path) — see the architectural-gap note in conversation; not a new architecture phase.

## Tasks (dependency order, 1-4h each)

### Phase A — Environment (blocking everything below) — ✅ DONE
- A1. Grant `eldos` docker group access — ✅ done
- A2. Stand up Frappe bench via custom Docker Compose (`infra/frappe_bench/`, not `frappe_docker`'s quick-start — a custom setup bind-mounting our vendored `erpnext`/`frappe`/`crm`, per the approved plan) — ✅ done, after fixing several real issues along the way (corepack bug, a pre-existing yarn shim, wrong MariaDB healthcheck binary, a volume-mount-path gotcha, and erpnext's `banking` sub-frontend needing a real clone instead of a symlink — full detail in `.ai/roadmap/sprint_1_phase_a_checklist.md`)
- A3. `bench get-app erpnext` (local clone), `bench get-app --soft-link crm`; site `korkem.localhost` created; both apps installed — ✅ done
- A4. Sanity check: Desk loads (HTTP 200, login page), asset URLs all 200, vendored repos confirmed to have zero modified tracked files — ✅ done

### Phase B — Custom app scaffolding — ✅ DONE
- B1. `bench new-app korkem_manufacturing` (skeleton) — ✅ done
- B2. `bench new-app korkem_ai` (skeleton) — ✅ done
- B3. Install both custom apps on the site — ✅ done, after one crash-and-restart (adding a bench-level app while `bench start` was already running broke the scheduler process until the container restarted — see `.ai/roadmap/sprint_1_phase_b_checklist.md`; harmless, but worth restarting the bench after any future `bench new-app`/`get-app`)

### Phase C — Data layer for this slice — ✅ DONE
- Prerequisite fix (found during this phase): `korkem_manufacturing`/`korkem_ai` moved from the ephemeral `bench-data` volume to bind-mounted, version-controlled directories under `backend/` (each its own git repo, required by bench tooling) — see `sprint_1_phase_c_checklist.md`.
- C1. `korkem_ai`: Agent Conversation doctype — ✅ done
- C2. `korkem_ai`: Agent Conversation Message doctype — ✅ done
- C3. `korkem_ai`: Pending Action doctype (`action_class`, `action_data`, `display_data`, `status`, `entity_type`, `expires_at`) — ✅ done, with real approve/reject/expire logic (not just schema)
- C4. `korkem_manufacturing`: hook extending CRM Task's valid `reference_doctype` targets — **turned out to need no code**: `crm_task.json`'s `reference_doctype` is already an unrestricted Link; ADR-0023's assumption was checked and found incorrect, flagged for correction on its next revision
- C5. `korkem_manufacturing`: Custom Field `originating_deal` (Link → CRM Deal) on `Work Order` (per `domain_model.md` §3.4) — ✅ done, via a `post_model_sync` patch
- All 12 tests passing (`bench --site korkem.localhost run-tests --app korkem_ai`); two real bugs found and fixed along the way (a CRM test-fixture gap, and a JSON-fieldtype read bug) — see `sprint_1_phase_c_checklist.md`

### Phase D — Integrations (WhatsApp)
- D1. Inbound WhatsApp webhook receiver — 3-4h
- D2. Outbound WhatsApp sender (Notifications) — 2-3h
- D3. Wire inbound webhook → create/continue Agent Conversation, store message — 2h

### Phase E — AI Orchestrator (minimal, this slice only)
- E1. Orchestrator service scaffold (LLM call for intent classification) — 3-4h
- E2. Intent classification: "new order inquiry" vs. other — 2-3h
- E3. Sales Agent skill: find-or-create Customer (CRM Organization) — 3h
- E4. Sales Agent skill: create CRM Deal linked to Customer — 2h
- E5. Sales Agent skill: draft + send Quote — 3h
- E6. Sales Agent: propose Quote-approval as a Pending Action — 3h

### Phase F — Human approval (minimal)
- F1. Desk-based approve/reject view for Pending Action — 3-4h
- F2. On approval: execute the real Command, advance the Deal — 2h

### Phase G — Production Order creation
- G1. On approval: create `Work Order` with `originating_deal` set — 3h
- G2. Create a `Task` on the Work Order, assign to a worker — 2h

### Phase H — Worker completes task
- H1. Minimal worker-facing completion action (Desk-based) — 2h
- H2. On completion: fire the notification-trigger event — 1h

### Phase I — Notify customer
- I1. Notification Service: send WhatsApp on Task completion — 3h
- I2. End-to-end test: simulate inbound WhatsApp → verify full chain → outbound confirmation — 2-3h

### Phase J — Tests & wrap-up
- J1. Automated tests per doctype/orchestrator logic — 3-4h
- J2. Manual end-to-end smoke test — 2h
- J3. Commit review, progress update — 1h

Work proceeds task by task, in this order — no skipping ahead. After each task: run tests, fix issues, commit, update this document's status.
