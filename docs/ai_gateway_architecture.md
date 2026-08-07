# KORKEM AI Gateway — architecture

**Status:** Gemini path LIVE VERIFIED end to end, 2026-08-07.
Companion documents: `full_project_audit.md`, `ai_p0_p1_fixes.md`.

---

## 1. Architecture

One gateway, many providers, and a client that knows about none of them.

```
Flutter (KORKEM Flow)
      │  chat.send {message, provider?, model?}       ← never a credential
      ▼
KORKEM backend (Frappe, whitelisted RPC)
      ▼
AI Gateway ── korkem_ai/
      ├── errors.py            code taxonomy, one vocabulary, two channels
      ├── orchestrator/
      │     ├── capabilities.py   yes / no / unknown, per adapter
      │     ├── protocol.py       AIMessage, AIToolCall, AIStreamEvent
      │     └── llm.py            resolve() → adapter; 4 wire protocols
      ├── agent/loop.py        provider-independent; bounded at 5 iterations
      ├── tools/registry.py    only registered names, schema-validated
      ├── chat.py              queue, publish, Pending Action persistence
      └── settings_api.py      configure providers; keys write-only
      ▼
Provider Adapter → AI Provider → structured tool call
      ▼
Tool Registry → Frappe permissions → CRM / ERP → tool result
      ▼
back to the provider → final answer → realtime stream → Flutter
```

The agent loop contains **no provider-specific branch**. It sees `AIMessage`,
`AIToolCall`, `AIStreamEvent` and nothing else; the four adapters translate.

## 2. Provider abstraction

Duck-typed, deliberately — four classes that share no behaviour should not share
a base class just to satisfy a type checker. What an adapter provides:

| Member | Purpose |
|---|---|
| `chat(system, messages, tools)` | one turn → `AIResponse` |
| `stream(system, messages, tools)` | `AIStreamEvent` sequence |
| `complete_json(system, user_message, schema)` | schema-constrained output |
| `capabilities` | `{Capability: Support}` — see §6 |
| `streams_natively` | derived from `capabilities`, not a second fact |
| `list_models()` | optional; absent means "no catalogue" |
| `_encode(message)` | the vendor's message shape |

`llm.resolve(provider, model)` is the single entry point. `PROVIDER_ADAPTERS`
maps a provider name to its class — one table, so "which providers exist" has a
single home.

### The opaque passthrough

`AIToolCall.provider_meta` carries bytes only the originating adapter
understands. It exists because Gemini returns a `thoughtSignature` beside each
`functionCall` and **rejects the next request** without it:

> Function call is missing a thought_signature in functionCall parts. This is
> required for tools to work correctly.

Modelling it as an opaque bag rather than a `thought_signature` field is what
keeps the protocol provider-agnostic — the next provider with a continuation
token needs no change, and the agent loop never learns any of this exists.

## 3. Credential model

**A key goes in and never comes out.**

- Stored on the `AI Provider` doctype as a Frappe `Password` field — encrypted
  at rest with the site key, readable only via `get_password()`.
- `settings_api` returns `masked_key` (`AQ.A••••••••iO5A`): enough to tell two
  accounts apart, useless to anyone who intercepts it. Keys under 12 characters
  are hidden entirely, because masking four of six is not masking.
- `api_key` is **write-only**. Omitting it leaves the stored value untouched, so
  a screen can save a model change without possessing the key.
- The client sends `provider` and `model` — *logical selections*. There is
  nowhere in the API to put a credential even if a client wanted to.
- Configuration is `System Manager` only. *Using* the assistant is for everyone.

Verified live: the real key appears in **no** response body from
`list_providers`, `save_provider`, `test_provider` or `list_models`.

## 4. Provider registry

`llm.PROVIDER_ADAPTERS` — Anthropic, OpenAI, OpenRouter, OpenAI-compatible,
Google Gemini, Ollama. `settings_api.list_providers()` returns all six whether
configured or not, so the settings screen never keeps its own copy of the list.

## 5. Model registry

`list_models(provider)` asks the provider. Advisory by construction, and
labelled so: Gemini lists `gemini-2.5-flash` and then answers **404 "no longer
available to new users"**. Only a connection test settles a specific model,
which is why the screen offers both. Per model: `id`, `display_name`,
`context_window`, `supports_tools`, `supports_streaming` — unknown where the
provider does not say, never guessed.

## 6. Capability system

Three-valued, and the third value is the point.

```python
class Support(StrEnum):
    YES = "yes"; NO = "no"; UNKNOWN = "unknown"
```

`can()` returns True **only** for `YES` — `UNKNOWN` is never permission.

| Provider | streaming | tools | structured output | local |
|---|---|---|---|---|
| Anthropic | yes | yes | yes | no |
| OpenAI-compatible / OpenRouter | yes | yes | yes | no |
| Google Gemini | yes | yes | yes | no |
| **Ollama** | yes | **unknown** | yes | yes |

Ollama's `unknown` is measured, not hedged: `qwen2.5-coder:7b` advertises a
`tools` capability through Ollama's API and then returns the call as prose.
Whether another local model would is genuinely unknown, and claiming either
answer would be a lie in one direction or the other.

## 7. Normalized events

The client subscribes to one realtime event, `korkem_ai_chat`, carrying a
`type`. Flutter never learns which vendor answered.

| `type` | Meaning |
|---|---|
| `started` | turn dequeued |
| `delta` | text fragment |
| `tool` | a tool ran (`tool`, `ok`, `call_id`) |
| `needs_confirmation` | paused; `calls` carry **server-issued** ids |
| `done` | final `text` + `usage` |
| `error` | `reason` = a code from §12 |

Unknown types are ignored rather than treated as failures, so an older client
meeting a newer server degrades quietly.

## 8. Tool registry

Unchanged by this work and reused as-is. Every tool declares name, description,
JSON-schema input, `Risk` (READ / WRITE / DESTRUCTIVE), handler, and the
doctypes it touches. Seven read tools today; **no write tools yet**.

Permissions are Frappe's: every read goes through `frappe.get_list`, so
`AI permission ≤ ERP permission` holds *by construction*. `frappe.db.get_all`
appears nowhere in a tool. The job runs as the asking user, never Administrator.

## 9. Agent loop

```
user message → model → text? → answer
                     → tool call? → needs confirmation and unapproved? → STOP
                                  → else execute → feed result back → model → …
```

Bounded at `MAX_ITERATIONS = 5`. Provider-independent: it receives an adapter
and never inspects its type. Malformed arguments are reported to the model as
data so it can retry, rather than killing the turn.

## 10. Confirmation flow

A proposal is **written down** before anyone is asked:

```
model proposes → Pending Action row (autoname: hash = the call id)
              → needs_confirmation published with that id
              → user approves → chat.confirm(call_id)
              → ownership + status + expiry checked synchronously
              → approve() runs exactly the recorded tool and arguments
              → results handed to the model, which only summarises
```

The model is never asked to propose again. This is what makes confirmation work
across providers that mint a fresh random call id per response — and what stops
a model substituting a different action after a human agreed to a specific one.
It also gives ADR-0014 an audit trail and ADR-0015 a real approval record.

## 11. Streaming

Anthropic, OpenAI-compatible and Ollama stream natively. **Gemini now does too**
— `streamGenerateContent?alt=sse`, replacing a buffered call that pretended to.

One bug worth recording: `requests.iter_lines(decode_unicode=True)` falls back to
ISO-8859-1 for `text/event-stream` when the Content-Type carries no charset, and
no provider sends one. Every streamed non-ASCII reply was mangled — which in a
Russian- and Kazakh-first product is *most* replies. `_post_stream` now forces
UTF-8. It affected all four providers, since they share that function.

## 12. Security

| Control | State |
|---|---|
| Keys server-side only, encrypted | ✔ |
| Never returned to a client | ✔ verified against live responses |
| Not in source, git history, logs, or tests | ✔ |
| Configuration gated to System Manager | ✔ |
| Model cannot issue arbitrary HTTP / SQL / shell | ✔ — only registered tools |
| Prompt injection | Structural: the system prompt is never concatenated with user or tool data |
| Writes require confirmation | ✔ — persisted, owner-bound, single-use, expiring |
| Tracebacks in error bodies | ⚠ developer mode only; must be off in production |

## 13. CRM integration

Seven read tools over `CRM Deal`, `CRM Lead`, `CRM Organization`, `CRM Task`,
`Work Order`, plus `profile.current_user`. Verified against live data: Gemini
asked for `crm.search_deals`, the registry executed it under real permissions,
and real records came back (`_T-CRM Deal-00802 — Kappa Tech`).

## 14. Adding a provider

1. Write an adapter class in `llm.py` inheriting `HasCapabilities`; implement
   `chat`, `stream`, `complete_json`, `_encode`; declare `capabilities`
   honestly, using `UNKNOWN` where nobody has checked.
2. Add it to `PROVIDER_ADAPTERS` and, if it has a default endpoint,
   `DEFAULT_BASE_URLS`.
3. Add a branch in `_build`.
4. Optionally implement `list_models()`.
5. Nothing else. The loop, tools, confirmation, streaming and the client are
   untouched — that is the test of whether the abstraction holds.

## 15. Testing strategy

Unit and integration tests use **fake providers only**; no test requires a
secret and none contains one. Live provider verification is manual and opt-in,
recorded in this document and in `ai_p0_p1_fixes.md` with quoted output.

Covered: provider registration, capability reporting, credential masking,
write-only key semantics, permission gating, missing/invalid configuration,
streaming (including a Gemini SSE tool call retaining its `thoughtSignature`),
structured tool calls, tool execution, the multi-step loop, confirmation, the
**shifting-provider-id replay** case, ownership, reuse, expiry, rejection.

## 16. Future roadmap

1. A real model must make a **write** through the confirmation path —
   `crm.create_lead` is the intended first one.
2. Per-user and per-workspace usage accounting; the `usage` field is already
   published, nothing aggregates it yet.
3. Rate limits and a token budget before wider use.
4. Server-side conversation history (`Agent Conversation` exists and is unused
   by the chat path; history is still device-local).
5. Explicit fallback between providers — deliberately **not** built yet.
6. OpenAI, Anthropic and OpenRouter adapters exist but are unverified against
   live endpoints; each needs one real call.
