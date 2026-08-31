> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Phase 32 — Channel operations, delivery centre and dispatch board

**Date:** 2026-08-12. Follows Phase 31 (proactive notifications).

## Goal

Phase 31 made the system able to speak. This one makes it **operable**: an
administrator who is told "Telegram is broken" or "Иван never got the job" can
find out what is actually true, and do something about it, without reading a log
file or opening the Frappe desk.

Nothing about the brain, the tools or ERPNext changed. What changed is the
surface an operator works through.

## Channel health is an answer, not a colour

Each channel now reports a health object rather than a bare state:

| | |
|---|---|
| `code` | what to branch on |
| `message` | a sentence to read |
| `retryable` | whether waiting could plausibly help — the difference between "wait" and "go and fix something" |
| `checked_at` | when a real call was last made |
| `last_error` | the provider's own words |
| `failed_deliveries` · `pending_retries` | what this channel is currently costing |

`READY` still is not `CONNECTED`: only a real successful call earns the second.
Alongside it the screen now shows the bot's username or the WhatsApp display
name — read from the provider at the last successful check, and a name rather
than a credential — plus when the channel last carried a message each way, read
from the conversation transcript and the delivery record rather than from
counters somebody has to remember to increment.

## Provider refusals are told apart

One function classifies an HTTP status, used by both adapters, because two
adapters disagreeing about what is retryable is two retry policies:

```
401 · 404  invalid_credentials   permanent — the token is wrong
403        forbidden             permanent — the chat blocked the bot
429        rate_limited          retryable — this is what backoff is for
5xx        provider_unavailable  retryable
```

Before this, a 429 and a 403 were both `provider_error`: one was retried when it
should have been, the other retried when it could never work.

## Operations

New endpoints, all `System Manager` only:

- `send_test_message` — one real message **to a linked identity**, never to a
  number typed into a screen. A settings page that can message arbitrary numbers
  is a settings page that can be used to message anybody.
- `disconnect_channel` — switch off and remove the webhook, **without** deleting
  credentials. "Turn it off for now" and "forget my bot token" are different
  intentions, and conflating them makes the destructive one the easy one.
- `list_deliveries` / `retry_delivery` / `cancel_delivery` / `retry_all_deliveries`
- `list_work_instructions` — read through `get_list`, so it is a view and not a
  door.
- `set_identity_priority` — which way to reach somebody first.

Identity rows now carry a masked address (`••••0020`): an administrator picking
the right row needs to recognise a number, not read it out, and every action
takes the row's own name.

## Retry, and the races it has to survive

`reopen` and `cancel` are conditional `UPDATE`s, exactly like `Pending Action.claim`:

- two administrators tapping Retry → **one** send;
- a Retry racing the scheduler → one send;
- a `Sent` delivery → not retryable at all, because re-sending it is the
  duplicate this whole model exists to prevent;
- a `Suppressed` one → not retryable either: there was nobody to send to, and
  that is not fixed by trying harder;
- a `Dead Letter` → retryable **only** by explicit action; the scheduler sweeps
  `Retrying` and nothing else, so an exhausted delivery never resurrects itself.

`attempt_count` is deliberately not reset by a manual retry — how hard something
has already been tried is the thing an operator is looking at.

## The dispatch board, and not duplicating work

`Work Instruction` gained two states: **Clarification Requested** (a question
settles nothing, so it stays open — but is no longer indistinguishable from
silence) and **Expired**.

And the behaviour §11 asks for: a second instruction to the same employee about
the same order, while the first is still open, **updates it**. «Тогда сделай
завтра до 12:00» is the same job with a new deadline, and two live cards for one
piece of work is how it gets done twice. Once somebody has accepted or refused,
it becomes a new instruction instead — changing what they answered would rewrite
what they agreed to.

## Flutter

Two screens under Settings, both administrator-facing:

- **Delivery centre** — every message the system tried to send: event, person,
  channel, status, attempts, next attempt, the provider's own error, and the
  `event_key` that makes it unique. Filter chips counted from the server's own
  totals. Retry and Cancel offered on exactly the states where they mean
  something.
- **Work instructions** — who was asked, what, on which channel, what they
  answered and how long they took. No actions: dispatching is a decision the
  assistant records after somebody confirms it, and a button that re-sent an
  instruction would be a second way to create one.

Named "delivery centre" rather than "notifications" because the app already has
a notifications screen — that one is what *this user* was told; this is the
operator's view of every message sent to anybody.

## Tests

**13** `korkem_manufacturing`, **922** `korkem_ai` (+41), **344** Flutter (+12).

*Channel operations (39, new).* Every health state has a sentence and a verdict
on whether waiting helps; a rejected credential is not worth waiting out and an
unreachable provider is; the status carries both channels' health; it counts
what could not be delivered; `READY` is still not `CONNECTED`; traffic is read
from what already happened. Provider refusals are told apart — 401 permanent,
403 permanent and a different fix, **429 retryable**, 5xx retryable — and a
rate-limited message is scheduled while a blocked chat is not retried at all.
Retrying by hand: an administrator can try again; a dead letter needs asking and
does not resurrect itself; **retrying twice sends once**; a delivered message is
never re-sent; cancelling stops the attempts and survives `retry_all`; a
suppressed one is not retried because there was nobody; a missing row says so;
only an administrator may retry. The board lists and summarises, narrows by
state and channel, carries no credential, and is administrator-only. A test
message goes to a linked identity and never to a typed number, refuses an
identity on another channel, and records its failure as the channel's health.
Disconnecting switches off **without** forgetting the credentials. Identity
addresses are masked, priority decides routing order, and only an administrator
may reorder them. The dispatch board reports how long somebody took to answer
and grants nothing beyond what ERPNext allows.

*Dispatch lifecycle (+2).* A second instruction to the same employee about the
same order **updates the open one** rather than duplicating it; an instruction
that has already been answered is never rewritten.

*Flutter (+12).* The delivery centre names the event, the person and the
channel; a delivered message offers no Retry and a failed one does; a dead
letter can be retried by asking; a suppressed one offers nothing; attempts and
the last error are shown; nothing token-shaped is ever rendered; an empty board
says so; the filters count from the server's own totals. The dispatch board
shows who was asked, what they answered and how long they took, and treats a
question as still open.

Two existing tests were updated because the behaviour they described changed on
purpose — a second instruction now updates, and a question now has its own
status. Both still assert the same claim, against the new rule.

## Android E2E

`business_loop_e2e_test.dart` — **`02:38 +4: All tests passed!`**
`channel_settings_e2e_test.dart` — **`00:33 +2: All tests passed!`**

Both re-run unchanged against the reworked dispatch and health code: the whole
customer → manager → employee → production → customer loop still holds, an
employee still cannot read the delivery records, and the settings screen still
shows no credential and no invented green light.

## ERPNext verification

Read from the database after the device runs:

```
SAL-ORD-2026-00011  customer=Мебель Астана  company=KORKEM
                    owner=korkem.client@example.com  600000.0
                    Шкаф Астана  qty 5.0  rate 120000.0

Work Instruction    to=korkem.ivan  by=korkem.manager  Acknowledged  «принял»
                    instructions on that order: 1     ← not duplicated

MFG-WO-2026-00007   In Process  qty 5.0  owner=korkem.ivan
   op Раскрой       completed 4.0  loss 1.0
                    work orders on that order: 1

deliveries          total 45 · distinct keys 45
summary             Sent 15 · Suppressed 30 · Pending/Retrying/Failed/
                    Dead Letter/Cancelled 0

customer messages carrying somebody else's business: none
health              telegram invalid_credentials (retryable False)
                    whatsapp disabled
operations API carries a token: False
carries an Authorization header: False
```

`Suppressed 30` is the honest count of messages with nobody to send to on this
bench, and `Sent 15` of those that went out. The health line is the placeholder
credential being rejected by the real Telegram API and correctly classified as
**not** worth retrying.

## Security

- Every operations endpoint is `System Manager` only, asserted per endpoint.
- A test message can only go to an identity an administrator has already bound
  to a person; there is no path from this API to an arbitrary chat address.
- Identity addresses are masked in the list, and every action takes the row's
  own name rather than the number.
- No credential in any response, delivery row, audit row, exception or rendered
  widget — asserted for the stored bot token and access token, for the literal
  string `Authorization`, and for anything token-shaped in the widget tree.
- Customer isolation re-verified from the sending side after the device run:
  every delivery addressed to a customer searched for another customer's name, a
  work order number, a material code and an employee's name. None found.
- Disconnect does not delete credentials; retry cannot re-send a delivered
  message; a dead letter cannot revive itself.

## Real provider status

**IMPLEMENTED · MOCK VERIFIED · PROVIDER REACHABLE · REAL E2E NOT VERIFIED.**
Unchanged from Phase 30: no real credentials and no public HTTPS endpoint exist
in this environment. The operator flow they would be entered through — token →
Test → Register webhook → Send test — is complete and tested against mocks.

## Limitations

- **No live provider end-to-end.** Unchanged: no real credentials, no public
  HTTPS endpoint in this environment.
- **The delivery centre has no paging.** It shows the most recent 50 (200 with
  an explicit limit); a bench that has been running for months will need paging
  before this screen is useful there.
- **`Expired` is a state nothing sets yet.** The status exists on
  `Work Instruction` so a board can show it; the sweep that would set it belongs
  with a decision about how long a job may wait unanswered, which nobody has
  made.
- **The delivery board is administrator-only by design**, so an employee cannot
  see whether a message to them failed — they experience it as silence. Telling
  them would mean giving them the table, and the table has everybody's messages
  in it.
- **A device run mutates the demo dataset**, so the procurement and shortage
  suites must run on a restored bench — unchanged since Phase 29.
- Row-level User Permissions beyond Company and Customer remain unverified,
  unchanged since Phase 12.

## Commits

`korkem_ai`, root — listed in the final report.
