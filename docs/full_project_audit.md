# KORKEM Flow — Full Project Audit

**Date:** 2026-08-07 · **Branch:** `dev` @ `c321839` · **Auditor:** independent pass, no prior claims trusted

> **Update, 2026-08-07 (later the same day).** Two rounds of work have landed
> since this audit: `ai_p0_p1_fixes.md` (P0/P1 defects) and
> `ai_gateway_architecture.md` (provider-agnostic gateway). What changed here:
>
> | Audit finding | Now |
> |---|---|
> | §8 D1 `notConfigured` unreachable | **Fixed** — validated before the queue, typed codes on both channels |
> | §8 D2 `chat.confirm` replay broken | **Fixed** — server-issued call ids via `Pending Action`; mutation-tested |
> | §8 D4 client drops `needs_confirmation` | **Fixed** — real UI state with a confirmation card |
> | §13 S1 no audit trail | **Fixed** — every proposal is a queryable row |
> | §7 fallback not announced | **Fixed** — badged per reply and in the subtitle |
> | §7 no AI capability discovery | **Partly** — an AI Settings screen now exists; `available_tools()` still has no consumer |
> | §9 "never had a key" | **Superseded** — Gemini is LIVE VERIFIED end to end, including structured tool calls, real CRM data and real streaming |
> | §11 streaming unproven | **Fixed and verified**, plus a UTF-8 bug that mangled every Cyrillic streamed reply |
> | §15 T1 socket channel untested | **Still open** |
> | §15 T4 no integration tests | **Still open** |
> | §11 no write tools | **Still open** — the confirmation path remains unreachable in production |
>
> Test counts at that point: **301 Flutter + 216 `korkem_ai` + 13
> `korkem_manufacturing`**. The scores in §31 predate this work and are not
> re-derived here; AI readiness in particular is materially higher.

## How to read the evidence tags

| Tag | Means |
|---|---|
| `LIVE VERIFIED` | Exercised against the running bench during this audit, output quoted |
| `TEST-ONLY VERIFIED` | An automated test covers it; **no human or device has seen it work** |
| `CODE VERIFIED` | Read in full, logic traced; not executed |
| `INFERRED` | Deduced from surrounding code, not proven |
| `NOT VERIFIED` | Nobody has checked. Stated as ignorance, not as pass |
| `BROKEN` | Proven not to work, or proven unreachable |

Nothing in this report is sourced from `README`, commit messages, `docs/`, or `.ai/`.
Where those disagree with the code, the code wins and the disagreement is noted.

---

## 1. Executive Summary

KORKEM Flow is a **well-engineered CRM/ERP mobile client with a genuine, unproven
AI gateway bolted to its front**. The engineering discipline is unusually high for
a project this young: 288 Flutter tests and 184 backend tests pass, `flutter
analyze` is silent, the design system is enforced *by a test that fails the build*,
localisation is complete across three languages, and no credential has ever been
committed.

The gap is not craftsmanship. It is that **the AI half has never once worked
end to end**, and three defects found in this audit mean it could not have:

1. `AssistantFailure.notConfigured` — the "AI is not set up" message — is **unreachable**.
   The gateway queues before validating, so a missing provider surfaces as a generic
   "unknown error". This is why the earlier device run could not show the expected state.
2. `chat.confirm` **cannot work with Anthropic or OpenAI**. It replays the turn, the
   model mints fresh random call ids, and the approved ids never match. It is
   permanently unreachable today (no write tools exist) and would loop forever the
   day one lands.
3. The Flutter client **silently discards** `needs_confirmation`. It is a terminal
   event, so the user would see an empty bubble where an approval prompt belongs.

None of the three is caught by any test, because each test injects the state it is
asserting on rather than producing it the way the system does.

**The honest one-line status: the ERP client is real and good; the AI is a
well-designed skeleton that has never had a model behind it.**

Score: **58/100**. AI architecture readiness **55/100**. Production readiness **20/100**.

---

## 2. Current Project State

### What ran during this audit

```
dart format --set-exit-if-changed lib test   → clean, 178 files          LIVE VERIFIED
flutter analyze                              → No issues found!          LIVE VERIFIED
flutter test                                 → 288 passed, exit 0        LIVE VERIFIED
bench run-tests --app korkem_ai              → Ran 184 tests … OK        LIVE VERIFIED
bench run-tests --app korkem_manufacturing   → Ran 13 tests … OK         LIVE VERIFIED
docker compose up -d → /api/method/ping      → {"message":"pong"}        LIVE VERIFIED
```

### Live endpoint probes

```
GET korkem_ai.korkem_ai.chat.info
  → {"site":"korkem.localhost","event":"korkem_ai_chat"}                 LIVE VERIFIED

GET korkem_ai.korkem_ai.chat.available_tools
  → 7 tools, every one risk:"read", requires_confirmation:false          LIVE VERIFIED

GET AI Settings
  → {enabled: 0, provider: "Anthropic", model: "claude-opus-5",
     api_key: None, base_url: None}                                      LIVE VERIFIED
```

**`enabled: 0` and no API key.** No model has ever answered in this system. Every
statement anywhere in the repo about the assistant "working" refers to the plumbing
around a model, never to a model.

---

## 3. Repository Architecture

```
furniture_ai/                    root git repo — 58 commits, tracks only custom code
├── mobile/korkem_flow/          Flutter app — 134 lib files, 18,564 LOC   ← the product
├── backend/
│   ├── korkem_ai/               custom Frappe app, own git repo (15 commits) ← AI gateway
│   └── korkem_manufacturing/    custom Frappe app, own git repo (6 commits)
├── infra/frappe_bench/          Docker Compose dev bench
├── docs/  .ai/                  11 + 44 documents
├── erpnext/ frappe/ crm/ relaticle/   vendored, own git repos, gitignored
└── frontend/ telegram/ agents/ prompts/   EMPTY SCAFFOLDS — README only
```

`CODE VERIFIED`: `frontend/`, `telegram/`, `agents/`, `prompts/` contain a README and
nothing else. `agents/` and `prompts/` are actively **misleading** — the real agent
and prompt code lives in `backend/korkem_ai/`, so a newcomer looking for agents finds
an empty directory. Recommend deleting or pointing them.

All six git repos were clean at audit start. **`crm/yarn.lock` drifted again during
this audit's bench boot** — third confirmed reproduction. `CLAUDE.md` calls it a
"benign build-tool regeneration" to revert by hand; three-for-three says it is
**systematic and should be automated away**, not re-reverted forever (GAP-14).

---

## 4. Git / Previous Work Audit

58 root commits. Commit activity by feature area:

| Area | Commits | Verdict |
|---|---|---|
| assistant | 28 | Heaviest investment; also the least proven |
| deals | 26 | Real, live data |
| dashboard | 16 | Real, live data |
| leads / tasks | 15 / 14 | Real |
| approvals | 13 | Reads `Pending Action` — the *old* AI stack's approvals |
| production | 12 | Real, thin |
| customers / warehouse / notifications / quotes | 11 / 9 / 9 / 8 | Real |

**Claims checked against code:**

| Claimed | Actual | Tag |
|---|---|---|
| "Android readiness audited on device, 5 fixes" | Fixes present in code; no device test exists to keep them fixed | `CODE VERIFIED` |
| "Design system enforced" | **True, and enforced by `token_discipline_test.dart` which fails the build** | `LIVE VERIFIED` |
| "Brand assets from real logo" | `logo/` committed with `extract_brand_assets.py`; regeneration reproducible | `CODE VERIFIED` |
| "Dashboard rebuilt around attention" | True; `attention_hero.dart`, `workload_bar.dart` read `dashboard.get_summary` | `CODE VERIFIED` |
| "AI Workspace phase 1 + 2" | Sidebar, grouping, streaming, scroll-to-bottom all present | `TEST-ONLY VERIFIED` |
| "Assistant connected to gateway" | Wired, but **never completed a turn** | `BROKEN` |

No dead code, no `TODO`/`FIXME` anywhere in `lib/` or `test/` (count: **0**), no
commented-out blocks, one `debugPrint` in a documented failure path. `active_filters.dart`
— flagged as leftover in an earlier pass — **no longer exists**; that cleanup landed.

---

## 5. Flutter Architecture

**Verdict: clean, and genuinely so.**

```
presentation/  →  application/ (Riverpod)  →  data/ (repository)  →  core/api
      └─ domain/ (pure Dart, no Flutter imports)
```

`LIVE VERIFIED` by grep:
- **Zero** files under `lib/features/` import `package:dio` — no UI reaches the network.
- **Zero** presentation files import a `data/*_repository` directly.
- Largest non-generated file is `app_sidebar.dart` at 504 lines. **No god objects.**
- 7 provider declarations; no hidden global state, no singletons.

**Concerns:**

| ID | Issue | Severity |
|---|---|---|
| A1 | `threads_controller.dart` (365 LOC) holds providers **and** the `sendMessage` orchestration function. It is the seam where three of this audit's defects live. Splitting the turn-runner out would make it testable in isolation. | P2 |
| A2 | `sendMessage(WidgetRef, String)` takes a `WidgetRef` — couples application logic to the widget layer and is why it needs a pumped `Consumer` to test. A `Ref`-based notifier would not. | P2 |
| A3 | Chat history persists to `SharedPreferences` while `Agent Conversation` doctypes sit unused server-side. History is device-local, lost on reinstall, invisible to the business. | P1 |

---

## 6. UI/UX Audit

**Design system: the strongest part of this codebase.**

| Check | Result |
|---|---|
| Raw numbers in `EdgeInsets` | **0** |
| Inline `Duration(...)` in widget files | **0** (4 in `core/api` — timeouts, correctly excluded) |
| Hardcoded colours | 81 references, **all** resolving to `AppColors.*` tokens or `context.statusColors` |
| `TODO`/`FIXME`/`HACK` | **0** |
| Enforcement | `token_discipline_test.dart` sweeps `lib/`, asserts the sweep is non-vacuous, fails on drift |

That last row matters more than the others. The rule is not documentation — it is a
test that breaks the build, including a guard against the test itself silently
matching nothing.

**One violation found:** `chat_composer.dart:126-127` re-derives the outline colour by
branching on `theme.brightness`, duplicating logic `app_theme.dart:60-64` already
resolves into the theme. Exactly the pattern `CLAUDE.md` forbids. One-line fix. **P3.**

**Responsive / theming:** goldens cover light+dark across ~14 screens plus a tablet
set. `shell_back_test.dart` parameterises 6 responsive cases. `TEST-ONLY VERIFIED` —
no device or emulator has rendered any of it this cycle.

**Text scale 1.3 / 1.6, landscape, screen reader:** `NOT VERIFIED`. `kpi_scale_test.dart`
covers dashboard numerals at large scale; nothing covers the chat surface at 1.6.

---

## 7. AI Workspace Audit

*If a new user opens the app, do they understand it is an AI workspace?*

**Partly.** The assistant is the landing route (`/chat`), the sidebar leads with it,
the empty state is branded and offers suggestions. That reads as an AI product.

But the questions that matter answer badly:

| Can the user… | Answer |
|---|---|
| Start a new conversation | **Yes** — sidebar "New chat" |
| Continue an old one | **Yes** — grouped Today / Yesterday / Earlier |
| Rename / delete a conversation | **Yes** |
| **Understand what the AI can do** | **No.** `available_tools()` exists, is live, and **no UI calls it.** The 7 capabilities are invisible. |
| **Know whether AI is even connected** | **No.** With the gateway unreachable the app silently falls back to a keyword matcher and shows a data card. Nothing says "no model is answering." |
| See which records an answer came from | **No.** Answers are prose; `ContextCardKind` is a fixed enum of four dashboards, not a citation. |
| Cancel a running turn | **No.** No stop button; no server-side cancel exists. |
| Approve an action | **No.** The event is silently dropped (§8, D3). |
| Jump to a CRM record from an answer | **No.** |

**The honesty problem.** `LocalAssistant` is well-designed — it writes no prose and
invents no numbers, only attaching cards backed by real providers. Its docstring is
right that a demo which improvises is a claim, not a demo. But it is substituted
**silently**: a user asking "покажи просроченные задачи" gets a tasks card and
reasonably concludes the AI works. It does not. **P1 — the fallback must announce itself.**

---

## 8. Chat Architecture

### The path, as built

```
Flutter  ──HTTP POST chat.send──→  Frappe  ──frappe.enqueue──→  short queue
                                                                    │
   ◄────socket.io :9000, room user:<user>, event korkem_ai_chat──────┘
```

Queuing rather than blocking is correct and deliberate (ADR-0009). Subscribing
*before* sending is correct — it closes a real race. The design is sound.

### Three verified defects

**D1 — `notConfigured` is unreachable. `BROKEN`**

`chat.send` validates only that the message is non-empty, then enqueues and returns
`200 {"turn_id":…}`. Provider configuration is never checked there. The failure
happens in the worker, is caught by a bare `except Exception` (`chat.py:153`), and
published as `{"type":"error","message":"The assistant could not answer just now."}`.

The client's `_decode` maps `'error'` → `AssistantFailure.unknown`
(`remote_assistant.dart:197`). `notConfigured` is produced **only** by `_failureOf`,
which runs only on an HTTP-level `FrappeException` that `chat.send` never throws.

Its comment — *"The gateway throws this when AI Settings has no provider configured"*
— is factually wrong. `LIVE VERIFIED`: with `enabled: 0`, `chat.send` returned
`{"turn_id":"db4ad232343b","event":"korkem_ai_chat"}` with HTTP 200.

The golden test `assistant failure` renders `notConfigured` via an **injected stub**,
so it passes while asserting a state the real system cannot produce.

**Fix:** the server should send a machine-readable `reason` on the error event, and
`chat.send` should reject a disabled provider synchronously.

**D2 — `chat.confirm` cannot work with Anthropic or OpenAI. `BROKEN`**

`confirm` *replays* the turn (`chat.py:68-90`), re-asking the model from scratch, and
matches `approved_calls` against `call.id` (`loop.py:128`). Call-id provenance differs
per adapter:

| Provider | Call id | Replay-stable? |
|---|---|---|
| Anthropic | `block.id` (`llm.py:318`) — provider-random `toolu_…` | **No** |
| OpenAI-compatible / OpenRouter | `raw.get("id")` (`llm.py:511`) — provider-random `call_…` | **No** |
| Google Gemini | `f"{name}-{index}"` (`llm.py:718`) | Yes, by accident |
| Ollama | `f"{name}-{index}"` (`llm.py:845,913`) | Yes, by accident |

On Anthropic — the *configured default provider* — the replayed turn emits a new
random id, the approval never matches, and the user is asked to confirm forever.

**D3 — the tests do not cover it.** `agent/test_loop.py:143` uses a `_FakeProvider`
returning a hardcoded `id="w1"`, so approval matches trivially. `run_turn` is tested;
the `chat.confirm` replay is not tested at all. `test_chat.py` only asserts that
`confirm` rejects an empty approval list. **This is false confidence on the single
most safety-critical path in the system.**

**D4 — the client drops `needs_confirmation`. `BROKEN`**

```dart
// threads_controller.dart:351
case AssistantNeedsConfirmation():
  break;
```

It is in `_terminal` (`remote_assistant.dart:167`), so the stream closes, busy clears,
and the user is left with an empty assistant bubble. Unreachable today; a trap the
moment a write tool exists.

### Everything else about the chat path

| Property | State |
|---|---|
| Streaming | Real. Anthropic/OpenAI/Ollama stream natively; Gemini does not (`streams_natively = False`) and is buffered |
| System prompt | Server-owned, never concatenated with data (§13) |
| History | Client-supplied, capped at 40, **prose only** — tool results are refused so a client cannot fabricate the model's evidence. Excellent decision |
| Timeout | Client-side, first-event only, 45s. Server-side: none on the turn |
| Cancellation | **None** |
| Retries | HTTP layer only (`retry_policy.dart`); no model-call retry |
| Token limits | `MAX_ITERATIONS = 5`; usage reported; **no budget cap, no rate limit** |
| Logging | `frappe.logger` — name/status/duration, never arguments or results. Correct, but not an audit trail |

---

## 9. AI Provider Readiness

**This is already built, and built well.** The abstraction the brief asks to design
exists at `korkem_ai/orchestrator/llm.py` (946 LOC) with four adapters against four
genuinely different wire protocols:

| Provider | Streams | Structured output | Notes |
|---|---|---|---|
| Anthropic | yes | `output_config.format` | tool_result on a *user* turn |
| OpenAI-compatible (+ OpenRouter) | yes | `response_format: json_schema` strict | args are a JSON *string*; streamed calls arrive as fragments keyed by `index` |
| Google Gemini | no | `responseSchema` | dialect rejects `additionalProperties`; assistant role is `model` |
| Ollama | yes | `format` | NDJSON; object arguments |

Selection is a single `get_provider()` branch reading `AI Settings`. Adding a provider
is one class plus one branch. `ToolCallAccumulator` reassembles fragmented streamed
calls and **flags truncation rather than inventing** the missing JSON — `TEST-ONLY VERIFIED`,
4 tests.

Credentials live in a Frappe `Password` field, server-side only. **No API key exists
anywhere in the mobile app, and none has ever been committed** (`LIVE VERIFIED`: history
scan across all refs of both repos is clean).

**Remaining gap:** none architecturally. The layer needs a key and one real call.
`test_connection()` exists (System Manager only) and has never been run against a
real provider.

---

## 10. Agent Architecture Readiness

`agent/loop.py` — 243 LOC, bounded at 5 iterations, correct shape:

```
model → wants tool? → needs approval and unapproved? → STOP
                    → else execute → feed result back → model → …
```

The confirmation gate is asserted **on the handler**, not on the loop's report — the
test proves the write never ran, which is the right assertion. `TEST-ONLY VERIFIED`
and undermined by D2/D3 above.

### The duplication that matters

**There are two AI stacks in this codebase and they share nothing:**

| | Stack A (Sprint 1) | Stack B (current) |
|---|---|---|
| Entry | WhatsApp webhook | Flutter `chat.send` |
| Routing | `orchestrator/router.py` + `intent.py` | `agent/loop.py` |
| Skills | `agents/sales_agent.py`, `production_agent.py` | `tools/registry.py` + `catalog.py` |
| Approval | **`Pending Action` doctype** — persisted, expiring, auditable, with a Flutter screen | **in-memory `approved_calls`**, no persistence, no record |
| Conversation | **`Agent Conversation` + messages** — persisted | `SharedPreferences` on the device |
| Audit | Doctype rows | A log line |

Stack B — the one the product is being built on — **reimplemented approval and
conversation worse**, ignoring working, tested, ADR-mandated machinery sitting in the
same app. `approvals_screen.dart` already renders `Pending Action`. This is the single
highest-leverage architectural correction available (GAP-05).

---

## 11. CRM / ERP Integration

The Flutter app calls exactly **five** custom backend methods:

```
korkem_ai.korkem_ai.chat.send / .confirm / .info
korkem_ai.korkem_ai.dashboard.get_summary
korkem_manufacturing.shop_floor.complete_task
```

Everything else goes through generic Frappe REST (`/api/resource/...`,
`frappe.client.get_count`, `frappe.client.set_value`) — consistent with ADR-0005 and
appropriate.

| Area | State |
|---|---|
| CRM (deals, leads, organizations, tasks) | **Real**, live data, permission-aware, paginated, searchable |
| Dashboard | **Real** — 6 counts + attention list, permission-aware, `None` when the caller may not look |
| Production | **Thin** — `Work Order` read + `complete_task` |
| ERP proper (inventory, purchasing, accounting, BOM) | **NOT IMPLEMENTED** |
| Production Order lifecycle (`PROJECT.md`'s core entity, 18 stages) | **NOT IMPLEMENTED** — no doctype models it; `Work Order` covers a fraction |

**This is worth stating plainly:** `PROJECT.md` declares Production Order the core
entity of the system and lists an 18-stage lifecycle. Nothing in the codebase
implements that lifecycle. The app is a CRM client with a manufacturing read-only
window attached.

---

## 12. Tool Calling Readiness

The pipeline the brief describes **exists**:

```
User → chat.send → queue → agent/loop → tools/registry → Frappe permissions → DB
```

### Registered tools — `LIVE VERIFIED`, all 7

| Tool | Risk | Doctype |
|---|---|---|
| `crm.search_deals` | read | CRM Deal |
| `crm.get_deal` | read | CRM Deal |
| `crm.search_organizations` | read | CRM Organization |
| `crm.search_leads` | read | CRM Lead |
| `tasks.list` | read | CRM Task |
| `production.list_work_orders` | read | Work Order |
| `profile.current_user` | read | — |

**Zero write tools.** Every confirmation mechanism in the system is therefore
currently unreachable code.

### Registry quality

| Property | State |
|---|---|
| Only registered tools callable | **Yes** — no `http_request`, no `run_query`, no `execute` |
| Schema validation | Hand-written strict validator; unknown property is an error; `bool` is not `integer` |
| Permissions | `frappe.get_list` throughout — **`db.get_all` appears nowhere**, so row-level permission conditions apply. `AI permission ≤ ERP permission` is true *by construction* |
| Runs as the user | `frappe.set_user(user)` in the job, never Administrator |
| Tool hiding | `available_to()` filters on doctype read permission |
| Failure handling | Errors returned as data so a turn survives one bad call; tracebacks go to the log, never to the model |
| Idempotency / rollback | **NOT IMPLEMENTED** |
| Audit trail | **NOT IMPLEMENTED** (log line only) |

### Recommended next tools — all `NOT IMPLEMENTED`

Against doctypes confirmed to exist. Nothing invented.

| Tool | Risk | Doctype | Enables |
|---|---|---|---|
| `crm.get_lead` | read | CRM Lead | symmetry with `get_deal` |
| `crm.list_deal_managers` | read | CRM Deal | *"group by manager"* |
| `tasks.get` | read | CRM Task | drill-down |
| `dashboard.get_summary` | read | — | wrap the existing endpoint |
| `crm.create_lead` | **write** | CRM Lead | first write; forces the approval path to work |
| `crm.update_deal_status` | **write** | CRM Deal | pipeline moves |
| `tasks.create` / `tasks.complete` | **write** | CRM Task | follow-ups |
| `crm.create_organization` | **write** | CRM Organization | *"создай клиента Иван Петров"* |

**Note:** `CRM Deal.status` and `CRM Lead.status` are **Link** fields, not Selects, and
`CRM Task.name` is an autoincrement **integer** — write-tool schemas must respect both.

### Can it answer the brief's target question?

> *"Найди всех клиентов с просроченными сделками, сгруппируй по менеджеру, предложи кому позвонить."*

**Not today.** `tasks.list(overdue=true)` and `crm.search_deals` exist, but there is
no overdue concept on deals, no manager grouping tool, and no model connected. With a
key and two read tools it becomes plausible; the grouping and the recommendation are
model work the loop already supports.

---

## 13. Security

### Genuinely strong

| Control | Evidence |
|---|---|
| No secret ever committed | Full-history scan of both repos: clean. `.env` gitignored, never tracked |
| No key on the device | Provider credentials are server-side `Password` fields |
| Permissions by construction | `frappe.get_list` only; job runs as the user |
| Tool allow-list | Only registered names; no arbitrary HTTP |
| Prompt injection | **Structural** — the system prompt is never concatenated with user or tool data; record text arrives in a tool-result slot. A textual "records are data" paragraph is the second line, correctly described as such |
| History cannot be forged | `_to_messages` accepts only user/assistant prose; a client cannot assert "this tool returned X" |
| Credentials on device | `FlutterSecureStorage` — Keychain / EncryptedSharedPreferences |
| WhatsApp webhook | `allow_guest=True` but HMAC signature-verified against App Secret; disabled state returns 403 |
| Log hygiene | Tool name/status/duration only — never arguments, results, or keys |

### Gaps

| ID | Issue | Severity |
|---|---|---|
| S1 | **No audit trail (ADR-0014 unmet).** `registry._log` writes to a rotating log file. Nothing queryable records what the AI did, for whom, with what arguments. Acceptable while all tools are reads; a **blocker** before the first write | **P0 for writes** |
| S2 | **Approval is not persisted (ADR-0015 partly unmet).** Stack B keeps approvals in memory for one turn. `Pending Action` — persisted, expiring, audited — is ignored | **P1** |
| S3 | **Chat history is device-local plaintext.** `SharedPreferences` is not encrypted; AI answers quote CRM data. A lost unlocked phone leaks business data the app took care to fetch over auth | **P2** |
| S4 | `chat.confirm` accepts client-supplied `message` and `history` alongside `call_ids`. Permissions still bound the damage, but approval is not bound to the text the user actually saw | **P2** |
| S5 | No rate limit or token budget per user. `MAX_ITERATIONS` caps one turn, nothing caps a day | **P2** |
| S6 | Bench serves plain HTTP; debug builds whitelist cleartext to loopback only (correctly scoped, and `privacy_policy.md` depends on it staying that way) | **P1 for production** |

**The destructive-action test the brief demands** — *"удали всех клиентов"* — currently
fails safe for three independent reasons: no delete tool is registered; the registry
refuses unregistered names; and any `DESTRUCTIVE` tool would be blocked pending
confirmation. That safety is **real but untested against a live model**, and D2 means
the confirmation it depends on is itself broken.

---

## 14. Backend / Frappe / Docker

`LIVE VERIFIED` — four containers, healthy:

```
korkem-bench-mariadb-1      healthy      (11.8)
korkem-bench-redis-cache-1  up           (7-alpine)
korkem-bench-redis-queue-1  up           (7-alpine)
korkem-bench-bench-1        up           ports 8000, 9000
```

**This is a development bench and nothing else.** Production blockers:

| Blocker | Detail |
|---|---|
| `bench start` | Dev supervisor — no gunicorn/supervisord/nginx |
| No restart policy | A crash stays down |
| No healthcheck on `bench` | Only MariaDB has one |
| No TLS | Plain HTTP on 8000; socket.io raw on 9000 |
| Single container | Web + workers + scheduler + socket.io in one process tree |
| Secrets in `.env` | Fine for dev; needs a real secret manager |
| Host-name coupling | `korkem.localhost`; emulator needs `10.0.2.2` — the socket namespace bug (§8) came from exactly this |
| Memory | Bench + emulator do not fit in 7.4 GB — a real constraint on verification |

**Emulator/device connectivity: `NOT VERIFIED` this cycle** (bench only, by agreement).
The last device run remains the open defect: server published, client received nothing.

---

## 15. Testing

**485 tests pass** (288 Flutter + 184 `korkem_ai` + 13 `korkem_manufacturing`). All
three suites are fast and green — `LIVE VERIFIED`, run during this audit.

### Where coverage is real

Retry policy, Frappe query building, exception mapping, thread grouping, session
control, tool registry permissions, schema validation, all four provider protocols,
streamed tool-call reassembly, the confirmation gate asserted on the handler, and
`shell_back_test.dart` — which watches `setFrameworkHandlesBack` rather than
delivering `popRoute`, because the naive version passed against a broken build.
That test is a model of the genre.

### Where coverage gives false confidence

| ID | Gap | Why it matters |
|---|---|---|
| T1 | **`FrappeSocketChannel` has zero tests.** Referenced only from `threads_controller.dart` | It is precisely where the unresolved device hang lives |
| T2 | **`chat.confirm` replay is never tested** | Hides D2 completely |
| T3 | **The `notConfigured` golden injects the state** | Renders something the system cannot produce (D1) |
| T4 | **No `integration_test/` directory at all** | Zero device or end-to-end tests. All 288 are host-side |
| T5 | `LocalAssistant` has no test | The silent-fallback path is unexercised |
| T6 | No test asserts an `AssistantNeedsConfirmation` reaches the UI | Hides D4 |

**Critical flows and their real status:**

| Flow | Status |
|---|---|
| Login / auth | `TEST-ONLY VERIFIED` |
| Navigation / back | `TEST-ONLY VERIFIED`, unusually well |
| CRM lists, search, pagination | `TEST-ONLY VERIFIED` |
| Chat send → reply | **`BROKEN`** — never completed once |
| Tool call → data | `TEST-ONLY VERIFIED` (fake providers) |
| Confirmation → write | **`BROKEN`** (D2/D4) |
| Backend failure / timeout | `TEST-ONLY VERIFIED` |
| Permissions | `TEST-ONLY VERIFIED` against live doctypes — the strongest backend coverage |

---

## 16. Performance

**`NOT VERIFIED`.** No profiling has been done, no frame timings captured, no
DevTools session recorded. What can be said from code:

| Aspect | Assessment |
|---|---|
| Lists | `paged_list_view.dart` — paginated, lazy. Good |
| Rebuilds | Riverpod granular; no `ref.watch` of whole controllers in leaves observed |
| Chat history | Whole list read/rewritten on every change, capped at 20 threads. Fine at that size |
| Streaming | Every delta rebuilds the message via `replaceMessage`. **Untested under a fast model** — the plausible first real-world performance problem |
| Animations | `flutter_animate`; no `BackdropFilter`; reduce-motion respected |
| Images | Brand assets only |
| Startup | `NOT VERIFIED` |

60 FPS is a **target, not a measurement**. Nobody has watched this app render a
streaming reply.

---

## 17. Accessibility

| Check | State |
|---|---|
| `Semantics` on chat | Present — `chat_screen.dart:173`, `chat_message_view.dart:225` |
| `liveRegion` for arriving replies | **Yes** (`chat_message_view.dart:227`, `chat_composer.dart:197`) — correct and easy to miss |
| KPI semantics | `kpi_semantics_test.dart` — announced as one fact, not two |
| Text scale | Dashboard covered to 1.6; **chat surface not covered** |
| Reduce motion | Respected |
| Screen reader (TalkBack) | **`NOT VERIFIED`** — never run |
| Tap targets / contrast | **`NOT VERIFIED`** — no automated check |

Only 8 files use `Semantics` at all. The intent is right; verification is absent.

---

## 18. Localization

**Complete — the cleanest area in the project.**

`LIVE VERIFIED` by parsing the ARB files: **200 keys in each of en / ru / kk. Zero
missing, zero extra, zero drift.** (An initial count suggesting 42 gaps was my error —
it counted `@`-metadata.)

Remaining: date/time formatting uses `intl` but per-locale formats are `NOT VERIFIED`;
terminology consistency across ru/kk is `NOT VERIFIED` (needs a native speaker, not a
grep).

---

## 19. Dead Code / Technical Debt

**Remarkably little.**

- `TODO`/`FIXME`/`HACK`/`XXX`: **0** across `lib/` and `test/`
- Commented-out code: none found
- `active_filters.dart`: **already deleted**
- Unused imports: none (`flutter analyze` clean)

**Actual debt:**

| ID | Item | Severity |
|---|---|---|
| D-1 | Empty scaffolds `agents/`, `prompts/`, `frontend/`, `telegram/` — actively misleading, real code is elsewhere | P3 |
| D-2 | Stack A (`router.py`, `intent.py`, `sales_agent.py`, `production_agent.py`) — working, tested, and reachable only via WhatsApp. Duplicates Stack B's purpose | P2 |
| D-3 | `AssistantFailure.notConfigured` — dead branch on the remote path (D1) | P1 |
| D-4 | `AssistantNeedsConfirmation` handler — a no-op `break` | P1 |
| D-5 | `available_tools()` — live endpoint, no consumer | P2 |
| D-6 | `Agent Conversation` / `Agent Conversation Message` — unused by the product's chat | P2 |
| D-7 | `crm/yarn.lock` regenerating on every bench boot (3/3 reproductions) | P3 |
| D-8 | `chat_composer.dart:126` brightness branching | P3 |

---

## 20. Production Readiness

**Not close, and not a criticism — nothing here was built for production yet.**

| Dimension | State |
|---|---|
| Backend deployment | Dev bench only |
| TLS | None |
| Monitoring / alerting | None |
| Structured logging | Partial (`frappe.logger` for tools) |
| Error tracking | Frappe Error Log only |
| Backups | None configured |
| CI/CD | **None** — no workflow files anywhere |
| Release (Android) | **Real** — signing, R8 rules, Play bundle path documented |
| Privacy policy | **Real** and specific |
| Multi-tenancy | Deferred (ADR-0018) |

The mobile release path is genuinely production-grade. The backend is not deployed at all.

---

## 21. Completed Work

| Item | Status |
|---|---|
| Flutter app skeleton, routing, shell, sidebar | **DONE** |
| Design system + token enforcement test | **DONE** |
| Brand integration (logo → assets, reproducible) | **DONE** |
| Localisation ru/kk/en, 200 keys, complete | **DONE** |
| Auth + secure credential storage | **DONE** |
| CRM: deals, leads, customers, tasks | **DONE** |
| Dashboard on real backend metrics | **DONE** |
| Warehouse / quotes / notifications / approvals screens | **DONE** |
| Android release plumbing (signing, R8, bundle) | **DONE** |
| Frappe bench (Docker), vendored repos pristine | **DONE** |
| LLM provider abstraction, 4 protocols | **DONE** |
| Tool registry + schema validation + permissions | **DONE** |
| 7 read tools against real doctypes | **DONE** |
| Agent loop with bounded iterations | **DONE** |
| Queued chat endpoint | **DONE** |
| WhatsApp webhook, signature-verified | **DONE** |
| Chat history, grouping, rename/delete | **DONE** (device-local) |

## 22. Partially Completed Work

| Item | What is missing |
|---|---|
| AI assistant end to end | **A model. Never once answered.** |
| Streaming | Implemented; never seen with real tokens |
| Confirmation flow | Loop gate works; replay broken (D2); client drops the event (D4) |
| Error reporting to the user | Generic only; `notConfigured` unreachable (D1) |
| Accessibility | Markup present; never verified with a screen reader |
| Production module | Read + one write; no lifecycle |
| Audit logging | Log line, not an audit trail |

## 23. Not Completed Work

Production Order lifecycle · write tools · AI settings UI in the app · tool
discoverability UI · context cards citing real records · stop/regenerate ·
server-side chat history · ERP integration (inventory, purchasing, accounting) ·
CI/CD · production deployment · integration/device tests · Telegram · rate
limiting · AI memory (ADR-0012/0019)

## 24. Broken / Risky Areas

| ID | Area | Tag |
|---|---|---|
| B1 | `notConfigured` unreachable — misdiagnoses the most common failure | `BROKEN` |
| B2 | `chat.confirm` replay vs random call ids (Anthropic/OpenAI) | `BROKEN` |
| B3 | Client discards `needs_confirmation` | `BROKEN` |
| B4 | Socket delivery on device — server published, client never received | `NOT VERIFIED` / open |
| B5 | Silent fallback to keyword matcher presented as an AI answer | Risky |
| B6 | No audit trail before the first write tool | Risky |
| B7 | Two AI stacks with divergent approval and persistence | Risky |

---

## 25. Gap Analysis

| ID | Area | Current | Expected | Gap | Sev | Evidence | Action | Depends on |
|---|---|---|---|---|---|---|---|---|
| GAP-01 | AI provider | `enabled:0`, no key | A model answers | Never proven end to end | **P0** | live AI Settings | Add key, run `test_connection`, one real turn | Owner supplies key |
| GAP-02 | Realtime | Turn hangs on device | Reply arrives | Delivery unproven | **P0** | prior device run | Instrument `socket_io_client`, capture handshake | bench + emulator |
| GAP-03 | Error semantics | `'error'` → `unknown` | Reason reaches UI | `notConfigured` dead | **P0** | `chat.py:157`, `remote_assistant.dart:197` | Publish `reason`; validate provider in `send` | — |
| GAP-04 | Confirmation | Replay + random ids | Approval matches | Broken on default provider | **P0** | `llm.py:318,511` vs `:718` | Server-issued stable call ids | GAP-05 |
| GAP-05 | Approval store | In-memory | Persisted + audited | `Pending Action` ignored | **P1** | `chat.py:76-88` | Route Stack B approvals through `Pending Action` | — |
| GAP-06 | Client confirmation | `break;` | Approval sheet | Event dropped | **P1** | `threads_controller.dart:351` | Build the sheet | GAP-04 |
| GAP-07 | Audit trail | Log line | Queryable record | ADR-0014 unmet | **P1** (P0 pre-write) | `registry.py:206` | `AI Tool Invocation` doctype | — |
| GAP-08 | Honesty of fallback | Silent | Announced | User misled | **P1** | `threads_controller.dart:79` | Badge the local assistant | — |
| GAP-09 | Chat history | Device plaintext | Server-side | No sync, leak risk | **P1** | `thread_store.dart` | Use `Agent Conversation` | — |
| GAP-10 | Socket tests | None | Covered | Untested transport | **P1** | grep | Fake socket server test | — |
| GAP-11 | Write tools | Zero | A safe first one | No AI action possible | **P1** | live | `crm.create_lead` | GAP-04/05/07 |
| GAP-12 | Discoverability | No UI | Capabilities visible | `available_tools` unused | **P2** | grep | Surface in empty state | — |
| GAP-13 | Two stacks | Divergent | One | Duplicate approval/persistence | **P2** | §10 | Converge or retire Stack A | — |
| GAP-14 | Vendored drift | Manual revert ×3 | Automatic | Repeats every boot | **P3** | this audit | Pin yarn or gitignore | — |
| GAP-15 | Integration tests | None | Smoke flow | No device proof | **P2** | ls | `integration_test/` | — |
| GAP-16 | ERP / Production Order | Absent | `PROJECT.md` core | Core entity unmodelled | **P2** | §11 | Design doctype | Product decision |
| GAP-17 | Production infra | Dev bench | Deployable | Not deployable | **P2** | §14 | gunicorn+nginx+TLS | — |
| GAP-18 | CI | None | Gates on push | Manual only | **P2** | ls | GH Actions | — |
| GAP-19 | Performance | Unmeasured | 60 FPS proven | No data | **P3** | §16 | Profile streaming | GAP-01 |
| GAP-20 | a11y verification | Unrun | TalkBack pass | Unproven | **P3** | §17 | Screen-reader pass | — |
| GAP-21 | Composer colour | Brightness branch | Theme token | DS violation | **P3** | `chat_composer.dart:126` | One-line fix | — |
| GAP-22 | Empty scaffolds | Misleading | Removed | Wrong signposts | **P3** | ls | Delete or point | — |
| GAP-23 | Rate limits | None | Per-user budget | Cost exposure | **P2** | §8 | Cap turns/day | GAP-01 |

---

## 26. Priority Matrix

**P0 — blocks everything:** GAP-01, GAP-02, GAP-03, GAP-04
**P1 — critical:** GAP-05…GAP-11
**P2 — important:** GAP-12, GAP-13, GAP-15, GAP-16, GAP-17, GAP-18, GAP-23
**P3 — improvement:** GAP-14, GAP-19, GAP-20, GAP-21, GAP-22

---

## 27. Recommended Architecture

Keep the shape — it is right. Correct four things inside it:

1. **Server-issued call ids.** The registry mints `f"{turn_id}:{n}"` when the model's
   call is normalised, so identity survives a replay on every provider. Fixes GAP-04
   at the root instead of per-adapter.
2. **`Pending Action` becomes the one approval store.** Both stacks write to it; the
   Flutter approvals screen already renders it; expiry already exists.
3. **`AI Tool Invocation` doctype** — turn id, user, tool, arguments hash, outcome,
   duration. Satisfies ADR-0014 with something queryable, without logging customer data.
4. **Typed failures on the wire.** `{"type":"error","reason":"not_configured"}` so the
   client can advise instead of shrugging.

## 28. AI-first Roadmap

```
Flutter AI Workspace          ✅ built (unproven)
      ↓
AI Gateway (chat.py)          ✅ built
      ↓
Provider abstraction          ✅ built, 4 protocols — never had a key
      ↓
Agent Orchestrator (loop)     ✅ built, bounded
      ↓
Tool Registry                 ✅ built, 7 read tools
      ↓
Permission Layer              ✅ real, by construction
      ↓
Audit + Approval              ⚠️  built twice, wired once, wired wrong
      ↓
CRM / ERP APIs                ✅ CRM real · ⛔ ERP absent
```

**The architecture is not the bottleneck. Proof is.** Roughly 85% of the AI-first
skeleton exists; ~0% has been exercised with a real model.

- **Phase 0 — Stabilise:** GAP-01/02/03. One real answer on a device.
- **Phase 1 — Workspace UX:** GAP-08, GAP-12, stop button.
- **Phase 2 — Provider:** done; add budget/rate limits (GAP-23).
- **Phase 3 — Agent:** GAP-04, GAP-13, server-side history (GAP-09).
- **Phase 4 — CRM tools:** GAP-11 + read tools from §12.
- **Phase 5 — ERP tools:** GAP-16 — needs a product decision first.
- **Phase 6 — Permissions/safety:** GAP-05/06/07.
- **Phase 7 — Observability:** GAP-07, GAP-18, GAP-19.
- **Phase 8 — Production:** GAP-17.

---

## 29. Next 10 Tasks

| # | Task | Why now | Impact | Difficulty | Depends | Risk | Acceptance |
|---|---|---|---|---|---|---|---|
| 1 | Put a key in AI Settings, run `test_connection` | Everything downstream is unproven without it | Critical | Trivial | Owner | Cost | `{"ok":true}` returned |
| 2 | Typed failure reasons (GAP-03) | The most common state is misreported today | High | Low | — | None | Disabled provider shows "not set up" |
| 3 | Diagnose socket delivery (GAP-02) | Only remaining unknown in the transport | Critical | Medium | 1 | May be Frappe's | One reply arrives on a device |
| 4 | Server-issued call ids (GAP-04) | Confirmation is broken on the default provider | Critical | Medium | — | Touches 4 adapters | Replay approves on Anthropic |
| 5 | `AI Tool Invocation` doctype (GAP-07) | ADR-0014; must precede any write | High | Low | — | None | Every call queryable, no PII |
| 6 | Route approvals via `Pending Action` (GAP-05) | Stop maintaining approval twice | High | Medium | 4,5 | Refactor | Approval survives restart |
| 7 | Confirmation sheet in Flutter (GAP-06) | Server can ask; client ignores | High | Medium | 4,6 | None | Sheet blocks the write |
| 8 | `crm.create_lead` write tool (GAP-11) | Proves the whole safety chain | High | Low | 5,6,7 | **Writes data** | Refused unconfirmed, audited when confirmed |
| 9 | Badge the local fallback (GAP-08) | Users are being misled now | Medium | Trivial | — | None | Visible "AI not connected" |
| 10 | `FrappeSocketChannel` tests (GAP-10) | Untested code where the bug lives | Medium | Medium | 3 | None | Reconnect + malformed payload covered |

## 30. Long-term Roadmap

Server-side conversation + AI memory (ADR-0012/0019) · Production Order lifecycle ·
ERP tools (inventory, purchasing, BOM) · proactive agents (ADR-0016) · Telegram ·
multi-tenancy (ADR-0018) · production infrastructure · AI-authored analytics.

---

## 31. Final Score

| Dimension | Score | Justification |
|---|---|---|
| Architecture | **8**/10 | Clean layering, enforced; ADRs real and followed. −2 for two parallel AI stacks with divergent approval/persistence |
| UI / UX | **8**/10 | Design system enforced by test; complete l10n; goldens. −2 for AI discoverability and the silent fallback |
| AI readiness | **5**/10 | Every layer exists and is well-built; none has run with a model, and three defects prove it never has |
| CRM integration | **7**/10 | Real, permission-aware, live. −3: read-heavy, no writes via AI |
| ERP integration | **4**/10 | Work Order read + one write. Production Order lifecycle — the declared core — absent |
| Security | **6**/10 | Excellent secret hygiene, permissions by construction, structural injection defence. −4: no audit trail, plaintext history, broken confirmation |
| Performance | **5**/10 | Sound choices, **zero measurement** |
| Accessibility | **7**/10 | `liveRegion` on chat, KPI semantics. −3: never screen-reader tested |
| Testing | **6**/10 | 485 green, some exemplary. −4: no integration tests, and the three tests covering the AI path assert injected states |
| Production readiness | **2**/10 | Mobile release path real; backend is a dev bench with no TLS, CI, or monitoring |

### **Total: 58 / 100**
### **AI architecture readiness: 55 / 100**
### **Production readiness: 20 / 100**

---

## 32. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Provider costs unbounded | High | High | GAP-23 before opening to users |
| Confirmation ships broken with the first write tool | **High** | **Severe** | GAP-04 before GAP-11 — order matters |
| No audit trail when a write misfires | High | Severe | GAP-07 first |
| Socket unreliable on real networks | Medium | High | GAP-02; keep a polling fallback behind `AssistantChannel` |
| Users trust the keyword matcher as AI | **High now** | Medium | GAP-08 — cheapest fix here |
| Two stacks diverge further | Medium | Medium | Decide before Phase 4 |
| Prompt injection via CRM records | Low | High | Structurally defended; re-test with a real model |
| 7.4 GB dev machine can't run bench + emulator | Certain | Medium | Documented sequencing |

---

## 33. Decisions Required From Product Owner

1. **Which provider, and who pays?** Nothing downstream is provable without a key.
   Anthropic is configured as default; the abstraction makes it reversible.
2. **Is Production Order still the core entity?** `PROJECT.md` says yes; the code says
   CRM. Either build the lifecycle or amend the constitution — the gap is currently
   silent.
3. **Retire Stack A, or converge it?** WhatsApp intent-routing works and is tested but
   duplicates Stack B's purpose.
4. **Server-side chat history?** Requires a privacy answer: business conversations
   stored centrally, retention, who may read them.
5. **First write tool — which, and at what blast radius?** Recommend `crm.create_lead`:
   additive, easy to reverse, exercises the whole chain.
6. **Target for "production"** — internal pilot on one factory, or a real deployment?
   The infra gap is 2/10 versus a pilot and lower versus anything public.

---

## Product Owner Summary

**Если бы я был Principal Engineer этого проекта, следующие 5 вещей я бы сделал в
первую очередь:**

1. **Вставил бы API-ключ и получил один настоящий ответ на устройстве.** Всё
   остальное — предположения. 85% AI-скелета построено, 0% проверено с моделью.
2. **Починил бы типизированные ошибки (GAP-03).** Самое частое состояние системы —
   «AI не настроен» — сейчас показывается как «неизвестная ошибка». Полдня работы,
   и диагностика всего остального становится возможной.
3. **Сделал бы call id серверными (GAP-04) до первого write-инструмента.** Сейчас
   подтверждение сломано на провайдере по умолчанию, и тесты этого не видят.
   Если write-инструмент появится раньше — поедет в продакшн сломанным.
4. **Добавил бы audit trail (GAP-07) и подключил `Pending Action` (GAP-05).**
   Механизм уже написан, протестирован и даже отрисован в приложении — и
   игнорируется. Это самая дешёвая архитектурная победа в проекте.
5. **Пометил бы локальный fallback (GAP-08).** Одна строка. Сегодня пользователь
   получает карточку от keyword-матчера и думает, что это AI.

**Что сейчас НЕ надо делать:**

1. **Не трогать дизайн-систему.** Она лучшая часть проекта и защищена тестом.
2. **Не строить ERP-модули** (склад, закупки, бухгалтерия), пока не решён вопрос
   про Production Order — иначе построите не то.
3. **Не делать production-инфраструктуру сейчас.** Незачем разворачивать то, что
   ещё ни разу не ответило.
4. **Не переписывать провайдерный слой.** Он готов, все четыре протокола реальны.
   Ему нужен ключ, а не рефакторинг.
5. **Не добавлять новые экраны.** Их уже больше, чем проверенной функциональности;
   разрыв между «есть UI» и «работает» — главная проблема проекта, и новые экраны
   его увеличивают.

---

## Appendix — What this audit did not check

| Item | Why |
|---|---|
| Socket delivery on a device | Emulator not booted (agreed scope: bench only) |
| A real model answering | No API key exists |
| Screen reader behaviour | Requires a device session |
| Frame timings / 60 FPS | Requires a device session and a real streaming reply |
| ru/kk terminology quality | Requires a native speaker |
| Vendored upstream code | Out of scope by design — integration targets, not product |
