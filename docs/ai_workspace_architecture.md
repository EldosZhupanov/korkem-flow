# AI Workspace — the architecture that exists, and where the AI goes

**Status:** research complete, implementation in progress.
**Method:** read from the repository and the running bench, not assumed. Anything
unverified is marked as such. No endpoint, doctype or field is named here unless
it was found in source.

---

## 1. What already exists

### 1.1 The backend AI app is real

`backend/korkem_ai/` is a working Frappe app, not a placeholder. It owns four
doctypes and an orchestrator:

| Doctype | Kind | What it is |
|---|---|---|
| `AI Settings` | Single | Provider configuration. Fields: `enabled` (Check), `provider` (Select: `Anthropic`, `Ollama`), `model` (Data), `effort` (Select), `anthropic_api_key` (**Password**), `ollama_base_url` (Data) |
| `Agent Conversation` | Document | A conversation thread |
| `Agent Conversation Message` | Document | One message in it |
| `Pending Action` | Document | An action awaiting human approval. Has whitelisted `approve` / `reject` |

`korkem_ai/orchestrator/llm.py` is already a **provider abstraction**: `get_provider()`
reads `AI Settings` and returns `AnthropicProvider` or `OllamaProvider`, both
exposing one method — `complete_json(system, user_message, schema)`.

`korkem_ai/orchestrator/router.py` classifies an inbound message's intent and
dispatches to an agent skill (`agents/sales_agent.py`, `agents/production_agent.py`).

**Important scoping fact:** this orchestrator was built for *inbound customer
messages from WhatsApp*, not for an internal user chatting with an assistant.
Its entry point is `handle_message(conversation_name, message_text)`, called from
the WhatsApp webhook. It produces `Pending Action`s for staff to approve. It is
not reachable from the mobile app and was never meant to be.

### 1.2 The custom API surface is almost empty

Verified in `docs/backend_api_audit.md` §3 and re-checked by grepping for
`@frappe.whitelist` across `backend/korkem_ai`:

| Method | Reachable from mobile |
|---|---|
| `korkem_ai.korkem_ai.dashboard.get_summary` | yes |
| `Pending Action.approve` / `.reject` (via `run_doc_method`) | yes |
| `korkem_manufacturing.shop_floor.complete_task` | yes |
| `korkem_ai…whatsapp.webhook` | no — `allow_guest`, inbound only |

Everything else the app does goes through the generic REST resource API.

### 1.3 The Flutter data layer

`lib/core/api/frappe_client.dart` — a thin typed wrapper over dio with exactly
four operations: `getList`, `getDoc`, `callMethod`, `runDocMethod`. Every feature
repository (`deal_repository.dart`, `task_repository.dart`, …) is built on it.
Auth is a `Session` with `ApiKeyCredentials` held in `flutter_secure_storage`.

`lib/features/assistant/` already has the seam: `AssistantRepository` is an
abstract class with one method, `reply({prompt, history})`, and `LocalAssistant`
is a keyword matcher that returns a card kind and no prose. It writes no figures
— context cards read the real providers at build time.

**There is no streaming infrastructure.** No websocket client, no SSE, no
`ResponseType.stream` anywhere in `lib/`. dio can do all three; none is wired.

### 1.4 Permissions are already enforced where it counts

Frappe CRM restricts `CRM Deal` and `CRM Lead` to the owner and assignees. A
fresh `Sales User` sees zero rows (`docs/backend_api_audit.md` §6). Two
consequences:

- **"AI permission ≤ ERP permission" is free** — *provided* every tool executes
  under the calling user's own Frappe session rather than a service account.
  This is the single most important design constraint in this document.
- `korkem_ai/dashboard.py` already models the right discipline: it counts through
  `frappe.client.get_count` so permission query conditions apply, and returns
  `None` rather than `0` for a metric the caller may not see — "no deals" and
  "not allowed to know" are different facts.

---

## 2. The decision the brief asks for: keys in the app, or keys on the server

The brief asks for provider adapters and API-key entry **in the Flutter app**
(its Phases 2, 3, 16, 38), and separately asks to compare that against a gateway
and "prefer the option that better protects provider credentials".

### 2.1 This project has already decided

**ADR-0011 — Integrations Through Gateways (Accepted, 2026-07-27):**

> All external, third-party integrations are called only from a designated
> gateway-layer service … **never directly from the Frontend, Mobile client**, or
> business-logic Doctype controllers.

Three further ADRs bind the same area: **ADR-0009** (long-running operations must
be queued — an LLM call must never block a request handler), **ADR-0014** (every
AI action must be auditable), **ADR-0015** (human approval for critical actions).

### 2.2 The comparison, on the merits

| | **A — Flutter → provider** | **B — Flutter → KORKEM gateway → provider** |
|---|---|---|
| **Credentials** | The key ships to every device. Android `flutter_secure_storage` is keystore-backed, but a rooted device, a debuggable build or a memory dump reaches it. Each user needs their own key. | Key stays in Frappe's encrypted `Password` field, server-side. No device ever holds one. |
| **Revocation** | Rotate = every user re-enters a key | One field, one save |
| **Cost control** | None. A device can spend the org's budget without limit | Rate limits and quotas at one point |
| **Audit** | Client-side only, therefore untrustworthy | Server-side, alongside the ERP audit trail ADR-0014 requires |
| **Multi-user** | Per-device configuration drift | One org policy |
| **Tool calling** | Tools execute in the app → app decides its own permissions → the LLM's reach is bounded by client code, which an attacker controls | Tools execute in Frappe under the user's session → **Frappe enforces permissions**, not us |
| **Latency** | One hop fewer | One hop more, same datacentre as the data the tools read |
| **Offline / local Ollama** | Direct to `localhost` works trivially | Needs the bench to reach the Ollama host |
| **Provider switching** | Client release | Settings change |

The tool-calling row is decisive on its own. In Option A the model's blast radius
is enforced by the client — and the client is the thing we do not control. In
Option B a tool call is a Frappe call under the user's session, so a deal the
user cannot read is a deal the AI cannot read, *by construction* rather than by
our diligence.

### 2.3 Decision

**Option B.** Provider credentials and provider adapters live in
`backend/korkem_ai`; the mobile app never holds an API key and never speaks a
provider wire protocol. This follows ADR-0011 rather than reversing it, and it is
the option the brief's own security criterion selects.

**What this changes about the brief:** the Flutter-side "AI Providers" settings
screen becomes a *view onto server-side configuration* (choose provider and
model, test the connection, see status) rather than a place to type secrets. The
provider abstraction — `AIProvider`, `AIModel`, `AITool`, `AIToolCall`, streaming
events — is still built exactly as the brief describes, but in Python, in the
gateway, where it protects something.

**What this does not change:** everything about the tool system, confirmation,
audit, context cards, deep links, streaming UX and error handling is unaffected;
only the side of the wire the provider adapters sit on.

---

## 3. Gaps between what exists and what the workspace needs

Recorded honestly. Nothing below is implemented yet.

| # | Gap | Why it matters |
|---|---|---|
| A1 | `llm.py` exposes only `complete_json()` | No streaming, no tool/function calling. Both are required and neither can be faked. |
| A2 | `AI Settings.provider` is a two-value Select (`Anthropic`, `Ollama`) | OpenAI, OpenRouter, Gemini and generic OpenAI-compatible need to be reachable. A Select is the wrong shape for "add your own endpoint". |
| A3 | No whitelisted chat endpoint | The mobile app cannot start a conversation turn at all today. |
| A4 | No tool registry | There is nothing to give a model, and nothing to validate a call against. |
| A5 | No streaming transport | ADR-0009 forbids blocking a request handler on an LLM call, so the answer is not "hold the HTTP response open". Frappe ships `frappe.publish_realtime` over socket.io: enqueue the turn, stream deltas to the user's own realtime room. **Now verified — see §3.1.** |
| A6 | `Agent Conversation` is shaped for WhatsApp customer threads | ADR-0012 separates AI memory from ERP data. Whether to reuse this doctype for workspace chats or add one is an open design question, not a decision to make casually. |
| A7 | Flutter `ChatThread` is local-only (`shared_preferences`) | Fine for now; a server-side conversation store is a later phase, and the brief does not ask for cross-device sync. |

### 3.1 The streaming transport, measured

Streaming was the one gap that could have invalidated the design, so it was
tested rather than reasoned about. Three findings, in the order they were made:

1. **The emulator can reach socket.io.** `10.0.2.2:9000` returns a valid
   Engine.IO handshake (`{"sid":…,"upgrades":["websocket"]}`), while `:8000`
   returns 404 for the same path — so the probe is genuinely hitting the
   socket.io process and not the web server.

2. **A first inference was wrong, and it is worth recording why.**
   `common_site_config.json` sets `redis_socketio: redis://127.0.0.1:13000`,
   and nothing listens there — connection refused. That looked like a broken
   realtime pipeline. It is not: `frappe.realtime.emit_via_redis` publishes
   through `get_redis_connection_without_auth()` and the node subscriber calls
   `get_redis_subscriber()`, whose default `kind` is **`redis_queue`**. Both
   ends use `redis://redis-queue:6379`, which is healthy. The `redis_socketio`
   entry is vestigial on this bench.

3. **A probe that cannot fail proves nothing.** Calling `publish_realtime` and
   observing no exception was not evidence: `emit_via_redis` wraps its publish
   in `with suppress(redis.exceptions.ConnectionError)`, so it returns quietly
   whether or not Redis is reachable. The conclusive test was to subscribe to
   the `events` channel and watch the payload arrive — which it did.

**Conclusion: the transport is viable.** Enqueue the turn (ADR-0009), publish
deltas to the user's room, and let the client read them over socket.io at the
configured base URL's host. No infrastructure change is required.

Still open, and not yet tested: authenticating the socket.io connection from
the app, which uses the Frappe session cookie rather than the API key pair the
REST client holds.

---

## 4. Target architecture

```
Flutter (no credentials, no provider protocol)
  │  POST /api/method/korkem_ai…chat.send      → enqueues a turn
  │  socket.io room: user-scoped                ← streams deltas
  ▼
KORKEM AI Gateway  (backend/korkem_ai)
  ├─ provider adapters: Anthropic · OpenAI · OpenRouter · Gemini · Ollama · generic OpenAI-compatible
  ├─ system instruction (immutable, application-owned)
  ├─ tool registry — explicitly registered tools only
  ├─ permission + confirmation policy per tool
  └─ audit trail per write
  ▼
Tool execution — in-process Frappe calls under **the caller's own session**
  ▼
Frappe / ERPNext / CRM  → permissions enforced here, not by us
```

Two invariants worth stating as rules:

1. **The model never gets a generic HTTP tool.** It sees only registered tools
   with typed schemas. This is what makes permissions, audit and confirmation
   possible at all.
2. **ERP data reaching the model is data, never instruction.** A deal whose
   notes read "ignore previous instructions" is a deal with odd notes. Tool
   results are delivered in tool-result slots, never concatenated into the
   system prompt.

---

## 5. What is deliberately not being built

- **A vector database / RAG over the ERP.** The brief's Phase 39 rules it out and
  it is not needed: structured tool calls against a relational ERP are more
  precise than embeddings over it.
- **Autonomous background agents, shell or HTTP tools.** Explicitly excluded.
- **Multi-tenancy.** ADR-0018 defers it.
- **Rewriting the WhatsApp orchestrator.** It serves a different actor
  (a customer, inbound) and works. The workspace chat is a second entry point to
  the same gateway, not a replacement for it.

---

## 6. Status legend used throughout this work

| Term | Meaning |
|---|---|
| IMPLEMENTED | Code exists, `flutter analyze` and tests pass |
| VERIFIED | Additionally exercised end to end against the running bench or on a device |
| PARTIAL | Some paths work, named exceptions do not |
| BLOCKED | Cannot proceed; the blocker is named |
| NOT IMPLEMENTED | Not started |

Nothing in this document is claimed as VERIFIED. The sections above are research
findings; §4 is a target, not a description of today.
