> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Phase 5 — Safe write tools and the real AI action loop

**Date:** 2026-08-08 · Follows `ai_gateway_architecture.md`.

Status vocabulary: `LIVE VERIFIED` (executed against the running bench and a real
provider, output quoted) · `TEST VERIFIED` · `NOT VERIFIED` ·
`NOT SUPPORTED BY MODEL`.

---

## 1. Executive summary

The first tool that changes data exists, and the whole safety chain has been
driven end to end by a real model: **`LIVE VERIFIED`**.

```
"Создай нового лида: Айгүл Серикова, компания «Мебель Астана», …"
  → Gemini emits a structured crm.create_lead call
  → 0 CRM records written
  → Pending Action 28js472lkv, status Pending
  → user confirms
  → server executes the *stored* tool and arguments
  → CRM-LEAD-2026-00003 created
  → audit row complete
  → Gemini streams: "Новый лид успешно создан: ID CRM-LEAD-2026-00003 …"
```

Confirming the same call id again creates **zero** additional records.

Three defects were found on the way, none by reading code:

| Found | How |
|---|---|
| `registry.execute` checked `"read"` permission for **every** tool regardless of risk — a write would have run for anyone who could see a lead | inspection before writing the tool |
| Confirmation was **check-then-act**, so two simultaneous confirmations could both pass and write twice | inspection; then mutation-tested |
| **Gemini refused to call the write tool at all**, writing its own confirmation in prose instead — the tool was unreachable | running it |

A fourth surfaced from the previous phase's own documentation debt: the Pending
Action did not store the provider's `thoughtSignature`, so a confirmed write
created the record and *then* failed to report it.

## 2. Before / After

| | Before | After |
|---|---|---|
| Write tools | none | `crm.create_lead` |
| Permission check | `"read"` for all tools | follows declared risk (`read`/`create`/`delete`) |
| Replay guard | check-then-act | atomic conditional UPDATE |
| Audit row | user, tool, args, status, result | + provider, model, `executed_at`, `error`, `provider_meta` |
| Tool failure | recorded as a clean `Approved` | recorded with its error |
| Model behaviour on writes | asked in prose, never called the tool | calls the tool; KORKEM asks |
| Backend tests | 216 | **240** |

## 3. Architecture

No new subsystem. Everything reuses what Phase 4 built:

```
Gemini → structured tool call (Risk.WRITE)
       → agent loop STOPS, executes nothing
       → chat._record_proposals → Pending Action row
             name = server-issued call id      (autoname: hash)
             tool, action_data (arguments), provider, model, turn_id,
             provider_meta (opaque, e.g. thoughtSignature), expires_at
       → needs_confirmation published with that id
       → Flutter ConfirmationCard shows tool + arguments
       → user approves → chat.confirm(call_ids=[…])
       → _owned_pending_action: exists? is a tool call? owned? still Pending?
       → PendingAction.approve()
             is_expired? → claim() atomically → registry.execute(stored args)
       → result recorded → fed back to the model as history
       → model summarises → streamed to Flutter
```

## 4. Files changed

**`backend/korkem_ai`**

| File | Change |
|---|---|
| `tools/registry.py` | `Risk.permission_type`; `execute()`/`available_to()` use it; `ToolSpec.timeout`, `.audit_category` |
| `tools/catalog.py` | `create_lead()` + registration (the only new business logic) |
| `doctype/pending_action/pending_action.py` | atomic `claim()`; failure recording; `provider_meta` replay |
| `doctype/pending_action/pending_action.json` | `provider`, `model`, `executed_at`, `error`, `provider_meta` |
| `chat.py` | records provider/model/provider_meta on proposals; restores them on confirm |
| `agent/prompt.py` | tells the model KORKEM owns confirmation — **the fix that made the tool reachable** |
| `tools/test_write_tools.py` | **new**, 23 tests |
| `tools/test_registry.py` | the "all tools are read-only" test replaced by the policy it should always have asserted |

Flutter: **unchanged this phase.** The existing `ConfirmationCard` renders the
new tool's arguments without modification, which is the strongest evidence the
Phase-4 abstraction holds.

## 5. `crm.create_lead` schema

Derived from `frappe.get_meta("CRM Lead")`, not assumed. Only `first_name` and
`status` are required by the doctype; `organization` is **Data**, not a link;
`status`/`source` are **Links** to `CRM Lead Status` / `CRM Lead Source`.

| Argument | Type | Notes |
|---|---|---|
| `first_name` | string | **required** |
| `last_name`, `organization`, `email`, `mobile_no`, `job_title` | string | optional |
| `source` | string | validated against `CRM Lead Source` |
| `status` | enum | `New Lead` · `Contacted` · `Nurture` · `Qualified` — default `New Lead` |

`Converted` and `Junk` are deliberately **excluded**: they are outcomes of a
sales process, and an assistant opening a lead as "Converted" would corrupt
every funnel report in the product.

Unknown arguments are rejected outright (`nickname is not a known argument`),
not ignored — silently dropping one lets a model believe it set something it
did not. Returns `{lead_id, lead_name, organization, status, lead_owner}`.

## 6. Confirmation flow — `LIVE VERIFIED`

```
=== EVENTS === ['started', 'needs_confirmation']
tool: crm.create_lead
arguments: {"first_name":"Айгүл","last_name":"Серикова",
            "organization":"Мебель Астана","job_title":"закупщик",
            "source":"Referral"}
server call_id: 28js472lkv
leads before confirm: 0

=== USER CONFIRMS ===
events: ['started', 'tool', 'delta', 'delta', 'delta', 'delta', 'done']
leads after confirm: 1
```

The model is never asked to propose again — `provider.asks == 1` across both
turns (`TEST VERIFIED`).

## 7. Security model

Checked against every item in the brief:

| Attack | Result |
|---|---|
| Another user confirms your proposal | Refused — same wording as an unknown id, so existence is not leaked (`TEST VERIFIED`) |
| Expired proposal | Refused (`TEST VERIFIED`) |
| Already-approved / already-executed | Refused at both `chat.confirm` and `approve()` (`TEST VERIFIED`) |
| Duplicate / replay | Refused; **0 extra records** (`LIVE` + `TEST VERIFIED`) |
| Modified arguments | Impossible — `confirm` accepts ids only; arguments are read from the row |
| Modified tool name | Impossible — same reason |
| Unauthorized request | `registry.execute` checks `create` permission on `CRM Lead` |
| Client-supplied user id | Never trusted — the job runs as `frappe.set_user(user)` from the session |

Nothing is checked client-side only. The Flutter app sends **one id**; the
server decides everything else.

## 8. Audit trail — `LIVE VERIFIED`

One row, the existing `Pending Action`, no parallel system:

```json
{"name":"28js472lkv","tool":"crm.create_lead","status":"Approved",
 "owner":"Administrator","resolved_by":"Administrator",
 "provider":"Google Gemini","model":"gemini-flash-latest","turn_id":"gw-1",
 "creation":"2026-08-08 01:08:03.478","resolved_at":"…03.678",
 "executed_at":"…04.220","error":null}
```

Covers every field the brief asked for. **No credential is stored** — the
provider *name*, never the key. `provider_meta` holds opaque continuation data
only.

A failed tool is now recorded as a failure. Previously it returned data rather
than raising, so `approve()` wrote a row reading `Approved` with an empty
`error` — an audit trail that said a write succeeded when it had not.

## 9. Replay protection

`claim()` performs a single conditional UPDATE and lets the database decide the
winner:

```sql
UPDATE `tabPending Action` SET status='Approved', …
 WHERE name=%(name)s AND status='Pending'
```

**Mutation test** — replacing it with the check-then-act it superseded:

```
with the fix:     claim() results: True False   VERDICT: PASS
mutation applied: claim() results: True True    VERDICT: FAIL — replay possible
```

Reverted; suite green.

## 10. Real Gemini evidence — `LIVE VERIFIED`

Provider `Google Gemini`, model `gemini-flash-latest`, key read from
`~/.korkem_gemini_key` into the encrypted `AI Provider` field. **The key was
never printed, committed, or placed in a fixture.**

Final streamed answer:

> Новый лид успешно создан:
> **ID:** CRM-LEAD-2026-00003 · **Имя:** Айгүл Серикова ·
> **Организация:** Мебель Астана · **Должность:** закупщик ·
> **Источник:** Referral · **Статус:** New Lead

### The prompt defect

On the first live attempt Gemini did **not** call the tool. It wrote its own
confirmation into the chat:

> «Пожалуйста, подтвердите создание нового лида… Создать лида с этими
> параметрами?»

Polite, and useless: the user would have had to answer twice, and the model's
question creates nothing. The write tool was unreachable. `agent/prompt.py` now
states that KORKEM owns confirmation and the model should call the tool. That
one paragraph is the difference between a working write path and none.

## 11. CRM evidence — `LIVE VERIFIED`

```json
{"name":"CRM-LEAD-2026-00003","lead_name":"Айгүл Серикова",
 "organization":"Мебель Астана","job_title":"закупщик",
 "source":"Referral","status":"New Lead","lead_owner":"Administrator"}
```

Kazakh (`ү`) and Cyrillic survive the whole path. Three probe leads
(`CRM-LEAD-2026-00001/2/3`) remain on the dev site **on purpose** — they are the
evidence for the claim above.

## 12. Flutter UX

`NOT VERIFIED on device.` The existing `ConfirmationCard` renders the new tool
and its arguments with no change, and `approvePendingAction` sends back the
server's id — `TEST VERIFIED`.

**Not implemented:** the "✓ Лид создан / [Открыть лид]" affordance. Today the
result reaches the user as the model's prose, which does name the lead id but is
not a link. Doing it properly needs the tool result on the `tool` event, which
is a server change and out of this phase's scope. Recorded rather than faked.

A failed write cannot read as success: failures arrive as `AssistantFailed` with
a typed reason and render through `_Failure`.

## 13–15. Tests

**240 backend** (was 216) + **301 Flutter** + **13 manufacturing** = **554**.

`tools/test_write_tools.py` — 23 tests: nothing runs before approval (asserted
on the *database*), exactly one lead on confirm, the model is not re-asked,
replay refused, simultaneous claims, server-decides-what-runs, foreign user,
invented id, expired, rejected, permission-by-risk, and the argument negatives
(missing required, wrong type, unknown argument, outcome status, unknown
source). Plus failure recording and no-traceback-to-the-user.

Mutation tests: the atomic claim (§9) and — from the prior phase, still
passing — the confirmation replay.

## 16. Provider matrix

| Provider | Chat / streaming | Structured tool calls | Write loop |
|---|---|---|---|
| Google Gemini | `LIVE VERIFIED` | `LIVE VERIFIED` | `LIVE VERIFIED` |
| Ollama (`qwen2.5-coder:7b`) | `LIVE VERIFIED` | `NOT SUPPORTED BY MODEL` | n/a |
| OpenAI | `TEST VERIFIED` (adapter) | `NOT VERIFIED` | `NOT VERIFIED` |
| Anthropic | `TEST VERIFIED` (adapter) | `NOT VERIFIED` | `NOT VERIFIED` |
| OpenRouter | `TEST VERIFIED` (adapter) | `NOT VERIFIED` | `NOT VERIFIED` |

No credentials exist for OpenAI, Anthropic or OpenRouter, so none was tried.

## 17. AI tool safety policy

Now enforced by a test rather than stated in prose
(`test_every_write_tool_requires_confirmation_and_create_permission`):

| Risk | Frappe permission | Confirmation | Today |
|---|---|---|---|
| `READ` | `read` | none — making people confirm a search is how confirmations become click-through | the 7 read tools |
| `WRITE` | `create` | **required**; persisted, owner-bound, single-use, 24h expiry | `crm.create_lead` |
| `DESTRUCTIVE` | `delete` | required, plus limits still to be designed | **none, deliberately** |

A separate test asserts no destructive tool exists, so adding one has to be a
decision rather than an accident.

## 18. Remaining risks

- Socket delivery to a device is still `NOT VERIFIED`; `FrappeSocketChannel`
  still has no tests. The whole write flow has been proven server-side and in
  widget tests, **never on a phone**.
- `ToolSpec.timeout` is declared and **not enforced** — an honest field with no
  mechanism behind it yet.
- No rate limit or token budget.
- Three probe leads on the dev site.
- The Ollama relay is still a temporary process.

## 19. NOT VERIFIED

The write flow on a physical device · OpenAI / Anthropic / OpenRouter live ·
tool timeout enforcement · concurrent confirmations from two real HTTP requests
(the race is proven at the `claim()` level, not through two simultaneous
requests).

## 20. Recommended Phase 6

**`crm.create_task`**, not `crm.update_lead`.

The reason is architectural rather than arbitrary: `create_lead` proved
*creation*. `CRM Task` has a genuinely different shape — its `name` is an
autoincrement **integer**, and it carries `reference_doctype`/`reference_name`,
so it is the first tool that must accept a *reference to an existing record*.
That exercises a part of the abstraction `create_lead` never touched, and it is
the natural next thing a user asks for after "покажи просроченные сделки".

`crm.update_lead` should follow, because updates need one thing writes do not:
showing the user what the value is *now* alongside what it would become.
