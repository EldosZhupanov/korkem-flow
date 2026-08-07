# AI pipeline — P0 / P1 fixes

**Date:** 2026-08-07 · Follows `full_project_audit.md`, which found the defects below.

Evidence tags as in the audit: `LIVE VERIFIED` (run against the bench, output
quoted), `TEST-ONLY VERIFIED`, `NOT SUPPORTED BY MODEL`, `NOT VERIFIED`.

---

## 1. What was broken

| # | Defect | Consequence |
|---|---|---|
| P0-1 | `chat.send` queued the turn **before** checking whether any provider was configured | The commonest state of a fresh install answered `HTTP 200`, then failed seconds later inside the worker as a generic error. `AssistantFailure.notConfigured` was **unreachable** — dead code the UI could never display |
| P0-2 | `chat.confirm` **replayed** the turn and matched the approved id against what the model asked for the *second* time | Anthropic and OpenAI mint a fresh random call id per response, so the id never matched: the user would be asked to confirm forever. Worse, the model got to re-decide the action *after* a human had agreed to a specific one |
| P0-3 | The confirmation tests used a fake provider returning a constant id `w1` | The suite passed against an implementation that could not work with either real provider. False confidence on the most safety-critical path |
| P1-1 | The Flutter client had `case AssistantNeedsConfirmation(): break;` | A terminal event silently dropped: the turn ended with an empty bubble and the proposal the server was holding open was unreachable from the app |
| P1-2 | Tool calls were recorded only via `frappe.logger()` | No queryable audit trail. ADR-0014 unmet |
| P1-3 | The keyword fallback answered with a real KORKEM data card and no marking | Users could not tell a matcher's card from an AI answer. The screen also said "local mode" unconditionally, which became untrue once the gateway worked |

## 2. Why it was broken

**P0-1** grew out of ADR-0009 applied too broadly. "Never block a request on an
LLM call" is right; it was read as "never do anything on the request path". But
configuration is a database read, costs no network call, and is exactly the
check that belongs where there is still a request to fail.

**P0-2** is the deeper one. The design treated an agent turn as a pure function
of *history + approvals*, so replaying it looked equivalent to resuming it. It
is not: the model is not a pure function. Two things follow — the identifier is
not stable, and neither is the decision. The id mismatch is the symptom; the
model re-deciding an approved action is the actual danger.

**P0-3** followed from a fake built for convenience rather than fidelity. A
constant id is the one thing no real provider does.

**P1-2** is the audit's own finding: a persistent, expiring, auditable approval
record (`Pending Action`) already existed, was tested, and was even rendered by
a Flutter screen — and the new path reimplemented approval in a worker's memory.

## 3. What was fixed

### P0-1 — typed errors, checked before the queue

New module `korkem_ai/errors.py`: one taxonomy, six codes, used by **both**
channels so they cannot drift.

```
AI_NOT_CONFIGURED · PROVIDER_UNAVAILABLE · AUTH_ERROR
RATE_LIMITED      · TOOL_ERROR           · UNKNOWN
```

- `chat.send` and `chat.confirm` call `llm.ensure_configured()` first — it builds
  the provider from the database and opens no socket.
- The code rides the HTTP error body as `ai_error_code`, alongside Frappe's own
  `exc_type`.
- Failures inside the worker are classified (`errors.classify`) and published as
  `{"type": "error", "reason": "<CODE>"}`.
- Provider HTTP statuses map by meaning: 401/403 → `AUTH_ERROR`, 429 →
  `RATE_LIMITED`, everything else → `PROVIDER_UNAVAILABLE`.

`LIVE VERIFIED` against the running bench with AI disabled:

```
POST /api/method/korkem_ai.korkem_ai.chat.send
→ HTTP 417
  {"ai_error_code":"AI_NOT_CONFIGURED",
   "exc_type":"AINotConfigured", ...}
```

The client maps the code, never the sentence — the server's English is
deliberately discarded so the UI can word it in ru/kk/en.

### P0-2 / P0-4 — server-assigned call ids, backed by `Pending Action`

The flow the brief asked for, built on the doctype that already existed rather
than a second one:

```
model proposes  →  Pending Action written (autoname: hash = the call id)
                →  needs_confirmation published with *that* id
                →  user confirms                → chat.confirm(call_id)
                →  ownership + status + expiry checked, synchronously
                →  approve() executes the recorded tool and arguments
                →  results fed to the model, which only summarises
```

The model is **never asked to propose again**. `Pending Action` gained two
fields (`tool`, `turn_id`); `entity_type`/`entity_name` became optional because
a creating tool has no target yet, and the existing re-validation still runs
whenever a target *is* named. `approve()` routes a model-proposed action through
the registry — never through `frappe.get_attr`, which stays reserved for
proposals this app writes itself.

`chat.confirm` refuses an id that is unknown, not a tool call, not the caller's,
or not still `Pending`. A rejection is recorded too (`chat.reject`), because
"a human said no" and "nobody answered" are different facts.

### P0-3 — a replay test that would have caught it

`_ShiftingIdProvider` mints a **new call id and different arguments every time it
is asked**, which is what Anthropic and OpenAI do.

**Mutation-checked.** Reinstating the replay-and-match implementation:

```
✖ test_the_approved_action_runs_exactly_once_with_its_original_arguments
✖ test_the_model_is_not_asked_to_propose_again        AssertionError: 2 != 1
✖ test_the_row_records_who_approved_it_and_what_happened
✖ test_the_turn_finishes_with_an_answer_rather_than_asking_again
      AssertionError: 'tool' not found in ['started', 'needs_confirmation']
✖ test_the_same_confirmation_cannot_be_used_twice
FAILED (failures=5)
```

That fourth line is the production symptom exactly: the user confirms, and the
system asks again.

### P1-1 — confirmation is a UI state

`pendingConfirmationProvider` holds the request; `ConfirmationCard` renders the
tool and **its arguments** inline in the transcript (not a modal — a dialog hides
the conversation the decision depends on, and dismissing it would strand a
proposal the server still holds). `approvePendingAction` sends back the server's
ids; `rejectPendingAction` calls `chat.reject`.

Mutation-checked: restoring `break;` fails 3 tests.

### P1-2 — audit trail

Every proposed AI action is now a `Pending Action` row carrying who
(`owner`/`resolved_by`), when (`creation`/`resolved_at`), what tool, what
arguments (`action_data`), which turn (`turn_id`), whether it was approved,
rejected or expired (`status`), and what happened (`result_data`). Queryable,
and swept by the existing hourly expiry job.

### P1-3 — the fallback says so

`ChatMessage.fromFallback` is set when the local matcher answered and is
persisted, so a conversation reopened after a model *is* connected still shows
which turns no model produced. A badge renders on any fallback reply that has
content to mistake for an answer — not on failures or "I don't understand",
which are already unambiguous. The screen subtitle now reflects which assistant
is actually answering instead of asserting "local mode" unconditionally.

## 4. Files changed

**Backend** (`backend/korkem_ai`, its own git repo)

| File | Change |
|---|---|
| `korkem_ai/errors.py` | **new** — the six-code taxonomy, `throw`, `classify`, `code_for_status` |
| `korkem_ai/chat.py` | validate-before-queue; `_record_proposals`; `_carry_out`; `_owned_pending_action`; `reject`; coded error events |
| `korkem_ai/orchestrator/llm.py` | `ensure_configured()`; misconfiguration → `AINotConfigured`; transport/status → specific codes |
| `korkem_ai/doctype/pending_action/pending_action.json` | `tool`, `turn_id`; `entity_type`/`entity_name`/`action_class` no longer required |
| `korkem_ai/doctype/pending_action/pending_action.py` | `_execute()` splits registry tools from legacy action paths; target re-validation only when a target exists |
| `korkem_ai/test_chat.py` | rewritten — see below |

**Flutter** (`mobile/korkem_flow`)

| File | Change |
|---|---|
| `core/api/frappe_exception.dart` | carries `ai_error_code` as `code` |
| `features/assistant/domain/assistant_event.dart` | 3 new failure cases; `AssistantFailure.fromCode`; `turnId` on the confirmation |
| `features/assistant/domain/chat_message.dart` | `fromFallback`, persisted |
| `features/assistant/data/remote_assistant.dart` | decode `reason`; prefer the code over the HTTP shape; `reject()` |
| `features/assistant/data/assistant_repository.dart` | `reject()` on the interface |
| `features/assistant/application/threads_controller.dart` | `pendingConfirmationProvider`, `approvePendingAction`, `rejectPendingAction`, `assistantIsRemoteProvider` |
| `features/assistant/presentation/widgets/confirmation_card.dart` | **new** |
| `features/assistant/presentation/widgets/chat_message_view.dart` | 3 new failure states; fallback badge |
| `features/assistant/presentation/chat_screen.dart` | renders the card; honest subtitle |
| `l10n/app_{en,ru,kk}.arb` | 9 new keys × 3 languages, parity kept at 209/209/209 |

## 5. Tests added

Backend `test_chat.py` — 28 tests (was 12):

- configuration refused before the queue, and the code on the response
- all six codes have wording; failures publish a `reason`
- a proposal is written down before anyone is asked, and nothing runs
- **the shifting-id replay suite** (4 tests)
- ownership: invented id, another user's id, reuse, expiry, rejection,
  approve-after-reject

Flutter — 8 new:

- all seven codes → the right `AssistantFailure`, including an unknown code
- an unconfigured gateway refused before the queue, using the **response shape a
  live bench actually returned**
- a 417 with no code is *not* read as unconfigured
- a confirmation carries its turn id
- confirmation becomes state; approving sends the server's ids; rejecting runs
  nothing; a local reply is marked as not-AI

## 6. Test results — `LIVE VERIFIED`

```
bench run-tests --app korkem_ai              Ran 201 tests   OK   (was 184)
bench run-tests --app korkem_manufacturing   Ran 13 tests    OK
dart format --set-exit-if-changed lib test   179 files, 0 changed
flutter analyze                              No issues found!
flutter test                                 296 passed        (was 288)
```

Total **510** automated tests, all passing.

## 7. Mutation tests

| Fix | Mutation | Result |
|---|---|---|
| P0-2 confirmation | restore replay + id matching in `run_turn_job` | **5 tests fail**, incl. the literal "asks again" symptom |
| P1-1 dropped event | restore `case AssistantNeedsConfirmation(): break;` | **3 tests fail** |

Both reverted; suites green again.

## 8. Ollama result

Environment, unchanged (no model downloaded):

```
ollama list → qwen2.5-coder:7b   4.7 GB   capabilities: completion, tools, insert
```

The brief expected a 3B model; the machine has **7B**. Ollama's systemd unit
binds `127.0.0.1` only, so the bench container could not reach it. Rather than
edit the unit, Docker or the repository, a temporary userspace TCP relay
(`0.0.0.0:11435 → 127.0.0.1:11434`) was used for the session.

**Working — `LIVE VERIFIED`:**

```
test_connection → {"ok":true,"provider":"Ollama","model":"qwen2.5-coder:7b"}
```

A real streamed turn through the real job function, real system prompt, all 7
tool schemas offered (1038 input tokens):

```
USER: Покажи мои открытые сделки
{"turn_id":"smoke-1","type":"delta","text":"status"}     ← token by token
{"turn_id":"smoke-1","type":"delta","text":"Open"}
{"turn_id":"smoke-1","type":"done","status":"answered",
 "usage":{"input_tokens":1038,"output_tokens":31}}
```

This is the first time in this project a real model has answered, and the first
time streaming has been seen with real tokens.

**Tool calling — `NOT SUPPORTED BY MODEL`.**

`qwen2.5-coder:7b` never populates the `tool_calls` field. It emits the call as
**text inside `content`**:

```
{"message":{"role":"assistant",
  "content":"{\n  \"name\": \"crm.search_deals\",\n  \"arguments\": {...}\n}"}}
                                    ← tool_calls: ABSENT
```

Confirmed across three prompts (Russian, English, and an explicit "use a tool"),
both raw against `:11434` and through our adapter. Ollama advertises a `tools`
capability for this model; in practice it does not produce structured calls.
**Not simulated, not worked around.** Our `OllamaProvider` reads
`message.tool_calls`, which is correct — the model is what does not comply.

One incidental validation: asked "How many deals are in the CRM?", the model
replied *"I cannot determine the exact number without calling a function"* rather
than inventing a figure — the system prompt's anti-fabrication rule working
against a real model.

## 9. Gemini result

```
GEMINI_API_KEY is missing
```

**GEMINI_API_KEY NOT AVAILABLE.** Also absent: `GOOGLE_API_KEY`, `GEMINI_KEY`,
`GOOGLE_GENAI_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
`OPENROUTER_API_KEY`, and no reference in any shell rc file. Phase 5 was not
run. No key was created, echoed, or written anywhere.

Consequence: **structured tool calling has still never been exercised by a real
model.** The local model cannot, and there is no cloud key. This remains the
single largest unproven area.

## 10. Real CRM tool result

All 7 registered tools, executed against the live site under real Frappe
permissions — `LIVE VERIFIED`:

```
profile.current_user          ok=True  {"user":"Administrator", roles:[…]}
crm.search_deals              ok=True  {"deals":[{"name":"_T-CRM Deal-00782",
                                        "organization":"Chi Systems", …}]}
crm.search_organizations      ok=True  {"organizations":[{"name":"Мобильный Тест ТОО"…}]}
tasks.list                    ok=True  {"tasks":[{"name":"46","title":"Produce Kitchen
                                        Facade (MFG-WO-2026-00001)"…}]}
production.list_work_orders   ok=True  {"work_orders":[{"name":"MFG-WO-2026-00001",
                                        "status":"In Process","qty":4.0…}]}
```

And the agent loop driving a tool against that live data end to end:

```
STATUS: answered
EXECUTED: [('crm.search_deals', True)]
ANSWER: Tool returned 5 deals from the live CRM.
```

**Stated precisely:** in that last run the *model* was scripted, because no
available model emits structured tool calls. Everything below it — the loop, the
registry, schema validation, permission checks, Frappe, the database, the real
rows — was live. No endpoint was invented and no data was faked.

## 11. Security findings

Re-checked against the Phase 7 list:

| Requirement | State |
|---|---|
| No database credentials reachable by the AI | Holds — tools receive no connection |
| No arbitrary SQL | Holds — no tool exposes one; `frappe.get_list` only |
| No shell execution | Holds |
| No root/Administrator access | Holds — `frappe.set_user(user)` in the job |
| No Frappe permission bypass | Holds — `db.get_all` appears nowhere in tools |
| Write/destructive → propose → confirm → execute | **Now holds end to end**, and is enforced by a persisted row rather than worker memory |

Improvements from this work:

- `frappe.get_attr` on a dotted path is now unreachable for model-proposed
  actions; they must resolve through the registry.
- Confirmations are bound to an owner, a status and an expiry, checked
  synchronously — a replayed confirm cannot run a write twice.
- Rejections are recorded.

Two issues found and fixed during this work, both mine:

1. **A test leaked into the developer's site.** `_record_proposals` commits
   deliberately (a client can confirm before the worker's transaction would
   close), and a commit inside a test carries everything pending with it — the
   first run left `AI Settings.enabled = 1` with a fake model name. This made a
   live probe of the "not configured" path pass for the wrong reason. Fixed by
   capturing and restoring the settings in `tearDown`. Worth noting generally:
   `run-tests` here runs against the real site, so rollback alone is not
   isolation.
2. The fallback badge initially rendered on *failed* turns as well, which two
   golden tests caught.

Still open: the bench serves plain HTTP and, in developer mode, returns full
tracebacks in error bodies (visible in the §3 output above). Both are
dev-only settings and both must be off before anything is deployed.

## 12. Remaining risks

| Risk | Status |
|---|---|
| **Structured tool calling never exercised by a real model** | The highest one. Needs a cloud key or a tool-capable local model |
| Socket delivery to a device | Still `NOT VERIFIED`. Untouched by this work; `FrappeSocketChannel` still has no tests |
| No write tools exist | The confirmation path is now correct and tested but still unreachable in production |
| No rate limit or token budget | Unchanged. `MAX_ITERATIONS` bounds one turn; nothing bounds a day |
| Chat history device-local and plaintext | Unchanged |
| Ollama relay is temporary | If the relay stops, turns fail with `PROVIDER_UNAVAILABLE` — correct and now legible, but the setup is not permanent |
| `frappe.get_attr` on `action_class` | Still reachable for legacy proposals. Permissions are System Manager only, but it deserves an allow-list |

## 13. Next 5 priorities

1. **Get one real model to make a structured tool call.** A Gemini key, or a
   tool-capable local model with the owner's approval to download. Everything in
   §10 stays half-proven until this happens.
2. **Ship `crm.create_lead`** — the first write tool. The whole chain (propose →
   persist → confirm → execute → audit) is now built and tested; this is what
   makes it real, and it is additive and easy to reverse.
3. **Test `FrappeSocketChannel`, then debug delivery on a device.** The last
   untested component, and where the one remaining unexplained failure lives.
4. **Rate limits and a token budget per user**, before any wider use.
5. **Surface `available_tools()` in the app.** It has been live and unused since
   it was written; users still cannot discover what the assistant can do.

---

## Appendix — reproducing the Ollama path

```sh
# 1. relay, because ollama's unit binds loopback only
python3 - <<'EOF' &
import socket, threading
def pipe(a,b):
    try:
        while (d:=a.recv(65536)): b.sendall(d)
    except OSError: pass
srv=socket.socket(); srv.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
srv.bind(("0.0.0.0",11435)); srv.listen(64)
while True:
    c,_=srv.accept(); u=socket.create_connection(("127.0.0.1",11434))
    threading.Thread(target=pipe,args=(c,u),daemon=True).start()
    threading.Thread(target=pipe,args=(u,c),daemon=True).start()
EOF

# 2. point the gateway at it (172.18.0.1 = the compose network gateway)
#    AI Settings: enabled=1, provider=Ollama,
#    model=qwen2.5-coder:7b, base_url=http://172.18.0.1:11435
```

Memory: the bench and a 7B model together leave ~90 MB free on this 7.4 GB
machine. It works, but do not also boot the emulator.
