---
name: korkem-architecture
description: The non-negotiable architectural invariants of KORKEM Flow — a local-first business OS for furniture manufacturing. Load BEFORE designing or writing any feature that touches business data, permissions, AI tools, channels (Telegram/WhatsApp), identity, or storage location. Triggers on: adding a tool, adding an endpoint, adding a screen that writes, adding a role, adding a channel, "where should this live", "can AI do X", offline behaviour, data ownership, multi-company.
---

# KORKEM Flow — architectural invariants

KORKEM Flow is **not** a Flutter app for ERPNext. It is a local-first operating
system for a furniture factory, with five equal front doors over one core:

```
Desktop UI · Mobile · Shop-floor terminal · Telegram/WhatsApp · AI assistant
                            │
                    KORKEM Service API          ← every write goes here
                            │
                    KORKEM Domain (korkem_manufacturing)
                            │
                    ERPNext / Frappe / Frappe CRM
                            │
                    Client-owned storage (their disk, their building)
```

The AI assistant is **one client of the API**, not the owner of the ERP.

---

## The ten rules

Violating any of these is a design defect, not a style preference. If a task
seems to require violating one, stop and say so before writing code.

**R1 — AI contains no business logic.** A tool handler validates arguments,
calls a domain service, and shapes the reply. Rules about what a factory may
do live in `korkem_manufacturing`, never in `korkem_ai/tools/`.

**R2 — Every write goes through a domain service.** No screen, no bot, no tool
writes a doctype directly. One code path per business action means one place
for its permission check, its validation and its audit row.

**R3 — Desktop, mobile, terminal, messengers and AI use the same Service API.**
If an action is reachable only through the assistant, it does not exist when
the model is down. If it is reachable only through a screen, the assistant
cannot do it. Both are bugs.

**R4 — Every query carries company scope, decided server-side.** Never from a
request parameter, never from the model. `tools/scope.py` already does this for
tools; services must do it for everyone.

**R5 — A user can never raise their own role.** Role assignment is a
server-side operation with its own permission. A UI that hides the button is
not a permission check.

**R6 — Production data lives on the client's hardware.** KORKEM's cloud may
hold a licence, an update manifest, an organization id, public keys and push
routing. It never holds orders, customers, wages, drawings, BOMs or prices.
Adding a call that ships business data outward requires an explicit decision
recorded as an ADR.

**R7 — The system works with no LLM.** Every business action has a
deterministic path. The assistant is a faster way to reach it, never the only
way. Ship the service first, the tool second.

**R8 — The system degrades honestly with no internet.** On the LAN, everything
must keep working: production, warehouse, tasks, terminals, reports, local
model. What stops is external only: OAuth login, Telegram, WhatsApp, hosted
LLMs, remote phones. Each of those must fail with a sentence that says which
of the two it was — never a spinner.

**R9 — Every dangerous action has a permission check and an audit row.** Both
server-side, both before the write. "Dangerous" means: changes stock, money,
wages, roles, or another person's work.

**R10 — Every AI write is confirmed by a person.** The model proposes a
`Pending Action`; a human agrees to a specific sentence; the server
re-validates at execution because the world may have moved between the two.
This is ADR-0015 and it has never been weakened.

---

## Where code goes

| What | Where | Test |
|---|---|---|
| Business rule, state transition, calculation | `backend/korkem_manufacturing/` | `bench run-tests --app korkem_manufacturing` |
| Whitelisted service endpoint | `korkem_manufacturing/api/` | same |
| AI tool wrapper (`ToolSpec` + handler) | `backend/korkem_ai/korkem_ai/tools/` | `--app korkem_ai` |
| Channel transport (Telegram/WhatsApp) | `korkem_ai/integrations/`, `korkem_ai/channels/` | same |
| Notification delivery | `korkem_ai/notifications/` | same |
| UI, any platform | `mobile/korkem_flow/lib/features/` | `flutter test` |

A pull request that adds a `ToolSpec` and no service is going the wrong way.

## Reuse before rebuilding

ERPNext already owns manufacturing. Before writing a scheduler, a stock
movement, a BOM explosion, a capacity model or a costing rule, find ERPNext's
own mechanism and extend it. Specifically:

- stages → `Operation` + `Routing` + `BOM Operation`
- execution → `Job Card`, `Work Order`, `Stock Entry`
- capacity → `Workstation.production_capacity`, `working_hours`, `hour_rate`
- shipping → `sales_order/mapper.py:make_delivery_note`
- money → `Quotation`, `Sales Invoice`, `Payment Entry`

Hand-moving a `Bin` leaves the ledger disagreeing with the shelf. Never do it.

## What the assistant may never have

No generic `http_request`, `run_query`, `execute` or `eval` tool. A model that
can issue arbitrary requests has whatever access the process has, and nothing
downstream can narrow it again. Tools are registered by name with a declared
schema and a declared risk, and that catalogue is the whole blast radius.

Reads go through `frappe.get_list` so Frappe's permission query conditions
apply. `frappe.db.get_all` bypasses exactly that and must never appear in a
tool or a service reached by a tool.

## Local-first consequences most people miss

- **The Node is a service, not a window.** It must survive the Desktop UI being
  closed and the laptop lid shutting. Desktop is a client of its own Node.
- **A client's dead disk is a dead business.** Local-first turns backup from
  good practice into a product feature: second disk, verified restore, and an
  optional off-site blob KORKEM cannot read.
- **Upgrades happen N times, sometimes offline.** Migrations must be
  idempotent, and a Node must refuse to start against data newer than its code
  rather than half-migrating it.
- **Identity needs a path that works with the internet down.** OAuth is a
  convenience that maps to a local user; every user also has a local credential.
  Never make a hosted provider the only way into a factory's own system.

## Before writing code, answer these

1. Which of R1–R10 does this touch?
2. Does ERPNext already do it? (search first, then say why not)
3. Which domain service is the single write path?
4. What does this look like with no internet? With no LLM?
5. Who is allowed to do it, and where is that checked?
6. What does the audit row say afterwards?

If any answer is "unclear", that is the thing to resolve — not the code.
