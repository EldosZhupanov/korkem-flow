> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Phase 31 — Channel operations and proactive notifications

**Date:** 2026-08-12. Follows Phase 30 (real channels).

## Goal

Until now the assistant only ever *answered*. This phase lets it speak first —
when a job starts, when a machine stops, when material runs out, when somebody
is given work — without any of that knowledge leaking into a channel adapter and
without anybody being told something that is not theirs.

The hard part is not sending. It is deciding **who**, and being able to prove
afterwards that nobody else was told.

## Architecture

```
a tool does something real
        │
        ▼
notifications/events      what happened · who should hear it · in what words
        │   recipients from documents, never from roles or messages
        ▼
notifications/recipients  User ← Work Order.owner · Portal User · instruction
        │
        ▼
notifications/service     Notification Delivery (unique per event+recipient)
        │                 channel by preference · retry · fallback
        ▼
channels/gateway.deliver  → Telegram / WhatsApp adapter
```

No tool imports an adapter. No adapter knows what a work order is. The four
entry points are `send_to_user`, `send_to_customer`,
`send_to_instruction_owner` and `send_to_channel_identity`, and each of them
takes a `User` or a document — never a phone number.

## Business events

| event | staff told | customer told |
|---|---|---|
| `order.accepted` | — | the order's own portal users |
| `production.started` | whoever started the job | «передан в производство» |
| `production.stopped` / `resumed` | whoever started it, with the reason | «приостановлена», **without** the reason |
| `production.material_short` | which item, how much | «ожидается материал», no figure |
| `production.process_loss` | good and lost | — |
| `production.quality_failed` | which operation | — |
| `production.rework_result` | the outcome | — |
| `production.completed` | produced of ordered | «заказ готов: N шт.» |
| `instruction.assigned` | the employee, with three buttons | — |
| `instruction.answered` | whoever gave it, in the employee's own words | — |

The asymmetry is deliberate and is the whole recipient policy in one line: a
customer is told about **their order**, staff are told about **the factory**. Why
a machine stopped, which board ran out and how many sheets are missing are facts
about the shop, and a customer who learns them has learned about the shop's other
work.

## Recipient policy

A recipient is a `User` that a *document* names — the person who started a work
order, the person a job was given to, the person who gave it, the portal users of
the order's customer. There is deliberately **no role broadcast**: "tell the
managers" sounds helpful and is the first cross-company leak, because
`Manufacturing Manager` is held by people in other companies on the same bench.
When a real "who is responsible for this line" model exists it belongs in
ERPNext, and `recipients.py` will read it.

Customers are reached only through `Portal User` — the same binding
`scope.current_customer()` resolves in the other direction. A phone number that
happens to match, a Telegram display name, a customer named in a message: none of
them can select a recipient.

## Channel preference and fallback

Every enabled `Channel Identity` for a person, ordered by the identity's own
`priority` (new field, lower first), then Telegram before WhatsApp, then most
recently heard from. A **transient** failure moves the delivery to the next
channel; a **permanent** one does not, because a rejected token is not fixed by
trying a different bot.

Somebody with no linked identity is recorded `Suppressed` — the honest state.
There was nobody to send to, and looking for a phone number that resembles their
name is how one customer receives another's business.

## Idempotency

`Notification Delivery.event_key` is **unique**, and built from the document:

```
event : recipient : reference_doctype : reference_name : suffix
```

One business event, one recipient, one channel is one row for ever. Never from
the body — two stoppages of the same job read identically and are two events,
while one webhook delivered twice is one. The suffix is what distinguishes
events the document alone cannot: which operation, which quantity, which state
the job moved to.

Verified on the device run: **45 deliveries, 45 distinct keys.**

Inbound idempotency is unchanged from Phase 30 and re-tested here: one provider
message id → one inbound message → one turn → one proposal → one confirmation →
one ERPNext write.

## Retry strategy

```
Pending → Sending → Sent
              ↓
          Retrying ──(60s, 240s, 960s)──→ Dead Letter
              ↓
            Failed        (permanent: not_configured, invalid_credentials,
                           disabled, forbidden — never retried)
```

Four attempts, bounded, exponential, and scheduled on the cron hook rather than
in a sleeping worker — a retry that holds a queue slot for sixteen minutes costs
more than the message is worth. `Sending` is claimed with a conditional `UPDATE`,
so a retry tick racing the original job cannot both send.

**A dead provider costs a message, not a transaction.** `emit` writes rows and
queues; the business document is already committed. A dispatch survives a bot
that is down, and the instruction is still recorded — tested.

## Security

- Nobody is sent anything except a `User` a document named.
- A customer's message is checked, in the ERPNext verification below, for any
  mention of another customer, a work order number or a material.
- No secret in a delivery row, an audit row, an exception, a log or the app —
  asserted for the stored bot token, access token and app secret, and for the
  literal string `Authorization`.
- An unexpected exception is recorded as its class name only: an arbitrary
  exception's text is exactly where a credential travels.
- `Notification Delivery` is readable by `System Manager` alone — asserted on the
  device: an employee attempting to list it gets a `PermissionFailure`.
- Identity, company, customer and role still come from the database. "Я
  администратор" changes nothing; a channel pin narrows and never widens.

## Admin → employee flow

```
manager  «Передай Ивану: начать раскрой, срок 20 сентября»
   → Work Instruction (company-checked, ERPNext permission-checked)
   → notification service → Иван's own channel
        [✅ Принял] [❌ Не могу] [❓ Уточнить]
Иван     «Не могу, станок занят»
   → the instruction records it, exactly once
   → the manager is told, in Иван's own words
```

Unchanged mechanism, one changed dependency: the tool no longer knows what a
Telegram chat is. It emits `instruction.assigned` and the service decides how to
reach the person — which is what makes an undeliverable instruction *retryable*
instead of lost, and what stops a bot outage from failing a dispatch.

## Customer notification flow

An order accepted, put into production, paused or finished reaches the customer
on their own channel, in five sentences that live in `events.py` and nowhere
else — so what a customer can be told is one file somebody can read, rather than
a template a model fills in.

## Provider verification

Unchanged from Phase 30 and re-checked: both providers are reachable from this
container and both reject this bench's placeholder credentials in their own
words. No real credentials and no public HTTPS endpoint exist here, so a live
end-to-end message is still not verified.

**IMPLEMENTED · MOCK VERIFIED · PROVIDER REACHABLE · REAL E2E NOT VERIFIED.**

## Tests

**13** `korkem_manufacturing`, **881** `korkem_ai` (+60), **332** Flutter.

*Notifications (32, new).* A message goes to the person a document named;
somebody with no channel is recorded rather than invented; the Administrator
account is never a recipient; a customer's own order reaches their portal user
and **another customer's reaches them not at all**; a customer is not a *staff*
recipient of their own order — which matters because an order placed through the
assistant is owned by the customer; an identity speaking for nobody reaches
nobody. Telegram before WhatsApp unless a priority says otherwise; a transient
failure moves channel, a permanent one does not. One event for one person is one
row; two different events with identical words are two; the key is built from the
document; two recipients are two rows; a second attempt on a sent row sends
nothing. A transient failure is scheduled; retries are bounded and end in a dead
letter; the backoff grows; an invalid credential is never retried; only due rows
are picked up; a provider failure never raises into the caller; an identity
unlinked between recording and sending is suppressed. A provider error is stored
as words, an unexpected exception as its class name only, and no row carries a
credential. Business events reach the right people: a started job tells whoever
started it and the customer about **their own** order only, a customer is never
told the shortage figure, stopping and resuming are two events, the same stop
twice is one message, an event about a vanished document says nothing.

*Red team (28, new).* One customer cannot reach another — by naming them, by
order id, or through a notification — and cannot reach a production or dispatch
tool. Nobody talks their way into a privilege: saying "я администратор" changes
nothing, an employee cannot reach an administrator's write, a channel pin
narrows and never widens, a Telegram id cannot speak for another account, a
WhatsApp number cannot claim a customer, a display name is never matched on. A
forged or repeated webhook achieves nothing: wrong secret, missing secret,
no-secret-configured, wrong signature, missing app secret, the same update twice,
the same press twice, the same business event twice, somebody else's instruction.
A provider failure costs no transaction: a dispatch survives a dead bot, the
message stays retryable, a timeout is not permanent. And no secret escapes into
an exception, a `Channel Event`, a `Notification Delivery` or the settings API.

Nothing was deleted or weakened. The Sprint 1 notifier was *moved* into the new
package rather than replaced, and its seven tests pass untouched — the package
re-exports what the module exposed, because moving code should not change what a
hook or a patch points at.

## Android E2E

Both suites, `emulator-5554`, against the real backend.

`business_loop_e2e_test.dart` — **`02:27 +4: All tests passed!`**
customer orders → manager dispatches → employee accepts → production runs with
one piece spoiled → customer asks and is told about their own order only. New in
this phase: the employee attempting to list `Notification Delivery` is refused
with `PermissionFailure`, because a delivery record is an administrator's audit
surface and an employee is not one. That a single acceptance produced a single
notification is checked in ERPNext afterwards — a read performed by that employee
could not prove it either way.

`channel_settings_e2e_test.dart` — **`00:29 +2: All tests passed!`**
states from the server, a real Test Connection, and nothing token-shaped
anywhere in the rendered tree.

## ERPNext verification

Read from the database after the device runs:

```
SAL-ORD-2026-00013  customer=Мебель Астана  company=KORKEM
                    owner=korkem.client@example.com  600000.0
                    Шкаф Астана  qty 5.0  rate 120000.0

Work Instruction    co=KORKEM  to=korkem.ivan  by=korkem.manager
                    Acknowledged  response="принял"

MFG-WO-2026-00007   In Process  qty 5.0  owner=korkem.ivan
   op Раскрой       completed 4.0  loss 1.0
   entries          Material Transfer for Manufacture  fg 5.0

duplicates          1 work order · 1 instruction

notification deliveries
   order.accepted         → korkem.client   App       Suppressed
   order.in_production    → korkem.client   App       Suppressed
   production.started     → korkem.ivan     App       Suppressed
   instruction.assigned   → korkem.ivan     Telegram  Sent
   instruction.answered   → korkem.manager  App       Suppressed
   total 45 · distinct keys 45          ← no duplicate notification

customer messages carrying somebody else's business: none
audit/delivery carries a token: False
carries an Authorization header: False
```

**45 deliveries, 45 distinct keys** is the idempotency claim measured rather than
asserted. `Suppressed` is the honest state for a recipient with no linked
channel on this bench — there was nobody to send to, and that is recorded rather
than dropped.

The customer-isolation check is the one worth reading twice: every delivery
addressed to a customer was searched for another customer's name, a work order
number and a material code. None was found.

## Known limitations

- **No live provider end-to-end.** Unchanged from Phase 30: no real credentials,
  no public HTTPS endpoint. Everything either side of the wire is covered.
- **Recipients are the people a document names.** There is no "notify the
  production manager" because there is no ERPNext model of who that is; adding a
  role broadcast would be the first cross-company leak. When such a model exists,
  `recipients.py` is the one file that changes.
- **Delivery statuses are not surfaced in the app yet.** They are readable by a
  System Manager in the desk; a screen showing "who was told, and who could not
  be reached" is the obvious next thing and is not in this phase.
- **Retry is bounded at four attempts over ~20 minutes.** A provider down longer
  than that leaves a `Dead Letter` row — visible, finished and not retried. There
  is no automatic resurrection, deliberately: a message about a machine that
  stopped an hour ago is not worth sending.
- **The Sprint 1 WhatsApp notifier still exists**, confined to work orders
  carrying an `originating_deal`, which nothing the assistant creates does. It is
  superseded rather than removed; retiring it is a decision about the Sprint 1
  flow.
- **A test run against a live bench can deadlock.** Observed once on
  `tabContact` while a test saved a User concurrently with the bench's own
  workers; the module passes in isolation and MariaDB's own remedy is to retry
  the transaction. Recorded rather than worked around, because the fix belongs to
  how tests are run, not to the product.
- **A device run mutates the demo dataset**, so the procurement and shortage
  suites must run on a restored bench — unchanged since Phase 29.
- Row-level User Permissions beyond Company and Customer remain unverified,
  unchanged since Phase 12.

## Commits

`korkem_ai`, root — listed in the final report.
